---
status: active
date: 2026-07-23
owner: codex
---

# Compute v8 handoff

Implemented `BUILD_V8_SPEC.md` locally in four N1-N4 commits; no GitHub push
occurred. Version is `1.8.0 (35)`.

- N1 `fde284b`: `NWPathMonitor` path/interface/IP change detection, 2.5-second
  debounce, automatic Vapor stop/start, `socket_rebinds`, and `REBIND` ring log.
- N2 `a556889`: successful-bind IP/interface snapshot, foreground comparison,
  and watchdog stale-binding recovery before the existing localhost probe.
- N3 `dce9beb`: preserves the existing `0.0.0.0` listener as an explicit
  immutable wildcard-bind invariant.
- N4 is the final commit containing nested `/health.network` diagnostics,
  version fields, report, completion marker, and this handoff.

Verified: 40/40 Swift files syntax-parse, four inline scripts parse, two Python
tools syntax-compile, three JSON resources parse, 13/13 V8 static checks pass,
the synchronized Xcode source group remains present, scoped product files avoid
keep-alive/governor/OCR/admin, and `git diff --check` passes.

Open: no Apple SDK/Xcode or device was available, so type-check/link/IPA and the
real lock/Wi-Fi-change/unlock recovery sequence are unverified. Runtime
`NWPathMonitor`, debounce/rebind behavior, Bonjour rediscovery, and `/health`
serialization still require an iPhone test. Full details: `BUILD_V8_codex.md`.
