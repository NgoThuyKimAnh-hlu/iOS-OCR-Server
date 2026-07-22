# Apple Compute Server build log

## Implemented

- `POST /translate`: JSON translation through an iOS `TranslationSession` owned by a hidden SwiftUI host. `source` is optional and the framework reports the detected source language.
- `POST /transcribe`: multipart or raw audio transcription with `SFSpeechRecognizer`, pinned to on-device recognition and default locale `vi-VN`.
- `POST /synthesize`: JSON text-to-speech with `AVSpeechSynthesizer`, returning a CAF audio file.
- Existing `/upload` and `/docOCR` routes remain in place. `DocRecognizer` still pins Vietnamese (`vi`) and disables automatic language detection.
- Generated Info.plist settings include Vietnamese Speech Recognition and Microphone usage descriptions.

## CI iterations

- Baseline before changes: run `29820887213`, commit `a131551`, succeeded on 2026-07-21.
- New implementation: pending first CI build.

## Verification status

- Verified: baseline fork builds in GitHub Actions.
- Pending: Swift compile verification for the three new services and routes.
- Runtime-only assumptions: language packs/voices must be installed on the device; STT requires user-granted Speech permission; Translation may show Apple's language-download UI.
