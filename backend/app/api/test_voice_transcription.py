import asyncio
import io
import os
import unittest
from unittest.mock import patch

from fastapi import HTTPException, UploadFile
from starlette.datastructures import Headers

from app.api import chat_routes
from app.services.transcription_service import (
    TranscriptionConfigurationError,
    TranscriptionProviderError,
)


def _upload(filename: str, content: bytes, content_type: str = "audio/mp4"):
    return UploadFile(
        file=io.BytesIO(content),
        filename=filename,
        headers=Headers({"content-type": content_type}),
    )


class VoiceTranscriptionRouteTests(unittest.TestCase):
    def test_success_returns_transcript(self):
        with patch.object(
            chat_routes,
            "transcribe_audio",
            return_value="phone under fifty thousand",
        ) as transcribe:
            response = asyncio.run(
                chat_routes.transcribe_chat_audio(
                    _upload("voice.m4a", b"valid-audio")
                )
            )
        self.assertEqual(response, {"text": "phone under fifty thousand"})
        self.assertEqual(transcribe.call_args.kwargs["filename"], "voice.m4a")

    def test_rejects_unsupported_and_empty_files(self):
        for upload, status in (
            (_upload("voice.txt", b"not-audio", "text/plain"), 415),
            (_upload("voice.wav", b"", "audio/wav"), 400),
        ):
            with self.subTest(status=status):
                with self.assertRaises(HTTPException) as raised:
                    asyncio.run(chat_routes.transcribe_chat_audio(upload))
                self.assertEqual(raised.exception.status_code, status)

    def test_rejects_oversized_file_before_provider_call(self):
        with patch.dict(os.environ, {"MAX_VOICE_UPLOAD_BYTES": "3"}), patch.object(
            chat_routes, "transcribe_audio"
        ) as transcribe:
            with self.assertRaises(HTTPException) as raised:
                asyncio.run(
                    chat_routes.transcribe_chat_audio(
                        _upload("voice.wav", b"four")
                    )
                )
        self.assertEqual(raised.exception.status_code, 413)
        transcribe.assert_not_called()

    def test_maps_configuration_and_provider_errors(self):
        for error, status in (
            (TranscriptionConfigurationError("not configured"), 503),
            (TranscriptionProviderError("provider failed"), 502),
        ):
            with self.subTest(status=status), patch.object(
                chat_routes, "transcribe_audio", side_effect=error
            ):
                with self.assertRaises(HTTPException) as raised:
                    asyncio.run(
                        chat_routes.transcribe_chat_audio(
                            _upload("voice.wav", b"valid-audio", "audio/wav")
                        )
                    )
                self.assertEqual(raised.exception.status_code, status)


if __name__ == "__main__":
    unittest.main()
