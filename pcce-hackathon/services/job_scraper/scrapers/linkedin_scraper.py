"""
linkedin_scraper.py

Primary strategy  : linkedin-jobs-scraper PyPI package (handles auth + pagination).
Fallback strategy : Playwright headless scrape of public LinkedIn job search pages
                    (used when the package is blocked or credentials are absent).
"""

import hashlib
import logging
from datetime import datetime, timezone
from typing import List

from models.job_listing import JobListing, SearchJobsParams
from scrapers.base_scraper import BaseScraper
from config import LINKEDIN_EMAIL, LINKEDIN_PASSWORD

logger = logging.getLogger(__name__)


def _make_id(company: str, title: str, location: str) -> str:
    raw = f"{company.lower()}{title.lower()}{location.lower()}"
    return hashlib.sha256(raw.encode()).hexdigest()


def _parse_skills(description: str) -> List[str]:
    """
    Naive keyword extraction for common tech skills from job descriptions.
    In production, replace with an NLP model or LLM extraction.
    """
    keywords = [
        "python", "java", "javascript", "typescript", "react", "node.js", "flutter",
        "dart", "kotlin", "swift", "sql", "postgresql", "mysql", "mongodb",
        "docker", "kubernetes", "aws", "gcp", "azure", "git", "rest api",
        "graphql", "redis", "kafka", "spark", "tensorflow", "pytorch",
        "scikit-learn", "fastapi", "django", "flask", "spring boot", "go",
        "rust", "c++", "c#", ".net", "android", "ios", "firebase", "figma",
    ]
    desc_lower = description.lower()
    return [k for k in keywords if k in desc_lower]


class LinkedInScraper(BaseScraper):
    domain = "linkedin.com"

    async def _scrape(self, params: SearchJobsParams) -> List[JobListing]:
        # Try package-based scrape first (requires credentials)
        if LINKEDIN_EMAIL and LINKEDIN_PASSWORD:
            try:
                return await self._scrape_with_package(params)
            except Exception as exc:  # noqa: BLE001
                logger.warning("linkedin-jobs-scraper package failed (%s). Falling back to Playwright.", exc)

        # Playwright fallback — scrapes public job search without login
        return await self._scrape_with_playwright(params)

    # ── Strategy 1: linkedin-jobs-scraper package ─────────────────────────────

    async def _scrape_with_package(self, params: SearchJobsParams) -> List[JobListing]:
        """
        Uses the `linkedin_jobs_scraper` PyPI package.
        Runs in a thread executor because the library is synchronous.
        """
        import asyncio
        from functools import partial

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, partial(self._sync_scrape, params))

    def _sync_scrape(self, params: SearchJobsParams) -> List[JobListing]:
        from linkedin_jobs_scraper import LinkedinScraper as LIScraper  # type: ignore
        from linkedin_jobs_scraper.events import Events, EventData  # type: ignore
        from linkedin_jobs_scraper.query import Query, QueryOptions, QueryFilters  # type: ignore
        from linkedin_jobs_scraper.filters import ExperienceLevelFilters, TypeFilters  # type: ignore

        results: List[JobListing] = []
        scraper = LIScraper(chrome_executable_path=None, headless=True, slow_mo=50, page_load_timeout=40)

        def on_data(data: EventData) -> None:
            description = data.description or ""
            listing = JobListing(
                id=_make_id(data.company or "", data.title or "", data.place or ""),
                title=data.title or "Unknown Title",
                company=data.company or "",
                location=data.place or params.location,
                salary_range=None,
                experience_required=None,
                skills_required=_parse_skills(description),
                description=description[:4000],
                source="linkedin",
                source_url=data.link or "",
                posted_at=data.date,
                scraped_at=datetime.now(timezone.utc),
                freshness_days=params.freshness_days,
                trust_score="verified",
                flag_reasons=[],
                match_score=0.0,
                is_duplicate=False,
            )
            results.append(listing)

        def on_error(error: Exception) -> None:
            logger.error("LinkedIn scraper error: %s", error)

        scraper.on(Events.DATA, on_data)
        scraper.on(Events.ERROR, on_error)

        queries = [
            Query(
                query=params.keywords,
                options=QueryOptions(
                    locations=[params.location],
                    limit=20,
                    filters=QueryFilters(
                        relevance="RECENT",
                        time="PAST_WEEK" if params.freshness_days <= 7 else "ANY_TIME",
                    ),
                ),
            )
        ]
        scraper.run(queries)
        return results

    # ── Strategy 2: Playwright fallback ───────────────────────────────────────

    async def _scrape_with_playwright(self, params: SearchJobsParams) -> List[JobListing]:
        """
        Scrapes LinkedIn public job search page.
        No login required — gives limited but usable data.
        """
        import urllib.parse

        query = urllib.parse.quote_plus(params.keywords)
        location = urllib.parse.quote_plus(params.location)
        url = (
            f"https://www.linkedin.com/jobs/search"
            f"?keywords={query}&location={location}&f_TPR=r604800&position=1&pageNum=0"
        )

        page = await self._get_page()
        results: List[JobListing] = []

        try:
            await page.goto(url, wait_until="domcontentloaded")
            await page.wait_for_selector(".jobs-search__results-list", timeout=15000)

            job_cards = await page.query_selector_all(".jobs-search__results-list li")
            logger.info("LinkedIn Playwright: found %d job cards.", len(job_cards))

            for card in job_cards[:20]:
                try:
                    title = await card.query_selector(".base-search-card__title")
                    company = await card.query_selector(".base-search-card__subtitle")
                    location_el = await card.query_selector(".job-search-card__location")
                    link_el = await card.query_selector("a.base-card__full-link")
                    date_el = await card.query_selector("time")

                    title_text = (await title.inner_text()).strip() if title else "Unknown"
                    company_text = (await company.inner_text()).strip() if company else ""
                    location_text = (await location_el.inner_text()).strip() if location_el else params.location
                    href = await link_el.get_attribute("href") if link_el else ""
                    posted_at_str = await date_el.get_attribute("datetime") if date_el else None

                    posted_at = datetime.fromisoformat(posted_at_str) if posted_at_str else None

                    listing = JobListing(
                        id=_make_id(company_text, title_text, location_text),
                        title=title_text,
                        company=company_text,
                        location=location_text,
                        description="",
                        source="linkedin",
                        source_url=href or url,
                        posted_at=posted_at,
                        scraped_at=datetime.now(timezone.utc),
                        freshness_days=params.freshness_days,
                        trust_score="verified",
                    )
                    results.append(listing)
                except Exception as exc:  # noqa: BLE001
                    logger.debug("Skipping LinkedIn card: %s", exc)

        except Exception as exc:
            logger.error("LinkedIn Playwright scrape failed: %s", exc)
        finally:
            await page.context.close()

        return results
