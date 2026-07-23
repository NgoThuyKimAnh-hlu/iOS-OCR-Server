---
status: active
date: 2026-07-23
owner: codex
---

# Compute v9 handoff

Implemented `BUILD_V9_SPEC.md` locally in five B1-B5 commits; no GitHub push
occurred. Version is `1.9.0 (36)`.

- B1 `f2e4437`: main-console blackout button, root/sheet black cover, brightness
  save/zero/restore, and foreground idle-timer enforcement.
- B2 `938f98d`: double-tap-only exit; single tap does not reveal the console.
- B3 `5375cd5`: hides status/persistent system overlays and renders no fixed
  bright indicator.
- B4 `42b210a`: auto-blackout idle setting/activity monitor, remote
  `blackout` control through `/admin/settings`, and `/health.blackout`.
- B5 is the final commit containing the visible/default-on keep-screen-awake
  setting, `.active` scene reapplication, version, report, and this handoff.

Verified: 42/42 Swift files syntax-parse, four inline scripts parse, both Python
tools syntax-compile, three JSON resources parse, 24/24 V9 static checks pass,
and `git diff --check` passes. The V9 changed paths exclude keep-alive,
governor, network rebind/server manager, and OCR implementation files.

Open: no Apple SDK/Xcode or physical iPhone was available, so type-check/link,
IPA, absolute-black system UI, brightness restore, idle timing, Guided Access,
foreground Wi-Fi reachability, remote control under load, and real OLED power
behavior remain unverified device/build checks. Full details:
`BUILD_V9_codex.md`.
