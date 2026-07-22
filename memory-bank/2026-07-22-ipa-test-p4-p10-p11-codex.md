---
status: active
date: 2026-07-22
owner: codex
---

# First IPA test handoff: P4, P10, P11

Completed the missing `BUILD_V2_SPEC.md` first-test scope in three local phase
commits; no GitHub push was performed.

- P4 `27e42cf`: admin API/web console, optional `X-Admin-Token`, managed restart,
  keep-alive control, settings/log access, and the admin URL in the app UI.
- P10 `bec3bbc`: deterministic VN legal corrector, 6.08 MB compressed resources,
  four small versioned domain packs, quality envelope, gated ROI multipass,
  raw/improved API fields, health counters, and `tests/verify_improve.py` using the
  real held-out manifest.
- P11 is the commit containing this note: full `/debug/ocr` and `/debug/last`
  traces, per-request hot tuning through `/admin/settings`, `debug_verbose`, and
  build stamps in health/debug.

Verified: all 37 Swift files syntax-parse clean; admin JS parses; resource build
is deterministic; packed maps decompress byte-identically to the source; project
resources are explicitly wired; Python verifier compiles and resolves held-out
paths.

Open: no Xcode/Apple SDK or device was available, so compile/link/IPA/device
behavior and CER gains remain unverified. After CI builds and the IPA is installed,
run `python3 tests/verify_improve.py PHONE:8000 --limit 20`, then tune knobs through
`POST /admin/settings` while inspecting `/debug/last?n=10`.
