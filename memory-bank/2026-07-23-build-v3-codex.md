---
status: active
date: 2026-07-23
owner: codex
---

# Compute v3 handoff

Implemented `BUILD_V3_SPEC.md` in four local commits; no GitHub push occurred.

- A `3af1428`: strict unigram `respect_valid` guard plus verifier OK/BAD output.
- B `42e021a`: removed DonationView, ReadmeView, StoreKit, and legacy menu UI.
- C `d422733`: actor request-log ring wired to middleware, `/admin/log`, and
  `/debug/last`.
- D `1908633`: 39 persistent settings, per-request OCR overrides, hot custom
  words/corrections/packs, 10 service switches, dynamic admin console, and
  version `1.4.0 (31)`.

Verification completed: all 36 Swift files syntax-parse, admin JavaScript parses,
JSON and compressed resources validate, Python verifier compiles, D1-D5 static
coverage passes, synchronized source group and resource phase are intact.

Important open item: no Xcode/Apple SDK or reachable phone was available. The
old device baseline is p0001 `OK=10 BAD=28`; offline checks prove all six named
destructive substitutions are blocked. The archived trace also shows the strict
unigram guard skips historically-correct corrections because those noisy source
forms are present in the supplied unigram. Do not claim a new device
`OK >> BAD` result until CI builds an IPA and p0001 is rerun.

Final report: `BUILD_V3_codex.md`. Completion/status marker: `BUILD_V3_DONE`.
