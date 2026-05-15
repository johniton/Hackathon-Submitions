"""
scam_detection/models.py — Pydantic models for the scam detection pipeline.

All I/O models used across rule_engine, ml_classifier, domain_validator,
community_flags, and trust_scorer are defined here to avoid circular imports.
"""

from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field

from models.job_listing import JobListing


# ── Rule Engine ───────────────────────────────────────────────────────────────

class RuleEngineResult(BaseModel):
    """Output of the Layer-1 rule-based checks."""

    verdict: Literal["flagged", "inconclusive", "verified"]
    suspicion_score: int = Field(ge=0, le=100, description="Accumulated soft-rule score (0–100).")
    hard_rule_triggers: List[str] = Field(default_factory=list, description="Names of hard rules that fired.")
    soft_rule_triggers: List[str] = Field(default_factory=list, description="Names of soft rules that fired.")
    skip_ml: bool = Field(description="True when the verdict is already final and Layer-2 can be skipped.")


# ── Domain Validator ──────────────────────────────────────────────────────────

class DomainValidationResult(BaseModel):
    """Output of domain / company verification checks."""

    domain_reachable: Optional[bool] = None
    verified_company: bool = False
    company_linkedin_exists: Optional[bool] = None
    suspicion_delta: int = Field(default=0, description="Extra suspicion points to add (0–35).")
    flag_reasons: List[str] = Field(default_factory=list)


# ── Community Flags ───────────────────────────────────────────────────────────

class CommunityFlag(BaseModel):
    """A single user-reported scam flag entry stored in Redis."""

    job_id: str
    reported_by_user_hash: str = Field(description="SHA-256 of the user_id — never store raw user ID.")
    reason: Literal[
        "fake_company",
        "payment_demand",
        "fake_offer_letter",
        "wrong_salary",
        "no_response_after_apply",
        "other",
    ]
    details: Optional[str] = Field(default=None, max_length=200)
    reported_at: datetime


# ── Trust Scorer I/O ──────────────────────────────────────────────────────────

class ScamAnalysisInput(BaseModel):
    """Input for the full scam analysis pipeline."""

    listing: JobListing
    user_id: Optional[str] = Field(default=None, description="Optional user context for community flags.")


class ScamAnalysisResult(BaseModel):
    """Final output of the scam detection pipeline — returned to the client."""

    job_id: str
    trust_score: Literal["verified", "caution", "flagged"]
    confidence: float = Field(ge=0.0, le=1.0)
    flag_reasons: List[str] = Field(default_factory=list, description="Human-readable reasons shown in UI.")
    rule_triggers: List[str] = Field(default_factory=list, description="Technical trigger names for logging.")
    ml_score: Optional[float] = None
    community_flag_count: int = 0
    verified_company: bool = False
    analysed_at: datetime
    from_cache: bool = False


# ── API Request / Response helpers ────────────────────────────────────────────

class ReportScamRequest(BaseModel):
    """Body for POST /scam/report."""

    job_id: str
    user_id: str
    reason: Literal[
        "fake_company",
        "payment_demand",
        "fake_offer_letter",
        "wrong_salary",
        "no_response_after_apply",
        "other",
    ]
    details: Optional[str] = Field(default=None, max_length=200)


class ReportScamResponse(BaseModel):
    """Response from POST /scam/report."""

    success: bool
    flag_count: int
