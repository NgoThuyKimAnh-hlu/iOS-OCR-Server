---
status: active
date: 2026-07-23
owner: codex
---

# Compute v6 handoff

Implemented `BUILD_V6_SPEC.md` app-side in five local feature commits; no GitHub
push occurred. Version is `1.6.0 (33)`.

- T1 `b7fef5e`: adaptive thermal governor, fair resume, 429 jitter, in-flight
  drain, bounded queue, and thermal response/health fields.
- T2 `2513782`: actor semaphore (`max_inflight=2`) and fair start gap
  (`fair_gap_ms=300`).
- T3 `b799d2f`: PDF default 150 DPI, critical `hot_dpi=120`, and `dpi_used`.
- T4 `e6e5908`: low-confidence pass2 regions, EXIF orientation metadata, and
  `pass2_fallback_ratio=0.4`; no crop endpoint/cache.
- T5 is the commit containing this note: global admin subroute auth,
  `max_upload_mb=60`, `max_batch_files=50`, and hard PDF page rejection.

Verified: 39/39 Swift files syntax-parse, four inline scripts parse, five OCR
resources validate, Python sources compile, settings/auth static coverage passes,
version and synchronized Xcode grouping are intact, and `git diff --check`
passes.

Open: no Apple SDK/Xcode or device was available, so type-check/link/IPA and
real thermal duty-cycle, 429 behavior, DPI quality, and rotated-image bbox
mapping remain unverified. Full details: `BUILD_V6_codex.md`.
