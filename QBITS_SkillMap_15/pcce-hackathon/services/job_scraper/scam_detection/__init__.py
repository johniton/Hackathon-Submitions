"""
scam_detection — Two-layer scam detection pipeline for SkillMap job listings.

Public API:
    analyse_listing()   — full pipeline (rule engine → ML → domain → community)
    report_scam()       — submit a community flag
    get_cached_result() — fetch a previously cached ScamAnalysisResult
"""

from scam_detection.trust_scorer import analyse_listing, get_cached_result
from scam_detection.community_flags import add_flag as report_scam

__all__ = ["analyse_listing", "report_scam", "get_cached_result"]
