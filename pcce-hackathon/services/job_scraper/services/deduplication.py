"""
deduplication.py — Hash-based deduplication across LinkedIn + Naukri results.

Uses Redis to store seen hashes with a 24-hour TTL so the same job listing
doesn't appear twice even when results are scraped minutes apart.
"""

import hashlib
import logging
from typing import List

from cache.redis_client import RedisClient

logger = logging.getLogger(__name__)

_DEDUP_PREFIX = "dedup:"


def _listing_hash(company: str, title: str, location: str) -> str:
    raw = f"{company.strip().lower()}{title.strip().lower()}{location.strip().lower()}"
    return hashlib.sha256(raw.encode()).hexdigest()


class DeduplicationService:
    """
    Checks whether a job listing has been seen before in the current 24-hour window.
    Persists seen hashes in Redis with DEDUP_TTL expiry.
    """

    def __init__(self, redis: RedisClient) -> None:
        self._redis = redis

    async def check_and_mark(
        self,
        company: str,
        title: str,
        location: str,
    ) -> bool:
        """
        Returns True if this listing is a duplicate (already seen).
        Marks the listing as seen in Redis if it is new.
        """
        h = _listing_hash(company, title, location)
        key = f"{_DEDUP_PREFIX}{h}"

        try:
            already_seen = await self._redis.exists(key)
            if already_seen:
                logger.debug("Duplicate detected: %s @ %s (%s)", title, company, location)
                return True

            await self._redis.set_dedup(key)
            return False
        except Exception as exc:  # noqa: BLE001
            # If Redis is unavailable, treat as non-duplicate so scraping continues.
            logger.warning("Redis unavailable for dedup check: %s. Treating as unique.", exc)
            return False

    async def filter_duplicates(self, listings: list) -> list:
        """
        Batch-filters a list of JobListing objects.
        Sets `is_duplicate = True` on duplicates but keeps them in the list
        so the API can optionally surface them with a flag.
        """
        for listing in listings:
            is_dup = await self.check_and_mark(
                listing.company,
                listing.title,
                listing.location,
            )
            listing.is_duplicate = is_dup
        return listings
