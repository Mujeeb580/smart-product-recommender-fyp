"""Secure server-side speech-to-text integration for chat voice input."""

from __future__ import annotations

import os
from typing import Optional

import requests


class TranscriptionConfigurationError(RuntimeError):
    """Raised when voice transcription is not configured on the server."""


class TranscriptionProviderError(RuntimeError):
    """Raised when the upstream transcription provider rejects a request."""


def transcribe_audio(
    *,
    filename: str,
    content: bytes,
    content_type: Optional[str] = None,
) -> str:
    """Transcribe one audio file with OpenAI and return non-empty text."""
    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if not api_key:
        raise TranscriptionConfigurationError(
            "Voice input is not configured. Set OPENAI_API_KEY on the backend."
        )

    model = os.getenv("OPENAI_TRANSCRIBE_MODEL", "gpt-4o-transcribe").strip()
    base_url = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1").rstrip("/")
    timeout_seconds = float(os.getenv("OPENAI_TRANSCRIBE_TIMEOUT_SECONDS", "45"))
    prompt = os.getenv(
        "OPENAI_TRANSCRIBE_PROMPT",
        (
            "The speaker may use English, Urdu, or Roman Urdu. Transcribe every audible "
            "word accurately, including the complete recording, numbers, and product names. "
            "Do not infer, complete, or add shopping terms that were not clearly spoken."
        ),
    ).strip()

    request_data = {
        "model": model,
        "response_format": "json",
        "temperature": "0",
        # The API normalizes loudness and uses VAD boundaries in this mode.
        "chunking_strategy": "auto",
    }
    if prompt:
        request_data["prompt"] = prompt

    try:
        response = requests.post(
            f"{base_url}/audio/transcriptions",
            headers={"Authorization": f"Bearer {api_key}"},
            files={
                "file": (
                    filename or "voice.m4a",
                    content,
                    content_type or "application/octet-stream",
                )
            },
            data=request_data,
            timeout=timeout_seconds,
        )
        response.raise_for_status()
        payload = response.json()
    except (requests.RequestException, ValueError) as exc:
        raise TranscriptionProviderError(
            "The speech-to-text service could not process this recording."
        ) from exc

    transcript = str(payload.get("text") or "").strip()
    if not transcript:
        raise TranscriptionProviderError(
            "No speech was detected. Please record again and speak clearly."
        )
    return transcript
