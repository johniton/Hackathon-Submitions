"""
instahyre_scraper.py

Scrapes jobs from Instahyre.
Strategy 1: Direct JSON API (fast, reliable)
Strategy 2: Playwright fallback (if API schema changes or requires tokens)
"""

import hashlib
import logging
import urllib.parse
from datetime import datetime, timezone
from typing import Dict, List, Optional

from models.job_listing import JobListing, SearchJobsParams
from scrapers.base_scraper import BaseScraper

logger = logging.getLogger(__name__)


def _make_id(company: str, title: str, location: str) -> str:
    raw = f"{company.lower()}{title.lower()}{location.lower()}"
    return hashlib.sha256(raw.encode()).hexdigest()


class InstahyreScraper(BaseScraper):
    domain = "instahyre.com"
    _API_URL = "https://www.instahyre.com/api/v1/job_search"
    _BASE_URL = "https://www.instahyre.com"

    async def _scrape(self, params: SearchJobsParams) -> List[JobListing]:
        try:
            return await self._scrape_api(params)
        except Exception as exc:  # noqa: BLE001
            logger.warning("Instahyre API failed: %s. Falling back to Playwright.", exc)
            return await self._scrape_playwright(params)

    async def _scrape_api(self, params: SearchJobsParams) -> List[JobListing]:
        skills = urllib.parse.quote_plus(params.keywords)
        location = urllib.parse.quote_plus(params.location)
        url = f"{self._API_URL}?search=true&skills={skills}&location={location}"

        headers = {
            "Accept": "application/json",
            "Referer": "https://www.instahyre.com/search-jobs/",
        }

        async with self._http_client() as client:
            resp = await client.get(url, headers=headers)
            resp.raise_for_status()

        data = resp.json()
        jobs_raw = data.get("objects", [])
        logger.info("Instahyre API: found %d jobs.", len(jobs_raw))

        results: List[JobListing] = []
        for job in jobs_raw[:20]:
            try:
                title = job.get("title", "Unknown Title")
                company_obj = job.get("employer", {})
                company = company_obj.get("company_name", "Unknown Company")
                
                loc_list = job.get("locations", [])
                if loc_list:
                    first_loc = loc_list[0]
                    loc = first_loc if isinstance(first_loc, str) else first_loc.get("name", params.location)
                else:
                    loc = params.location
                
                exp_min = job.get("experience_min", 0)
                exp_max = job.get("experience_max", 0)
                exp_req = f"{exp_min}-{exp_max} Yrs" if exp_max > 0 else "Fresher"

                job_id = job.get("id")
                source_url = job.get("public_url")
                if not source_url:
                    source_url = f"{self._BASE_URL}/job-{job_id}-{title.lower().replace(' ', '-')}-at-{company.lower().replace(' ', '-')}" if job_id else f"{self._BASE_URL}/search-jobs"

                listing = JobListing(
                    id=_make_id(company, title, loc),
                    title=title,
                    company=company,
                    location=loc,
                    salary_range=None,  # Instahyre usually hides salary behind login
                    experience_required=exp_req,
                    skills_required=[s if isinstance(s, str) else s.get("name", "") for s in job.get("skills", [])],
                    description=job.get("description", "")[:4000],
                    source="instahyre",
                    source_url=source_url,
                    posted_at=None,
                    scraped_at=datetime.now(timezone.utc),
                    freshness_days=params.freshness_days,
                    trust_score="verified",
                )
                results.append(listing)
            except Exception as e:
                logger.debug("Error parsing Instahyre job: %s", e)

        return results

    async def _scrape_playwright(self, params: SearchJobsParams) -> List[JobListing]:
        skills = urllib.parse.quote_plus(params.keywords)
        location = urllib.parse.quote_plus(params.location)
        url = f"{self._BASE_URL}/search-jobs/?skills={skills}&location={location}"

        page = await self._get_page()
        results: List[JobListing] = []

        try:
            await page.goto(url, wait_until="networkidle")
            
            cards = await page.query_selector_all(".employer-row")
            logger.info("Instahyre Playwright: found %d cards.", len(cards))

            for card in cards[:20]:
                try:
                    comp_title_el = await card.query_selector('.company-name')
                    link_el       = await card.query_selector('a#employer-profile-opportunity, a.job-title')

                    if not comp_title_el:
                        continue

                    raw_text = (await comp_title_el.inner_text()).strip()
                    parts = raw_text.split(" - ", 1)
                    if len(parts) == 2:
                        company, title = parts[0].strip(), parts[1].strip()
                    else:
                        company, title = raw_text, "Software Engineer"
                        
                    href = await link_el.get_attribute('href') if link_el else ""
                    source_url = href if href and href.startswith("http") else (f"{self._BASE_URL}{href}" if href else url)

                    listing = JobListing(
                        id=_make_id(company, title, params.location),
                        title=title,
                        company=company,
                        location=params.location,
                        source="instahyre",
                        source_url=source_url,
                        scraped_at=datetime.now(timezone.utc),
                        freshness_days=params.freshness_days,
                        description="",
                        trust_score="verified",
                    )
                    results.append(listing)
                except Exception as e:
                    logger.debug("Skipping Instahyre card: %s", e)

        except Exception as exc:
            logger.error("Instahyre Playwright failed: %s", exc)
        finally:
            await page.context.close()

        return results
