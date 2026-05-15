"""
Hustlr AI Interview — Audio Service
Extract audio from video files using ffmpeg.
"""
import os
import asyncio
import subprocess


async def extract_audio_from_video(video_path: str, output_format: str = "wav") -> str:
    """
    Extract audio track from video file using ffmpeg.
    Returns path to the extracted audio file.
    """
    output_path = video_path.rsplit(".", 1)[0] + f".{output_format}"

    cmd = [
        "ffmpeg", "-y",
        "-i", video_path,
        "-vn",                  # No video
        "-acodec", "pcm_s16le", # PCM 16-bit
        "-ar", "16000",         # 16kHz sample rate (optimal for Whisper)
        "-ac", "1",             # Mono
        output_path,
    ]

    try:
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        _, stderr = await asyncio.wait_for(process.communicate(), timeout=60)

        if process.returncode != 0:
            err_msg = stderr.decode() if stderr else "Unknown error"
            print(f"[AUDIO] ffmpeg failed: {err_msg}")
            raise RuntimeError(f"ffmpeg extraction failed: {err_msg}")

        if not os.path.exists(output_path) or os.path.getsize(output_path) == 0:
            raise RuntimeError("Audio extraction produced empty file")

        return output_path

    except asyncio.TimeoutError:
        raise RuntimeError("Audio extraction timed out (60s)")
    except FileNotFoundError:
        # ffmpeg not installed — try with subprocess as fallback
        try:
            subprocess.run(cmd, capture_output=True, timeout=60, check=True)
            return output_path
        except FileNotFoundError:
            raise RuntimeError("ffmpeg is not installed. Install with: sudo apt install ffmpeg")
