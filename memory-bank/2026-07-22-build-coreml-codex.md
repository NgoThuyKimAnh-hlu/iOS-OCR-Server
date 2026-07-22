---
status: active
date: 2026-07-22
owner: codex
---

# Core ML runner handoff

Implemented `BUILD_COREML_SPEC.md` in the iOS OCR fork:

- Added isolated `CoreMLService.swift` with persistent model storage, lazy
  reload/cache, `.all` compute units, dynamic model metadata, prediction, and
  deletion.
- Added `POST /coreml/upload`, `GET /coreml/info`, `POST /coreml/predict`, and
  `POST /coreml/delete`; preserved all eight previous compute routes.
- Added JSON mapping for scalar, string, multi-array, and base64 image inputs;
  outputs support scalar, string, multi-array, dictionary, and base64 PNG image.
- Added ZIPFoundation 0.9.20 so directory-based `.mlpackage` and `.mlmodelc`
  uploads can be transferred through multipart safely, with a 2 GB expanded
  size limit.
- Updated the root HTML with upload and prediction examples. The vi-VN OCR pin
  and language-detection files were not changed.

Verification:

- Implementation commits `8ada3b2` and `ad580ad` were pushed only to
  `NgoThuyKimAnh-hlu/iOS-OCR-Server`.
- GitHub Actions run `29904273720` passed on Xcode 26.5. Build, unsigned IPA
  packaging, and artifact upload succeeded; artifact ID `8523339122`.
- The first run (`29903736703`) failed on one multiline HTML indentation error;
  the second run passed after the one-line correction.

Open device-only checks:

- Upload and compile representative `.mlmodel`, zipped `.mlpackage`, and zipped
  `.mlmodelc` assets on an iPhone.
- Verify actual ANE scheduling. `.all` permits ANE but Core ML may choose
  CPU/GPU for unsupported operations, so the response marker is not proof of
  the physical backend.
- Validate model-specific output correctness, latency, memory pressure, and
  persistence across app restarts.
