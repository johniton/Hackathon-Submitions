"""
Hustlr Resume Builder — ATS Scoring Service
Keyword-based ATS compatibility scoring with JD matching.
"""
import os
import json
import httpx
from typing import List, Optional
from dotenv import load_dotenv

load_dotenv()

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_MODEL = os.getenv("GROQ_LLM_MODEL", "llama-3.3-70b-versatile")


def _extract_keywords(text: str) -> set:
    """Extract meaningful keywords from text."""
    import re
    # Common stop words to ignore
    stop = {"the","a","an","is","are","was","were","be","been","being","have","has","had",
            "do","does","did","will","would","could","should","may","might","must","shall",
            "and","or","but","if","while","as","at","by","for","with","about","against",
            "between","through","during","before","after","above","below","to","from","up",
            "down","in","out","on","off","over","under","again","further","then","once",
            "here","there","when","where","why","how","all","both","each","few","more",
            "most","other","some","such","no","nor","not","only","own","same","so","than",
            "too","very","can","just","don","now","of","it","its","this","that","these","those",
            "i","me","my","we","our","you","your","he","him","his","she","her","they","them",
            "what","which","who","whom","work","working","experience","role","team","company",
            "ability","knowledge","understanding","strong","excellent","good","great","required",
            "preferred","minimum","years","year","including","using","used","also","well"}

    words = re.findall(r'[a-zA-Z+#.]+(?:\.[a-zA-Z]+)*', text.lower())
    return {w for w in words if len(w) > 1 and w not in stop}


def compute_ats_score(resume_json: dict, jd_text: str = "") -> dict:
    """Compute ATS compatibility score for a resume."""
    score = 0
    breakdown = {}
    suggestions = []

    # 1. Section presence (30 points)
    section_score = 0
    required_sections = {
        "name": 5, "headline": 3, "summary": 5, "experience": 5,
        "education": 5, "skills": 5, "projects": 2,
    }
    for section, points in required_sections.items():
        val = resume_json.get(section)
        if val and (isinstance(val, str) and len(val) > 0) or (isinstance(val, (list, dict)) and len(val) > 0):
            section_score += points
        else:
            suggestions.append(f"Add a '{section}' section to improve ATS compatibility")
    breakdown["section_presence"] = section_score
    score += section_score

    # 2. Content quality (30 points)
    content_score = 0
    exp = resume_json.get("experience", [])
    if isinstance(exp, list):
        # Bullet points with numbers/metrics
        all_bullets = []
        for e in exp:
            all_bullets.extend(e.get("bullets", []))
        if all_bullets:
            content_score += 10
            quantified = sum(1 for b in all_bullets if any(c.isdigit() for c in b))
            ratio = quantified / len(all_bullets) if all_bullets else 0
            content_score += min(10, int(ratio * 15))
            if ratio < 0.3:
                suggestions.append("Add more quantified achievements (numbers, percentages) to bullet points")
        else:
            suggestions.append("Add bullet points to your experience entries")

    # Action verbs check
    action_verbs = ["built","developed","designed","implemented","led","managed","created","improved",
                    "increased","reduced","achieved","launched","deployed","optimized","automated",
                    "architected","engineered","established","delivered","drove","spearheaded"]
    if all_bullets:
        verb_count = sum(1 for b in all_bullets if any(b.lower().startswith(v) for v in action_verbs))
        content_score += min(10, int(verb_count / max(len(all_bullets), 1) * 15))
        if verb_count < len(all_bullets) * 0.5:
            suggestions.append("Start more bullet points with strong action verbs")
    breakdown["content_quality"] = content_score
    score += content_score

    # 3. Skills coverage (20 points)
    skills = resume_json.get("skills", {})
    skills_score = 0
    if isinstance(skills, dict):
        total_skills = sum(len(v) for v in skills.values() if isinstance(v, list))
        skills_score = min(20, total_skills * 2)
        if total_skills < 5:
            suggestions.append("Add more specific skills — aim for 10-15 relevant technical skills")
    elif isinstance(skills, list):
        skills_score = min(20, len(skills) * 2)
    breakdown["skills_coverage"] = skills_score
    score += skills_score

    # 4. JD keyword match (20 points) — only if JD provided
    keyword_score = 0
    matched_keywords = []
    missing_keywords = []
    if jd_text:
        jd_keywords = _extract_keywords(jd_text)
        resume_text = json.dumps(resume_json).lower()
        resume_keywords = _extract_keywords(resume_text)

        # Filter to meaningful JD keywords (technical terms, tools, etc.)
        important_jd = {k for k in jd_keywords if len(k) > 2}
        matched = important_jd & resume_keywords
        missing = important_jd - resume_keywords

        match_ratio = len(matched) / max(len(important_jd), 1)
        keyword_score = min(20, int(match_ratio * 25))
        matched_keywords = sorted(list(matched))[:20]
        missing_keywords = sorted(list(missing))[:15]

        if match_ratio < 0.5:
            suggestions.append(f"Your resume matches only {int(match_ratio*100)}% of JD keywords. Add more relevant terms.")
    breakdown["jd_keyword_match"] = keyword_score
    score += keyword_score

    return {
        "score": min(100, score),
        "breakdown": breakdown,
        "matched_keywords": matched_keywords,
        "missing_keywords": missing_keywords,
        "suggestions": suggestions,
    }


async def match_jd_detailed(resume_json: dict, jd_text: str) -> dict:
    """Detailed JD matching with AI-powered suggestions."""
    # Basic scoring first
    basic = compute_ats_score(resume_json, jd_text)

    # AI-enhanced analysis
    if not GROQ_API_KEY:
        return basic

    system = """You are an ATS (Applicant Tracking System) expert. Compare the resume against the job description.
Return JSON:
{
  "match_percent": 0-100,
  "matched_skills": ["skill1", "skill2"],
  "missing_skills": ["skill1", "skill2"],
  "improvement_tips": ["tip1", "tip2", "tip3"]
}"""

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
                json={
                    "model": GROQ_MODEL,
                    "messages": [
                        {"role": "system", "content": system},
                        {"role": "user", "content": f"RESUME:\n{json.dumps(resume_json)[:3000]}\n\nJOB DESCRIPTION:\n{jd_text[:3000]}"},
                    ],
                    "temperature": 0.5,
                    "max_tokens": 1024,
                    "response_format": {"type": "json_object"},
                },
            )
            resp.raise_for_status()
            ai_result = json.loads(resp.json()["choices"][0]["message"]["content"])

        return {
            **basic,
            "match_percent": ai_result.get("match_percent", basic["score"]),
            "matched_skills": ai_result.get("matched_skills", basic["matched_keywords"]),
            "missing_skills": ai_result.get("missing_skills", basic["missing_keywords"]),
            "improvement_tips": ai_result.get("improvement_tips", basic["suggestions"]),
        }
    except Exception as e:
        print(f"[ATS] AI matching failed: {e}")
        return basic
