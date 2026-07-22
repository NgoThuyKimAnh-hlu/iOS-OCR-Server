# Apple Compute Server build log

## Implemented

- `POST /translate`: JSON translation through an iOS `TranslationSession` owned by a hidden SwiftUI host. `source` is optional and the framework reports the detected source language.
- `POST /transcribe`: multipart or raw audio transcription with `SFSpeechRecognizer`, pinned to on-device recognition and default locale `vi-VN`.
- `POST /synthesize`: JSON text-to-speech with `AVSpeechSynthesizer`, returning a CAF audio file.
- Existing `/upload` and `/docOCR` routes remain in place. `DocRecognizer` still pins Vietnamese (`vi`) and disables automatic language detection.
- Generated Info.plist settings include Vietnamese Speech Recognition and Microphone usage descriptions.

## CI iterations

- Baseline before changes: run `29820887213`, commit `a131551`, succeeded on 2026-07-21.
- Round 1: commit `6ea9d47`, run `29895740342`, succeeded on 2026-07-22.
- No Swift compiler fixes were required: the first implementation build passed.
- The unsigned IPA was packaged and uploaded as artifact `OcrServer-unsigned-ipa` (`13,354,699` bytes, artifact ID `8520022147`).

## Verification status

- Verified: baseline fork builds in GitHub Actions.
- Verified: the three new services and routes compile with the repository's unsigned-iPhoneOS GitHub Actions build.
- Verified: checkout, environment inspection, Xcode build, IPA packaging, and artifact upload all completed successfully in run `29895740342`.
- Not device-tested: HTTP responses, permission prompts, recognition accuracy, language-pack downloads, and generated CAF playback require a physical iOS device.
- Runtime-only assumptions: language packs/voices must be installed on the device; STT requires user-granted Speech permission; Translation may show Apple's language-download UI.
