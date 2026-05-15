"""
Hustlr AI Interview — Pydantic v2 Schemas
Request/response models for all interview API endpoints.
"""
from __future__ import annotations
from pydantic import BaseModel, Field
from typing import Optional, List
from enum import Enum


# ─── ENUMs ────────────────────────────────────────────────────

class InterviewType(str, Enum):
    TECHNICAL = "TECHNICAL"
    HR = "HR"
    MIXED = "MIXED"

class DifficultyLevel(str, Enum):
    JUNIOR = "JUNIOR"
    MID = "MID"
    SENIOR = "SENIOR"

class InterviewStatus(str, Enum):
    CREATED = "CREATED"
    IN_PROGRESS = "IN_PROGRESS"
    SUBMITTED = "SUBMITTED"
    PROCESSING = "PROCESSING"
    SCORED = "SCORED"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"

class PerformanceTier(str, Enum):
    EXCELLENT = "EXCELLENT"
    GOOD = "GOOD"
    NEEDS_IMPROVEMENT = "NEEDS_IMPROVEMENT"
    POOR = "POOR"


# ─── Question ─────────────────────────────────────────────────

class QuestionItem(BaseModel):
    id: Optional[str] = None
    order: int
    question_text: str
    areas_covered: Optional[List[str]] = None


# ─── Interview Setup & Start ──────────────────────────────────

class InterviewStartRequest(BaseModel):
    user_id: Optional[str] = "anonymous"
    job_role: str = Field(..., min_length=2, description="e.g. 'Flutter Engineer'")
    target_companies: List[str] = Field(default=[], description="e.g. ['Google', 'Swiggy']")
    interview_type: InterviewType = InterviewType.MIXED
    difficulty: DifficultyLevel = DifficultyLevel.MID
    # Company screening extras
    screening_context: Optional[str] = None  # Plain text instructions from company
    custom_questions: Optional[List[str]] = None  # Extra questions to inject

class InterviewStartResponse(BaseModel):
    session_id: str
    questions: List[QuestionItem]
    company_context_summary: Optional[str] = None
    estimated_duration_minutes: int = 15
    message: str


# ─── Answer Submit ────────────────────────────────────────────

class AnswerSubmitResponse(BaseModel):
    success: bool
    answer_id: Optional[str] = None
    next_question: Optional[QuestionItem] = None
    message: str


# ─── Interview Complete ──────────────────────────────────────

class InterviewCompleteRequest(BaseModel):
    session_id: str

class InterviewCompleteResponse(BaseModel):
    success: bool
    message: str
    estimated_processing_time: str = "1-3 minutes"


# ─── Interview Result ────────────────────────────────────────

class InterviewResultResponse(BaseModel):
    session_id: str
    status: str
    composite_score: Optional[float] = None
    confidence_interval: Optional[float] = None
    performance_tier: Optional[str] = None
    tier_rationale: Optional[str] = None
    upskilling_areas: Optional[List[str]] = None
    strong_areas: Optional[List[str]] = None
    per_question_scores: Optional[List[dict]] = None
    processing_complete: bool = False
