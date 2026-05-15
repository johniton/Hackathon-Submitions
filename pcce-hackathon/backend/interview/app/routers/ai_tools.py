from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import json
import logging
from app.services.gemini_service import _call_groq, _call_gemini

router = APIRouter(prefix="/ai-tools", tags=["ai-tools"])
logger = logging.getLogger(__name__)

# --- Models ---
class ChatRequest(BaseModel):
    messages: List[Dict[str, str]]

class TechFeedRequest(BaseModel):
    headlines: str

class ColdDmRequest(BaseModel):
    company: str
    role: str
    recipient: str
    context: str

class FlashcardRequest(BaseModel):
    topics: List[str]
    difficulty: str

class GithubReviewRequest(BaseModel):
    repoName: str
    repoDescription: str
    readmeContent: str
    fileTree: str

class EmailAnalyzeRequest(BaseModel):
    email_content: str

class EmailSummaryRequest(BaseModel):
    emails_content: str

# --- Endpoints ---

@router.post("/chat")
async def chat_counsellor(req: ChatRequest):
    """Counsellor chatbot endpoint"""
    try:
        # Construct prompt from messages
        prompt = "Conversation History:\n"
        for msg in req.messages[:-1]:
            role = "User" if msg.get("role") == "user" else "Assistant"
            prompt += f"{role}: {msg.get('content')}\n"
        
        last_message = req.messages[-1].get("content", "")
        prompt += f"\nUser: {last_message}\n\nPlease reply as the helpful career counsellor. Provide concise, friendly, and actionable advice."
        
        system = "You are a friendly, highly experienced career counsellor. Be encouraging, concise, and helpful. Use markdown to format your replies."
        
        reply = await _call_groq(prompt, system_instruction=system, json_mode=False)
        return {"reply": reply}
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/tech-feed")
async def generate_tech_feed(req: TechFeedRequest):
    """Tech feed generation"""
    try:
        prompt = f"""
        System: You are a senior tech career strategist analyzing real-time tech news for a software developer.

        Here are today's live tech headlines:
        {req.headlines}

        Create a personalized intelligence briefing:
        🎯 **Top Priority** (1 item): The most career-impactful news and why
        📈 **Trending Now** (2-3 items): Technologies gaining momentum
        ⚡ **Action Items** (2-3 items): Specific things to learn or explore this week

        Reference actual headlines. Be specific. Max 120 words.
        
        Return ONLY valid JSON in this format:
        {{"digest": "The generated digest string here with newlines (\\n\\n) for paragraphs"}}
        """
        response_json = await _call_groq(prompt, system_instruction="")
        return json.loads(response_json)
    except Exception as e:
        logger.error(f"Tech feed error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/cold-dm")
async def generate_cold_dm(req: ColdDmRequest):
    try:
        prompt = f"""
        Write a highly personalized, professional cold DM (LinkedIn/Email style) for a job application.
        Target Company: {req.company}
        Target Role: {req.role}
        Recipient Name: {req.recipient}
        Context about the recipient/company: {req.context}
        
        The DM must be concise (under 150 words), engaging, not desperate, and clearly highlight value.
        Return ONLY valid JSON in this format:
        {{"dm": "The personalized DM text here"}}
        """
        response_json = await _call_groq(prompt, system_instruction="")
        return json.loads(response_json)
    except Exception as e:
        logger.error(f"Cold DM error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/flashcards/generate")
async def generate_flashcards(req: FlashcardRequest):
    try:
        topics_str = ", ".join(req.topics)
        prompt = f"""
        Generate 5 high-quality flashcards for the following topics: {topics_str}.
        Difficulty level: {req.difficulty}.
        
        Return ONLY valid JSON in this exact format:
        {{"cards": [
            {{"question": "Front of card", "answer": "Back of card", "topic": "Topic Name", "type": "qa"}}
        ]}}
        """
        response_json = await _call_groq(prompt, system_instruction="You are an expert tutor creating study materials.")
        return json.loads(response_json)
    except Exception as e:
        logger.error(f"Flashcards error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/flashcards/projects")
async def generate_projects(req: FlashcardRequest):
    try:
        topics_str = ", ".join(req.topics)
        prompt = f"""
        Generate 3 practical project ideas for the following topics: {topics_str}.
        Difficulty level: {req.difficulty}.
        
        Return ONLY valid JSON in this format:
        {{"projects": [
            {{"title": "Project Title", "description": "Short description of what to build", "key_skills": ["Skill1", "Skill2"]}}
        ]}}
        """
        response_json = await _call_groq(prompt, system_instruction="You are a senior developer suggesting portfolio projects.")
        return json.loads(response_json)
    except Exception as e:
        logger.error(f"Projects error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/flashcards/assessment")
async def generate_assessment(req: FlashcardRequest):
    try:
        topics_str = ", ".join(req.topics)
        prompt = f"""
        Generate 5 multiple-choice assessment questions for the following topics: {topics_str}.
        Difficulty level: {req.difficulty}.
        
        Return ONLY valid JSON in this format:
        {{"assessment": [
            {{"question": "The question text", "options": ["Option A", "Option B", "Option C", "Option D"], "correct_answer": "Option A", "explanation": "Why this is correct"}}
        ]}}
        """
        response_json = await _call_groq(prompt, system_instruction="You are a technical interviewer creating an assessment.")
        return json.loads(response_json)
    except Exception as e:
        logger.error(f"Assessment error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/github/review")
async def github_review(req: GithubReviewRequest):
    try:
        prompt = f"""
        Perform a professional code review based on the following GitHub repository details:
        Repository Name: {req.repoName}
        Description: {req.repoDescription}
        File Tree:
        {req.fileTree}
        
        README Snippet:
        {req.readmeContent[:1500]}
        
        Provide a constructive review of the repository structure, potential improvements, and overall impression.
        Return ONLY valid JSON in this format:
        {{"review": "The review in markdown format (can contain newlines)"}}
        """
        response_json = await _call_groq(prompt, system_instruction="You are an expert open-source maintainer doing a code review.")
        return json.loads(response_json)
    except Exception as e:
        logger.error(f"Github review error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/email/analyze")
async def email_analyze(req: EmailAnalyzeRequest):
    try:
        prompt = f"""
        System: You are an expert career advisor and job search assistant. Your role is to analyze job-related emails and provide structured, actionable intelligence.

        Analyze the following job email:

        \"\"\"
        {req.email_content}
        \"\"\"

        Provide a structured analysis:
        📋 **Email Type**: (Interview Invite / Offer Letter / Rejection / Assessment / Follow-up / Other)
        🔴 **Priority**: (Urgent / Important / Low Priority)
        📅 **Key Deadlines**: Extract any dates, times, or deadlines mentioned
        ✅ **Action Items**: List 2-4 specific next steps the candidate should take immediately
        💡 **Pro Tips**: 1-2 strategic suggestions (e.g. research the interviewer, prepare specific topics)
        ✉️ **Suggested Reply**: If a reply is needed, draft a brief professional response (max 50 words)

        Be concise and specific. Use bullet points.
        Return ONLY valid JSON in this format:
        {{"analysis": "The markdown formatted analysis here"}}
        """
        response_json = await _call_groq(prompt, system_instruction="")
        return json.loads(response_json)
    except Exception as e:
        logger.error(f"Email analyze error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/email/summary")
async def email_summary(req: EmailSummaryRequest):
    try:
        prompt = f"""
        System: You are a job search strategist. Your role is to analyze a candidate's job email inbox and create an executive briefing.

        Here are all emails in the inbox:
        {req.emails_content}

        Create a concise executive summary (max 120 words):
        🔥 **Urgent Actions**: What needs immediate attention
        📊 **Pipeline Status**: Overview of where things stand
        📅 **This Week**: Key deadlines and scheduled events
        💡 **Strategy**: One tactical recommendation

        Be specific with company names and dates.
        Return ONLY valid JSON in this format:
        {{"summary": "The markdown formatted summary here"}}
        """
        response_json = await _call_groq(prompt, system_instruction="")
        return json.loads(response_json)
    except Exception as e:
        logger.error(f"Email summary error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
