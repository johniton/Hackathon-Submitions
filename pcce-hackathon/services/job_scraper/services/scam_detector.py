"""
scam_detector.py — Rule-based v1 scam/fraud detection for job listings.

No ML required at this stage. Rules are deterministic and fast.
Future v2 can swap in a fine-tuned classifier while keeping the same interface.

Trust score levels:
  verified  — passed all checks
  caution   — 1–2 soft flags (unusual but not conclusive)
  flagged   — hard flag: very likely fraudulent
"""

import re
import logging
from urllib.parse import urlparse
from typing import List, Tuple

logger = logging.getLogger(__name__)

# ─── Rule constants ────────────────────────────────────────────────────────────

# Hard-flag phrases that commonly appear in scam JDs (case-insensitive)
_SCAM_PHRASES: List[str] = [
    "work from home earn",
    "no experience rs",
    "whatsapp only",
    "pay registration fee",
    "registration charges",
    "pay to apply",
    "send your details on whatsapp",
    "earn rs daily",
    "earn money from home",
    "data entry work from home",
    "part time online job",
    "refer and earn",
    "guaranteed income",
]

# Salary threshold above which a "freshers" role is suspicious (in lakhs per month)
_MAX_FRESHER_MONTHLY_SALARY_LAKHS = 5.0

# Minimum acceptable company name length
_MIN_COMPANY_NAME_LEN = 3

# Trusted top-level domains
_TRUSTED_TLDS = {".com", ".in", ".co.in", ".org", ".net", ".io", ".gov.in"}

# Regex to extract numeric salary from strings like "₹6L/month" or "6,00,000"
_SALARY_NUMBER_RE = re.compile(r"[\d,.]+")


def _extract_monthly_lakhs(salary_str: str) -> float | None:
    """
    Best-effort salary extraction returning monthly value in lakhs.
    Handles formats: "₹6L/month", "5-8 LPA", "60000/month", "6,00,000".
    Returns None if the salary string is uninterpretable.
    """
    s = salary_str.lower().replace(",", "")
    nums = _SALARY_NUMBER_RE.findall(s)
    if not nums:
        return None

    val = float(nums[0])

    if "lpa" in s or "l/yr" in s or "lakhs per annum" in s:
        return val / 12  # convert annual lakhs to monthly

    if "l/month" in s or "lakh/month" in s or "lakhs/month" in s:
        return val

    # Bare number — assume annual salary in Rs if > 10000, else treat as LPA
    if val > 10_000:
        return (val / 100_000) / 12  # Rs per annum → monthly lakhs
    return val / 12  # treat as LPA


class ScamDetector:
    """
    Analyses a job listing and returns a trust score with reasons.
    """

    def analyse(
        self,
        *,
        company: str,
        title: str,
        description: str,
        salary_range: str | None,
        source_url: str,
        experience_required: str | None,
    ) -> Tuple[str, List[str]]:
        """
        Returns (trust_score, flag_reasons).
        trust_score ∈ {"verified", "caution", "flagged"}
        """
        reasons: List[str] = []
        hard_flag = False

        # Rule 1: Empty or too-short company name
        if not company or len(company.strip()) < _MIN_COMPANY_NAME_LEN:
            reasons.append("Company name is missing or too short.")
            hard_flag = True

        # Rule 2: Scam phrases in description
        desc_lower = description.lower()
        for phrase in _SCAM_PHRASES:
            if phrase in desc_lower:
                reasons.append(f"Suspicious phrase detected: '{phrase}'.")
                hard_flag = True
                break  # One phrase is enough to flag

        # Rule 3: Unrealistic salary for freshers
        if salary_range:
            is_fresher = self._is_fresher_role(title, experience_required)
            monthly = _extract_monthly_lakhs(salary_range)
            if is_fresher and monthly and monthly > _MAX_FRESHER_MONTHLY_SALARY_LAKHS:
                reasons.append(
                    f"Salary ({salary_range}) appears unrealistically high for a fresher role."
                )
                hard_flag = True

        # Rule 4: Untrusted URL domain
        url_ok, url_reason = self._check_url(source_url)
        if not url_ok:
            reasons.append(url_reason)
            # Soft flag only — job boards often use redirect URLs

        # Determine trust score
        if hard_flag:
            score = "flagged"
        elif reasons:
            score = "caution"
        else:
            score = "verified"

        if reasons:
            logger.debug("Scam check → %s: %s", score, reasons)

        return score, reasons

    # ── Helpers ───────────────────────────────────────────────────────────────

    @staticmethod
    def _is_fresher_role(title: str, experience_required: str | None) -> bool:
        title_l = title.lower()
        exp_l = (experience_required or "").lower()
        fresher_signals = ["fresher", "0 year", "0-1 year", "entry level", "graduate", "trainee"]
        return any(s in title_l or s in exp_l for s in fresher_signals)

    @staticmethod
    def _check_url(url: str) -> Tuple[bool, str]:
        if not url:
            return False, "Job listing has no source URL."
        try:
            parsed = urlparse(url)
            netloc = parsed.netloc.lower()
            for tld in _TRUSTED_TLDS:
                if netloc.endswith(tld):
                    return True, ""
            return False, f"Job URL domain '{netloc}' is not in the trusted TLD list."
        except Exception:  # noqa: BLE001
            return False, "Job source URL could not be parsed."
