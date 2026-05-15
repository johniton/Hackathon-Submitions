"""
Hustlr AI Interview — FastAPI Application Entry Point
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv
import os

load_dotenv()

from app.routers import interview
from app.routers import resume

app = FastAPI(
    title="Hustlr AI Backend",
    description="AI-powered mock interview + smart resume builder",
    version="1.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS — allow Flutter app and dev servers
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(interview.router, prefix="/interview", tags=["Interview"])
app.include_router(resume.router, tags=["Resume"])

# Serve local uploads as static files
os.makedirs("./uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


@app.get("/", tags=["Health"])
async def root():
    return {
        "service": "Hustlr AI Interview API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs",
    }


@app.get("/health", tags=["Health"])
async def health_check():
    from app.db.supabase import db_health_check
    db_ok = await db_health_check()
    return {
        "status": "healthy",
        "environment": os.getenv("ENVIRONMENT", "development"),
        "database": db_ok,
        "services": {
            "gemini": bool(os.getenv("GEMINI_API_KEY")),
            "groq": bool(os.getenv("GROQ_API_KEY")),
            "tavily": bool(os.getenv("TAVILY_API_KEY")),
            "supabase": bool(os.getenv("SUPABASE_URL")),
        },
    }
