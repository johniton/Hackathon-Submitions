"""
api/routes.py — All FastAPI route handlers for the Job Scraper microservice.

Endpoints:
  GET  /health
  POST /jobs/search
  GET  /jobs/{job_id}
  POST /jobs/scam-check
  POST /scam/analyse
  POST /scam/report
  GET  /scam/result/{job_id}
  GET  /scam/flagged
"""

import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, HTTPException, Query, Request

from models.job_listing import (
    JobListing,
    ScamCheckRequest,
    ScamCheckResponse,
    ScrapedJobResponse,
    SearchJobsParams,
)
from scrapers.linkedin_scraper import LinkedInScraper
from scrapers.naukri_scraper import NaukriScraper
from scrapers.instahyre_scraper import InstahyreScraper
from scrapers.internshala_scraper import InternshalaScaper
from scrapers.shine_scraper import ShineScraper
from services.deduplication import DeduplicationService
from services.scam_detector import ScamDetector
from services.ranker import Ranker

# New scam detection pipeline imports
from scam_detection.models import (
    ScamAnalysisInput,
    ScamAnalysisResult,
    ReportScamRequest,
    ReportScamResponse,
)
from scam_detection import rule_engine
from scam_detection.trust_scorer import analyse_listing, get_cached_result
from scam_detection.community_flags import add_flag, get_flag_count, should_re_analyse

logger = logging.getLogger(__name__)
router = APIRouter()

# Module-level singletons (initialised once at startup)
_scam_detector = ScamDetector()
_ranker = Ranker()

# In-memory job store — keyed by job.id
# In production replace with Redis hash or PostgreSQL.
_job_store: dict[str, JobListing] = {}


# ─── /health ──────────────────────────────────────────────────────────────────

@router.get("/health")
async def health() -> dict:
    return {
        "status": "ok",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "job-scraper",
    }


# ─── POST /jobs/search ────────────────────────────────────────────────────────

@router.post("/jobs/search", response_model=ScrapedJobResponse)
async def search_jobs(params: SearchJobsParams, request: Request) -> ScrapedJobResponse:
    """
    Scrapes LinkedIn and/or Naukri for matching job listings.
    Results are deduplicated, scam-checked, ranked by skill match, and cached.
    """
    redis = request.app.state.redis
    dedup_svc = DeduplicationService(redis)

    # ── Build & check cache key ───────────────────────────────────────────────
    cache_key = redis.build_cache_key(
        source="+".join(sorted(params.sources)),
        params_dict=params.model_dump(),
    )
    cached_raw = await redis.get_cached_jobs(cache_key)
    if cached_raw:
        logger.info("Cache HIT for key: %s", cache_key)
        jobs = [JobListing(**j) for j in json.loads(cached_raw)]
        return ScrapedJobResponse(jobs=jobs, total=len(jobs), from_cache=True)

    logger.info("Cache MISS — scraping sources: %s", params.sources)

    # ── Scrape in parallel ────────────────────────────────────────────────────
    scrape_tasks = []
    scrapers = []

    if "linkedin" in params.sources:
        li_scraper = LinkedInScraper()
        scrapers.append(li_scraper)
        scrape_tasks.append(li_scraper.scrape(params))

    if "naukri" in params.sources:
        nk_scraper = NaukriScraper()
        scrapers.append(nk_scraper)
        scrape_tasks.append(nk_scraper.scrape(params))

    if "instahyre" in params.sources:
        ih_scraper = InstahyreScraper()
        scrapers.append(ih_scraper)
        scrape_tasks.append(ih_scraper.scrape(params))

    if "internshala" in params.sources:
        is_scraper = InternshalaScaper()
        scrapers.append(is_scraper)
        scrape_tasks.append(is_scraper.scrape(params))

    if "shine" in params.sources:
        sh_scraper = ShineScraper()
        scrapers.append(sh_scraper)
        scrape_tasks.append(sh_scraper.scrape(params))

    results_per_source = await asyncio.gather(*scrape_tasks, return_exceptions=True)

    # Close scraper browser instances
    for scraper in scrapers:
        await scraper.close()

    # ── Flatten results (skip failed scrapers gracefully) ─────────────────────
    all_jobs: List[JobListing] = []
    for res in results_per_source:
        if isinstance(res, Exception):
            logger.error("A scraper failed (skipped): %s", res)
        else:
            all_jobs.extend(res)

    # ── Deduplication ─────────────────────────────────────────────────────────
    all_jobs = await dedup_svc.filter_duplicates(all_jobs)

    # ── Scam detection ────────────────────────────────────────────────────────
    for job in all_jobs:
        result = rule_engine.check(job)
        job.trust_score = result.verdict
        job.flag_reasons = result.hard_rule_triggers + result.soft_rule_triggers
        job.scam_percentage = 100 if result.verdict == "flagged" else min(100, result.suspicion_score)

    # ── Rank by skill match ───────────────────────────────────────────────────
    all_jobs = _ranker.rank(all_jobs, params.user_skills)

    # ── Persist to in-memory store for /jobs/{id} ─────────────────────────────
    for job in all_jobs:
        _job_store[job.id] = job

    # ── Cache results ─────────────────────────────────────────────────────────
    payload = json.dumps([j.model_dump(mode="json") for j in all_jobs], default=str)
    await redis.set_cached_jobs(cache_key, payload)

    return ScrapedJobResponse(jobs=all_jobs, total=len(all_jobs), from_cache=False)


# ─── GET /jobs/{job_id} ───────────────────────────────────────────────────────

@router.get("/jobs/{job_id}", response_model=JobListing)
async def get_job(job_id: str) -> JobListing:
    """Returns a previously scraped job listing by its ID (sha256 hash)."""
    job = _job_store.get(job_id)
    if not job:
        raise HTTPException(
            status_code=404,
            detail=f"Job '{job_id}' not found. Run /jobs/search first to populate the store.",
        )
    return job


# ─── POST /jobs/scam-check ────────────────────────────────────────────────────

@router.post("/jobs/scam-check", response_model=ScamCheckResponse)
async def scam_check(body: ScamCheckRequest) -> ScamCheckResponse:
    """
    Accepts either a job_id (to look up from store) or a raw JobListing object.
    Returns trust_score and flag_reasons.
    """
    if body.job_id:
        job = _job_store.get(body.job_id)
        if not job:
            raise HTTPException(
                status_code=404,
                detail=f"Job '{body.job_id}' not found in store.",
            )
    elif body.raw_listing:
        job = body.raw_listing
    else:
        raise HTTPException(
            status_code=422,
            detail="Provide either 'job_id' or 'raw_listing'.",
        )

    result = rule_engine.check(job)
    return ScamCheckResponse(
        trust_score=result.verdict,
        flag_reasons=result.hard_rule_triggers + result.soft_rule_triggers
    )


# ─── POST /scam/analyse ──────────────────────────────────────────────────────

@router.post("/scam/analyse", response_model=ScamAnalysisResult)
async def scam_analyse(body: ScamAnalysisInput, request: Request) -> ScamAnalysisResult:
    """
    Full scam detection pipeline: rule engine → ML classifier → domain
    validation → community flags → trust score aggregation.
    Results are cached for 6 hours.
    """
    redis = request.app.state.redis
    return await analyse_listing(redis, body)


# ─── POST /scam/report ───────────────────────────────────────────────────────

@router.post("/scam/report", response_model=ReportScamResponse)
async def scam_report(body: ReportScamRequest, request: Request) -> ReportScamResponse:
    """
    Submit a community flag for a job listing.
    Auto-triggers re-analysis if the flag count reaches 3.
    """
    redis = request.app.state.redis

    flag_count_val = await add_flag(
        redis=redis,
        job_id=body.job_id,
        user_id=body.user_id,
        reason=body.reason,
        details=body.details,
    )

    # Auto-escalation: re-analyse if flag_count hits threshold
    if should_re_analyse(flag_count_val):
        job = _job_store.get(body.job_id)
        if job:
            logger.info("Auto re-analysis triggered for job %s (flags=%d).", body.job_id, flag_count_val)
            input_data = ScamAnalysisInput(listing=job)
            # Invalidate cache by running fresh analysis
            await analyse_listing(redis, input_data)

    return ReportScamResponse(success=True, flag_count=flag_count_val)


# ─── GET /scam/result/{job_id} ────────────────────────────────────────────────

@router.get("/scam/result/{job_id}", response_model=ScamAnalysisResult)
async def scam_result(job_id: str, request: Request) -> ScamAnalysisResult:
    """Returns a previously cached ScamAnalysisResult for the given job ID."""
    redis = request.app.state.redis
    result = await get_cached_result(redis, job_id)
    if not result:
        raise HTTPException(
            status_code=404,
            detail=f"No scam analysis result found for job '{job_id}'. Run POST /scam/analyse first.",
        )
    return result


# ─── GET /scam/flagged ────────────────────────────────────────────────────────

@router.get("/scam/flagged")
async def scam_flagged(
    request: Request,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> dict:
    """
    Returns job IDs with trust_score 'flagged', sorted by community flag count
    (descending). Used by the admin review queue.
    """
    redis = request.app.state.redis

    # Collect flagged jobs from in-memory store
    flagged_entries = []
    for job_id, job in _job_store.items():
        if job.trust_score == "flagged":
            count = await get_flag_count(redis, job_id)
            flagged_entries.append({"job_id": job_id, "flag_count": count, "title": job.title, "company": job.company})

    # Sort by flag_count descending
    flagged_entries.sort(key=lambda x: x["flag_count"], reverse=True)

    # Paginate
    total = len(flagged_entries)
    paginated = flagged_entries[offset : offset + limit]

    return {"flagged_jobs": paginated, "total": total, "limit": limit, "offset": offset}
