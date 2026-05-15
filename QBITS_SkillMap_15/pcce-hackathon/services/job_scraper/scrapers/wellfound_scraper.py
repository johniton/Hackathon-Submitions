"""
wellfound_scraper.py

Scrapes startup/tech jobs from Wellfound (formerly AngelList Talent).
Strategy 1: GraphQL API (same endpoint their frontend uses)
Strategy 2: Public listing page via Playwright fallback
"""

import hashlib
import json
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


class WellfoundScraper(BaseScraper):
    domain = "wellfound.com"
    _BASE_URL = "https://wellfound.com"
    _GRAPHQL_URL = "https://wellfound.com/graphql"

    async def _scrape(self, params: SearchJobsParams) -> List[JobListing]:
        try:
            return await self._scrape_graphql(params)
        except Exception as exc:
            logger.warning("Wellfound GraphQL failed: %s. Trying Playwright.", exc)
            return await self._scrape_playwright(params)

    async def _scrape_graphql(self, params: SearchJobsParams) -> List[JobListing]:
        """Uses Wellfound's internal GraphQL API."""
        query = """
        query JobsSearchQuery($query: String!, $locationType: String) {
          jobs(query: $query, locationTypes: [$locationType], first: 20) {
            edges {
              node {
                id
                title
                slug
                locationNames
                employmentType
                description
                skills { name }
                minCompensation
                maxCompensation
                startups {
                  name
                  highlightedJobListingTag
                }
              }
            }
          }
        }
        """

        variables = {
            "query": params.keywords,
            "locationTypes": "IN_OFFICE",
        }

        headers = {
            "Content-Type": "application/json",
            "Referer": f"{self._BASE_URL}/jobs",
            "Accept": "application/json",
        }

        payload = {"query": query, "variables": variables}

        async with self._http_client() as client:
            resp = await client.post(self._GRAPHQL_URL, json=payload, headers=headers)
            resp.raise_for_status()

        data = resp.json()
        edges = data.get("data", {}).get("jobs", {}).get("edges", [])
        logger.info("Wellfound GraphQL: %d jobs found.", len(edges))

        results: List[JobListing] = []
        for edge in edges:
            node = edge.get("node", {})
            try:
                title = node.get("title", "Unknown")
                startups = node.get("startups", [{}])
                company = startups[0].get("name", "Unknown Startup") if startups else "Unknown Startup"
                loc_list = node.get("locationNames", [])
                location = ", ".join(loc_list) if loc_list else "India"
                
                min_comp = node.get("minCompensation")
                max_comp = node.get("maxCompensation")
                salary = f"${min_comp}k – ${max_comp}k" if min_comp and max_comp else None

                slug = node.get("slug", "")
                source_url = f"{self._BASE_URL}/jobs/{slug}" if slug else f"{self._BASE_URL}/jobs"

                listing = JobListing(
                    id=_make_id(company, title, location),
                    title=title,
                    company=company,
                    location=location,
                    salary_range=salary,
                    experience_required=node.get("employmentType"),
                    skills_required=[s.get("name", "") for s in node.get("skills", [])],
                    description=(node.get("description") or "")[:4000],
                    source="wellfound",
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
                logger.debug("Skipping Wellfound node: %s", e)

        return results

    async def _scrape_playwright(self, params: SearchJobsParams) -> List[JobListing]:
        keywords = urllib.parse.quote_plus(params.keywords)
        url = f"{self._BASE_URL}/jobs?q={keywords}&l=India"

        page = await self._get_page()
        results: List[JobListing] = []
        try:
            await page.goto(url, wait_until="domcontentloaded")
            await page.wait_for_selector('[data-test="JobsListItem"]', timeout=10000)
            cards = await page.query_selector_all('[data-test="JobsListItem"]')
            logger.info("Wellfound Playwright: %d cards.", len(cards))

            for card in cards[:20]:
                try:
                    title_el = await card.query_selector("h2")
                    company_el = await card.query_selector('[data-test="startup-result-name"]')
                    link_el = await card.query_selector("a")

                    title = (await title_el.inner_text()).strip() if title_el else "Unknown"
                    company = (await company_el.inner_text()).strip() if company_el else "Unknown"
                    href = await link_el.get_attribute("href") if link_el else ""
                    source_url = f"{self._BASE_URL}{href}" if href and not href.startswith("http") else (href or url)

                    listing = JobListing(
                        id=_make_id(company, title, "India"),
                        title=title,
                        company=company,
                        location="India",
                        description="",
                        source="wellfound",
                        source_url=source_url,
                        scraped_at=datetime.now(timezone.utc),
                        freshness_days=params.freshness_days,
                        trust_score="verified",
                        flag_reasons=[],
                        match_score=0.0,
                        is_duplicate=False,
                    )
                    results.append(listing)
                except Exception as e:
                    logger.debug("Skipping Wellfound card: %s", e)
        except Exception as exc:
            logger.error("Wellfound Playwright failed: %s", exc)
        finally:
            await page.context.close()

        return results
