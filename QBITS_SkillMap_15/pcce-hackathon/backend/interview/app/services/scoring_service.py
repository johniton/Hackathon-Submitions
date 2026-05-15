"""
Hustlr AI Interview — Scoring Service
Assessment scoring pipeline: per-question scoring, composite calculation, full processing.
Adapted from AI SkillFit — no face/selfie checks, no Supabase audit logs.
"""
import math
from typing import List
from app.db.supabase import get_supabase
from app.services.gemini_service import score_response, classify_performance
from app.services.stt_service import transcribe
from app.services.audio_service import extract_audio_from_video


def calculate_composite_score(question_scores: List[dict]) -> tuple:
    """
    Calculate weighted composite score (0-100) and confidence interval.
    Weights: relevance=30%, completeness=25%, clarity=25%, confidence=20%
    """
    if not question_scores:
        return 0.0, 20.0

    weights = {
        "relevance": 0.30,
        "completeness": 0.25,
        "clarity": 0.25,
        "confidence": 0.20,
    }

    per_question_composites = []
    for qs in question_scores:
        weighted = sum(
            qs.get(dim, 5) * w for dim, w in weights.items()
        )
        per_question_composites.append(weighted * 10)

    composite = sum(per_question_composites) / len(per_question_composites)

    if len(per_question_composites) > 1:
        variance = sum((x - composite) ** 2 for x in per_question_composites) / len(per_question_composites)
        std_dev = math.sqrt(variance)
        stt_penalty = sum(1 for qs in question_scores if qs.get("stt_uncertainty", False)) * 3
        confidence_interval = min(round(std_dev + stt_penalty, 1), 25.0)
    else:
        confidence_interval = 15.0

    return round(composite, 2), confidence_interval


async def process_interview_pipeline(session_id: str):
    """
    Full processing pipeline for a completed interview.
    Steps:
    1. Extract audio from videos
    2. Transcribe each answer
    3. Score each response
    4. Calculate composite score
    5. Classify performance tier
    6. Store results in Supabase
    """
    db = get_supabase()
    print(f"🔄 Processing interview: {session_id}")

    try:
        # Update status
        db.table("interview_sessions").update({"status": "PROCESSING"}).eq("id", session_id).execute()

        # Get session details
        session = db.table("interview_sessions").select("*").eq("id", session_id).execute()
        if not session.data:
            raise ValueError(f"Session {session_id} not found")

        sv = session.data[0]
        role = sv.get("job_role", "General")
        interview_type = sv.get("interview_type", "MIXED")

        # Get all questions and answers
        questions = (
            db.table("interview_questions")
            .select("*")
            .eq("session_id", session_id)
            .order("order_index")
            .execute()
        )
        answers = (
            db.table("interview_answers")
            .select("*")
            .eq("session_id", session_id)
            .execute()
        )

        answer_map = {a["question_id"]: a for a in (answers.data or [])}

        # Process each answer
        question_scores = []
        stt_uncertainty_count = 0

        for q in (questions.data or []):
            answer = answer_map.get(q["id"])
            if not answer:
                continue

            # Transcribe (if not already done during submit)
            transcript = answer.get("transcript", "")
            if not transcript and answer.get("video_local_path"):
                try:
                    audio_path = await extract_audio_from_video(answer["video_local_path"])
                    stt_result = await transcribe(audio_path)
                    transcript = stt_result.get("text", "")
                except Exception as e:
                    print(f"[WARN] STT failed for answer {answer['id']}: {e}")
                    transcript = "[Transcription failed]"

            # Score the response
            try:
                score = await score_response(
                    question=q["question_text"],
                    transcript=transcript,
                    role=role,
                    interview_type=interview_type,
                )
            except Exception as e:
                print(f"[WARN] Scoring failed for answer {answer['id']}: {e}")
                score = {
                    "relevance": 5, "completeness": 5, "clarity": 5, "confidence": 5,
                    "stt_uncertainty": True,
                }

            if score.get("stt_uncertainty"):
                stt_uncertainty_count += 1

            # Update answer record with scores
            db.table("interview_answers").update({
                "transcript": transcript,
                "score_relevance": score.get("relevance", 5),
                "score_completeness": score.get("completeness", 5),
                "score_clarity": score.get("clarity", 5),
                "score_confidence": score.get("confidence", 5),
                "stt_uncertainty": score.get("stt_uncertainty", False),
                "key_points_covered": score.get("key_points_covered", []),
                "notable_gaps": score.get("notable_gaps", []),
                "scoring_explanation": score.get("short_explanation", ""),
            }).eq("id", answer["id"]).execute()

            question_scores.append(score)

        # Update status
        db.table("interview_sessions").update({"status": "SCORED"}).eq("id", session_id).execute()

        # Calculate composite score
        composite_score, confidence_interval = calculate_composite_score(question_scores)

        # Classify performance
        perf_result = await classify_performance(
            composite_score=composite_score,
            confidence_interval=confidence_interval,
            question_scores=question_scores,
            role=role,
            interview_type=interview_type,
            stt_uncertainty_count=stt_uncertainty_count,
            total_questions=len(questions.data or []),
        )

        # Store assessment
        assessment_data = {
            "session_id": session_id,
            "composite_score": composite_score,
            "confidence_interval": confidence_interval,
            "performance_tier": perf_result["performance_tier"],
            "tier_rationale": perf_result.get("tier_rationale", ""),
            "upskilling_areas": perf_result.get("upskilling_areas", []),
            "strong_areas": perf_result.get("strong_areas", []),
            "recommended_resources": perf_result.get("recommended_resources", []),
        }
        db.table("interview_assessments").upsert(
            assessment_data, on_conflict="session_id"
        ).execute()

        # Update session status
        db.table("interview_sessions").update({
            "status": "COMPLETED",
            "completed_at": "now()",
        }).eq("id", session_id).execute()

        print(f"[DONE] Session {session_id}: Score={composite_score}, Tier={perf_result['performance_tier']}")

    except Exception as e:
        print(f"[ERROR] Pipeline failed for {session_id}: {e}")
        db.table("interview_sessions").update({"status": "FAILED"}).eq("id", session_id).execute()
        raise
