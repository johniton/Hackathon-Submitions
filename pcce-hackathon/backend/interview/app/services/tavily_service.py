"""
Hustlr AI Interview — Tavily Web Search Service
Fetches company intelligence (culture, interview style, recent news) to enrich AI prompts.
"""
import os
import httpx
from typing import List
from dotenv import load_dotenv

load_dotenv()

TAVILY_API_KEY = os.getenv("TAVILY_API_KEY", "")
TAVILY_URL = "https://api.tavily.com/search"


async def get_company_context(companies: List[str], role: str) -> dict:
    """
    Search Tavily for company interview context.
    Returns { "summary": "...", "sources": [{"title": "...", "url": "..."}] }
    """
    if not TAVILY_API_KEY or not companies:
        return {"summary": "", "sources": []}

    all_results = []
    sources = []

    for company in companies[:3]:  # Max 3 companies to stay within rate limits
        queries = [
            f"{company} {role} interview questions and process",
            f"{company} engineering culture and values",
        ]

        for query in queries:
            try:
                async with httpx.AsyncClient(timeout=15.0) as client:
                    response = await client.post(
                        TAVILY_URL,
                        json={
                            "api_key": TAVILY_API_KEY,
                            "query": query,
                            "search_depth": "basic",
                            "max_results": 3,
                            "include_answer": True,
                        },
                    )
                    response.raise_for_status()
                    data = response.json()

                if data.get("answer"):
                    all_results.append(f"[{company}] {data['answer']}")

                for result in data.get("results", [])[:2]:
                    sources.append({
                        "title": result.get("title", ""),
                        "url": result.get("url", ""),
                    })
                    if result.get("content"):
                        all_results.append(result["content"][:300])

            except Exception as e:
                print(f"[TAVILY] Search failed for '{query}': {e}")

    summary = "\n\n".join(all_results)
    # Cap at 2000 chars to avoid bloating the AI prompt
    if len(summary) > 2000:
        summary = summary[:2000] + "..."

    return {"summary": summary, "sources": sources}
