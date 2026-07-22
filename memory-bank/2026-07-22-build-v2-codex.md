---
status: active
date: 2026-07-22
owner: codex
---

# Compute v2 handoff

Implemented the user-scoped P1, P2, and P3 phases of `BUILD_V2_SPEC.md` in three
local commits; no GitHub push was performed.

- P1 `3872031`: silent-audio keep-alive, background/Bonjour plist keys,
  bind-ready Vapor startup, 8000 retry/fallback policy, watchdog, telemetry,
  request log, and `/health`.
- P2 `3ef9e14`: new Compute Console UI, direct service availability checks,
  counters/device metrics/sparklines, log tail, compact toolbar/menu, and display
  name `Compute`.
- P3 `Add document input and vision APIs`: PDF OCR for `/upload` and `/docOCR`,
  scan rectification, repeated-field `/batch`, `/barcode`, `/stats`, and root HTML
  documentation. This commit also contains `BUILD_V2_codex.md` and
  `BUILD_V2_DONE`.

Verification completed:

- Full diff check passed.
- All 17 changed Swift files passed a tree-sitter syntax parse.
- Exact Vapor 4.115.1 lifecycle/middleware/query/multipart behavior was checked.
- Repeated multipart `file` parsing was smoke-checked with two binary payloads.
- Debug and Release generated plist keys were both verified.
- Existing routes and the Vietnamese OCR recognizer files were preserved.

Open verification:

- No Xcode/Apple SDK exists on this machine, so compile/link is not proven.
- No physical iPhone test was available for background survival, Bonjour,
  watchdog restart, PDF/rectify/barcode behavior, memory pressure, or UI layout.
- `NetService` advertises service name `compute`, but direct `compute.local`
  resolution depends on the LAN; browse-based discovery is the reliable path.
- P4 remote control was intentionally left open because the takeover request
  explicitly scoped execution to P1 -> P2 -> P3 and exactly three commits.
