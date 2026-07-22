# BUILD_INTELLIGENCE report

Date: 2026-07-22

## Implemented APIs

- `POST /llm`: accepts `prompt`, optional `system`, and optional positive `max`.
  It uses `SystemLanguageModel.default`, returns HTTP 503 with the framework's
  availability reason when Apple Intelligence is unavailable, then creates a
  `LanguageModelSession` and maps `max` to `maximumResponseTokens`.
- `POST /ner`: uses `NLTagger` with `.nameType` for organization, place, and
  person names. Independent regular expressions extract Vietnamese document
  numbers and Điều/Khoản/Điểm references.
- `POST /embed`: first tries the Vietnamese sentence embedding. It falls back
  to averaging available Vietnamese word vectors and returns HTTP 501 with
  `NLEmbedding chưa hỗ trợ vi, cần Core ML embedding model sau` when neither
  path can produce a vector.

Each implementation is isolated in `LLMService.swift`, `NERService.swift`, or
`EmbeddingService.swift`. The root HTML page contains curl examples for all
three APIs. No new Info.plist permission is required.

## Compatibility and availability

- `/llm` requires iOS 26 or later, an eligible device, Apple Intelligence
  enabled, and the on-device model ready.
- Natural Language model coverage is device/OS dependent. Vietnamese NER
  quality and embedding availability must be checked on the target iPhones;
  the legal regex extraction does not depend on an NER model.
- Existing `/upload`, `/docOCR`, `/translate`, `/transcribe`, and `/synthesize`
  routes remain registered. `DocRecognizer` still pins `vi` and disables
  automatic language detection.

## Verification

- Implementation commit: `983376a`.
- GitHub Actions run: `29899577703`.
- Runner toolchain: Xcode 26.5.
- Result: Build, unsigned IPA packaging, and artifact upload all succeeded.
- Artifact: `OcrServer-unsigned-ipa`, artifact ID `8521453912`, uploaded size
  13,392,313 bytes.
- CI compile fixes: none. The first implementation push compiled successfully,
  so no artificial extra iteration was performed.
- The only build warning was the existing App Intents metadata notice because
  the target has no AppIntents dependency.

Not verified without a physical compatible device: Foundation Models runtime
generation/availability, Vietnamese NLTagger accuracy, and whether the installed
OS provides Vietnamese sentence or word embeddings.
