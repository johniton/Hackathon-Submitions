"""
scam_detection/rule_engine.py — Layer 1: fast, zero-ML-cost rule-based checks.

Runs ALWAYS on every listing. If any HARD rule fires the verdict is immediately
"flagged" and Layer 2 (ML) is skipped. If only SOFT rules accumulate enough
suspicion the listing is marked "inconclusive" and forwarded to the ML layer.

Hard rules:  any single match → "flagged", skip_ml=True
Soft rules:  accumulate suspicion_score
  - score >= 70 → "flagged", skip_ml=True
  - score >= 40 → "inconclusive", skip_ml=False
  - score <  40 → "verified", skip_ml=True
"""

import re
import logging
from typing import List, Optional

from models.job_listing import JobListing
from scam_detection.models import RuleEngineResult

logger = logging.getLogger(__name__)

# ── Constants ─────────────────────────────────────────────────────────────────

# Hard-flag: payment demand phrases (case-insensitive)
_PAYMENT_DEMAND_PHRASES: List[str] = [
    "pay registration fee",
    "security deposit",
    "training fee",
    "refundable deposit",
    "pay to join",
    "investment required",
    "buy our kit",
    "purchase starter pack",
]

# Hard-flag: WhatsApp-only contact patterns
_WHATSAPP_PATTERNS = re.compile(
    r"(contact\s+on\s+whatsapp|whatsapp\s+only|msg\s+on\s+whatsapp|whatsapp\s+number)",
    re.IGNORECASE,
)

# Hard-flag: suspicious URL shorteners
_URL_SHORTENERS = {"bit.ly", "tinyurl.com", "t.co", "rb.gy", "shorturl.at", "goo.gl", "is.gd", "cutt.ly"}

# Hard-flag: trusted TLDs
_TRUSTED_TLD_ENDINGS = (".com", ".in", ".co.in", ".org", ".net", ".io")

# Hard-flag: double-extension patterns
_DOUBLE_EXT_RE = re.compile(r"\.(com|net|org|co)\.[a-z]{2,4}$", re.IGNORECASE)
_SUSPICIOUS_DOUBLE_EXT_RE = re.compile(r"\.(com|net|org|co)\.(tk|ml|ga|cf|gq|ru|cn|xyz|buzz)$", re.IGNORECASE)

# Soft-flag: MLM / scam keywords
_MLM_KEYWORDS: List[str] = [
    "unlimited earning",
    "be your own boss",
    "mlm",
    "direct selling",
    "network marketing",
    "work from home earn daily",
]

# Soft-flag: personal email patterns
_PERSONAL_EMAIL_RE = re.compile(
    r"[a-zA-Z0-9._%+-]+@(gmail\.com|yahoo\.com|yahoo\.co\.in|hotmail\.com|outlook\.com|rediffmail\.com)",
    re.IGNORECASE,
)

# Soft-flag: company email pattern (non-personal domain)
_COMPANY_EMAIL_RE = re.compile(
    r"[a-zA-Z0-9._%+-]+@(?!gmail\.com|yahoo\.com|yahoo\.co\.in|hotmail\.com|outlook\.com|rediffmail\.com)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}",
    re.IGNORECASE,
)

# Soft-flag: excessive caps / punctuation in title
_EXCESSIVE_CAPS_RE = re.compile(r"[A-Z]{5,}")
_EXCESSIVE_PUNCT_RE = re.compile(r"[!?$]{2,}")

# Soft-flag: individual poster markers
_INDIVIDUAL_MARKERS = ["mr.", "mrs.", "ms.", "sir", "madam"]

# Salary parsing helpers
_SALARY_NUMBER_RE = re.compile(r"[\d,.]+")
_FRESHER_SIGNALS = ["fresher", "0 year", "0-1 year", "0 - 1 year", "entry level", "graduate trainee", "intern"]

# ── 200 Common Indian Job Titles (for soft rule S8) ───────────────────────────

COMMON_JOB_TITLES: frozenset = frozenset([
    # Engineering & IT
    "software engineer", "software developer", "senior software engineer", "lead software engineer",
    "principal engineer", "staff engineer", "frontend developer", "backend developer",
    "full stack developer", "fullstack developer", "web developer", "mobile developer",
    "android developer", "ios developer", "flutter developer", "react developer",
    "react native developer", "angular developer", "vue developer", "node developer",
    "python developer", "java developer", "dotnet developer", ".net developer",
    "php developer", "ruby developer", "golang developer", "rust developer",
    "devops engineer", "site reliability engineer", "sre", "cloud engineer",
    "cloud architect", "solutions architect", "system administrator", "system engineer",
    "network engineer", "network administrator", "database administrator", "dba",
    "data engineer", "data scientist", "data analyst", "machine learning engineer",
    "ml engineer", "ai engineer", "deep learning engineer", "nlp engineer",
    "computer vision engineer", "research scientist", "research engineer",
    "cybersecurity analyst", "security engineer", "information security analyst",
    "penetration tester", "soc analyst", "blockchain developer", "embedded engineer",
    "embedded software engineer", "firmware engineer", "hardware engineer",
    "vlsi engineer", "chip design engineer", "test engineer", "qa engineer",
    "quality assurance engineer", "sdet", "automation test engineer", "manual tester",
    "performance engineer", "reliability engineer", "platform engineer",
    "infrastructure engineer", "release engineer", "build engineer",
    # Management & Leadership
    "engineering manager", "technical lead", "tech lead", "team lead",
    "project manager", "program manager", "product manager", "product owner",
    "scrum master", "agile coach", "delivery manager", "operations manager",
    "general manager", "assistant manager", "deputy manager", "senior manager",
    "associate vice president", "vice president", "director", "senior director",
    "managing director", "chief technology officer", "cto", "chief executive officer", "ceo",
    "chief operating officer", "coo", "chief financial officer", "cfo",
    "chief marketing officer", "cmo", "chief information officer", "cio",
    "chief product officer", "cpo", "chief data officer", "cdo",
    # Design
    "ui designer", "ux designer", "ui ux designer", "graphic designer",
    "visual designer", "interaction designer", "product designer", "motion designer",
    "creative director", "art director", "brand designer",
    # Marketing & Sales
    "marketing executive", "marketing manager", "digital marketing executive",
    "digital marketing manager", "seo executive", "seo analyst", "seo specialist",
    "sem executive", "social media manager", "social media executive",
    "content marketing manager", "email marketing specialist", "growth hacker",
    "performance marketing manager", "brand manager", "marketing analyst",
    "sales executive", "sales manager", "sales officer", "area sales manager",
    "regional sales manager", "national sales manager", "business development executive",
    "business development manager", "bde", "bdm", "key account manager",
    "account executive", "account manager", "inside sales executive",
    "territory sales officer", "sales coordinator", "pre sales consultant",
    # HR & Admin
    "hr executive", "hr manager", "hr generalist", "hr business partner",
    "talent acquisition executive", "talent acquisition manager", "recruiter",
    "technical recruiter", "senior recruiter", "recruitment consultant",
    "training manager", "learning and development manager",
    "compensation and benefits manager", "payroll executive",
    "hr analyst", "people operations manager", "admin executive",
    "office administrator", "executive assistant", "personal assistant",
    "receptionist", "office manager", "facilities manager",
    # Finance & Accounting
    "accountant", "senior accountant", "chartered accountant", "ca",
    "accounts executive", "accounts manager", "finance executive", "finance manager",
    "financial analyst", "financial controller", "treasury manager",
    "audit executive", "internal auditor", "external auditor", "tax consultant",
    "company secretary", "cs", "cost accountant", "cma",
    "credit analyst", "risk analyst", "investment analyst", "equity analyst",
    "portfolio manager", "wealth manager", "financial planner",
    # Content & Communication
    "content writer", "copywriter", "technical writer", "editor", "sub editor",
    "journalist", "reporter", "correspondent", "public relations executive",
    "communications manager", "corporate communications executive",
    # Operations & Supply Chain
    "operations executive", "operations analyst", "supply chain manager",
    "logistics manager", "logistics executive", "warehouse manager",
    "procurement manager", "purchase manager", "vendor manager",
    "inventory manager", "import export executive", "customs officer",
    # Legal
    "legal executive", "legal advisor", "legal counsel", "company lawyer",
    "corporate lawyer", "compliance officer", "compliance manager",
    # Customer Service
    "customer service executive", "customer support executive",
    "customer success manager", "call center executive", "helpdesk executive",
    "technical support engineer", "support engineer",
    # Education & Training
    "teacher", "lecturer", "professor", "assistant professor",
    "training executive", "corporate trainer", "instructional designer",
    "curriculum developer", "academic counselor",
    # Healthcare
    "doctor", "physician", "surgeon", "nurse", "staff nurse",
    "pharmacist", "lab technician", "medical representative",
    "clinical research associate", "medical officer",
    # Manufacturing & Engineering (non-IT)
    "mechanical engineer", "civil engineer", "electrical engineer",
    "electronics engineer", "chemical engineer", "production engineer",
    "manufacturing engineer", "industrial engineer", "process engineer",
    "quality engineer", "quality manager", "maintenance engineer",
    "plant manager", "factory manager", "safety officer",
    "environment health safety officer", "ehs manager",
    # Consulting & Analytics
    "business analyst", "management consultant", "strategy consultant",
    "associate consultant", "senior consultant", "principal consultant",
    "analytics manager", "bi analyst", "bi developer",
    "tableau developer", "power bi developer", "etl developer",
    # Miscellaneous
    "executive", "associate", "analyst", "specialist", "coordinator",
    "supervisor", "officer", "assistant", "trainee", "apprentice", "intern",
])


# ── Salary Parsing ────────────────────────────────────────────────────────────

def _parse_monthly_salary_inr(salary_str: Optional[str]) -> Optional[float]:
    """
    Best-effort extraction of monthly salary in INR from a free-text salary string.
    Returns the MAXIMUM value if a range is given (to catch inflated upper bounds).
    Handles: "LPA", "per month", "k/month", "per annum", bare numbers.
    """
    if not salary_str:
        return None

    s = salary_str.lower().replace(",", "").replace("₹", "").replace("rs.", "").replace("rs", "").strip()
    nums = [float(n) for n in _SALARY_NUMBER_RE.findall(s) if n]
    if not nums:
        return None

    # Use the maximum value in the range
    val = max(nums)

    # "k/month" or "k per month"
    if "k/month" in s or "k per month" in s or "k / month" in s:
        return val * 1000

    # "LPA" or "lakhs per annum"
    if "lpa" in s or "l/yr" in s or "lakhs per annum" in s or "lakh per annum" in s or "lac per annum" in s:
        return (val * 100_000) / 12

    # "lakh/month" or "l/month"
    if "l/month" in s or "lakh/month" in s or "lakhs/month" in s or "lakh per month" in s:
        return val * 100_000

    # "per month" or "/month"
    if "per month" in s or "/month" in s or "monthly" in s:
        return val

    # "per annum" or "/year" or "/yr"
    if "per annum" in s or "/year" in s or "/yr" in s or "annual" in s or "yearly" in s:
        return val / 12

    # Bare number heuristics
    if val >= 100_000:
        # Likely annual in INR (e.g., "600000") → monthly
        return val / 12
    elif val >= 1_000:
        # Likely monthly in INR (e.g., "50000")
        return val
    elif val >= 1:
        # Likely LPA (e.g., "6") → monthly
        return (val * 100_000) / 12

    return None


def _salary_range_ratio(salary_str: Optional[str]) -> Optional[float]:
    """Returns max/min ratio if a range is detected, else None."""
    if not salary_str:
        return None
    s = salary_str.lower().replace(",", "").replace("₹", "").replace("rs.", "").replace("rs", "").strip()
    nums = [float(n) for n in _SALARY_NUMBER_RE.findall(s) if n and float(n) > 0]
    if len(nums) >= 2:
        return max(nums) / min(nums)
    return None


# ── Core Check Function ──────────────────────────────────────────────────────

def check(listing: JobListing) -> RuleEngineResult:
    """
    Run all hard and soft rules against a job listing.
    Returns a RuleEngineResult with verdict, score, triggers, and skip_ml flag.
    """
    hard_triggers: List[str] = []
    soft_triggers: List[str] = []
    suspicion_score = 0
    desc_lower = (listing.description or "").lower()
    title_lower = (listing.title or "").lower()
    company = (listing.company or "").strip()

    # ── HARD RULES ────────────────────────────────────────────────────────────

    # H1: Fresher salary unrealism (> ₹80,000/month for freshers)
    is_fresher = any(
        sig in title_lower or sig in (listing.experience_required or "").lower()
        for sig in _FRESHER_SIGNALS
    )
    if is_fresher and listing.salary_range:
        monthly = _parse_monthly_salary_inr(listing.salary_range)
        if monthly and monthly > 80_000:
            hard_triggers.append("H1:fresher_salary_unrealism")

    # H2: Payment demand keywords
    for phrase in _PAYMENT_DEMAND_PHRASES:
        if phrase in desc_lower:
            hard_triggers.append(f"H2:payment_demand:{phrase}")
            break  # One is enough

    # H3: WhatsApp-only contact
    if _WHATSAPP_PATTERNS.search(desc_lower):
        has_company_email = bool(_COMPANY_EMAIL_RE.search(listing.description or ""))
        if not has_company_email:
            hard_triggers.append("H3:whatsapp_only_contact")

    # H4: No company name
    if not company or company.lower() in ("-", "n/a", "na", "none", "confidential") or len(company) < 3:
        hard_triggers.append("H4:no_company_name")

    # H5: Suspicious URL patterns
    source_url = (listing.source_url or "").lower()
    if source_url:
        from urllib.parse import urlparse
        try:
            parsed = urlparse(source_url)
            netloc = parsed.netloc.lower()

            # Check for URL shorteners
            for shortener in _URL_SHORTENERS:
                if shortener in netloc:
                    hard_triggers.append(f"H5:url_shortener:{shortener}")
                    break

            # Check for suspicious double extensions
            if _SUSPICIOUS_DOUBLE_EXT_RE.search(netloc):
                hard_triggers.append("H5:suspicious_double_extension")

            # Check for untrusted TLD (only if not already flagged above)
            if not any(t.startswith("H5:") for t in hard_triggers):
                if netloc and not any(netloc.endswith(tld) for tld in _TRUSTED_TLD_ENDINGS):
                    hard_triggers.append("H5:untrusted_tld")
        except Exception:
            hard_triggers.append("H5:url_parse_error")


    # ── SOFT RULES ────────────────────────────────────────────────────────────

    # S1: Vague company info (no LinkedIn URL or website in description)  +10
    if not re.search(r"linkedin\.com|www\.|https?://", desc_lower):
        soft_triggers.append("S1:vague_company_info")
        suspicion_score += 10

    # S2: Suspiciously wide salary range (ratio > 5×)  +15
    ratio = _salary_range_ratio(listing.salary_range)
    if ratio and ratio > 5.0:
        soft_triggers.append("S2:wide_salary_range")
        suspicion_score += 15

    # S3: Excessive caps / punctuation in title  +20
    if _EXCESSIVE_CAPS_RE.search(listing.title or "") or _EXCESSIVE_PUNCT_RE.search(listing.title or ""):
        soft_triggers.append("S3:excessive_caps_punctuation")
        suspicion_score += 20

    # S4: MLM / scam keywords  +25 each
    for kw in _MLM_KEYWORDS:
        if kw in desc_lower:
            soft_triggers.append(f"S4:mlm_keyword:{kw}")
            suspicion_score += 25

    # S5: No skills_required  +5
    if not listing.skills_required:
        soft_triggers.append("S5:no_skills_listed")
        suspicion_score += 5

    # S6: Posted by individual  +15
    for marker in _INDIVIDUAL_MARKERS:
        if marker in title_lower:
            soft_triggers.append(f"S6:individual_poster:{marker}")
            suspicion_score += 15
            break

    # S7: Personal email in description  +20
    if _PERSONAL_EMAIL_RE.search(listing.description or ""):
        soft_triggers.append("S7:personal_email")
        suspicion_score += 20

    # S8: Non-standard job title  +15
    title_normalised = re.sub(r"[^a-z\s]", "", title_lower).strip()
    title_matches = any(
        common_title in title_normalised
        for common_title in COMMON_JOB_TITLES
    )
    if not title_matches and title_normalised:
        soft_triggers.append("S8:non_standard_title")
        suspicion_score += 15

    # S9: Tiny description  +15
    if len((listing.description or "").strip()) < 80:
        soft_triggers.append("S9:tiny_description")
        suspicion_score += 15

    # Cap suspicion score at 100
    suspicion_score = min(suspicion_score, 100)

    # ── DECISION LOGIC ────────────────────────────────────────────────────────

    if hard_triggers:
        verdict = "flagged"
        skip_ml = True
    elif suspicion_score >= 70:
        verdict = "flagged"
        skip_ml = True
    elif suspicion_score >= 40:
        verdict = "inconclusive"
        skip_ml = False
    else:
        verdict = "verified"
        skip_ml = True

    result = RuleEngineResult(
        verdict=verdict,
        suspicion_score=suspicion_score,
        hard_rule_triggers=hard_triggers,
        soft_rule_triggers=soft_triggers,
        skip_ml=skip_ml,
    )

    if hard_triggers or soft_triggers:
        logger.info(
            "Rule engine → %s (score=%d, hard=%s, soft=%s)",
            verdict, suspicion_score, hard_triggers, soft_triggers,
        )

    return result
