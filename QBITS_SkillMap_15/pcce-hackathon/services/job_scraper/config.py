"""
config.py — Central configuration for the Job Scraper microservice.
All secrets are loaded from environment variables (.env file).
"""

import os
from dotenv import load_dotenv

load_dotenv()

# ─── Service ──────────────────────────────────────────────────────────────────

APP_TITLE = "SkillMap Job Scraper"
APP_VERSION = "1.0.0"
PORT = int(os.getenv("PORT", "8001"))
DEBUG = os.getenv("DEBUG", "false").lower() == "true"

# ─── Redis ────────────────────────────────────────────────────────────────────

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
REDIS_CACHE_TTL = int(os.getenv("REDIS_CACHE_TTL", "1800"))   # 30 min
REDIS_DEDUP_TTL = int(os.getenv("REDIS_DEDUP_TTL", "86400"))  # 24 h

# ─── Proxy (optional) ─────────────────────────────────────────────────────────

PROXY_URL: str | None = os.getenv("PROXY_URL", None)  # e.g. http://user:pass@host:port

# ─── Rate limiting & retry ────────────────────────────────────────────────────

RATE_LIMIT_DELAY_MIN = float(os.getenv("RATE_LIMIT_DELAY_MIN", "1.5"))
RATE_LIMIT_DELAY_MAX = float(os.getenv("RATE_LIMIT_DELAY_MAX", "4.0"))
MAX_RETRIES = int(os.getenv("MAX_RETRIES", "3"))
# Exponential backoff delays in seconds (index = attempt number starting at 0)
RETRY_DELAYS = [2, 4, 8]
RATE_LIMIT_BACKOFF = 30  # seconds to wait on HTTP 429

# ─── Scraper timeouts ─────────────────────────────────────────────────────────

REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "30"))       # httpx timeout in seconds
PLAYWRIGHT_TIMEOUT = int(os.getenv("PLAYWRIGHT_TIMEOUT", "45000"))  # ms

# ─── LinkedIn ─────────────────────────────────────────────────────────────────

LINKEDIN_EMAIL = os.getenv("LINKEDIN_EMAIL", "")
LINKEDIN_PASSWORD = os.getenv("LINKEDIN_PASSWORD", "")

# ─── User-Agent rotation pool ─────────────────────────────────────────────────

USER_AGENTS: list[str] = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0",
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0",
    "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.94 Safari/537.36",
    "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6367.82 Mobile Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 OPR/110.0.0.0",
]
