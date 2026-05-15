"""
base_scraper.py — Abstract base class for all scrapers.

Provides:
  - asyncio.Semaphore-based per-domain rate limiting (1 req / 3s)
  - Exponential backoff retry logic with 429 special handling
  - Random human-like delay between requests
  - Playwright browser context factory with anti-detection settings
  - Optional proxy injection
"""

import asyncio
import random
import logging
from abc import ABC, abstractmethod
from datetime import datetime
from typing import List, Optional

import httpx
from playwright.async_api import async_playwright, Browser, BrowserContext, Page

from config import (
    USER_AGENTS,
    RATE_LIMIT_DELAY_MIN,
    RATE_LIMIT_DELAY_MAX,
    MAX_RETRIES,
    RETRY_DELAYS,
    RATE_LIMIT_BACKOFF,
    REQUEST_TIMEOUT,
    PLAYWRIGHT_TIMEOUT,
    PROXY_URL,
)
from models.job_listing import JobListing, SearchJobsParams

logger = logging.getLogger(__name__)

# One semaphore per domain — enforces max 1 concurrent request per domain
_domain_semaphores: dict[str, asyncio.Semaphore] = {}


def _get_semaphore(domain: str) -> asyncio.Semaphore:
    if domain not in _domain_semaphores:
        _domain_semaphores[domain] = asyncio.Semaphore(1)
    return _domain_semaphores[domain]


class BaseScraper(ABC):
    """
    All scrapers inherit from this class.
    Subclasses implement `_scrape()` which is called automatically
    with retry and rate-limit logic applied.
    """

    domain: str = "unknown"  # Override in subclass: e.g. "linkedin.com"

    def __init__(self) -> None:
        self._browser: Optional[Browser] = None
        self._playwright = None

    # ── Public entry point ────────────────────────────────────────────────────

    async def scrape(self, params: SearchJobsParams) -> List[JobListing]:
        """
        Wraps `_scrape()` with per-domain semaphore + exponential backoff retry.
        """
        semaphore = _get_semaphore(self.domain)
        async with semaphore:
            return await self._with_retry(params)

    # ── Retry wrapper ─────────────────────────────────────────────────────────

    async def _with_retry(self, params: SearchJobsParams) -> List[JobListing]:
        last_exc: Exception = RuntimeError("Unknown scraper error")
        for attempt in range(MAX_RETRIES):
            try:
                await self._random_delay()
                return await self._scrape(params)
            except httpx.HTTPStatusError as exc:
                last_exc = exc
                if exc.response.status_code == 429:
                    logger.warning(
                        "[%s] Rate limited (429). Backing off %ds.",
                        self.domain,
                        RATE_LIMIT_BACKOFF,
                    )
                    await asyncio.sleep(RATE_LIMIT_BACKOFF)
                else:
                    delay = RETRY_DELAYS[attempt] if attempt < len(RETRY_DELAYS) else RETRY_DELAYS[-1]
                    logger.warning(
                        "[%s] HTTP %d on attempt %d. Retrying in %ds.",
                        self.domain,
                        exc.response.status_code,
                        attempt + 1,
                        delay,
                    )
                    await asyncio.sleep(delay)
            except Exception as exc:  # noqa: BLE001
                last_exc = exc
                delay = RETRY_DELAYS[attempt] if attempt < len(RETRY_DELAYS) else RETRY_DELAYS[-1]
                logger.error(
                    "[%s] Attempt %d failed: %s. Retrying in %ds.",
                    self.domain,
                    attempt + 1,
                    exc,
                    delay,
                )
                await asyncio.sleep(delay)
        logger.error("[%s] All %d retries exhausted.", self.domain, MAX_RETRIES)
        raise last_exc

    # ── Abstract scrape method ────────────────────────────────────────────────

    @abstractmethod
    async def _scrape(self, params: SearchJobsParams) -> List[JobListing]:
        """Implement the actual scraping logic here."""
        ...

    # ── Playwright helpers ────────────────────────────────────────────────────

    async def _get_browser(self) -> Browser:
        """Lazily start a persistent Playwright Chromium browser."""
        if self._browser is None or not self._browser.is_connected():
            self._playwright = await async_playwright().start()
            launch_args = [
                "--disable-blink-features=AutomationControlled",
                "--no-sandbox",
                "--disable-dev-shm-usage",
            ]
            proxy_config = {"server": PROXY_URL} if PROXY_URL else None
            self._browser = await self._playwright.chromium.launch(
                headless=True,
                args=launch_args,
                proxy=proxy_config,
            )
        return self._browser

    async def _new_context(self) -> BrowserContext:
        """Create a fresh browser context with randomised UA and stealth settings."""
        browser = await self._get_browser()
        ua = random.choice(USER_AGENTS)
        context = await browser.new_context(
            user_agent=ua,
            viewport={"width": random.randint(1280, 1920), "height": random.randint(720, 1080)},
            locale="en-IN",
            timezone_id="Asia/Kolkata",
            java_script_enabled=True,
            bypass_csp=True,
        )
        # Patch navigator.webdriver to avoid detection
        await context.add_init_script("""
            Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
            Object.defineProperty(navigator, 'plugins', { get: () => [1, 2, 3] });
        """)
        return context

    async def _get_page(self) -> Page:
        context = await self._new_context()
        page = await context.new_page()
        page.set_default_timeout(PLAYWRIGHT_TIMEOUT)
        return page

    # ── HTTP helper ───────────────────────────────────────────────────────────

    def _http_client(self) -> httpx.AsyncClient:
        headers = {"User-Agent": random.choice(USER_AGENTS)}
        proxy = PROXY_URL or None
        return httpx.AsyncClient(
            headers=headers,
            timeout=REQUEST_TIMEOUT,
            proxy=proxy if proxy else None,
            follow_redirects=True,
        )

    # ── Delay helper ──────────────────────────────────────────────────────────

    @staticmethod
    async def _random_delay() -> None:
        delay = random.uniform(RATE_LIMIT_DELAY_MIN, RATE_LIMIT_DELAY_MAX)
        logger.debug("Sleeping %.2fs (rate limit delay).", delay)
        await asyncio.sleep(delay)

    # ── Cleanup ───────────────────────────────────────────────────────────────

    async def close(self) -> None:
        if self._browser:
            await self._browser.close()
        if self._playwright:
            await self._playwright.stop()
