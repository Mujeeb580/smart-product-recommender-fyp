import os
import unittest
from unittest.mock import Mock, patch

import requests

from app.services.transcription_service import (
    TranscriptionConfigurationError,
    TranscriptionProviderError,
    transcribe_audio,
)


class TranscriptionServiceTests(unittest.TestCase):
    def test_requires_backend_api_key(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(TranscriptionConfigurationError):
                transcribe_audio(filename="voice.m4a", content=b"audio")

    def test_posts_audio_and_returns_trimmed_transcript(self):
        response = Mock()
        response.raise_for_status.return_value = None
        response.json.return_value = {"text": "  مجھے اچھا فون چاہیے  "}
        with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}, clear=True), patch(
            "app.services.transcription_service.requests.post",
            return_value=response,
        ) as post:
            transcript = transcribe_audio(
                filename="voice.m4a",
                content=b"audio-bytes",
                content_type="audio/mp4",
            )

        self.assertEqual(transcript, "مجھے اچھا فون چاہیے")
        request_data = post.call_args.kwargs["data"]
        self.assertEqual(request_data["model"], "gpt-4o-transcribe")
        self.assertEqual(request_data["chunking_strategy"], "auto")
        self.assertEqual(request_data["temperature"], "0")
        self.assertIn("Roman Urdu", request_data["prompt"])
        self.assertEqual(post.call_args.kwargs["files"]["file"][1], b"audio-bytes")
        self.assertEqual(
            post.call_args.kwargs["headers"]["Authorization"],
            "Bearer test-key",
        )

    def test_provider_failure_has_safe_message(self):
        with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}, clear=True), patch(
            "app.services.transcription_service.requests.post",
            side_effect=requests.Timeout("private upstream detail"),
        ):
            with self.assertRaisesRegex(
                TranscriptionProviderError,
                "speech-to-text service could not process",
            ):
                transcribe_audio(filename="voice.wav", content=b"audio")

    def test_empty_transcript_is_rejected(self):
        response = Mock()
        response.raise_for_status.return_value = None
        response.json.return_value = {"text": " "}
        with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}, clear=True), patch(
            "app.services.transcription_service.requests.post",
            return_value=response,
        ):
            with self.assertRaisesRegex(TranscriptionProviderError, "No speech"):
                transcribe_audio(filename="voice.wav", content=b"audio")


if __name__ == "__main__":
    unittest.main()
