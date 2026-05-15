"""
scam_detection/domain_validator.py — Domain reachability, MCA/GSTIN stub, and
LinkedIn company page existence checks.

Three checks:
  1. Domain reachability — HEAD request, 5s timeout
  2. MCA/GSTIN stub    — local JSON lookup (top 500 Indian companies)
  3. LinkedIn page     — HEAD request, 8s timeout
"""

import json
import logging
import re
from pathlib import Path
from typing import Optional
from urllib.parse import urlparse

import httpx

from models.job_listing import JobListing
from scam_detection.models import DomainValidationResult

logger = logging.getLogger(__name__)

# ── Load known legitimate companies (once at import) ──────────────────────────

_DATA_DIR = Path(__file__).resolve().parent.parent / "data"
_KNOWN_COMPANIES_FILE = _DATA_DIR / "known_legitimate_companies.json"

_known_companies: set[str] = set()
try:
    with open(_KNOWN_COMPANIES_FILE, "r", encoding="utf-8") as f:
        _raw = json.load(f)
    _known_companies = {name.strip().lower() for name in _raw if isinstance(name, str)}
    logger.info("Loaded %d known legitimate companies.", len(_known_companies))
except FileNotFoundError:
    logger.warning("known_legitimate_companies.json not found — MCA stub disabled.")
except Exception as exc:
    logger.warning("Failed to load known companies: %s", exc)


def _slugify(name: str) -> str:
    """Convert a company name to a LinkedIn-style slug."""
    slug = name.lower().strip()
    slug = re.sub(r"[^a-z0-9\s-]", "", slug)
    slug = re.sub(r"[\s]+", "-", slug)
    return slug.strip("-")


# ── Public API ────────────────────────────────────────────────────────────────

async def validate(listing: JobListing) -> DomainValidationResult:
    """
    Run all three domain validation checks and return aggregated result.
    Each check is independent — failures in one do not block the others.
    """
    flag_reasons: list[str] = []
    suspicion_delta = 0
    domain_reachable: Optional[bool] = None
    verified_company = False
    company_linkedin_exists: Optional[bool] = None

    # ── Check 1: Domain reachability ──────────────────────────────────────────
    domain_reachable = await _check_domain_reachability(listing.source_url)
    if domain_reachable is False:
        flag_reasons.append("Job source domain is unreachable or returned an error.")
        suspicion_delta += 20

    # ── Check 2: MCA/GSTIN stub — local lookup ───────────────────────────────
    # TODO: Replace with live MCA API call:
    #       https://www.mca.gov.in/mcafoportal/viewCompanyMasterData.do
    company_name = (listing.company or "").strip()
    if company_name:
        verified_company = _check_known_company(company_name)
        if verified_company:
            logger.debug("Company '%s' found in known-legitimate list.", company_name)

    # ── Check 3: LinkedIn company page existence ──────────────────────────────
    if company_name:
        company_linkedin_exists = await _check_linkedin_page(company_name)
        if company_linkedin_exists is False:
            flag_reasons.append(
                f"No LinkedIn company page found for '{company_name}'."
            )
            suspicion_delta += 15

    return DomainValidationResult(
        domain_reachable=domain_reachable,
        verified_company=verified_company,
        company_linkedin_exists=company_linkedin_exists,
        suspicion_delta=suspicion_delta,
        flag_reasons=flag_reasons,
    )


# ── Internal checks ──────────────────────────────────────────────────────────

async def _check_domain_reachability(source_url: str) -> Optional[bool]:
    """HEAD request to the job source domain with 5s timeout."""
    if not source_url:
        return None
    try:
        parsed = urlparse(source_url)
        domain = f"{parsed.scheme}://{parsed.netloc}"
        if not parsed.netloc:
            return None

        async with httpx.AsyncClient(timeout=5.0, follow_redirects=True) as client:
            resp = await client.head(domain)
            if resp.status_code >= 400:
                logger.debug("Domain %s returned %d.", domain, resp.status_code)
                return False
            return True
    except httpx.ConnectError:
        logger.debug("Domain unreachable (connect error): %s", source_url)
        return False
    except httpx.TimeoutException:
        logger.debug("Domain unreachable (timeout): %s", source_url)
        return False
    except Exception as exc:
        logger.debug("Domain check failed: %s", exc)
        return None


def _check_known_company(company_name: str) -> bool:
    """Check if the company appears in the known-legitimate list (fuzzy-ish)."""
    normalised = company_name.strip().lower()
    if normalised in _known_companies:
        return True
    # Try partial match: "Tata Consultancy Services Ltd" → "tata consultancy services"
    for known in _known_companies:
        if known in normalised or normalised in known:
            return True
    return False


async def _check_linkedin_page(company_name: str) -> Optional[bool]:
    """HEAD request to LinkedIn company page with 8s timeout."""
    slug = _slugify(company_name)
    if not slug:
        return None
    url = f"https://www.linkedin.com/company/{slug}"
    try:
        async with httpx.AsyncClient(
            timeout=8.0,
            follow_redirects=True,
            headers={"User-Agent": "Mozilla/5.0 (compatible; SkillMap/1.0)"},
        ) as client:
            resp = await client.head(url)
            if resp.status_code == 200:
                return True
            if resp.status_code == 404:
                return False
            # LinkedIn may return 999 for bot detection — treat as unknown
            return None
    except Exception as exc:
        logger.debug("LinkedIn check failed for '%s': %s", company_name, exc)
        return None
