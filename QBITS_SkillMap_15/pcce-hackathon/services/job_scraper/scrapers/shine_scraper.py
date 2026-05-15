"""
shine_scraper.py

Scrapes jobs from Shine.com — a major India-focused job portal.
Strategy 1: Shine's internal search JSON API
Strategy 2: Playwright HTML fallback
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


class ShineScraper(BaseScraper):
    domain = "shine.com"
    _BASE_URL = "https://www.shine.com"
    _SEARCH_URL = "https://www.shine.com/job-search/{keywords}-jobs-in-{location}"

    async def _scrape(self, params: SearchJobsParams) -> List[JobListing]:
        try:
            return await self._scrape_playwright(params)
        except Exception as exc:
            logger.error("Shine scrape failed: %s", exc)
            return []

    async def _scrape_playwright(self, params: SearchJobsParams) -> List[JobListing]:
        kw_slug  = params.keywords.lower().replace(" ", "-")
        loc_slug = params.location.lower().replace(" ", "-")
        url = f"{self._BASE_URL}/job-search/{kw_slug}-jobs-in-{loc_slug}"

        page = await self._get_page()
        results: List[JobListing] = []

        try:
            await page.goto(url, wait_until="domcontentloaded")
            # Wait for job listings to render
            await page.wait_for_selector(".jobCard, .job-card, [class*='jobCard']", timeout=12000)
            cards = await page.query_selector_all(".jobCard, [class*='jobCard']")
            logger.info("Shine: %d cards found.", len(cards))

            for card in cards[:20]:
                try:
                    title_el   = await card.query_selector("h2 a, .job-title a, [class*='jobTitle'] a")
                    company_el = await card.query_selector("[class*='companyName'], [class*='company-name']")
                    loc_el     = await card.query_selector("[class*='location'], [class*='Location']")
                    sal_el     = await card.query_selector("[class*='salary'], [class*='Salary']")
                    link_el    = await card.query_selector("a[href*='/job/']")

                    if not title_el:
                        continue

                    title    = (await title_el.inner_text()).strip()
                    company  = (await company_el.inner_text()).strip() if company_el else "Unknown"
                    location = (await loc_el.inner_text()).strip()     if loc_el     else params.location
                    salary   = (await sal_el.inner_text()).strip()     if sal_el     else None
                    href     = await link_el.get_attribute("href")     if link_el    else ""
                    source_url = f"{self._BASE_URL}{href}" if href.startswith("/") else (href or url)

                    listing = JobListing(
                        id=_make_id(company, title, location),
                        title=title,
                        company=company,
                        location=location,
                        salary_range=salary or None,
                        experience_required=None,
                        skills_required=[],
                        description="",
                        source="shine",
                        source_url=source_url,
                        posted_at=None,
                        scraped_at=datetime.now(timezone.utc),
                        freshness_days=params.freshness_days,
                        trust_score="verified",
                        flag_reasons=[],
                        match_score=0.0,
                        is_duplicate=False,
                    )
                    results.append(listing)
                except Exception as e:
                    logger.debug("Skipping Shine card: %s", e)

        except Exception as exc:
            logger.error("Shine Playwright failed: %s", exc)
        finally:
            await page.context.close()

        logger.info("Shine: returning %d jobs.", len(results))
        return results
