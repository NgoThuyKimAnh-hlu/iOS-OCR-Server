# BUILD V9 report

Date: 2026-07-23

## Outcome

Implemented `BUILD_V9_SPEC.md` locally as five B1-B5 commits. No GitHub push or
publish action was performed. The app version is `1.9.0 (36)` in Debug and
Release.

Implementation commits:

- B1 `f2e4437` - `Add foreground blackout view`
- B2 `938f98d` - `Exit blackout only on double tap`
- B3 `5375cd5` - `Keep blackout free of fixed bright pixels`
- B4 `42b210a` - `Add idle and remote blackout controls`
- B5 - the final commit containing the visible keep-screen-awake setting,
  version, guidance, this report, completion marker, and handoff note

## B1-B3 - foreground blackout

- The main console has a visible `🌑 Blackout` button. It changes only the
  foreground SwiftUI presentation state; it does not request backgrounding,
  lock the device, stop the server, or replace the running app scene.
- `Color.black` covers the app root and any presented Settings/Monitor sheet.
  The status bar and persistent system overlays are hidden, and no visible dot,
  label, or other fixed bright pixel is rendered, so pixel shifting is not
  needed.
- Entering blackout saves `UIScreen.main.brightness`, sets brightness to `0`,
  and forces `UIApplication.shared.isIdleTimerDisabled` on. Leaving restores
  the saved brightness.
- If the scene becomes inactive while blackout is selected, brightness is
  restored for the other foreground UI. Returning to `.active` reapplies
  brightness `0` while keeping the app's blackout state selected.
- A single tap has no exit action. A double-tap anywhere on the black view exits
  and restores the console and saved brightness.

The Vapor server manager, translation host, telemetry, and other foreground
objects remain mounted under the black overlay. This is how the implementation
keeps the app foreground instead of using an iOS background mode.

## B4 - idle and remote control

- Persistent `auto_blackout_idle_s` defaults to `0` (disabled). A window-level,
  non-cancelling gesture observer resets the deadline on user touch activity.
  When the active foreground scene remains idle for a positive configured
  duration, the same blackout state is entered automatically.
- `GET/POST /admin/settings` exposes `auto_blackout_idle_s` and the live
  `blackout` boolean. Both changes are hot and do not restart Vapor.
- `GET /health` exposes the live top-level `blackout` boolean.

Example remote controls:

```sh
curl -H 'X-Admin-Token: TOKEN' -H 'Content-Type: application/json' \
  -d '{"blackout":true}' http://PHONE:8000/admin/settings

curl -H 'X-Admin-Token: TOKEN' -H 'Content-Type: application/json' \
  -d '{"blackout":false,"auto_blackout_idle_s":300}' \
  http://PHONE:8000/admin/settings
```

## B5 - visible screen-awake control

- Settings shows `Giữ màn hình luôn sáng`, persistent and enabled by default.
  It is also available as `keep_screen_awake` in `/admin/settings`.
- The controller reapplies `isIdleTimerDisabled` whenever `scenePhase` becomes
  `.active`. Blackout always forces it on; outside blackout the visible setting
  decides the value.
- Settings and `README.md` include the farm guidance: Guided Access + Blackout +
  external power keeps the app foreground with an electrically on but visually
  black display.

## Scope

Product changes are limited to the display controller, main SwiftUI console,
app scene wiring, user-activity observer, display settings, admin DTO/apply
schema, the requested health field, README guidance, and Xcode version fields.
No changes were made to `KeepAliveService.swift`, `ThermalGovernor.swift`,
`NetworkMonitor.swift`, `VaporServerManager.swift`, or OCR implementation files.
The `VaporServer.swift` diff is limited to the existing admin settings schema and
apply path.

## Verification performed

- Parsed all 42 Swift source files with tree-sitter-swift 0.7.2: zero syntax
  errors.
- Parsed all four inline JavaScript blocks with Node's JavaScript parser.
- Syntax-compiled both Python tools with `py_compile` using a temporary cache.
- Parsed all three plain JSON OCR resource files.
- Passed 24/24 static V9 coverage checks for the button, absolute-black cover,
  brightness save/zero/restore, double-tap exit, hidden system overlays, idle
  default and activity reset, admin controls, health field, visible/default-on
  screen-awake control, active-scene wiring, farm guidance, version fields, and
  the synchronized Xcode source group.
- Confirmed `git diff --check` passes and the V9 changed-path list does not
  include keep-alive, governor, network rebind, server manager, or OCR source
  files.

## Not verified

- This machine has no `xcodebuild`, `xcrun`, Apple SDK, or Swift compiler.
  Apple-framework type-checking, linking, signing, and an actual Xcode build are
  not verified. The compile-oriented self-check proves Swift syntax and static
  wiring only; `XCODE_BUILD_VERIFIED=0` is recorded honestly.
- No physical iPhone was available. Absolute-black appearance across real
  system UI, brightness restore, idle timing, Guided Access, foreground Wi-Fi
  reachability, OLED power behavior, remote blackout while under load, and
  double-tap ergonomics remain device tests.
- The supplied premise that an electrically on foreground display keeps Wi-Fi
  reachable was not independently reproduced here. The implementation avoids
  backgrounding, but 24/7 reachability is not claimed proven until observed on
  the target phone.
