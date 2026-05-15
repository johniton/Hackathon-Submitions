"""
internshala_scraper.py

Scrapes internships from Internshala.com using httpx and BeautifulSoup4.
Much faster and more reliable than Playwright because Internshala doesn't block raw HTML fetching.
"""

import hashlib
import logging
import urllib.parse
from datetime import datetime, timezone
from typing import List

import httpx
from bs4 import BeautifulSoup

from scrapers.base_scraper import BaseScraper
from models.job_listing import JobListing, SearchJobsParams
from config import USER_AGENTS
import random

logger = logging.getLogger(__name__)


def _make_id(company: str, title: str, location: str) -> str:
    raw = f"{company}-{title}-{location}".lower()
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


class InternshalaScaper(BaseScraper):
    domain = "internshala.com"
    _BASE_URL = "https://internshala.com"

    async def _scrape(self, params: SearchJobsParams) -> List[JobListing]:
        """
        Main entry point for BaseScraper.
        Fetches raw HTML via httpx and parses it using BeautifulSoup.
        """
        # Format URL e.g. https://internshala.com/internships/python-internship-in-india
        skills = params.keywords.lower().replace(" ", "-")
        location = params.location.lower().replace(" ", "-")
        
        # If user explicitly disabled internshala or didn't select it, return empty
        if "internshala" not in params.sources:
            return []

        url = f"{self._BASE_URL}/internships/{skills}-internship-in-{location}"
        
        results: List[JobListing] = []
        try:
            # Use random UA
            headers = {"User-Agent": random.choice(USER_AGENTS)}
            
            async with httpx.AsyncClient() as client:
                resp = await client.get(url, headers=headers, timeout=15.0)
                resp.raise_for_status()
                html = resp.text
                
                soup = BeautifulSoup(html, "html.parser")
                cards = soup.find_all("div", class_="individual_internship")
                
                logger.info("Internshala BS4: %d cards found.", len(cards))
                
                for card in cards[:20]:
                    try:
                        title_el = card.find(class_="job-internship-name")
                        company_el = card.find(class_="company-name")
                        
                        if not title_el or not company_el:
                            # Fallback to older classes
                            title_el = card.find(class_="heading_4_5")
                            company_el = card.find(class_="company_name")
                            if not title_el or not company_el:
                                continue
                                
                        title = title_el.get_text(strip=True)
                        # Clean company noise like '\n\n \n' and rating stars
                        company = company_el.get_text(strip=True).split('\n')[0].strip()
                        
                        # Find link
                        link_el = card.find("a", class_="job-title-href") or (title_el.find("a") if title_el else None)
                        href = link_el["href"] if link_el and link_el.has_attr("href") else ""
                        source_url = f"{self._BASE_URL}{href}" if href else url
                        
                        # Find loc
                        loc_el = card.find(class_="locations")
                        loc = loc_el.get_text(strip=True) if loc_el else params.location
                        
                        listing = JobListing(
                            id=_make_id(company, title, loc),
                            title=title,
                            company=company,
                            location=loc,
                            source="internshala",
                            source_url=source_url,
                            scraped_at=datetime.now(timezone.utc),
                            freshness_days=params.freshness_days,
                            description="",
                            trust_score="verified",
                        )
                        results.append(listing)
                    except Exception as e:
                        logger.debug("Skipping Internshala card: %s", e)
                        
        except Exception as exc:
            logger.error("Internshala BS4 failed: %s", exc)

        return results
