"""
Hustlr AI Interview — Supabase Client
"""
import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

_client: Client | None = None


def get_supabase() -> Client:
    """Get or create Supabase client singleton."""
    global _client
    if _client is None:
        url = os.getenv("SUPABASE_URL", "")
        key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", os.getenv("SUPABASE_ANON_KEY", ""))
        if not url or not key:
            raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env")
        _client = create_client(url, key)
    return _client


async def db_health_check() -> str:
    """Quick health check — try a simple query."""
    try:
        db = get_supabase()
        db.table("interview_sessions").select("id").limit(1).execute()
        return "connected"
    except Exception as e:
        return f"error: {e}"
