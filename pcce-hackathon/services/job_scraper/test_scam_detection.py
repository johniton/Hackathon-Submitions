#!/usr/bin/env python3
"""
test_scam_detection.py — Quick sanity tests for the scam detection pipeline.

Runs directly against the rule_engine and trust_scorer without needing
a live server or Redis. Just run:

    cd services/job_scraper
    source venv/bin/activate
    python test_scam_detection.py
"""

import sys
import os
from datetime import datetime, timezone

# Add project root to path so imports work
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from models.job_listing import JobListing
from scam_detection import rule_engine
from scam_detection.models import RuleEngineResult

# ── Helpers ───────────────────────────────────────────────────────────────────

def make_job(**overrides) -> JobListing:
    """Create a baseline legitimate job listing with optional overrides."""
    defaults = dict(
        id="test-job-001",
        title="Software Engineer",
        company="Tata Consultancy Services",
        location="Bangalore",
        salary_range="8-12 LPA",
        experience_required="2-4 years",
        skills_required=["Python", "Django", "REST APIs"],
        description=(
            "We are looking for a skilled Software Engineer to join our Bangalore team. "
            "You will work on enterprise-grade backend systems using Python and Django. "
            "Strong knowledge of REST APIs and SQL required. Apply via careers.tcs.com."
        ),
        source="naukri",
        source_url="https://www.naukri.com/job-listings-software-engineer-tcs",
        scraped_at=datetime.now(timezone.utc),
        freshness_days=2,
    )
    defaults.update(overrides)
    return JobListing(**defaults)


PASS = "✅ PASS"
FAIL = "❌ FAIL"
results = []

def test(name: str, listing: JobListing, expected_verdict: str, expected_triggers=None):
    result: RuleEngineResult = rule_engine.check(listing)
    ok = result.verdict == expected_verdict
    if expected_triggers:
        # Check that at least one expected trigger prefix is present
        all_triggers = result.hard_rule_triggers + result.soft_rule_triggers
        trigger_ok = any(
            any(t.startswith(exp) for t in all_triggers)
            for exp in expected_triggers
        )
        ok = ok and trigger_ok

    icon = PASS if ok else FAIL
    results.append(ok)

    print(f"\n{icon}  {name}")
    print(f"     verdict={result.verdict}  score={result.suspicion_score}  skip_ml={result.skip_ml}")
    if result.hard_rule_triggers:
        print(f"     hard  → {result.hard_rule_triggers}")
    if result.soft_rule_triggers:
        print(f"     soft  → {result.soft_rule_triggers}")
    if not ok:
        print(f"     ⚠  EXPECTED verdict='{expected_verdict}'  got='{result.verdict}'")


# ─────────────────────────────────────────────────────────────────────────────
# TEST CASES
# ─────────────────────────────────────────────────────────────────────────────

print("=" * 60)
print("  Scam Detection — Rule Engine Tests")
print("=" * 60)

# ── Legitimate listing (should be verified) ───────────────────────────────────
test(
    "Legitimate TCS job → verified",
    make_job(),
    expected_verdict="verified",
)

# ── H1: Fresher salary too high ───────────────────────────────────────────────
test(
    "H1: Fresher role with ₹2L/month salary → flagged",
    make_job(
        title="Software Developer Fresher",
        experience_required="0 years / fresher",
        salary_range="2,00,000 per month",
    ),
    expected_verdict="flagged",
    expected_triggers=["H1:"],
)

# ── H2: Payment demand ────────────────────────────────────────────────────────
test(
    "H2: 'pay registration fee' in description → flagged",
    make_job(
        description=(
            "Great opportunity! Work from home. You must pay registration fee of Rs 500 "
            "to get started. Earn up to 50,000 per month. Guaranteed income for all."
        )
    ),
    expected_verdict="flagged",
    expected_triggers=["H2:"],
)

test(
    "H2: 'security deposit' in description → flagged",
    make_job(description="Join us! Pay security deposit of Rs 2000. Get kit and start earning."),
    expected_verdict="flagged",
    expected_triggers=["H2:"],
)

# ── H3: WhatsApp-only ─────────────────────────────────────────────────────────
test(
    "H3: WhatsApp-only contact, no company email → flagged",
    make_job(
        description=(
            "We are hiring! Contact on WhatsApp only: 9876543210. "
            "Work from home, earn daily. No office required."
        )
    ),
    expected_verdict="flagged",
    expected_triggers=["H3:"],
)

# ── H4: No company name ───────────────────────────────────────────────────────
test(
    "H4: Empty company name → flagged",
    make_job(company=""),
    expected_verdict="flagged",
    expected_triggers=["H4:"],
)

test(
    "H4: Company name 'N/A' → flagged",
    make_job(company="N/A"),
    expected_verdict="flagged",
    expected_triggers=["H4:"],
)

# ── H5: URL shortener ─────────────────────────────────────────────────────────
test(
    "H5: bit.ly URL → flagged",
    make_job(source_url="https://bit.ly/scamjob123"),
    expected_verdict="flagged",
    expected_triggers=["H5:url_shortener"],
)

test(
    "H5: Suspicious double extension → flagged",
    make_job(source_url="https://jobs.com.tk/apply"),
    expected_verdict="flagged",
    expected_triggers=["H5:"],
)

# ── H6: Tiny description ──────────────────────────────────────────────────────
test(
    "H6: Description < 80 chars → flagged",
    make_job(description="Good job. Apply now. Call us."),
    expected_verdict="flagged",
    expected_triggers=["H6:"],
)

# ── S4: MLM keywords ──────────────────────────────────────────────────────────
test(
    "S4: 'network marketing' + 'be your own boss' → flagged (score ≥ 70)",
    make_job(
        description=(
            "Join our network marketing team! Be your own boss and earn unlimited! "
            "This is direct selling. Work from home earn daily. No experience needed. "
            "Earn from day one. Great MLM opportunity for freshers. Apply today!"
        ),
        skills_required=[],  # S5: +10
        company="AB",         # H4: flagged immediately
    ),
    expected_verdict="flagged",
)

# ── S3: Excessive caps in title ───────────────────────────────────────────────
test(
    "S3: ALLCAPS title → inconclusive (S1+S3+S8 = score 55, sent to ML)",
    make_job(title="URGENT HIRING NOW EARN BIG MONEY"),
    expected_verdict="inconclusive",   # S1(20)+S3(20)+S8(15) = 55 → ML layer
    expected_triggers=["S3:"],
)

# ── Salary parsing — LPA ──────────────────────────────────────────────────────
test(
    "Salary 8-12 LPA for experienced → verified (not flagged)",
    make_job(
        salary_range="8-12 LPA",
        experience_required="3-5 years",
        title="Senior Software Engineer",
    ),
    expected_verdict="verified",
)

test(
    "Salary 50k/month for fresher → not flagged (under ₹80k threshold)",
    make_job(
        salary_range="50,000 per month",
        experience_required="fresher",
        title="Junior Developer Fresher",
    ),
    expected_verdict="verified",
)

test(
    "Salary 1,50,000 per month for fresher → flagged (over ₹80k)",
    make_job(
        salary_range="1,50,000 per month",
        experience_required="fresher",
        title="Data Entry Fresher",
    ),
    expected_verdict="flagged",
    expected_triggers=["H1:"],
)

# ── Internshala internship listing ────────────────────────────────────────────
test(
    "Legitimate Internshala internship → verified",
    make_job(
        title="Flutter Developer Intern",
        company="Swiggy",
        source="internshala",
        source_url="https://internshala.com/internship/flutter-dev",
        salary_range="15,000 per month",
        experience_required="0 year",
        skills_required=["Flutter", "Dart", "Firebase"],
        description=(
            "Swiggy is looking for a Flutter Developer Intern for our mobile team. "
            "You will work on the consumer-facing Flutter app. "
            "Stipend: Rs 15,000/month. Duration: 3 months. Apply at internshala.com."
        ),
    ),
    expected_verdict="verified",
)

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────

passed = sum(results)
total = len(results)
print("\n" + "=" * 60)
print(f"  Results: {passed}/{total} passed")
if passed == total:
    print("  🎉 All tests passed!")
else:
    print(f"  ⚠  {total - passed} test(s) failed — check output above.")
print("=" * 60)

sys.exit(0 if passed == total else 1)
