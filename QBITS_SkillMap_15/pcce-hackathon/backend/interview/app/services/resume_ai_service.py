"""
Hustlr Resume Builder — AI Service
3-stage pipeline using Groq LLaMA-3.3-70b.
Ported from ResumeForge lib/ai/prompts/*.ts
"""
import os
import json
import httpx
from typing import List, Optional
from dotenv import load_dotenv

load_dotenv()

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_MODEL = "llama-3.1-8b-instant"

import asyncio


async def _call_groq(prompt: str, system: str = "", max_tokens: int = 4096, temperature: float = 0.7, json_mode: bool = True, model: str = None) -> str:
    """Call Groq LLaMA for JSON generation with retry on 429."""
    if not GROQ_API_KEY:
        raise ValueError("GROQ_API_KEY not set")

    messages = []
    if system:
        if json_mode:
            messages.append({"role": "system", "content": system + "\nReturn ONLY valid JSON, no markdown, no explanation."})
        else:
            messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    max_retries = 3
    for attempt in range(max_retries + 1):
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                payload = {
                    "model": model or GROQ_MODEL,
                    "messages": messages,
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                }
                if json_mode:
                    payload["response_format"] = {"type": "json_object"}
                
                resp = await client.post(
                    "https://api.groq.com/openai/v1/chat/completions",
                    headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
                    json=payload,
                )
                if resp.status_code == 429 and attempt < max_retries:
                    wait = 2 ** (attempt + 1)  # 2, 4, 8 seconds
                    print(f"[GROQ] Rate limited (429), retrying in {wait}s (attempt {attempt + 1}/{max_retries})")
                    await asyncio.sleep(wait)
                    continue
                resp.raise_for_status()
                return resp.json()["choices"][0]["message"]["content"]
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 429 and attempt < max_retries:
                wait = 2 ** (attempt + 1)
                print(f"[GROQ] Rate limited (429), retrying in {wait}s (attempt {attempt + 1}/{max_retries})")
                await asyncio.sleep(wait)
                continue
            raise
    raise Exception("Groq API failed after all retries")


# ═══════════════════════════════════════════════════════════════
# STAGE 1 — ANALYSIS
# ═══════════════════════════════════════════════════════════════

STAGE1_SYSTEM = """You are an expert technical resume strategist. Analyze the candidate profile against the job description and output a precise JSON strategy object.

RULES:
- Output ONLY valid JSON. No markdown, no explanation, no code fences.
- Never fabricate. Only use information from the provided source material.
- Be specific and concrete, not vague.
- achievement_rewrites must use XYZ format: "Accomplished [X] by doing [Y] which resulted in [Z]"

OUTPUT FORMAT:
{
  "positioning_angle": "string — one sentence on how to position the candidate",
  "projects_to_highlight": ["repo/project names to feature prominently"],
  "projects_to_drop": ["repo/project names to omit — irrelevant to this JD"],
  "skills_to_emphasize": ["skills from candidate profile that match JD requirements"],
  "skills_to_remove": ["skills from candidate profile irrelevant to this role"],
  "achievement_rewrites": [
    { "original": "original bullet point", "rewrite": "quantified, impact-focused rewrite" }
  ],
  "headline": "tailored professional headline for this application",
  "summary_draft": "2-3 sentence professional summary tailored to this role (100 words max)",
  "tone_notes": "startup|enterprise|academic — communication style notes"
}"""


async def stage1_analyze(
    candidate_profile: dict,
    jd_text: str = "",
    repo_cards: List[str] = None,
    extra_info: str = "",
) -> dict:
    """Stage 1: Analyze candidate vs JD and produce a strategy."""
    prompt = f"CANDIDATE PROFILE:\n{json.dumps(candidate_profile, indent=2)}\n\n"
    if jd_text:
        prompt += f"JOB DESCRIPTION:\n{jd_text[:3000]}\n\n"
    if repo_cards:
        prompt += f"GITHUB REPOS ({len(repo_cards)} selected):\n" + "\n---\n".join(repo_cards) + "\n\n"
    if extra_info:
        prompt += f"ADDITIONAL INFO FROM CANDIDATE:\n{extra_info}\n\n"
    prompt += "Analyze everything above and output the strategy JSON."

    try:
        result = await _call_groq(prompt, STAGE1_SYSTEM)
        return json.loads(result)
    except Exception as e:
        print(f"[RESUME-AI] Stage 1 failed: {e}")
        return {
            "positioning_angle": "General professional positioning",
            "projects_to_highlight": [],
            "projects_to_drop": [],
            "skills_to_emphasize": candidate_profile.get("skills", [])[:10],
            "skills_to_remove": [],
            "achievement_rewrites": [],
            "headline": candidate_profile.get("headline", "Professional"),
            "summary_draft": candidate_profile.get("summary", ""),
            "tone_notes": "professional",
        }


# ═══════════════════════════════════════════════════════════════
# STAGE 2 — RESUME GENERATION
# ═══════════════════════════════════════════════════════════════

STAGE2_SYSTEM = """You are an expert professional resume writer with 15+ years of experience crafting ATS-optimized resumes. Generate a COMPLETE, DETAILED, and FULLY POPULATED structured resume as JSON.

STRICT RULES:
1. Output ONLY valid JSON. No markdown, no explanation.
2. Never fabricate skills, experience, or achievements not present in the source material.
3. Only use content from the analysis JSON and candidate profile provided.
4. IMPORTANT: Generate RICH, DETAILED content. Every section must be thorough:
   - Each experience entry MUST have 2-4 detailed bullet points describing accomplishments
   - Each bullet point should be 1-2 sentences using action verbs and quantified results
   - The summary must be a compelling 2-3 sentence professional summary
   - Projects must have detailed descriptions explaining what the project does and its impact
   - Skills must be categorized into languages, frameworks, tools, and platforms
5. Use action verbs to start each bullet point (Developed, Implemented, Architected, Led, etc.)
6. Quantify achievements wherever possible (percentages, user counts, performance metrics).
7. If experience/project descriptions are sparse in the source, intelligently expand them based on the tech stack, role title, and context provided. Stay factual but be thorough.
8. For hackathon/competition wins, describe what was built and the impact.
9. Fill ALL sections — do not leave any section empty if there is even minimal source data.
10. The resume should feel like a polished, professional document ready for job applications.

OUTPUT FORMAT:
{
  "name": "Full Name",
  "email": "email@example.com",
  "phone": "+91-XXXXXXXXXX",
  "location": "City, Country",
  "linkedin": "linkedin.com/in/...",
  "github": "github.com/...",
  "headline": "Compelling Professional Headline (e.g. Full-Stack Developer | AI/ML Enthusiast | Hackathon Winner)",
  "summary": "2-3 sentence professional summary highlighting key strengths, experience level, and career focus",
  "experience": [
    {
      "company": "Company Name",
      "title": "Job Title",
      "dates": "Jan 2023 – Present",
      "location": "City, Country",
      "bullets": [
        "Achievement-focused bullet using XYZ format: Accomplished X by doing Y resulting in Z",
        "Another detailed bullet point with quantified impact",
        "Technical contribution bullet describing systems built or improved"
      ]
    }
  ],
  "education": [
    {
      "school": "University Name",
      "degree": "B.E. in Computer Engineering",
      "dates": "2020 – 2024",
      "gpa": "9.2/10"
    }
  ],
  "projects": [
    {
      "name": "Project Name",
      "description": "Detailed 1-2 sentence description of what it does, the problem it solves, and key technical highlights",
      "stack": ["Python", "FastAPI", "PostgreSQL"],
      "url": "github.com/..."
    }
  ],
  "skills": {
    "languages": ["Python", "JavaScript", "C++"],
    "frameworks": ["FastAPI", "React", "Flutter"],
    "tools": ["Docker", "Git", "Linux"],
    "platforms": ["AWS", "Supabase", "Firebase"]
  },
  "certifications": [
    {"name": "Certification Name", "issuer": "Organization", "date": "2024"}
  ],
  "achievements": ["Detailed achievement 1 with context", "Achievement 2"]
}"""


async def stage2_generate(
    analysis: dict,
    candidate_profile: dict,
    template_name: str = "ats_safe",
    extra_instructions: str = "",
) -> dict:
    """Stage 2: Generate structured resume JSON from analysis + profile."""
    prompt = f"STRATEGY ANALYSIS:\n{json.dumps(analysis, indent=2)}\n\n"
    prompt += f"CANDIDATE PROFILE (source of truth for all content):\n{json.dumps(candidate_profile, indent=2)}\n\n"
    prompt += f"TEMPLATE STYLE: {template_name}\n\n"
    if extra_instructions:
        prompt += f"ADDITIONAL INSTRUCTIONS:\n{extra_instructions}\n\n"
    prompt += """CRITICAL INSTRUCTIONS:
1. Generate a COMPLETE and DETAILED resume JSON. DO NOT leave any section empty.
2. For each experience entry, write 2-4 detailed bullet points describing what was accomplished.
3. If the candidate has GitHub repos or projects mentioned, include them with full descriptions.
4. Skills MUST be a categorized object with keys: languages, frameworks, tools, platforms.
5. The summary MUST be a compelling 2-3 sentence professional overview.
6. The headline MUST be a professional title, NOT a casual tagline.
7. If experience descriptions are sparse, expand them based on the job title and tech stack context.
8. Always include education with degree, school, dates, and GPA if available.
9. Every field must have real content — no empty strings, no empty arrays unless truly no data exists.

Generate the complete resume JSON now."""

    try:
        result = await _call_groq(prompt, STAGE2_SYSTEM, max_tokens=6000, temperature=0.4)
        resume = json.loads(result)
        print(f"[RESUME-AI] Stage 2 raw AI output keys: {list(resume.keys())}")

        # ─── POST-PROCESSING: Fix common AI output issues ───

        # Ensure all required keys exist
        for key in ["name", "email", "headline", "summary", "experience", "education", "projects", "skills"]:
            if key not in resume:
                resume[key] = "" if key in ["name", "email", "headline", "summary"] else []
        for key in ["certifications", "achievements", "phone", "location", "linkedin", "github"]:
            if key not in resume:
                resume[key] = [] if key in ["certifications", "achievements"] else ""

        # Fix 1: Convert skills list → categorized map
        if isinstance(resume.get("skills"), list) and resume["skills"]:
            flat = resume["skills"]
            categorized = {"languages": [], "frameworks": [], "tools": [], "other": []}
            known_langs = {"python", "javascript", "typescript", "java", "c", "c++", "c#", "kotlin", "go", "rust", "ruby", "swift", "php", "sql", "bash", "dart", "r", "scala", "perl", "lua", "html", "css", "c/c++", "javascript/typescript"}
            known_frameworks = {"react", "react.js", "next.js", "angular", "vue", "vue.js", "svelte", "express", "express.js", "fastapi", "flask", "django", "spring", "node.js", "flutter", "jetpack compose", "tailwindcss", "bootstrap", "pytorch", "tensorflow", "pandas", "numpy", "scikit-learn", "matplotlib", "supabase", "firebase", "socket programming", "sdl2"}
            known_tools = {"docker", "git", "github", "linux", "aws", "gcp", "azure", "kubernetes", "jenkins", "nginx", "redis", "postgresql", "mongodb", "mysql", "pinecone", "vercel", "netlify", "figma", "postman", "vscode"}
            for s in flat:
                sl = s.lower().strip()
                if sl in known_langs:
                    categorized["languages"].append(s)
                elif sl in known_frameworks:
                    categorized["frameworks"].append(s)
                elif sl in known_tools:
                    categorized["tools"].append(s)
                else:
                    categorized["other"].append(s)
            resume["skills"] = {k: v for k, v in categorized.items() if v}

        # Fix 2: Ensure EVERY experience entry has non-empty bullets
        if isinstance(resume.get("experience"), list):
            for exp in resume["experience"]:
                bullets = exp.get("bullets")
                # Treat None, non-list, or empty list as missing
                if not bullets or not isinstance(bullets, list) or len(bullets) == 0:
                    desc = exp.get("description", "")
                    if desc and isinstance(desc, str) and len(desc) > 10:
                        sentences = [s.strip() for s in desc.replace(". ", ".\n").split("\n") if s.strip() and len(s.strip()) > 5]
                        exp["bullets"] = sentences if sentences else [desc]
                    else:
                        title = exp.get("title", "Software Developer")
                        company = exp.get("company", "the organization")
                        exp["bullets"] = [
                            f"Spearheaded development initiatives as {title} at {company}, driving technical innovation and delivering impactful solutions.",
                            f"Collaborated with cross-functional teams to design, develop, and deploy production-ready features aligned with business objectives.",
                            f"Implemented best practices in code quality, testing, and CI/CD pipelines, improving development efficiency and software reliability.",
                        ]

        # Fix 3: If headline is empty/generic, generate from analysis or name
        headline = resume.get("headline", "").strip()
        if not headline or len(headline) < 5 or headline.lower() in ["professional", "n/a", "software developer"]:
            # Try from analysis
            if isinstance(analysis, dict) and analysis.get("headline"):
                resume["headline"] = analysis["headline"]
            elif candidate_profile.get("headline"):
                resume["headline"] = candidate_profile["headline"]
            else:
                name = resume.get("name", "Professional")
                resume["headline"] = f"Software Developer | {name}"

        # Fix 4: If summary is too short or is just a bio tagline, expand it
        summary = resume.get("summary", "").strip()
        if len(summary) < 50:
            src_summary = candidate_profile.get("summary", "")
            exp_titles = [e.get("title", "") for e in resume.get("experience", []) if e.get("title")]
            skills_list = []
            if isinstance(resume.get("skills"), dict):
                for v in resume["skills"].values():
                    if isinstance(v, list):
                        skills_list.extend(v[:3])
            elif isinstance(resume.get("skills"), list):
                skills_list = resume["skills"][:5]

            name = resume.get("name", "Professional")
            headline_str = resume.get("headline", "Software Developer")
            top_skills = ", ".join(skills_list[:5]) if skills_list else "modern technologies"
            recent_role = exp_titles[0] if exp_titles else "Software Developer"

            resume["summary"] = (
                f"Results-driven {headline_str} with hands-on experience in {top_skills}. "
                f"Proven ability to design, develop, and deploy scalable applications. "
                f"Passionate about building innovative solutions and contributing to high-impact projects."
            )

        # Fix 5: Merge projects/achievements/certs from source if AI dropped them
        for field in ["projects", "achievements", "certifications"]:
            src = candidate_profile.get(field, [])
            if not resume.get(field) and src:
                resume[field] = src

        # Fix 6: Fill contact info from source profile if missing
        for field in ["email", "phone", "location", "linkedin", "github", "name"]:
            if not resume.get(field) and candidate_profile.get(field):
                resume[field] = candidate_profile[field]

        # Fix 7: If skills dict is empty, pull from source profile
        if not resume.get("skills") or (isinstance(resume["skills"], dict) and not any(resume["skills"].values())):
            src_skills = candidate_profile.get("skills", [])
            if src_skills:
                if isinstance(src_skills, list):
                    resume["skills"] = {"core": src_skills}
                else:
                    resume["skills"] = src_skills

        # ─── QUALITY CHECK: Log what we're returning ───
        exp_bullets = sum(len(e.get("bullets", [])) for e in resume.get("experience", []))
        skill_count = sum(len(v) for v in resume["skills"].values()) if isinstance(resume.get("skills"), dict) else len(resume.get("skills", []))
        print(f"[RESUME-AI] Stage 2 FINAL: name={resume.get('name')}, "
              f"headline={resume.get('headline','')[:40]}, "
              f"summary_len={len(resume.get('summary',''))}, "
              f"exp={len(resume.get('experience',[]))}, total_bullets={exp_bullets}, "
              f"edu={len(resume.get('education',[]))}, "
              f"proj={len(resume.get('projects',[]))}, "
              f"skills={skill_count}, "
              f"achievements={len(resume.get('achievements',[]))}")

        return resume
    except Exception as e:
        print(f"[RESUME-AI] Stage 2 failed: {e}")
        # Build resume from raw profile data, then apply same post-processing
        name = candidate_profile.get("name", "Professional")
        headline_src = candidate_profile.get("headline", "")
        # Use analysis headline if available
        if isinstance(analysis, dict) and analysis.get("headline") and len(analysis["headline"]) > 5:
            headline_src = analysis["headline"]
        if not headline_src or len(headline_src) < 5:
            headline_src = "Software Developer"

        resume = {
            "name": name,
            "email": candidate_profile.get("email", ""),
            "phone": candidate_profile.get("phone", ""),
            "location": candidate_profile.get("location", ""),
            "linkedin": candidate_profile.get("linkedin", ""),
            "github": candidate_profile.get("github", ""),
            "headline": headline_src,
            "summary": "",
            "experience": candidate_profile.get("experience", []),
            "education": candidate_profile.get("education", []),
            "projects": candidate_profile.get("projects", []),
            "skills": candidate_profile.get("skills", {}),
            "certifications": candidate_profile.get("certifications", []),
            "achievements": candidate_profile.get("achievements", []),
        }

        # Apply same post-processing as success path
        # Bullets
        if isinstance(resume.get("experience"), list):
            for exp in resume["experience"]:
                bullets = exp.get("bullets")
                if not bullets or not isinstance(bullets, list) or len(bullets) == 0:
                    desc = exp.get("description", "")
                    if desc and isinstance(desc, str) and len(desc) > 10:
                        sentences = [s.strip() for s in desc.replace(". ", ".\n").split("\n") if s.strip() and len(s.strip()) > 5]
                        exp["bullets"] = sentences if sentences else [desc]
                    else:
                        title = exp.get("title", "Software Developer")
                        company = exp.get("company", "the organization")
                        exp["bullets"] = [
                            f"Spearheaded development initiatives as {title} at {company}, driving technical innovation and delivering impactful solutions.",
                            f"Collaborated with cross-functional teams to design, develop, and deploy production-ready features aligned with business objectives.",
                            f"Implemented best practices in code quality, testing, and CI/CD pipelines, improving development efficiency and software reliability.",
                        ]

        # Summary
        skills_list = []
        if isinstance(resume.get("skills"), list):
            skills_list = resume["skills"][:5]
        elif isinstance(resume.get("skills"), dict):
            for v in resume["skills"].values():
                if isinstance(v, list):
                    skills_list.extend(v[:3])
        top_skills = ", ".join(skills_list[:5]) if skills_list else "modern technologies"
        resume["summary"] = (
            f"Results-driven {headline_src} with hands-on experience in {top_skills}. "
            f"Proven ability to design, develop, and deploy scalable applications. "
            f"Passionate about building innovative solutions and contributing to high-impact projects."
        )

        print(f"[RESUME-AI] Stage 2 FALLBACK applied: {len(resume.get('experience',[]))} exp with bullets")
        return resume


# ═══════════════════════════════════════════════════════════════
# CERTIFICATE AI EXTRACTION
# ═══════════════════════════════════════════════════════════════

async def extract_cert_with_ai(raw_text: str) -> dict:
    """Use AI to parse certificate OCR text into structured data."""
    system = """Extract certificate information from the OCR text.
Return JSON: {"cert_name": "...", "issuer": "...", "issue_date": "...", "skills": ["skill1", "skill2"]}
If any field is unclear, set it to empty string or empty array."""

    try:
        result = await _call_groq(f"OCR TEXT:\n{raw_text[:2000]}", system, max_tokens=512)
        return json.loads(result)
    except Exception:
        return {"cert_name": "", "issuer": "", "issue_date": "", "skills": []}


# ═══════════════════════════════════════════════════════════════
# AI HTML GENERATION
# ═══════════════════════════════════════════════════════════════

async def ai_generate_html(resume_json: dict, template_html: str) -> str:
    """Use AI to rewrite the raw HTML template, injecting the resume JSON data."""
    system = """You are an expert web developer and UI designer. 
You will be provided with a candidate's resume data in JSON format and a base HTML/CSS template.
Your task is to generate the COMPLETE HTML string by intelligently inserting the candidate's data into the template structure.
RULES:
1. Output ONLY the raw HTML string. Do NOT wrap it in markdown code blocks like ```html ... ```. Just the raw HTML.
2. Maintain the CSS exactly as it is in the template.
3. If some data is missing (e.g. no projects), remove that section cleanly from the HTML.
4. Replace ALL placeholders in the HTML (such as {{FIRST_NAME}}, {{LAST_NAME}}, {{NAME}}, {{CONTACT_LINE}}, {{HEADLINE}}, {{SUMMARY_SECTION}}, {{EXPERIENCE_SECTION}}, {{EDUCATION_SECTION}}, {{PROJECTS_SECTION}}, {{SKILLS_SECTION}}, {{CERTIFICATIONS_SECTION}}, {{ACHIEVEMENTS_SECTION}}) with actual HTML code representing the candidate's data.
5. Create fully formatted HTML lists/divs for array fields like experience, education, projects, skills, etc.
6. Make sure the output is a fully valid, well-formed HTML document. NEVER leave any {{}} placeholders in your output."""

    prompt = f"RESUME JSON DATA:\n{json.dumps(resume_json, indent=2)}\n\n"
    prompt += f"BASE HTML TEMPLATE:\n{template_html}\n\n"
    prompt += "Generate the final complete HTML document with all data correctly injected and all placeholders replaced."

    try:
        result = await _call_groq(prompt, system, max_tokens=4000, temperature=0.2, json_mode=False, model="llama-3.1-8b-instant")
        # Strip markdown if Groq adds it anyway
        if result.startswith("```html"):
            result = result[7:]
        if result.startswith("```"):
            result = result[3:]
        if result.endswith("```"):
            result = result[:-3]
        return result.strip()
    except Exception as e:
        print(f"[RESUME-AI] AI HTML Generation failed: {e}")
        raise e
