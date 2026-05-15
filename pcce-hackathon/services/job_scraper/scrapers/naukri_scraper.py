"""
naukri_scraper.py

Naukri.com is built on Next.js — the full job listing payload is embedded in a
<script id="__NEXT_DATA__"> JSON tag on every search page. We extract that JSON
directly rather than parsing rendered HTML, which is far more reliable and fast.

Fallback: If the Next.js data tag is absent (Naukri A/B test or CDN variant),
we fall back to Playwright + CSS selector parsing.
"""

import json
import hashlib
import logging
import urllib.parse
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import httpx

from models.job_listing import JobListing, SearchJobsParams
from scrapers.base_scraper import BaseScraper

logger = logging.getLogger(__name__)


def _make_id(company: str, title: str, location: str) -> str:
    raw = f"{company.lower()}{title.lower()}{location.lower()}"
    return hashlib.sha256(raw.encode()).hexdigest()


def _safe_str(val: Any, default: str = "") -> str:
    return str(val).strip() if val else default


def _parse_skills_from_naukri(job: Dict) -> List[str]:
    """Extract skills from Naukri's keySkills field (list of dicts or plain list)."""
    raw = job.get("keySkills") or job.get("skillDetails") or []
    if isinstance(raw, list):
        skills = []
        for item in raw:
            if isinstance(item, dict):
                skills.append(item.get("label", item.get("skill", "")))
            elif isinstance(item, str):
                skills.append(item)
        return [s.strip() for s in skills if s.strip()]
    return []


def _parse_salary(job: Dict) -> Optional[str]:
    low = job.get("minimumSalary")
    high = job.get("maximumSalary")
    label = job.get("salary", job.get("salaryLabel"))
    if label:
        return _safe_str(label)
    if low and high:
        return f"₹{low}L – ₹{high}L"
    return None


def _parse_posted_at(job: Dict) -> Optional[datetime]:
    """Naukri stores Unix epoch in milliseconds under various keys."""
    ts = job.get("footerPlaceholderLabel", {}).get("postDate") \
        or job.get("createdDate") \
        or job.get("modifiedDate")
    if ts:
        try:
            return datetime.fromtimestamp(int(ts) / 1000, tz=timezone.utc)
        except (ValueError, OSError):
            pass
    return None


class NaukriScraper(BaseScraper):
    domain = "naukri.com"

    _BASE_URL = "https://www.naukri.com"
    _API_URL = "https://www.naukri.com/jobapi/v3/search"

    async def _scrape(self, params: SearchJobsParams) -> List[JobListing]:
        # Attempt 1: Naukri's internal API (fast, structured JSON)
        try:
            return await self._scrape_via_api(params)
        except Exception as exc:  # noqa: BLE001
            logger.warning("Naukri API scrape failed (%s). Falling back to Playwright.", exc)

        # Attempt 2: Playwright + __NEXT_DATA__ extraction
        try:
            return await self._scrape_via_playwright(params)
        except Exception as exc:
            logger.error("Naukri Playwright scrape also failed: %s", exc)
            return []

    # ── Strategy 1: Naukri's internal search API ──────────────────────────────

    async def _scrape_via_api(self, params: SearchJobsParams) -> List[JobListing]:
        """
        Naukri exposes an undocumented but stable JSON API used by their own web app.
        We mimic the XHR headers their frontend sends.
        """
        keywords_encoded = urllib.parse.quote_plus(params.keywords)
        location_encoded = urllib.parse.quote_plus(params.location)

        api_url = (
            f"{self._API_URL}"
            f"?noOfResults=20"
            f"&urlType=search_by_keyword"
            f"&searchType=adv"
            f"&keyword={keywords_encoded}"
            f"&location={location_encoded}"
            f"&experience={params.experience_years}"
            f"&pageNo=1"
        )

        headers = {
            "Accept": "application/json",
            "systemcountrycode": "IN",
            "gid": "LOCATION,INDUSTRY,EDUCATION,FAREA_ROLE",
            "Referer": "https://www.naukri.com/",
            "appid": "109",
            "clientid": "d3skt0p",
        }

        async with self._http_client() as client:
            resp = await client.get(api_url, headers=headers)
            resp.raise_for_status()

        data = resp.json()
        jobs_raw: List[Dict] = data.get("jobDetails", [])
        logger.info("Naukri API: got %d raw jobs.", len(jobs_raw))
        return [self._map_api_job(j, params) for j in jobs_raw]

    def _map_api_job(self, job: Dict, params: SearchJobsParams) -> JobListing:
        title = _safe_str(job.get("title"), "Unknown Title")
        company = _safe_str(job.get("companyName"))
        location_list: List = job.get("placeholders", [])
        location = (location_list[0].get("label", "") if location_list else "") or params.location
        description = _safe_str(job.get("jobDescription", job.get("description", "")))
        job_id_raw = _safe_str(job.get("jobId", ""))

        return JobListing(
            id=job_id_raw or _make_id(company, title, location),
            title=title,
            company=company,
            location=location,
            salary_range=_parse_salary(job),
            experience_required=_safe_str(job.get("experienceText")) or None,
            skills_required=_parse_skills_from_naukri(job),
            description=description[:4000],
            source="naukri",
            source_url=_safe_str(job.get("jdURL")) or f"{self._BASE_URL}/job-listings-{job_id_raw}",
            posted_at=_parse_posted_at(job),
            scraped_at=datetime.now(timezone.utc),
            freshness_days=params.freshness_days,
            trust_score="verified",
            flag_reasons=[],
            match_score=0.0,
            is_duplicate=False,
        )

    # ── Strategy 2: Playwright + __NEXT_DATA__ ────────────────────────────────

    async def _scrape_via_playwright(self, params: SearchJobsParams) -> List[JobListing]:
        keywords_slug = params.keywords.lower().replace(" ", "-")
        location_slug = params.location.lower().replace(" ", "-")
        url = f"{self._BASE_URL}/{keywords_slug}-jobs-in-{location_slug}"

        page = await self._get_page()
        results: List[JobListing] = []

        try:
            await page.goto(url, wait_until="networkidle")

            # Extract __NEXT_DATA__ JSON blob
            next_data_el = await page.query_selector("script#__NEXT_DATA__")
            if next_data_el:
                json_text = await next_data_el.inner_text()
                next_data: Dict = json.loads(json_text)
                jobs_raw = (
                    next_data
                    .get("props", {})
                    .get("pageProps", {})
                    .get("jobList", [])
                )
                logger.info("Naukri __NEXT_DATA__: found %d jobs.", len(jobs_raw))
                return [self._map_api_job(j, params) for j in jobs_raw[:20]]

            # Last resort: CSS selector scrape
            job_cards = await page.query_selector_all("article.jobTuple")
            logger.info("Naukri CSS fallback: found %d cards.", len(job_cards))

            for card in job_cards[:20]:
                try:
                    title_el = await card.query_selector("a.title")
                    company_el = await card.query_selector("a.subTitle")
                    location_el = await card.query_selector("span.location")
                    link_el = await card.query_selector("a.title")

                    title = (await title_el.inner_text()).strip() if title_el else "Unknown"
                    company = (await company_el.inner_text()).strip() if company_el else ""
                    loc = (await location_el.inner_text()).strip() if location_el else params.location
                    href = await link_el.get_attribute("href") if link_el else ""

                    listing = JobListing(
                        id=_make_id(company, title, loc),
                        title=title,
                        company=company,
                        location=loc,
                        description="",
                        source="naukri",
                        source_url=href or url,
                        scraped_at=datetime.now(timezone.utc),
                        freshness_days=params.freshness_days,
                        trust_score="verified",
                    )
                    results.append(listing)
                except Exception as exc:  # noqa: BLE001
                    logger.debug("Skipping Naukri card: %s", exc)

        except Exception as exc:
            logger.error("Naukri Playwright page load failed: %s", exc)
        finally:
            await page.context.close()

        return results
