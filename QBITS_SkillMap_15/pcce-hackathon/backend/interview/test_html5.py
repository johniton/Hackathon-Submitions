import asyncio
import httpx
import os
import json
from dotenv import load_dotenv

load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

async def main():
    system = """You are an expert web developer.
You must output ONLY valid HTML. Do NOT include markdown code blocks.
Your task is to take the provided HTML template and replace ALL placeholders (like {{NAME}}, {{EMAIL}}, {{EXPERIENCE_SECTION}}) with the correct information from the JSON data.
- Create valid HTML elements for the arrays like experience and education.
- DO NOT change the CSS. Output the entire HTML document.
"""
    resume_json = {
        "name": "Harsh Gaonker",
        "headline": "Full stack dev",
        "summary": "I am a great dev",
        "experience": [{"title": "Dev", "company": "Tech", "bullets": ["Did stuff"]}]
    }
    template_html = "<html><body><h1>{{NAME}}</h1><p>{{HEADLINE}}</p><div>{{EXPERIENCE_SECTION}}</div></body></html>"
    prompt = f"RESUME JSON DATA:\n{json.dumps(resume_json, indent=2)}\n\nBASE HTML TEMPLATE:\n{template_html}\n\nGenerate the final complete HTML now."

    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
            json={
                "model": "llama-3.1-8b-instant",
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": prompt}
                ],
                "max_tokens": 4000
            }
        )
        print(resp.status_code)
        print(resp.json()["choices"][0]["message"]["content"])

asyncio.run(main())
