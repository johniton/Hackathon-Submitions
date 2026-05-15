"""
Hustlr AI Interview — Interview Router
Interview lifecycle: start, submit answers, complete, get results.
Supports dynamic question count (5–12) driven by AI.
Adapted from AI SkillFit — English-only, company-aware, Tavily-enriched.
"""
from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from app.models.schemas import (
    InterviewStartRequest, InterviewStartResponse,
    AnswerSubmitResponse, InterviewCompleteRequest,
    InterviewCompleteResponse, InterviewResultResponse, QuestionItem,
)
from app.db.supabase import get_supabase
from app.services.gemini_service import generate_questions, generate_dynamic_question, MIN_QUESTIONS, MAX_QUESTIONS
from app.services.tavily_service import get_company_context
from app.services.scoring_service import process_interview_pipeline
import uuid
import os
import json
import base64

router = APIRouter()

# Offline fallback questions (English only)
OFFLINE_QUESTIONS = {
    "offline-2": {"order": 2, "question_text": "What tools and technologies do you use most often in your work?"},
    "offline-3": {"order": 3, "question_text": "How do you approach debugging a complex issue in production?"},
    "offline-4": {"order": 4, "question_text": "Describe a challenging project you worked on and what you learned from it."},
    "offline-5": {"order": 5, "question_text": "Where do you see yourself in 2-3 years? What skills are you actively developing?"},
}


@router.post("/start", response_model=InterviewStartResponse)
async def start_interview(request: InterviewStartRequest):
    """Start a new interview session. Fetches company context via Tavily, generates first question via Gemini."""
    db = get_supabase()

    # Fetch company context via Tavily
    company_context = ""
    context_sources = []
    if request.target_companies:
        try:
            ctx = await get_company_context(request.target_companies, request.job_role)
            company_context = ctx.get("summary", "")
            context_sources = ctx.get("sources", [])
        except Exception as e:
            print(f"[WARN] Tavily search failed: {e}")

    # Generate first question using Gemini (with company context + screening context)
    questions_data = await generate_questions(
        role=request.job_role,
        companies=request.target_companies,
        interview_type=request.interview_type.value,
        difficulty=request.difficulty.value,
        company_context=company_context,
        screening_context=request.screening_context or "",
        custom_questions=request.custom_questions or [],
    )

    # Create interview session in Supabase
    session_data = {
        "user_id": request.user_id,
        "job_role": request.job_role,
        "target_companies": request.target_companies,
        "interview_type": request.interview_type.value,
        "difficulty": request.difficulty.value,
        "company_context": company_context,
        "context_sources": context_sources,
        "status": "CREATED",
    }
    session_result = db.table("interview_sessions").insert(session_data).execute()
    if not session_result.data:
        raise HTTPException(status_code=500, detail="Failed to create interview session.")

    session_id = session_result.data[0]["id"]

    # Store questions
    question_items = []
    for i, q in enumerate(questions_data):
        q_data = {
            "session_id": session_id,
            "question_text": q.get("question_text", ""),
            "order_index": q.get("order", i + 1),
            "question_type": "standard",
            "areas_covered": q.get("areas_covered", []),
        }
        q_result = db.table("interview_questions").insert(q_data).execute()
        if q_result.data:
            qd = q_result.data[0]
            question_items.append(QuestionItem(
                id=qd["id"],
                order=qd["order_index"],
                question_text=qd["question_text"],
                areas_covered=qd.get("areas_covered"),
            ))

    # Update session status
    db.table("interview_sessions").update({
        "status": "IN_PROGRESS",
        "started_at": "now()",
    }).eq("id", session_id).execute()

    companies_str = ", ".join(request.target_companies) if request.target_companies else "general"
    return InterviewStartResponse(
        session_id=session_id,
        questions=question_items,
        company_context_summary=company_context[:300] if company_context else None,
        estimated_duration_minutes=15,
        message=f"Interview started for {request.job_role} at {companies_str}. AI will ask {MIN_QUESTIONS}–{MAX_QUESTIONS} questions adaptively.",
    )


@router.post("/submit", response_model=AnswerSubmitResponse)
async def submit_answer(
    session_id: str = Form(...),
    question_id: str = Form(...),
    video: UploadFile = File(...),
):
    """Submit a video recording, process synchronously, and let AI decide next question."""
    db = get_supabase()

    # Verify session exists and is in progress
    session = db.table("interview_sessions").select("*").eq("id", session_id).execute()
    if not session.data:
        raise HTTPException(status_code=404, detail="Interview session not found.")
    if session.data[0]["status"] not in ["IN_PROGRESS", "CREATED"]:
        raise HTTPException(status_code=400, detail="Interview is not in progress.")

    sv = session.data[0]

    # Handle offline fallback question IDs
    if question_id.startswith("offline-"):
        existing = (
            db.table("interview_questions")
            .select("*")
            .eq("session_id", session_id)
            .eq("question_type", question_id)
            .execute()
        )
        if existing.data:
            q_data = existing.data[0]
            question_id = q_data["id"]
            order_index = q_data["order_index"]
        else:
            oq = OFFLINE_QUESTIONS.get(question_id)
            if not oq:
                raise HTTPException(status_code=400, detail="Invalid offline question ID.")
            db_q_data = {
                "session_id": session_id,
                "question_text": oq["question_text"],
                "order_index": oq["order"],
                "question_type": question_id,
            }
            q_result = db.table("interview_questions").insert(db_q_data).execute()
            if not q_result.data:
                raise HTTPException(status_code=500, detail="Failed to create offline question.")
            q_data = q_result.data[0]
            question_id = q_data["id"]
            order_index = q_data["order_index"]
    else:
        question = (
            db.table("interview_questions")
            .select("*")
            .eq("id", question_id)
            .eq("session_id", session_id)
            .execute()
        )
        if not question.data:
            raise HTTPException(status_code=404, detail="Question not found in this session.")
        q_data = question.data[0]
        order_index = q_data.get("order_index", 1)

    # Save video locally
    from app.services.audio_service import extract_audio_from_video
    from app.services.stt_service import transcribe

    video_content = await video.read()
    local_dir = f"./uploads/interviews/{session_id}"
    os.makedirs(local_dir, exist_ok=True)
    ext = os.path.splitext(video.filename or "video.mp4")[1] or ".mp4"
    local_path = f"{local_dir}/{question_id}{ext}"

    with open(local_path, "wb") as f:
        f.write(video_content)

    video_url = local_path

    # Try upload to Supabase Storage
    try:
        video_filename = f"interviews/{session_id}/{question_id}_{uuid.uuid4().hex[:8]}{ext}"
        storage = db.storage.from_("interview-videos")
        storage.upload(video_filename, video_content, {"content-type": video.content_type or "video/mp4"})
        video_url = f"interview-videos/{video_filename}"
    except Exception as e:
        print(f"[WARN] Supabase upload failed, using local path: {e}")

    # Create answer record
    answer_data = {
        "question_id": question_id,
        "session_id": session_id,
        "video_url": video_url,
        "video_local_path": local_path,
    }
    ans_result = db.table("interview_answers").insert(answer_data).execute()
    if not ans_result.data:
        raise HTTPException(status_code=500, detail="Failed to save answer.")
    answer_id = ans_result.data[0]["id"]

    next_question_item = None

    # ─── Dynamic question logic ───
    transcript_text = ""

    # 1. Extract audio & Transcribe
    try:
        audio_path = await extract_audio_from_video(local_path)
        stt_result = await transcribe(audio_path)
        transcript_text = stt_result.get("text", "")

        db.table("interview_answers").update({
            "transcript": transcript_text,
            "stt_engine": stt_result.get("engine", "unknown"),
        }).eq("id", answer_id).execute()
    except Exception as e:
        print(f"[WARN] Sync STT failed: {e}")

    # 2. Get Q&A history
    all_q = db.table("interview_questions").select("id, question_text").eq("session_id", session_id).execute()
    all_a = db.table("interview_answers").select("question_id, transcript").eq("session_id", session_id).execute()

    qa_map = {q["id"]: {"q": q["question_text"]} for q in (all_q.data or [])}
    for a in (all_a.data or []):
        if a["question_id"] in qa_map:
            qa_map[a["question_id"]]["a"] = a.get("transcript", "")

    previous_qa = [{"question": v["q"], "answer": v.get("a", "")} for k, v in qa_map.items() if "a" in v]

    # 3. Generate dynamic question
    next_order = order_index + 1
    new_q_data = await generate_dynamic_question(
        role=sv["job_role"],
        companies=sv.get("target_companies", []),
        interview_type=sv.get("interview_type", "MIXED"),
        difficulty=sv.get("difficulty", "MID"),
        order=next_order,
        previous_qa=previous_qa,
        company_context=sv.get("company_context", ""),
    )

    should_continue = new_q_data.get("should_continue", next_order < MAX_QUESTIONS)
    stop_reason = new_q_data.get("stop_reason", None)

    # Force continue below min, force stop at max
    if next_order <= MIN_QUESTIONS:
        should_continue = True
    if next_order > MAX_QUESTIONS:
        should_continue = False
        stop_reason = "MAX_REACHED"

    if should_continue:
        db_q_data = {
            "session_id": session_id,
            "question_text": new_q_data.get("question_text", ""),
            "order_index": next_order,
            "question_type": "dynamic",
            "areas_covered": new_q_data.get("areas_covered", []),
        }
        nq_result = db.table("interview_questions").insert(db_q_data).execute()

        if nq_result.data:
            nqd = nq_result.data[0]
            next_question_item = QuestionItem(
                id=nqd["id"],
                order=nqd["order_index"],
                question_text=nqd["question_text"],
                areas_covered=nqd.get("areas_covered"),
            )
    else:
        try:
            db.table("interview_sessions").update({
                "total_questions_asked": order_index,
                "ai_stop_reason": stop_reason or "SUFFICIENT_INFO",
            }).eq("id", session_id).execute()
        except Exception as e:
            print(f"[WARN] Could not update session stop metadata: {e}")

    return AnswerSubmitResponse(
        success=True,
        answer_id=answer_id,
        next_question=next_question_item,
        message=f"Answer submitted. {'Next question generated.' if next_question_item else f'Interview complete ({stop_reason}).'}",
    )


@router.post("/complete", response_model=InterviewCompleteResponse)
async def complete_interview(request: InterviewCompleteRequest):
    """Mark interview as submitted and trigger async processing pipeline."""
    db = get_supabase()

    session = db.table("interview_sessions").select("*").eq("id", request.session_id).execute()
    if not session.data:
        raise HTTPException(status_code=404, detail="Interview session not found.")

    sv = session.data[0]
    if sv["status"] not in ["IN_PROGRESS", "CREATED"]:
        raise HTTPException(status_code=400, detail=f"Interview cannot be completed from status: {sv['status']}")

    db.table("interview_sessions").update({
        "status": "SUBMITTED",
        "submitted_at": "now()",
    }).eq("id", request.session_id).execute()

    # Trigger async processing
    try:
        import asyncio
        asyncio.create_task(process_interview_pipeline(request.session_id))
    except Exception as e:
        print(f"[WARN] Background processing failed to start: {e}")

    return InterviewCompleteResponse(
        success=True,
        message="Interview submitted. AI is processing your responses.",
        estimated_processing_time="1-3 minutes",
    )


@router.get("/{session_id}/result", response_model=InterviewResultResponse)
async def get_interview_result(session_id: str):
    """Poll for interview processing result."""
    db = get_supabase()

    session = db.table("interview_sessions").select("*").eq("id", session_id).execute()
    if not session.data:
        raise HTTPException(status_code=404, detail="Interview session not found.")

    sv = session.data[0]

    # Get assessment
    assessment = db.table("interview_assessments").select("*").eq("session_id", session_id).execute()
    a = assessment.data[0] if assessment.data else None

    # Get per-question scores with question text
    answers = (
        db.table("interview_answers")
        .select("question_id, score_relevance, score_completeness, score_clarity, score_confidence, transcript, scoring_explanation")
        .eq("session_id", session_id)
        .execute()
    )

    questions = (
        db.table("interview_questions")
        .select("id, question_text, order_index")
        .eq("session_id", session_id)
        .order("order_index")
        .execute()
    )
    q_map = {q["id"]: q for q in (questions.data or [])}

    per_question = []
    for ans in (answers.data or []):
        q_info = q_map.get(ans["question_id"], {})
        per_question.append({
            "question_id": ans["question_id"],
            "question_text": q_info.get("question_text", ""),
            "order": q_info.get("order_index", 0),
            "relevance": ans.get("score_relevance"),
            "completeness": ans.get("score_completeness"),
            "clarity": ans.get("score_clarity"),
            "confidence": ans.get("score_confidence"),
            "transcript": ans.get("transcript"),
            "explanation": ans.get("scoring_explanation"),
        })

    per_question.sort(key=lambda x: x.get("order", 0))

    return InterviewResultResponse(
        session_id=session_id,
        status=sv["status"],
        composite_score=a["composite_score"] if a else None,
        confidence_interval=a["confidence_interval"] if a else None,
        performance_tier=a["performance_tier"] if a else None,
        tier_rationale=a["tier_rationale"] if a else None,
        upskilling_areas=a.get("upskilling_areas") if a else None,
        strong_areas=a.get("strong_areas") if a else None,
        per_question_scores=per_question if per_question else None,
        processing_complete=sv["status"] in ["COMPLETED", "FAILED"],
    )


@router.post("/verify_face")
async def verify_face(
    baseline_image: UploadFile = File(...),
    current_image: UploadFile = File(...),
):
    """Verify if the current face matches the baseline face using DeepFace."""
    import asyncio
    from deepface import DeepFace
    
    base_path = f"/tmp/{uuid.uuid4()}_base.jpg"
    curr_path = f"/tmp/{uuid.uuid4()}_curr.jpg"
    
    try:
        with open(base_path, "wb") as f:
            f.write(await baseline_image.read())
        with open(curr_path, "wb") as f:
            f.write(await current_image.read())
            
        def _verify():
            return DeepFace.verify(
                img1_path=base_path,
                img2_path=curr_path,
                enforce_detection=True
            )
            
        result = await asyncio.to_thread(_verify)
        
        # Cleanup
        os.remove(base_path)
        os.remove(curr_path)
        
        return {
            "verified": bool(result.get("verified", False)),
            "distance": float(result.get("distance", 1.0)),
            "error": None
        }
    except Exception as e:
        # Cleanup
        if os.path.exists(base_path): os.remove(base_path)
        if os.path.exists(curr_path): os.remove(curr_path)
        
        err_msg = str(e).lower()
        if "face could not be detected" in err_msg:
            return {"verified": False, "distance": 1.0, "error": "NO_FACE_DETECTED"}
        return {"verified": False, "distance": 1.0, "error": str(e)}


@router.post("/{session_id}/mark_cheating")
async def mark_cheating(session_id: str):
    """Mark an interview as failed due to cheating/face mismatch."""
    db = get_supabase()
    
    try:
        db.table("interview_sessions").update({
            "cheating_detected": True,
            "status": "FAILED",
            "ai_stop_reason": "CHEATING_DETECTED"
        }).eq("id", session_id).execute()
        return {"success": True, "message": "Interview marked as cheating."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
