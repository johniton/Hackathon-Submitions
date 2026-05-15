"""
main.py — FastAPI application entry point for the SkillMap Job Scraper microservice.

Startup sequence:
  1. Initialise Redis connection (graceful fallback if unavailable)
  2. Mount API router
  3. Configure structured logging

Run with:
  uvicorn main:app --reload --port 8001
"""

import logging
import sys
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routes import router
from cache.redis_client import RedisClient
from config import APP_TITLE, APP_VERSION, DEBUG

# ─── Logging ──────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.DEBUG if DEBUG else logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)


# ─── Lifespan (startup / shutdown) ────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting %s v%s …", APP_TITLE, APP_VERSION)
    app.state.redis = await RedisClient.create()
    yield
    # Shutdown
    logger.info("Shutting down %s …", APP_TITLE)
    await app.state.redis.close()


# ─── App ──────────────────────────────────────────────────────────────────────

app = FastAPI(
    title=APP_TITLE,
    version=APP_VERSION,
    description=(
        "Scrapes LinkedIn and Naukri.com for job listings. "
        "Applies deduplication, scam detection, and skill-match ranking before returning results."
    ),
    lifespan=lifespan,
)

# Allow Flutter web/mobile to call without CORS issues in dev
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],       # Tighten in production to your Flutter web origin
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)

logger.info("Routes registered. Docs available at http://localhost:8001/docs")
