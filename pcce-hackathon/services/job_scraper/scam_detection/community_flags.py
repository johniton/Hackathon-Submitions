"""
scam_detection/community_flags.py — Redis-backed community scam reporting.

Users can flag job listings as scams. Flags are stored in Redis with a 30-day TTL.
User IDs are SHA-256 hashed — raw IDs are never persisted.

Redis key format:  scam:flags:{job_id}
Value:             JSON list of CommunityFlag entries
TTL:               30 days (2_592_000 seconds)
"""

import hashlib
import json
import logging
from datetime import datetime, timezone
from typing import List, Optional

from scam_detection.models import CommunityFlag

logger = logging.getLogger(__name__)

_FLAGS_PREFIX = "scam:flags:"
_FLAGS_TTL = 2_592_000  # 30 days in seconds


def _hash_user_id(user_id: str) -> str:
    """SHA-256 hash of a raw user ID — never store the original."""
    return hashlib.sha256(user_id.encode("utf-8")).hexdigest()


# ── Public API ────────────────────────────────────────────────────────────────

async def add_flag(
    redis,
    job_id: str,
    user_id: str,
    reason: str,
    details: Optional[str] = None,
) -> int:
    """
    Add a community flag for a job listing.

    Args:
        redis:   RedisClient instance (from app.state.redis)
        job_id:  The job listing ID
        user_id: Raw user ID (will be hashed before storage)
        reason:  One of the allowed CommunityFlag.reason literals
        details: Optional free-text details (max 200 chars)

    Returns:
        Updated flag count for the job.
    """
    key = f"{_FLAGS_PREFIX}{job_id}"
    user_hash = _hash_user_id(user_id)

    flag = CommunityFlag(
        job_id=job_id,
        reported_by_user_hash=user_hash,
        reason=reason,
        details=details[:200] if details else None,
        reported_at=datetime.now(timezone.utc),
    )

    try:
        # Get existing flags
        existing_raw = await redis.get_cached_jobs(key)
        if existing_raw:
            flags_list = json.loads(existing_raw)
        else:
            flags_list = []

        # Prevent duplicate reports from the same user
        for existing_flag in flags_list:
            if existing_flag.get("reported_by_user_hash") == user_hash:
                logger.info("Duplicate flag from user %s… for job %s — skipping.", user_hash[:8], job_id)
                return len(flags_list)

        # Append new flag
        flags_list.append(flag.model_dump(mode="json"))

        # Store with TTL
        payload = json.dumps(flags_list, default=str)
        try:
            await redis._r.setex(key, _FLAGS_TTL, payload)
        except Exception as exc:
            logger.warning("Redis SETEX (community flag) failed: %s", exc)

        flag_count = len(flags_list)
        logger.info(
            "Community flag added for job %s (reason=%s, total_flags=%d).",
            job_id, reason, flag_count,
        )
        return flag_count

    except Exception as exc:
        logger.warning("Failed to add community flag: %s", exc)
        return 0


async def get_flags(redis, job_id: str) -> List[CommunityFlag]:
    """Retrieve all community flags for a job listing."""
    key = f"{_FLAGS_PREFIX}{job_id}"
    try:
        raw = await redis.get_cached_jobs(key)
        if not raw:
            return []
        flags_list = json.loads(raw)
        return [CommunityFlag(**f) for f in flags_list]
    except Exception as exc:
        logger.warning("Failed to retrieve community flags: %s", exc)
        return []


async def get_flag_count(redis, job_id: str) -> int:
    """Return the number of community flags for a job listing."""
    flags = await get_flags(redis, job_id)
    return len(flags)


def should_re_analyse(flag_count: int) -> bool:
    """Returns True if the flag count hits the auto-escalation threshold (>=3)."""
    return flag_count >= 3
