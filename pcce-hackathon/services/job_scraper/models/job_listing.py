from pydantic import BaseModel
from typing import List, Literal, Optional
from datetime import datetime


class JobListing(BaseModel):
    id: str                                        # sha256 hash used as primary key
    title: str
    company: str
    location: str
    salary_range: Optional[str] = None
    experience_required: Optional[str] = None
    skills_required: List[str] = []
    description: str
    source: Literal["linkedin", "naukri", "instahyre", "internshala", "shine"]
    source_url: str
    posted_at: Optional[datetime] = None
    scraped_at: datetime
    freshness_days: int
    trust_score: Literal["verified", "caution", "flagged"] = "verified"
    flag_reasons: List[str] = []
    scam_percentage: int = 0
    match_score: float = 0.0                       # 0.0–1.0 Jaccard vs user profile
    is_duplicate: bool = False


class SearchJobsParams(BaseModel):
    keywords: str
    location: str
    experience_years: int = 0
    user_skills: List[str] = []
    freshness_days: Literal[1, 2, 7] = 7
    sources: List[Literal["linkedin", "naukri", "instahyre", "internshala", "shine"]] = [
        "linkedin", "naukri", "instahyre", "internshala", "shine"
    ]


class ScrapedJobResponse(BaseModel):
    jobs: List[JobListing]
    total: int
    from_cache: bool = False


class ScamCheckRequest(BaseModel):
    job_id: Optional[str] = None
    raw_listing: Optional[JobListing] = None


class ScamCheckResponse(BaseModel):
    trust_score: Literal["verified", "caution", "flagged"]
    flag_reasons: List[str]
