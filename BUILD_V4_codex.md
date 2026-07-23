# BUILD_V4 report

Date: 2026-07-23

## Outcome

Implemented `BUILD_V4_SPEC.md` locally. No GitHub push or publish action was
performed. The app version is `1.5.0 (32)` in Debug and Release.

Implementation commits:

- A: `46a46b2` - `Apply remote custom words to Vision`
- B: `6be2159` - `Raise admin JSON body limit`
- C: `eaa33aa` - `Freeze OCR response contract`
- D: `449f132` - `Add offline field batch console`
- D mobile QA fix: `3add223` - `Fix field console mobile overflow`
- A applied-count trace: `f11fee9` - `Trace applied Vision custom words`

## A - customWords into Vision

- The effective list remains the deduplicated union produced by
  `OCRCustomizationStore`: active pack words plus persistent user custom words.
- `/upload`, `/debug/ocr`, multipass ROI retries, `/docOCR`, the legacy `/batch`,
  and the new field batch endpoints all pass the resolved words into their
  Vision request.
- Empty lists no longer set the Vision `customWords` property.
- `config_snapshot.customwords_count` is read from the configured Vision request,
  while `/health.ocr_improve.customwords_count` reports the effective persistent
  active-pack count.

The V3 repository already contained the resolver merge and most call-site
plumbing. V4 makes the request assignment explicit and observable. A physical
iPhone run is still required to prove that a chosen custom word changes a
particular OCR result; equal raw text alone does not prove whether Vision used or
ignored the hint.

## B - admin JSON size

The following routes now collect up to `8mb`:

- `POST /admin/settings`
- `POST /admin/customwords`
- `POST /admin/corrections`
- `POST /admin/pack`

The existing validation ceilings allow 50,000 words and 50,000 overrides. A
synthetic `vn_legal_v1`-shaped payload with 1,995 words and 3,759 overrides was
233,420 bytes, below the route limit and validation ceilings.

## C - stable OCR contract and language pin

`/upload` and `/docOCR` JSON results now always carry contract schema v1 fields:

`raw`, `improved`, `page_score`, `line_scores`, `flags`, `needs_pass2`,
`mean_confidence`, `corrections_applied`, `build_version`, and `schema_version`.

The fields exist on single-image responses, PDF page responses, PDF aggregate
responses, and handled OCR validation/processing failures. Existing legacy
fields remain for compatibility. PDF aggregates conservatively use the minimum
page score, union flags, and set `needs_pass2` when any page needs it.

Defaults are now pinned to `recognition_languages=["vi-VT"]` with
`automatically_detects_language=false`. Admin settings can still change both.
Both `RecognizeTextRequest` and iOS 26 `RecognizeDocumentsRequest` apply the live
language array and auto-detect boolean to each request.

## D - offline field appliance

- Added self-contained dark `GET /console`, linked from `/`.
- Added `POST /batch/ocr`, `/batch/markdown`, and `/batch/docx`.
- Multipart files and PDF pages are processed with serial `for`/`await` loops.
- Results include `completed`/`total` progress plus the frozen OCR contract.
- Markdown and Word source use the existing iOS 26 document OCR pipeline.
- The browser creates basic DOCX files and the final ZIP with self-contained
  JavaScript. Swift does not create or compress DOCX files.
- Added default-on service toggles: `console`, `batch_ocr`, `batch_markdown`, and
  `batch_docx`; disabled routes return HTTP 503.
- README and console document Personal Hotspot/same-Wi-Fi offline use.
- No SQLite spool, parallel batch, or batch translate/STT/TTS/LLM was added.

## Verification performed

- Parsed all 37 Swift source files with the tree-sitter Swift grammar: zero
  syntax errors.
- Parsed all four inline JavaScript blocks with `node --check`.
- Smoke-tested the browser ZIP and minimal DOCX generators in Node.
- Chrome CDP functional QA verified two files issue exactly two sequential
  `/batch/ocr` requests, populate two results, reach 100% progress, and download
  a ZIP. It also verified the HTTP 503 disabled-service path.
- Chrome CDP mobile emulation verified a 390 x 844 viewport with
  `scrollWidth=390`; desktop, mobile, and completed-result states were visually
  inspected. This pass found the mobile overflow fixed in `3add223`.
- Validated all five bundled OCR resources, including CZL1/raw-deflate JSON.
- Syntax-compiled both Python tools in memory.
- Confirmed the Xcode project still uses `PBXFileSystemSynchronizedRootGroup`, so
  `FieldConsole.swift` is included without manual source-phase entries.
- Confirmed both build configurations are `1.5.0 (32)` and all resource build
  entries remain present.
- `git diff --check` passed across the full V4 commit range.

## Not verified

- Per the task constraint, no local Xcode build was run. This machine has no
  Apple SDK or `xcodebuild`, so Apple-framework/Vapor type-checking, linking,
  signing, and IPA packaging are not proven locally.
- No physical iPhone was available. Actual Vision custom-word influence,
  iOS 26 document OCR, PDF batch thermals, hotspot access, and device-side 503
  behavior remain device tests.
- The real 174 KB `vn_legal_v1.json` was not present in this repository, so its
  actual HTTP upload was not performed; the exact route limit, payload shape,
  and validation capacity were checked statically and with a larger synthetic
  payload.
