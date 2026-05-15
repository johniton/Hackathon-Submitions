"""
Hustlr AI Interview — Gemini AI Service
Question generation, response scoring, performance classification.
Uses Gemini as primary with retry, falls back to Groq Llama when rate-limited.
Adapted from AI SkillFit — English-only, company-aware prompts.
"""
import os
import json
import httpx
import asyncio
from typing import List, Optional
from dotenv import load_dotenv

load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")
GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta"

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_MODEL = os.getenv("GROQ_LLM_MODEL", "llama-3.3-70b-versatile")

MIN_QUESTIONS = int(os.getenv("MIN_QUESTIONS", "5"))
MAX_QUESTIONS = int(os.getenv("MAX_QUESTIONS", "12"))

# Rate limit tracking
_gemini_backoff_until = 0.0


# ═══════════════════════════════════════════════════════════════
# LLM CALL HELPERS
# ═══════════════════════════════════════════════════════════════

async def _call_groq(prompt: str, system_instruction: str = "") -> str:
    """Fallback: call Groq's OpenAI-compatible API."""
    if not GROQ_API_KEY:
        raise ValueError("GROQ_API_KEY not set")

    messages = []
    if system_instruction:
        messages.append({"role": "system", "content": system_instruction + "\nReturn ONLY valid JSON, no markdown, no explanation."})
    messages.append({"role": "user", "content": prompt})

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
            json={
                "model": GROQ_MODEL,
                "messages": messages,
                "temperature": 0.7,
                "max_tokens": 2048,
                "response_format": {"type": "json_object"},
            },
        )
        response.raise_for_status()
        data = response.json()

    return data["choices"][0]["message"]["content"]


async def _call_gemini(prompt: str, system_instruction: str = "", images: List[str] = None) -> str:
    """Proxy all calls to Groq (Llama-3.3-70b) as requested by user to avoid Gemini 429 rate limits."""
    print("[AI] Bypassing Gemini, using Groq API exclusively.")
    return await _call_groq(prompt, system_instruction)


# ═══════════════════════════════════════════════════════════════
# QUESTION GENERATION
# ═══════════════════════════════════════════════════════════════

async def generate_questions(
    role: str,
    companies: List[str],
    interview_type: str,
    difficulty: str,
    company_context: str = "",
    screening_context: str = "",
    custom_questions: List[str] = None,
) -> List[dict]:
    """Generate the FIRST interview question — a role-specific ice-breaker."""
    companies_str = ", ".join(companies) if companies else "top tech companies"
    difficulty_desc = {
        "JUNIOR": "entry-level / fresher (0-2 years experience)",
        "MID": "mid-level (2-5 years experience)",
        "SENIOR": "senior-level (5+ years experience)",
    }.get(difficulty, "mid-level")

    system_prompt = f"""You are a PROFESSIONAL AI interviewer conducting a mock interview.
The candidate is preparing for the role of {role} at {companies_str}.
Difficulty level: {difficulty_desc}.
Interview type: {interview_type}.

GENERATE exactly 1 opening question that:
- Directly relates to the role ({role}) — NOT generic
- Asks about their specific experience, background, or motivation for this role
- Is conversational but professional
- Is appropriate for the {difficulty_desc} level
- Max 2 sentences

Return JSON array: [{{"order": 1, "question_text": "..."}}]"""

    if company_context:
        system_prompt += f"""

COMPANY INTELLIGENCE (use to make questions specific):
{company_context[:1000]}
Tailor the question to reflect these companies' interview style and values."""

    if screening_context:
        system_prompt += f"""

COMPANY SCREENING INSTRUCTIONS (IMPORTANT — follow these):
{screening_context}"""

    if custom_questions:
        cq_str = "\n".join(f"- {q}" for q in custom_questions[:5])
        system_prompt += f"""

COMPANY CUSTOM QUESTIONS (prefer to use these if they fit the opening):
{cq_str}"""

    prompt = f"ROLE: {role}\nCOMPANIES: {companies_str}\nTYPE: {interview_type}\nDIFFICULTY: {difficulty}\n\nGenerate the opening interview question."

    try:
        result = await _call_gemini(prompt, system_prompt)
        questions = json.loads(result)
        if isinstance(questions, list) and len(questions) >= 1:
            return questions[:1]
        if isinstance(questions, dict) and "questions" in questions:
            return questions["questions"][:1]
        if isinstance(questions, dict) and "question_text" in questions:
            return [questions]
    except Exception as e:
        print(f"[AI] Question generation failed: {e}")

    # Fallback
    if custom_questions:
        return [{"order": 1, "question_text": custom_questions[0]}]
    return [
        {"order": 1, "question_text": f"Tell me about your experience as a {role}. What projects have you worked on recently?"},
    ]


async def generate_dynamic_question(
    role: str,
    companies: List[str],
    interview_type: str,
    difficulty: str,
    order: int,
    previous_qa: List[dict],
    company_context: str = "",
    base64_frames: List[str] = None,
) -> dict:
    """Generate the NEXT dynamic question. AI decides when to stop."""
    companies_str = ", ".join(companies) if companies else "top tech companies"
    difficulty_desc = {
        "JUNIOR": "entry-level / fresher",
        "MID": "mid-level (2-5 years)",
        "SENIOR": "senior-level (5+ years)",
    }.get(difficulty, "mid-level")

    type_areas = {
        "TECHNICAL": [
            "1. BACKGROUND: Work history, education, projects",
            "2. CORE TECHNICAL SKILLS: Language/framework proficiency, coding concepts",
            "3. PROBLEM SOLVING: System design, algorithmic thinking, debugging",
            "4. ARCHITECTURE: Design patterns, scalability, trade-offs",
            "5. GROWTH: Learning approach, staying current with tech",
        ],
        "HR": [
            "1. BACKGROUND: Career journey, motivation",
            "2. TEAMWORK: Collaboration, conflict resolution",
            "3. LEADERSHIP: Initiative, ownership, mentoring",
            "4. CULTURE FIT: Values alignment, work style",
            "5. CAREER GOALS: Growth plans, why this company",
        ],
        "MIXED": [
            "1. BACKGROUND: Work history, education, key projects",
            "2. CORE SKILLS: Technical depth in their domain",
            "3. PROBLEM SOLVING: Real-world scenarios, debugging, system design",
            "4. CULTURE FIT: Teamwork, communication, values alignment",
            "5. GROWTH MINDSET: Learning approach, career goals",
        ],
    }

    areas = "\n".join(type_areas.get(interview_type, type_areas["MIXED"]))

    system_prompt = f"""You are a PROFESSIONAL AI interviewer for a {role} position at {companies_str}.
Difficulty: {difficulty_desc}. Interview type: {interview_type}. This is question #{order}.

ASSESSMENT AREAS (cover ALL before stopping):
{areas}

QUESTION QUALITY RULES:
- Ask SPECIFIC questions related to {role} — NOT generic
- For Technical: ask about real technologies, frameworks, algorithms relevant to {role}
- Reference their PREVIOUS ANSWERS to ask deeper follow-ups
- Match the {difficulty_desc} difficulty level
- If candidate gives short/vague answers, probe deeper

DYNAMIC STOP LOGIC:
- Minimum: {MIN_QUESTIONS} questions (ALWAYS continue if order < {MIN_QUESTIONS})
- Maximum: {MAX_QUESTIONS} questions (ALWAYS stop if order >= {MAX_QUESTIONS})
- Stop when ALL 5 areas above are adequately covered
- If candidate gives short/vague answers, ask MORE questions to probe deeper

Return JSON:
{{
  "order": {order},
  "question_text": "English question...",
  "should_continue": true/false,
  "stop_reason": null or "SUFFICIENT_INFO" or "MAX_REACHED",
  "areas_covered": ["BACKGROUND", "CORE_SKILLS", ...],
  "areas_remaining": ["GROWTH", ...]
}}"""

    if company_context:
        system_prompt += f"""

COMPANY INTELLIGENCE (reference for tailored questions):
{company_context[:800]}"""

    prompt = f"ROLE: {role}\nCOMPANIES: {companies_str}\nTYPE: {interview_type}\n\nCONVERSATION SO FAR:\n"
    for qa in previous_qa:
        prompt += f"Q: {qa['question']}\nA: {qa['answer']}\n\n"

    prompt += f"Ask question #{order}. Decide whether more questions are needed based on coverage of all 5 assessment areas."

    try:
        result = await _call_gemini(prompt, system_prompt, images=base64_frames)
        question = json.loads(result)
        if isinstance(question, dict) and "question_text" in question:
            question["order"] = order
            if "should_continue" not in question:
                question["should_continue"] = order < MAX_QUESTIONS
            if "stop_reason" not in question:
                question["stop_reason"] = None
            return question
        elif isinstance(question, list) and len(question) > 0:
            q = question[0]
            q["order"] = order
            q["should_continue"] = q.get("should_continue", order < MAX_QUESTIONS)
            q["stop_reason"] = q.get("stop_reason", None)
            return q
    except Exception as e:
        print(f"[AI] Dynamic generation failed: {e}")

    # Fallback questions
    fallback_questions = {
        2: f"What specific technologies and tools do you use in your work as a {role}? Walk me through your typical tech stack.",
        3: f"Describe a challenging technical problem you solved recently. What was your approach?",
        4: f"How do you handle disagreements with team members on technical decisions?",
        5: f"Where do you see yourself in 2-3 years? What skills are you actively developing?",
        6: f"Tell me about a project you're particularly proud of. What was your specific contribution?",
    }
    fb = fallback_questions.get(order, f"Tell me more about your experience as a {role}.")

    should_continue = order < MIN_QUESTIONS
    return {
        "order": order,
        "question_text": fb,
        "should_continue": should_continue,
        "stop_reason": "SUFFICIENT_INFO" if not should_continue else None,
    }


# ═══════════════════════════════════════════════════════════════
# RESPONSE SCORING
# ═══════════════════════════════════════════════════════════════

async def score_response(question: str, transcript: str, role: str, interview_type: str) -> dict:
    """Score a candidate's spoken response using AI."""
    system_prompt = f"""You are evaluating a mock interview response for a {role} position.
Interview type: {interview_type}.
Score on 4 dimensions (0-10):

- relevance: Did they answer the question? (0=off-topic, 10=perfectly on-point)
- completeness: Key aspects covered? (0=blank, 10=thorough)
- clarity: Was the answer clear and well-structured? (0=incomprehensible, 10=crystal clear)
- confidence: Did they demonstrate domain confidence? (0=very uncertain, 10=highly confident expert)

IMPORTANT:
- Score based on role-specific knowledge demonstrated
- Do NOT penalize short but accurate answers
- Give benefit of doubt for STT errors (set stt_uncertainty=true)
- Consider the interview type when scoring

Return JSON:
{{
  "relevance": 0-10,
  "completeness": 0-10,
  "clarity": 0-10,
  "confidence": 0-10,
  "stt_uncertainty": true/false,
  "key_points_covered": ["point1", "point2"],
  "notable_gaps": ["gap1"],
  "short_explanation": "2 sentence explanation"
}}"""

    prompt = f"QUESTION: {question}\nROLE: {role}\nTRANSCRIPT: {transcript}\nINTERVIEW TYPE: {interview_type}"

    try:
        result = await _call_gemini(prompt, system_prompt)
        return json.loads(result)
    except Exception as e:
        print(f"[AI] Scoring failed: {e}")
        return {
            "relevance": 5, "completeness": 5, "clarity": 5, "confidence": 5,
            "stt_uncertainty": True,
            "key_points_covered": [],
            "notable_gaps": ["AI scoring unavailable"],
            "short_explanation": "Scoring could not be completed. Default scores applied.",
        }


# ═══════════════════════════════════════════════════════════════
# PERFORMANCE CLASSIFICATION
# ═══════════════════════════════════════════════════════════════

async def classify_performance(
    composite_score: float,
    confidence_interval: float,
    question_scores: list,
    role: str,
    interview_type: str,
    stt_uncertainty_count: int,
    total_questions: int,
) -> dict:
    """Classify candidate performance into tier."""
    system_prompt = f"""You are the final performance classifier for a mock interview system.
The candidate interviewed for: {role} ({interview_type}).

Classify into ONE performance tier:
1. EXCELLENT — Score >= 80, strong across all dimensions
2. GOOD — Score 65-79, solid performance with minor gaps
3. NEEDS_IMPROVEMENT — Score 45-64, clear areas to work on
4. POOR — Score < 45, significant preparation needed

Also identify:
- Strong areas (what they did well)
- Upskilling areas (what they need to improve)
- Specific resources/topics they should study

Return JSON:
{{
  "performance_tier": "EXCELLENT|GOOD|NEEDS_IMPROVEMENT|POOR",
  "tier_rationale": "2-3 sentence explanation",
  "strong_areas": ["area1", "area2"],
  "upskilling_areas": ["area1", "area2"],
  "recommended_resources": ["resource1", "resource2"]
}}"""

    prompt = f"""INPUT:
- Composite Score: {composite_score}/100
- Confidence Interval: +/-{confidence_interval}
- Role: {role}
- Interview Type: {interview_type}
- Per-Question Scores: {json.dumps(question_scores)}
- STT Uncertainty: {stt_uncertainty_count}/{total_questions}
- Total Questions Asked: {total_questions}"""

    try:
        result = await _call_gemini(prompt, system_prompt)
        return json.loads(result)
    except Exception as e:
        print(f"[AI] Classification failed: {e}")
        if composite_score >= 80:
            tier = "EXCELLENT"
        elif composite_score >= 65:
            tier = "GOOD"
        elif composite_score >= 45:
            tier = "NEEDS_IMPROVEMENT"
        else:
            tier = "POOR"

        return {
            "performance_tier": tier,
            "tier_rationale": f"Rule-based classification. Score: {composite_score}/100.",
            "strong_areas": [],
            "upskilling_areas": [],
            "recommended_resources": [],
        }
