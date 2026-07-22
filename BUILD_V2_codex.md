# BUILD_V2 report

Date: 2026-07-22

## Scope

Implemented the user-scoped P1, P2, and P3 phases from `BUILD_V2_SPEC.md`.
The P4 remote-control appendix was not implemented because the takeover request
explicitly required P1 -> P2 -> P3 and exactly three local phase commits.

No GitHub push or publish action was performed.

## P1 - resilient background server

- Added `KeepAliveService.swift` with a looping silent `AVAudioEngine` buffer,
  `.playback` plus `.mixWithOthers`, interruption recovery, and background /
  foreground notification recovery. Keep-alive defaults to on and is exposed in
  Settings.
- Added generated Info.plist settings for background audio, Bonjour service
  discovery, and local-network permission in both Debug and Release.
- Changed Vapor startup to use `Application.startup()` so socket bind failure is
  returned before the UI reports RUNNING. Vapor `reuseAddress` is enabled.
- Port 8000 is attempted five times with one-second backoff. Only then are
  8001...8010 tried as non-persistent fallback ports.
- Added a 60-second localhost `/health` watchdog. Two consecutive failures
  trigger stop/start recovery, increment `auto_restarts`, and append a system
  entry to the shared 200-entry ring buffer.
- Advertises `_http._tcp.` with Bonjour service name `compute` on the actual
  bound port.
- Added request middleware plus `GET /health` with uptime, port, version,
  request counters, automatic restarts, keep-alive state, battery, thermal
  state, and free memory.

## P2 - Compute Console

- Replaced the old two-button screen with a dark Compute dashboard and changed
  only the display name to `Compute`; product name and bundle identifier remain
  unchanged.
- Added a copyable primary IP/port card, Bonjour address, RUNNING/STOPPED badge,
  and live uptime.
- Added a nine-service grid for OCR, docOCR, Translate, STT, TTS, LLM, NER,
  Embed, and CoreML. Statuses use the same framework/service checks as the API
  implementations; unsupported or unavailable features are degraded.
- Added live request counters, battery/charging, thermal color state, free RAM,
  and CPU/RAM sparklines using the existing `Monitor/` sampler and chart. The
  full existing `DashboardView` remains available by tapping the device card.
- Added a reverse chronological request log tail backed by the shared 200-entry
  middleware ring buffer.
- Kept Settings in the toolbar and moved README plus Donation into the overflow
  menu.

## P3 - document and vision inputs

- `/upload` and `/docOCR` detect `%PDF`, render pages with PDFKit/Core Graphics,
  and OCR pages sequentially. Defaults are 200 DPI and 50 pages; accepted query
  ranges are `dpi=72...300` and `max_pages=1...200`.
- `rectify=1` runs `VNDetectDocumentSegmentationRequest` and
  `CIPerspectiveCorrection` before OCR. Failure to find/correct a document falls
  back to the original image and returns `rectified: false`.
- Added `POST /batch` for repeated multipart `file` fields. A small binary-safe
  parser is used because MultipartKit's keyed decoder overwrites repeated fields
  with the same bare name. Files are processed sequentially and returned as a
  JSON array in `/upload` format plus `filename`.
- Added `POST /barcode` using `VNDetectBarcodesRequest`.
- Added `GET /stats`, which mirrors health fields and adds the latest 20 log
  entries.
- Updated the root HTML title to Compute Server and documented PDF, rectify,
  batch, barcode, health, and stats endpoints.

## Verification performed

- `git diff 7d71932 --check`: passed.
- Parsed all 17 changed Swift files with the tree-sitter Swift parser: zero
  syntax errors.
- Checked exact Vapor 4.115.1 source for `startup()`, `reuseAddress`, async
  middleware, response-body size, URL query decoding, and repeated multipart
  behavior.
- Smoke-checked the repeated-field multipart algorithm with two `file` parts,
  including a payload whose real content ends in CRLF; filenames and bytes were
  preserved.
- Verified the Xcode project uses `PBXFileSystemSynchronizedRootGroup`, so new
  Swift files under `OcrServer/` join the app target by the same mechanism used
  for the prior service files.
- Verified background/Bonjour/display-name generated plist keys exist in both
  target configurations.
- Verified all pre-existing compute routes are still registered.
- Verified `DocRecognizer.swift` and `TextRecognizer.swift` are unchanged from
  baseline commit `7d71932`, preserving the Vietnamese document-language pin.
- Verified `origin/main` remained at `7d71932` while the local branch advanced;
  no push was performed.

## Not verified / remaining risks

- This environment has no Xcode, Apple SDK, `swiftc`, or physical iPhone.
  Therefore Apple-framework type-checking, linking, signing, and runtime behavior
  are not verified. The source was written against the iOS 18.4 target and the
  existing iOS 26 availability pattern.
- Silent audio background execution, interruption recovery, watchdog recovery,
  battery impact, and App Store policy behavior require a locked physical device
  test. iOS retains final control over suspension.
- Bonjour advertises a service instance named `compute`; whether a client can
  type `compute.local` directly depends on the LAN resolver. Bonjour service
  discovery is implemented, but a universal host alias cannot be guaranteed by
  `NetService` alone.
- PDF rendering/OCR memory and latency depend on page dimensions, DPI, page
  count, and device RAM. Explicit page, DPI, dimension, and pixel limits prevent
  unbounded single-page rendering but still need device stress testing.
- Rectification accuracy, barcode symbology coverage, OCR quality, service-grid
  availability states, and the custom multipart parser need device/client tests
  with representative files.

## Local commits

- P1: `3872031` - `Add resilient background server lifecycle`
- P2: `3ef9e14` - `Build the Compute Console dashboard`
- P3: the commit containing this report - `Add document input and vision APIs`
