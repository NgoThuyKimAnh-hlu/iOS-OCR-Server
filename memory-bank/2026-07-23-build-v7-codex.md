---
status: active
date: 2026-07-23
owner: codex
---

# Compute v7 handoff

Implemented `BUILD_V7_SPEC.md` locally in five K1-K5 commits; no GitHub push
occurred. Version is `1.7.0 (34)`.

- K1 `b8c1fd3`: non-zero 20 Hz, `1e-4` PCM loop with player volume `0.001`.
- K2 `6714601`: own `.playback` session by default; persistent
  `keep_alive_own_session` knob restores mixing when false.
- K3 `a371427`: 15-second engine/player watchdog, ring-log event, and reheal
  counter.
- K4 `28c5a2f`: media-services reset rebuild, route recovery, interruption
  `.shouldResume`, and bounded 0.5/1/2-second start retries.
- K5 `4193e3d`: nested `/health.keep_alive` diagnostics, build version, report,
  and completion marker.

Verified: 39/39 Swift files syntax-parse, four inline scripts parse, both Python
tools syntax-compile, K1-K5 static coverage and version wiring pass, and
`git diff --check` passes.

Open: no Apple SDK/Xcode or device was available, so type-check/link/IPA and real
long-lock survival, inaudibility, session arbitration, watchdog background
execution, reset/route/interruption recovery, and runtime health JSON remain
unverified. Full details: `BUILD_V7_codex.md`.
