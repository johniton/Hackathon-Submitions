import asyncio
from app.services.pdf_service import _load_template
from app.services.resume_ai_service import ai_generate_html
import json

async def main():
    profile = {
        "name": "Harsh Gaonker",
        "headline": "Full stack dev",
        "experience": [{"title": "Dev", "company": "Tech", "bullets": ["Did stuff"]}]
    }
    template_html = _load_template("modern")
    html = await ai_generate_html(profile, template_html)
    with open("out.html", "w") as f:
        f.write(html)
    print("Done. Saved out.html")

if __name__ == "__main__":
    asyncio.run(main())
