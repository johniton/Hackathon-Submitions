"""
Hustlr AI Interview — STT Service
Routes audio to the best available STT engine.
English-only: Groq Whisper primary, local Whisper fallback.
"""
import os
import httpx
from dotenv import load_dotenv

load_dotenv()

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_WHISPER_MODEL = os.getenv("GROQ_WHISPER_MODEL", "whisper-large-v3")


async def transcribe(audio_path: str, language: str = "en") -> dict:
    """
    Transcribe audio using Groq Whisper (cloud, fast).
    Falls back to local Whisper if Groq fails.
    """
    try:
        return await groq_whisper_transcribe(audio_path, language)
    except Exception as e:
        print(f"[WARN] Groq Whisper failed: {e}, falling back to local Whisper")
        try:
            return await local_whisper_transcribe(audio_path, language)
        except Exception as e2:
            print(f"[WARN] Local Whisper also failed: {e2}")
            return {
                "text": "[Transcription failed]",
                "language": language,
                "engine": "failed",
            }


async def groq_whisper_transcribe(audio_path: str, language: str = "en") -> dict:
    """Transcribe audio using Groq's Whisper API (cloud, fast, free tier)."""
    if not GROQ_API_KEY:
        raise ValueError("GROQ_API_KEY not set")

    async with httpx.AsyncClient(timeout=60.0) as client:
        with open(audio_path, "rb") as f:
            response = await client.post(
                "https://api.groq.com/openai/v1/audio/transcriptions",
                headers={"Authorization": f"Bearer {GROQ_API_KEY}"},
                files={"file": (os.path.basename(audio_path), f, "audio/wav")},
                data={
                    "model": GROQ_WHISPER_MODEL,
                    "language": language,
                    "response_format": "json",
                },
            )
            response.raise_for_status()
            data = response.json()

    return {
        "text": data.get("text", ""),
        "language": language,
        "duration": data.get("duration"),
        "engine": "groq_whisper",
    }


async def local_whisper_transcribe(audio_path: str, language: str = "en") -> dict:
    """Transcribe audio using local Whisper model (offline fallback)."""
    try:
        import torch
        import librosa
        from transformers import WhisperProcessor, WhisperForConditionalGeneration

        model_id = os.getenv("LOCAL_WHISPER_MODEL_ID", "openai/whisper-tiny")

        processor = WhisperProcessor.from_pretrained(model_id)
        model = WhisperForConditionalGeneration.from_pretrained(model_id)

        try:
            model.config.forced_decoder_ids = processor.get_decoder_prompt_ids(
                language=language, task="transcribe"
            )
        except Exception:
            pass

        audio, sr = librosa.load(audio_path, sr=16000)
        inputs = processor(audio, sampling_rate=16000, return_tensors="pt")

        with torch.no_grad():
            predicted_ids = model.generate(inputs["input_features"])

        transcript = processor.batch_decode(predicted_ids, skip_special_tokens=True)[0]

        return {
            "text": transcript,
            "language": language,
            "duration": len(audio) / sr,
            "engine": "local_whisper",
        }
    except ImportError:
        raise RuntimeError("torch/transformers not installed for local Whisper fallback")
