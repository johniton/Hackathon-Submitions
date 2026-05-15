"""
Hustlr Resume Builder — API Router
All 7 resume endpoints under /resume/*
"""
import json
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import Response
from typing import Optional

router = APIRouter(prefix="/resume", tags=["resume"])


# ═══════════════════════════════════════════════════════════════
# POST /resume/github — Fetch repos
# ═══════════════════════════════════════════════════════════════

@router.post("/github")
async def fetch_github_repos(github_url: str = Form(...), github_token: Optional[str] = Form(None)):
    """Fetch repos + user profile from a GitHub URL."""
    from app.services.github_service import fetch_repos, fetch_github_profile
    try:
        username = github_url.rstrip("/").split("/")[-1]
        repos = await fetch_repos(github_url, github_token)
        profile = await fetch_github_profile(username, github_token)
        return {"repos": repos, "count": len(repos), "profile": profile}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))



# ═══════════════════════════════════════════════════════════════
# POST /resume/ocr — Extract text from certificate
# ═══════════════════════════════════════════════════════════════

@router.post("/ocr")
async def ocr_certificate(file: UploadFile = File(...)):
    """Extract certificate info from uploaded PDF or image."""
    from app.services.ocr_service import extract_certificate_info
    from app.services.resume_ai_service import extract_cert_with_ai

    file_bytes = await file.read()
    result = await extract_certificate_info(file_bytes, file.filename or "upload", ai_extract_fn=extract_cert_with_ai)
    return result



# ═══════════════════════════════════════════════════════════════
# POST /resume/generate — Full AI pipeline
# ═══════════════════════════════════════════════════════════════

@router.post("/generate")
async def generate_resume(
    candidate_profile: str = Form(...),
    selected_repos: str = Form("[]"),
    jd_text: str = Form(""),
    extra_info: str = Form(""),
    template_name: str = Form("ats_safe"),
    github_token: Optional[str] = Form(None),
):
    """Full 3-stage AI pipeline: analyze → generate → score."""
    from app.services.resume_ai_service import stage1_analyze, stage2_generate
    from app.services.github_service import build_repo_card, compress_repo_card, fetch_github_profile
    from app.services.ats_service import compute_ats_score

    try:
        profile = json.loads(candidate_profile)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid candidate_profile JSON")

    try:
        repos_list = json.loads(selected_repos)
    except json.JSONDecodeError:
        repos_list = []

    # Auto-fetch GitHub profile and merge into candidate profile
    github_url = profile.get("github", "")
    if github_url:
        try:
            username = github_url.rstrip("/").split("/")[-1]
            gh_profile = await fetch_github_profile(username, github_token)
            # Fill in missing fields from GitHub profile
            if gh_profile:
                if not profile.get("name"):
                    profile["name"] = gh_profile.get("name", "")
                if not profile.get("email"):
                    profile["email"] = gh_profile.get("email", "")
                if not profile.get("location"):
                    profile["location"] = gh_profile.get("location", "")
                if not profile.get("summary") and gh_profile.get("bio"):
                    profile["summary"] = gh_profile["bio"]
                if not profile.get("github"):
                    profile["github"] = gh_profile.get("github", github_url)
                if gh_profile.get("blog"):
                    profile["portfolio"] = gh_profile["blog"]
            print(f"[RESUME] GitHub profile merged for {username}")
        except Exception as e:
            print(f"[RESUME] GitHub profile fetch failed: {e}")

    # Build repo cards for selected repos
    repo_cards = []
    for repo_info in repos_list:
        if isinstance(repo_info, dict) and repo_info.get("full_name"):
            try:
                parts = repo_info["full_name"].split("/")
                card = await build_repo_card(parts[0], parts[1], github_token)
                repo_cards.append(compress_repo_card(card))
            except Exception as e:
                print(f"[RESUME] Repo card failed for {repo_info.get('full_name')}: {e}")
        elif isinstance(repo_info, str):
            repo_cards.append(repo_info)

    # Stage 1 (Skipped as per new single-stage plan)
    analysis = {}

    # Stage 2 — Generate resume JSON
    print("[RESUME] Generating resume JSON...")
    resume_json = await stage2_generate(analysis, profile, template_name, extra_info)

    # Stage 3 — ATS Score
    print("[RESUME] Stage 3: Scoring...")
    ats = compute_ats_score(resume_json, jd_text)

    return {
        "resume_json": resume_json,
        "analysis": analysis,
        "ats_score": ats,
        "template": template_name,
    }


# ═══════════════════════════════════════════════════════════════
# POST /resume/score — ATS score
# ═══════════════════════════════════════════════════════════════

@router.post("/score")
async def score_resume(
    resume_json: str = Form(...),
    jd_text: str = Form(""),
):
    """Compute ATS score for a resume."""
    from app.services.ats_service import compute_ats_score
    try:
        resume = json.loads(resume_json)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid resume_json")

    return compute_ats_score(resume, jd_text)


# ═══════════════════════════════════════════════════════════════
# POST /resume/match-jd — Match resume against JD
# ═══════════════════════════════════════════════════════════════

@router.post("/match-jd")
async def match_jd(
    resume_json: str = Form(...),
    jd_text: str = Form(""),
    jd_url: str = Form(""),
):
    """Score resume against a job description (text or URL)."""
    from app.services.ats_service import match_jd_detailed

    try:
        resume = json.loads(resume_json)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid resume_json")

    # Removed JD URL scraping because scraper_service is deleted.
    if jd_url and not jd_text:
        raise HTTPException(status_code=400, detail="JD URL scraping is no longer supported. Paste the JD text instead.")

    if not jd_text:
        raise HTTPException(status_code=400, detail="Provide jd_text or jd_url")

    return await match_jd_detailed(resume, jd_text)


# ═══════════════════════════════════════════════════════════════
# POST /resume/export/pdf — Export PDF
# ═══════════════════════════════════════════════════════════════

@router.post("/export/pdf")
async def export_pdf(
    resume_json: str = Form(...),
    template_name: str = Form("ats_safe"),
):
    """Generate downloadable PDF from resume JSON."""
    from app.services.pdf_service import generate_pdf

    try:
        resume = json.loads(resume_json)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid resume_json")

    pdf_bytes = await generate_pdf(resume, template_name)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": "attachment; filename=resume.pdf"},
    )


# ═══════════════════════════════════════════════════════════════
# POST /resume/export/docx — Export DOCX
# ═══════════════════════════════════════════════════════════════

@router.post("/export/docx")
async def export_docx(
    resume_json: str = Form(...),
):
    """Generate downloadable DOCX from resume JSON."""
    from app.services.docx_service import generate_docx

    try:
        resume = json.loads(resume_json)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid resume_json")

    docx_bytes = generate_docx(resume)
    return Response(
        content=docx_bytes,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={"Content-Disposition": "attachment; filename=resume.docx"},
    )
