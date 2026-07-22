---
status: active
date: 2026-07-22
owner: codex
---

# On-device intelligence handoff

Implemented `BUILD_INTELLIGENCE_SPEC.md` in the iOS OCR fork:

- Added separate `LLMService.swift`, `NERService.swift`, and
  `EmbeddingService.swift`.
- Added `POST /llm`, `/ner`, and `/embed`, plus root-page curl examples.
- `/llm` checks Foundation Models availability and supports system instructions
  plus a maximum response-token count.
- `/ner` combines Natural Language name tagging with Vietnamese legal regexes.
- `/embed` tries Vietnamese sentence embeddings, then averaged word embeddings,
  and returns 501 when neither is available.
- Preserved all previous routes and the `DocRecognizer` Vietnamese language pin.

Verification:

- Implementation commit `983376a` passed GitHub Actions run `29899577703` on
  Xcode 26.5.
- Build, package, and artifact upload succeeded. Artifact ID: `8521453912`.
- The first implementation CI run passed, so there were no compile errors to
  iterate on.

Open device-only checks:

- Foundation Models eligibility, Apple Intelligence state, and Vietnamese
  generation quality.
- Vietnamese NLTagger accuracy and installed NLEmbedding coverage.

The user explicitly authorized pushes only to
`NgoThuyKimAnh-hlu/iOS-OCR-Server` for this task. No other repository was pushed.
