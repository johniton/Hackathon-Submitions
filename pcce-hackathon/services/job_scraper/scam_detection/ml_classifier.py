"""
scam_detection/ml_classifier.py — Layer 2: lightweight ML-based scam classifier.

Uses bert-tiny (~17 MB) for text classification. Runs ONLY when rule engine
returns "inconclusive". Model loaded ONCE at startup in a background thread.
"""

import logging
import threading
from typing import Optional, Literal, Tuple

logger = logging.getLogger(__name__)

_pipeline = None
_model_load_error: Optional[str] = None
_model_loaded = threading.Event()


def _load_model_background() -> None:
    global _pipeline, _model_load_error
    try:
        from transformers import pipeline as hf_pipeline
        logger.info("Loading ML scam classifier model (bert-tiny) …")
        _pipeline = hf_pipeline(
            "text-classification",
            model="mrm8488/bert-tiny-finetuned-sms-spam-detection",
            device=-1,
            truncation=True,
            max_length=512,
        )
        logger.info("ML scam classifier loaded successfully.")
    except Exception as exc:
        _model_load_error = str(exc)
        logger.warning("ML classifier failed to load — Layer 2 skipped: %s", exc)
    finally:
        _model_loaded.set()


_loader_thread = threading.Thread(target=_load_model_background, daemon=True)
_loader_thread.start()


def classify(title: str, company: str, description: str) -> Optional[float]:
    """Return scam probability 0.0–1.0, or None if model unavailable."""
    _model_loaded.wait(timeout=30)
    if _pipeline is None:
        logger.debug("ML classifier unavailable — skipping Layer 2.")
        return None
    try:
        text = f"{title} | {company} | {description}"
        result = _pipeline(text)[0]
        label = result["label"]
        score = result["score"]
        if label == "LABEL_1":
            return round(score, 4)
        else:
            return round(1.0 - score, 4)
    except Exception as exc:
        logger.warning("ML classifier inference failed: %s", exc)
        return None


def score_to_verdict(ml_score: Optional[float]) -> Optional[Literal["verified", "caution", "flagged"]]:
    if ml_score is None:
        return None
    if ml_score >= 0.75:
        return "flagged"
    if ml_score >= 0.45:
        return "caution"
    return "verified"


def classify_with_verdict(
    title: str, company: str, description: str,
) -> Tuple[Optional[float], Optional[str]]:
    score = classify(title, company, description)
    return score, score_to_verdict(score)


def is_model_ready() -> bool:
    return _model_loaded.is_set() and _pipeline is not None
