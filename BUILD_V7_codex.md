# BUILD V7 report

Date: 2026-07-23

## Outcome

Implemented `BUILD_V7_SPEC.md` locally in five K1-K5 commits. No GitHub push or
publish action was performed. The app version is `1.7.0 (34)` in Debug and
Release.

Implementation commits:

- K1 `b8c1fd3` - `Play low-amplitude keep-alive audio`
- K2 `6714601` - `Own keep-alive audio session by default`
- K3 `a371427` - `Self-heal keep-alive audio every 15 seconds`
- K4 `28c5a2f` - `Recover keep-alive audio from session resets`
- K5 - `Expose keep-alive health diagnostics` (the commit containing this report)

The implementation only changes keep-alive audio, its persistent settings knob,
the keep-alive health payload, and the requested build version. Governor, OCR,
and the existing admin authentication/request-limit behavior were not changed.

## K1 - low-amplitude audio

- The one-second loop is no longer all-zero PCM. It contains a deterministic
  20 Hz triangle signal with amplitude `0.0001`.
- `AVAudioPlayerNode.volume` is `0.001`, so the graph remains non-zero while the
  effective output is extremely small.

## K2 - own audio session by default

- `keep_alive_own_session` is persistent and defaults to `true`.
- The default `.playback` category has no `.mixWithOthers`, allowing Compute to
  own the audio session. Setting the knob to `false` restores
  `.mixWithOthers` and records `/audio/mixed-session/less-reliable` in the ring
  log when the value changes.
- The knob is exposed through the existing dynamic `GET/POST /admin/settings`
  flow and is applied immediately when keep-alive is enabled.

## K3 - 15-second watchdog

- A main-run-loop timer checks `AVAudioEngine.isRunning` and
  `AVAudioPlayerNode.isPlaying` every 15 seconds while keep-alive is enabled.
- A failed check increments the in-memory reheal counter, records
  `/audio/reheal` in the existing ring log, and starts bounded recovery.
- Disabling keep-alive invalidates the watchdog and cancels pending recovery.

## K4 - event recovery

- `AVAudioSession.mediaServicesWereResetNotification` discards the invalid
  engine, player node, buffer, and configuration flag, then creates a fresh
  graph and restarts it when enabled.
- `AVAudioSession.routeChangeNotification` reasserts the category/session and
  restarts the graph if needed.
- Interruption begin pauses recovery. Interruption end reads `.shouldResume` and
  only resumes when allowed; foreground, route-change, explicit enable, or media
  reset can permit a later recovery.
- Every start first attempts immediately. Failure, including `setActive(true)`
  failure, gets three bounded retries after 0.5, 1, and 2 seconds. Each retry
  performs a real engine/player readiness check.

## K5 - health diagnostics

`GET /health` now returns:

```json
{
  "keep_alive": {
    "active": true,
    "own_session": true,
    "reheals": 0,
    "last_error": null,
    "engine_running": true,
    "player_playing": true
  }
}
```

`GET /stats` keeps its existing Boolean `keep_alive` field for compatibility.

## Verification performed

- Parsed all 39 Swift source files with tree-sitter-swift 0.7.1: zero syntax
  errors.
- Parsed all four inline JavaScript blocks with Node's JavaScript parser.
- Syntax-compiled both Python tools with `py_compile`, then removed the generated
  cache files.
- Statically confirmed K1 non-zero signal/volume, K2 knob coverage in settings
  response/patch/schema, K3 timer/log/counter, K4 notification/retry paths, and
  all six K5 health members.
- Confirmed both build configurations are `1.7.0 (34)`, the synchronized Xcode
  source group remains present, and `git diff --check` passes.
- Audited the product-code scope from the V6 baseline: only
  `KeepAliveService.swift`, `Settings.swift`, `ServerTelemetry.swift`,
  `VaporServer.swift`, and the requested Xcode version fields changed.

## Not verified

- This machine has no Apple SDK, Swift compiler, or `xcodebuild`. Apple-framework
  type-checking, linking, unsigned IPA packaging, and signing are not proven
  locally; the self-check proves syntax and static wiring, not a full Xcode
  compile.
- No physical iPhone was available. Long screen-off survival, inaudibility,
  audio-session ownership, actual iOS culling behavior, watchdog execution in
  background, media-server reset, route changes, interruptions, and runtime
  `/health` serialization remain device checks.

