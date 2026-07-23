# BUILD_V6 report

Date: 2026-07-23

## Outcome

Implemented the app-side scope of `BUILD_V6_SPEC.md` locally. No GitHub push or
publish action was performed. The app version is `1.6.0 (33)` in Debug and
Release.

Implementation commits:

- T1 `b7fef5e` - `Add adaptive thermal admission governor`
- T2 `2513782` - `Cap OCR concurrency and pace fair load`
- T3 `b799d2f` - `Default PDF OCR to 150 DPI`
- T4 `e6e5908` - `Expose pass two OCR regions`
- T5 - `Enforce admin auth and request limits` (the commit containing this report)

PC-side crop, perplexity, and farm scheduling were not added.

## T1 - adaptive thermal governor

- `ThermalGovernor` samples `ProcessInfo.processInfo.thermalState` on each
  admission, listens to `thermalStateDidChangeNotification`, and polls every 15
  seconds as a lightweight fallback.
- `nominal` and `fair` admit new OCR work. `serious` returns HTTP 429 with
  `Retry-After` of 3-5 seconds. `critical` returns HTTP 429 with 8-10 seconds.
  Queue saturation returns 429 with 1-2 seconds. All retry values include small
  jitter.
- Hysteresis resumes at `fair`, not only `nominal`. Requests already admitted
  continue and release their slot normally; the governor does not cancel an
  in-flight Vision/PDF operation.
- `thermal_guard` defaults on. `max_queue` defaults to 8 and bounds waiting OCR
  requests; excess requests fail immediately instead of extending the queue.
- `/health`, `/stats`, debug device data, and OCR responses expose `thermal` and
  `thermal_throttling`.

## T2 - concurrency and fair-state pacing

- The actor-backed admission controller limits active OCR requests with
  `max_inflight` (default 2). Upload, docOCR, legacy/new batch, and debug OCR all
  pass through the same cap.
- At `fair`, `fair_gap_ms` (default 300) spaces job starts. Slots are reserved
  before the delay, so actor reentrancy cannot exceed the cap or collapse the
  gap into a burst.
- Waiting requests are rejected if the device moves to `serious`/`critical`;
  active requests drain.

## T3 - PDF DPI

- `pdf_dpi` now defaults to 150, based on the supplied measured result (CER
  1.03% at 150 versus 1.16% at 200).
- `hot_dpi` defaults to 120. If an already-admitted request reaches `critical`,
  or thermal guarding is disabled for testing, PDF rendering uses
  `min(requested_dpi, hot_dpi)`.
- PDF upload, docOCR, and field-batch responses expose `dpi_used`. Image-only
  responses return `dpi_used: null`.

## T4 - pass-2 bounding boxes

- When line confidence is uncertain, `/upload` returns `pass2_regions` entries
  with 1-based `line_index`, `bbox`, raw Vision text, and the immediate previous
  and next line text in `neighbor_lines`.
- `pass2_fallback_ratio` defaults to 0.4. `full_page_fallback` becomes true when
  uncertain regions exceed that ratio, or when the page needs pass 2 but no
  line-local region can represent the reason.
- The response declares
  `bbox_coordinate_system="vision_normalized_origin_bottom_left_range_0_1"`.
  Each `bbox` is `{x,y,width,height}` in Vision normalized coordinates with
  origin at the lower-left and all values relative to `[0,1]`.
- `image_width` and `image_height` remain the encoded source pixel dimensions.
  `orientation` is the standard EXIF/ImageIO orientation integer 1-8. The PC
  should inverse-transform normalized bbox corners by that EXIF orientation,
  then multiply by the source dimensions to address original encoded pixels.
- PDF-rendered and rectified PNG pages report orientation 1. No `/crop`
  endpoint or phone-side image cache was added.

## T5 - admin auth and limits

- A global middleware protects every API path below `/admin/...` whenever
  `admin_token` is non-empty. Missing or wrong `X-Admin-Token` returns HTTP 401.
  The read-only `/admin` HTML shell stays open so a browser can load the token
  input; all data and mutation requests made by the shell are authenticated.
- Existing per-handler token checks remain as defense in depth. The web console
  already stores the entered token in browser `localStorage` and attaches it to
  every admin fetch.
- `max_upload_mb` defaults to 60 and is configurable from 1-100 MB. Normal
  `Content-Length` requests are rejected before the OCR handler; the collected
  body size is checked again so a false/missing length header cannot bypass it.
- `max_batch_files` defaults to 50. Legacy `/batch` and all three field-batch
  endpoints return HTTP 400 when the file count is exceeded.
- PDFs exceeding `pdf_max_pages` now return a clear HTTP 400 error instead of
  silently processing a truncated prefix.

## New knobs

`thermal_guard`, `max_queue`, `max_inflight`, `fair_gap_ms`, `pdf_dpi`,
`hot_dpi`, `pass2_fallback_ratio`, `max_upload_mb`, and `max_batch_files` are
persistent, exposed by `GET /admin/settings`, validated by partial
`POST /admin/settings`, and rendered by the dynamic admin console.

## Verification performed

- Parsed all 39 Swift source files with tree-sitter-swift 0.7.2: zero syntax
  errors.
- Parsed all four inline JavaScript blocks with `node --check`.
- Syntax-compiled both Python tools with `py_compile`.
- Validated all five OCR JSON/CZL1 resources, including raw-deflate length and
  JSON decoding.
- Statically verified all 15 admin route declarations are covered by the global
  middleware and existing per-route checks (except the intentional HTML shell).
- Confirmed all new knobs occur in settings response, patch validation, and
  admin schema.
- Confirmed the project still uses `PBXFileSystemSynchronizedRootGroup`; the two
  new Swift files therefore join the target without manual source-phase edits.
- Confirmed both build configurations are `1.6.0 (33)` and `git diff --check`
  passes.

## Not verified

- This machine has no Apple SDK or `xcodebuild`. Apple-framework/Vapor
  type-checking, linking, unsigned IPA packaging, and signing are not proven
  locally.
- No iPhone was available. Thermal notification behavior, full duty-cycle
  sustained throughput, real 429/drain timing, PDF memory use, and Vision OCR
  quality at 150/120 DPI remain device checks.
- EXIF orientation is read and returned, but a physical rotated/mirrored image
  matrix is still needed to prove the PC inverse transform against Vision's
  device-side orientation behavior.
- Early upload rejection is verified statically; actual HTTP behavior with both
  fixed-length and chunked clients requires an installed build. The collected
  body check remains the fallback for missing or dishonest length headers.
