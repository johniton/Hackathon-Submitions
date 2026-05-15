"""
redis_client.py — Async Redis wrapper for the Job Scraper microservice.

Responsibilities:
  1. Job search result caching (TTL = 1800s / 30 min)
  2. Deduplication hash storage (TTL = 86400s / 24 h)

Cache key format:
  jobs:{source}:{sha256(serialised_search_params)}

Falls back gracefully if Redis is unavailable (logs warning, returns None on get).
"""

import hashlib
import json
import logging
from typing import Optional

import redis.asyncio as aioredis

from config import REDIS_URL, REDIS_CACHE_TTL, REDIS_DEDUP_TTL

logger = logging.getLogger(__name__)

_JOBS_PREFIX = "jobs:"
_DEDUP_PREFIX = "dedup:"


class RedisClient:
    """
    Async Redis client wrapper.
    Call `await RedisClient.create()` to get an initialised instance.
    """

    def __init__(self, pool: aioredis.Redis) -> None:
        self._r = pool

    @classmethod
    async def create(cls) -> "RedisClient":
        pool = aioredis.from_url(REDIS_URL, encoding="utf-8", decode_responses=True)
        instance = cls(pool)
        # Test connection at startup; log warning instead of crashing if Redis is down.
        try:
            await pool.ping()
            logger.info("Redis connected: %s", REDIS_URL)
        except Exception as exc:  # noqa: BLE001
            logger.warning("Redis unavailable at startup: %s — caching disabled.", exc)
        return instance

    # ── Cache helpers ─────────────────────────────────────────────────────────

    @staticmethod
    def build_cache_key(source: str, params_dict: dict) -> str:
        """
        Deterministic cache key based on search parameters.
        params_dict should be the serialised SearchJobsParams dict.
        """
        params_hash = hashlib.sha256(
            json.dumps(params_dict, sort_keys=True).encode()
        ).hexdigest()
        return f"{_JOBS_PREFIX}{source}:{params_hash}"

    async def get_cached_jobs(self, key: str) -> Optional[str]:
        """Returns raw JSON string if cached, else None."""
        try:
            return await self._r.get(key)
        except Exception as exc:  # noqa: BLE001
            logger.warning("Redis GET failed: %s", exc)
            return None

    async def set_cached_jobs(self, key: str, payload: str) -> None:
        """Stores serialised job list JSON with REDIS_CACHE_TTL expiry."""
        try:
            await self._r.setex(key, REDIS_CACHE_TTL, payload)
            logger.debug("Cached %d chars under key '%s' (TTL=%ds).", len(payload), key, REDIS_CACHE_TTL)
        except Exception as exc:  # noqa: BLE001
            logger.warning("Redis SET failed: %s", exc)

    # ── Deduplication helpers ─────────────────────────────────────────────────

    async def exists(self, key: str) -> bool:
        """Returns True if the key exists in Redis."""
        try:
            return bool(await self._r.exists(key))
        except Exception as exc:  # noqa: BLE001
            logger.warning("Redis EXISTS failed: %s", exc)
            return False

    async def set_dedup(self, key: str) -> None:
        """Stores a deduplication marker with REDIS_DEDUP_TTL (24h) expiry."""
        try:
            await self._r.setex(key, REDIS_DEDUP_TTL, "1")
        except Exception as exc:  # noqa: BLE001
            logger.warning("Redis SETEX (dedup) failed: %s", exc)

    # ── Lifecycle ─────────────────────────────────────────────────────────────

    async def close(self) -> None:
        await self._r.aclose()
