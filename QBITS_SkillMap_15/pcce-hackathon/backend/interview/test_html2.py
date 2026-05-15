import asyncio
import httpx
import os

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

async def main():
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
            json={
                "model": "llama-3.3-70b-versatile",
                "messages": [{"role": "user", "content": "hi"}],
                "max_tokens": 4000
            }
        )
        print(resp.status_code)
        print(resp.text)

asyncio.run(main())
