"""
ranker.py — Skill-match scoring between user profile and job requirements.

Uses Jaccard similarity for v1 — fast, interpretable, no ML needed.

  match_score = |intersection(user_skills, job_skills)| / |union(user_skills, job_skills)|

Returns a float in [0.0, 1.0].
  1.0 = perfect match
  0.0 = no skill overlap

Example:
  user_skills     = {"python", "django", "postgresql"}
  job_skills      = {"python", "postgresql", "aws"}
  intersection    = {"python", "postgresql"}  → 2
  union           = {"python", "django", "postgresql", "aws"}  → 4
  match_score     = 2 / 4 = 0.5
"""

import logging
from typing import List

logger = logging.getLogger(__name__)


def _normalise(skills: List[str]) -> set[str]:
    """Lowercase, strip whitespace, remove empty strings."""
    return {s.strip().lower() for s in skills if s.strip()}


class Ranker:
    """
    Computes a Jaccard similarity match score between a user's skill set
    and a job's required skills.

    Designed to be stateless and thread-safe — construct once and reuse.
    """

    def score(
        self,
        user_skills: List[str],
        job_required_skills: List[str],
    ) -> float:
        """
        Returns match_score ∈ [0.0, 1.0].
        Returns 0.0 if either skill set is empty (avoids division-by-zero).
        """
        user_set = _normalise(user_skills)
        job_set = _normalise(job_required_skills)

        if not user_set or not job_set:
            logger.debug(
                "Ranker: empty skill set — user=%d job=%d → score=0.0",
                len(user_set), len(job_set),
            )
            return 0.0

        intersection = user_set & job_set
        union = user_set | job_set

        score = len(intersection) / len(union)
        logger.debug(
            "Ranker: intersection=%d union=%d → score=%.3f",
            len(intersection), len(union), score,
        )
        return round(score, 4)

    def rank(
        self,
        jobs: list,          # List[JobListing]
        user_skills: List[str],
    ) -> list:
        """
        Sets match_score on each JobListing in-place,
        then returns the list sorted descending by match_score.
        """
        for job in jobs:
            job.match_score = self.score(user_skills, job.skills_required)
        return sorted(jobs, key=lambda j: j.match_score, reverse=True)
