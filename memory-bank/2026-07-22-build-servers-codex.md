---
status: active
date: 2026-07-22
owner: codex
---

# Apple Compute Server handoff

Implemented `BUILD_SERVERS_SPEC.md` in the iOS OCR fork:

- Added separate `TranslationService.swift`, `SpeechService.swift`, and `SynthService.swift`.
- Added `POST /translate`, `/transcribe`, and `/synthesize`; preserved `/upload` and `/docOCR`.
- Translation uses a hidden SwiftUI `.translationTask` host; STT requires on-device recognition and defaults to `vi-VN`; TTS returns CAF audio.
- Added Speech/Microphone generated Info.plist keys and updated the root HTML examples.
- Preserved the `DocRecognizer` Vietnamese language pin and disabled automatic language detection there.

Verification:

- Implementation commit `6ea9d47` passed GitHub Actions run `29895740342`.
- All build/package/upload steps passed; artifact `OcrServer-unsigned-ipa` was produced.
- No physical-device runtime test was available, so framework permissions, language downloads, STT accuracy, and audio playback remain device-verification items.

The user explicitly authorized pushes only to `NgoThuyKimAnh-hlu/iOS-OCR-Server` for this task. No other repository was pushed.
