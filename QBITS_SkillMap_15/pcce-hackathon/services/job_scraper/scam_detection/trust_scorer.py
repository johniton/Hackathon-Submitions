"""
scam_detection/trust_scorer.py — Orchestrates the full scam detection pipeline.

This is the ONLY module called by the API routes. It runs:
  1. Redis cache check (6h TTL)
  2. Rule engine (Layer 1)
  3. ML classifier (Layer 2, only if inconclusive)
  4. Domain validator
  5. Community flags
  6. Final scoring aggregation
  7. Cache result
"""

import json
import logging
from datetime import datetime, timezone
from typing import Optional

from models.job_listing import JobListing
from scam_detection import rule_engine, ml_classifier, domain_validator, community_flags
from scam_detection.models import ScamAnalysisInput, ScamAnalysisResult

logger = logging.getLogger(__name__)

_RESULT_PREFIX = "scam:result:"
_RESULT_TTL = 21_600  # 6 hours


# ── Public API ────────────────────────────────────────────────────────────────

async def analyse_listing(redis, input_data: ScamAnalysisInput) -> ScamAnalysisResult:
    """
    Full scam detection pipeline. Returns a ScamAnalysisResult.

    Args:
        redis:      RedisClient instance (from app.state.redis)
        input_data: ScamAnalysisInput containing the listing and optional user_id
    """
    listing = input_data.listing
    job_id = listing.id

    # ── 1. Check Redis cache ──────────────────────────────────────────────────
    cached = await _get_cached(redis, job_id)
    if cached:
        return cached

    # ── 2. Rule Engine (Layer 1) ──────────────────────────────────────────────
    rule_result = rule_engine.check(listing)

    flag_reasons: list[str] = []
    rule_triggers: list[str] = list(rule_result.hard_rule_triggers + rule_result.soft_rule_triggers)

    # Build human-readable flag reasons from rule triggers
    for trigger in rule_result.hard_rule_triggers:
        flag_reasons.append(f"Hard rule triggered: {_humanise_trigger(trigger)}")
    for trigger in rule_result.soft_rule_triggers:
        flag_reasons.append(f"Soft rule triggered: {_humanise_trigger(trigger)}")

    # ── 3. ML Classifier (Layer 2) — only if inconclusive ─────────────────────
    ml_score: Optional[float] = None
    if not rule_result.skip_ml:
        ml_score = ml_classifier.classify(
            title=listing.title,
            company=listing.company,
            description=listing.description,
        )
        if ml_score is not None:
            flag_reasons.append(f"ML classifier confidence: {ml_score:.0%}")
            rule_triggers.append(f"ML:score={ml_score:.4f}")

    # ── 4. Domain Validator ───────────────────────────────────────────────────
    domain_result = await domain_validator.validate(listing)
    flag_reasons.extend(domain_result.flag_reasons)
    verified_company = domain_result.verified_company

    # ── 5. Community Flags ────────────────────────────────────────────────────
    flag_count = await community_flags.get_flag_count(redis, job_id)

    # ── 6. Final Scoring Aggregation ──────────────────────────────────────────
    verdict = rule_result.verdict  # start with rule engine verdict

    # ML override: ml_score >= 0.75 → force "flagged"
    if ml_score is not None and ml_score >= 0.75:
        verdict = "flagged"

    # Community override: flag_count >= 5 → force "flagged"
    if flag_count >= 5:
        verdict = "flagged"
        flag_reasons.append(f"Community: {flag_count} users flagged this listing.")

    # Community downgrade: flag_count >= 2 → downgrade one level
    elif flag_count >= 2:
        if verdict == "verified":
            verdict = "caution"
        elif verdict == "caution":
            verdict = "flagged"
        flag_reasons.append(f"Community: {flag_count} users flagged this listing.")

    # Verified company uplift: if verified AND no hard rules → force "verified"
    if verified_company and not rule_result.hard_rule_triggers:
        verdict = "verified"

    # ── Compute confidence ────────────────────────────────────────────────────
    confidence = _compute_confidence(rule_result.suspicion_score, ml_score, flag_count, verified_company)

    # ── 7. Assemble result ────────────────────────────────────────────────────
    result = ScamAnalysisResult(
        job_id=job_id,
        trust_score=verdict,
        confidence=confidence,
        flag_reasons=flag_reasons,
        rule_triggers=rule_triggers,
        ml_score=ml_score,
        community_flag_count=flag_count,
        verified_company=verified_company,
        analysed_at=datetime.now(timezone.utc),
        from_cache=False,
    )

    # ── 8. Cache result ───────────────────────────────────────────────────────
    await _cache_result(redis, job_id, result)

    logger.info(
        "Scam analysis complete for job %s → %s (confidence=%.2f)",
        job_id, verdict, confidence,
    )
    return result


async def get_cached_result(redis, job_id: str) -> Optional[ScamAnalysisResult]:
    """Retrieve a previously cached ScamAnalysisResult."""
    return await _get_cached(redis, job_id)


# ── Internal helpers ──────────────────────────────────────────────────────────

async def _get_cached(redis, job_id: str) -> Optional[ScamAnalysisResult]:
    key = f"{_RESULT_PREFIX}{job_id}"
    try:
        raw = await redis.get_cached_jobs(key)
        if raw:
            data = json.loads(raw)
            result = ScamAnalysisResult(**data)
            result.from_cache = True
            return result
    except Exception as exc:
        logger.debug("Cache miss or parse error for %s: %s", job_id, exc)
    return None


async def _cache_result(redis, job_id: str, result: ScamAnalysisResult) -> None:
    key = f"{_RESULT_PREFIX}{job_id}"
    try:
        payload = result.model_dump_json()
        await redis._r.setex(key, _RESULT_TTL, payload)
        logger.debug("Cached scam result for job %s (TTL=%ds).", job_id, _RESULT_TTL)
    except Exception as exc:
        logger.warning("Failed to cache scam result: %s", exc)


def _compute_confidence(
    suspicion_score: int,
    ml_score: Optional[float],
    flag_count: int,
    verified_company: bool,
) -> float:
    """
    Weighted confidence score (0.0–1.0) where 1.0 = high confidence in the verdict.
    """
    # Rule engine component (40% weight)
    rule_conf = min(suspicion_score / 100.0, 1.0) * 0.4

    # ML component (35% weight) — 0 if unavailable
    ml_conf = (ml_score or 0.0) * 0.35

    # Community component (15% weight)
    community_conf = min(flag_count / 5.0, 1.0) * 0.15

    # Verified company bonus (10% weight, inverted — verified = lower scam confidence)
    company_conf = 0.0 if verified_company else 0.10

    raw = rule_conf + ml_conf + community_conf + company_conf
    return round(min(max(raw, 0.0), 1.0), 4)


def _humanise_trigger(trigger: str) -> str:
    """Convert a technical trigger name to a human-readable reason."""
    mapping = {
        "H1:fresher_salary_unrealism": "Salary appears unrealistically high for a fresher role",
        "H3:whatsapp_only_contact": "Listing uses WhatsApp-only contact with no company email",
        "H4:no_company_name": "Company name is missing or invalid",
        "H5:url_parse_error": "Job source URL could not be parsed",
        "H5:untrusted_tld": "Job source URL uses an untrusted domain extension",
        "H6:tiny_description": "Job description is suspiciously short (< 80 characters)",
        "S1:vague_company_info": "No company website or LinkedIn URL in description",
        "S2:wide_salary_range": "Salary range is suspiciously wide",
        "S3:excessive_caps_punctuation": "Title contains excessive capitalization or punctuation",
        "S5:no_skills_listed": "No required skills listed",
        "S7:personal_email": "Description contains a personal email instead of company email",
        "S8:non_standard_title": "Job title does not match any common role",
    }
    # Handle dynamic triggers like "H2:payment_demand:pay registration fee"
    if trigger.startswith("H2:payment_demand:"):
        phrase = trigger.split(":", 2)[2]
        return f"Description contains suspicious phrase: '{phrase}'"
    if trigger.startswith("H5:url_shortener:"):
        shortener = trigger.split(":", 2)[2]
        return f"Job URL uses a URL shortener ({shortener})"
    if trigger.startswith("H5:suspicious_double_extension"):
        return "Job URL has a suspicious double domain extension"
    if trigger.startswith("S4:mlm_keyword:"):
        kw = trigger.split(":", 2)[2]
        return f"Description contains MLM/scam keyword: '{kw}'"
    if trigger.startswith("S6:individual_poster:"):
        return "Job appears to be posted by an individual, not a company"
    return mapping.get(trigger, trigger)
