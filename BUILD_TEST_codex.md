# Compute IPA test build: P4 + P10 + P11

Date: 2026-07-22

This takeover completed the missing first-IPA-test scope from `BUILD_V2_SPEC.md`.
All work is committed locally by phase and nothing was pushed.

## Phase commits

- P4: `27e42cf` - remote admin API, optional token, web console, and in-app admin URL.
- P10: `bec3bbc` - on-device OCR improvement, quality envelope, small domain packs,
  compressed corrector resources, and the held-out CER verifier.
- P11: the local commit containing this report - debug trace endpoints, trace ring
  buffer, live tuning knobs, and build stamps.

## P4 remote administration

- `GET /admin` serves a dependency-free dark web console.
- `GET|POST /admin/settings`, `POST /admin/restart`, `POST /admin/keepalive`, and
  `GET /admin/log` are implemented.
- An empty admin token leaves the LAN API open. When configured, data/control
  endpoints require `X-Admin-Token`; the HTML shell remains loadable so the token
  can be entered locally in the browser.
- OCR/server settings that are captured by the running Vapor instance trigger a
  managed restart. Keep-alive, token, improve/debug, threshold, multipass, ROI,
  corrector groups, and domain-pack settings apply immediately.

## P10 on-device improvement

- `VNLegalCorrector.swift` ports the deterministic phrase-first trigram/bigram
  behavior from `engine/vn_legal_corrector.py` and the conservative ALL-CAPS /
  ambiguous-syllable guards from `Iphone OCR/vn_corrector.py`.
- `correction_map.json` (923,186 rules) and `unigram.json` (97,197 entries) are
  stored as raw-DEFLATE bundle resources with hashes and original sizes in
  `OCRResources/resource_manifest.json`.
- Total OCR resource payload is 6,075,950 bytes. `phrases.json` is explicitly
  excluded.
- Domain packs are versioned and small: `minimal` 146 words, `legal` 807,
  `tax` 397, and `customs` 389. Request metadata or `pack=` selects a pack;
  `pack=none` provides the A/B rollback path.
- `/upload` and `/docOCR` now expose `raw`, `improved`, `mean_confidence`,
  `page_score`, `line_scores`, `flags`, `needs_pass2`, and
  `corrections_applied`. Legacy `ocr_result` / `ocr_text` contains improved text
  by default and raw text for `?raw=1` or `?improve=0`.
- Quality flags are limited to `invalid_legal_id`, `low_confidence`,
  `missing_page_number`, and `broken_table`. ROI OCR is capped and runs only for
  low-confidence or invalid-legal-ID lines after the first quality gate.

Run the device CER check from WSL after installing the IPA:

```bash
python3 tests/verify_improve.py 192.168.31.65:8000 --limit 20
```

The default manifest is:

```text
/mnt/d/AI Projects/Iphone OCR/engine/finetune/gold_vlm/heldout_manifest.jsonl
```

## P11 debug and hot tuning

- `POST /debug/ocr` returns raw top-3 candidates with confidence and normalized
  bbox, per-token corrector actions/rule IDs, quality envelope, stage timings,
  device status, config snapshot, and `build_version`.
- `GET /debug/last?n=10` returns the newest full traces from a 30-entry ring
  buffer. Normal OCR requests also populate it while verbose debug is enabled.
- `debug_verbose` defaults ON. When OFF, normal requests skip top-3/corrector
  trace collection and `/debug/*` returns 403.
- Hot knobs read from `UserDefaults` at the start of every request:
  `confidence_threshold`, `multipass`, `roi_upscale`, `corrector_groups`,
  `active_pack`, and `improve`.
- `/health`, `/stats`, and every debug trace include a build stamp derived from
  `COMPUTE_BUILD_SHA` when supplied, otherwise `CFBundleShortVersionString` plus
  `CFBundleVersion`.

Example live update:

```bash
curl -H 'Content-Type: application/json' \
  -H 'X-Admin-Token: TOKEN' \
  -X POST http://PHONE:8000/admin/settings \
  -d '{"confidence_threshold":0.58,"multipass":true,"roi_upscale":2.5,"active_pack":"legal","corrector_groups":["allcaps_diacritic","undiacritic_map","legalid_normalize","ambiguous_skip"],"improve":true,"debug_verbose":true}'
```

## Verification performed

- Parsed all 37 Swift files under `OcrServer/` with the tree-sitter Swift parser:
  zero syntax errors.
- Parsed the inline admin JavaScript with Node: no syntax error.
- `git diff --check`: passed.
- Checked the Xcode project structure and verified all five OCR resources are in
  the explicit Copy Bundle Resources phase.
- Rebuilt resources twice and compared SHA-256 lists: deterministic output.
- Decompressed both packed JSON files with raw DEFLATE and verified byte-for-byte
  equality with the source lexicon files.
- Ran representative corpus-map cases against the Python source corrector; the
  Swift-port algorithm's phrase ordering/casing model produced the same expected
  replacements in the mirrored test.
- Python-compiled `tests/verify_improve.py` and resolved image/target paths from
  the real held-out manifest.
- Checked official Apple declarations for Vision `customWords`,
  `recognitionLanguages`, and Compression `compression_decode_buffer`; the bundle
  uses the raw DEFLATE format required by `COMPRESSION_ZLIB`.

## Not verified locally

- This machine has no Xcode, Apple SDK, `swiftc`, or physical iPhone. Apple
  framework type-checking, linking, IPA packaging, installation, and device
  runtime behavior are not proven here.
- CER improvement is not claimed until `tests/verify_improve.py` runs against the
  installed IPA and held-out images.
- ROI crop quality, first-load memory/time for the 923k-rule dictionary,
  iOS 26 `/docOCR`, background survival, and thermal behavior require device tests.
