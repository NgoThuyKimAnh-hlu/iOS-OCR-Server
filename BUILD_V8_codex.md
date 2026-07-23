# BUILD V8 report

Date: 2026-07-23

## Outcome

Implemented `BUILD_V8_SPEC.md` locally as four N1-N4 commits. No GitHub push or
publish action was performed. The app version is `1.8.0 (35)` in Debug and
Release.

Implementation commits:

- N1 `fde284b` - `Rebind server when network paths change`
- N2 `a556889` - `Recover stale sockets on foreground and IP drift`
- N3 `dce9beb` - `Keep Vapor bound to all network interfaces`
- N4 - the final commit containing health diagnostics, version, this report,
  completion marker, and handoff note

The product-code diff is limited to `NetworkMonitor.swift`,
`VaporServerManager.swift`, `ServerTelemetry.swift`, `VaporServer.swift`, and
the requested Xcode version fields. Keep-alive audio, thermal governor, OCR,
and admin behavior were not changed.

## N1 - network path rebind

- A process-wide `NWPathMonitor` runs on its own serial queue and snapshots path
  status, available interface names/types, the selected active interface, and
  its current non-loopback IPv4 address from `getifaddrs`.
- A transition from an unsatisfied path to a satisfied path, a change in
  available/active interfaces, or a detected IP change schedules a socket
  rebind.
- Rebinds are debounced for 2.5 seconds. A real rebind stops and starts Vapor,
  increments `socket_rebinds`, and appends a `REBIND` event to the existing
  200-entry ring log.

## N2 - foreground and bound-IP checks

- After a successful Vapor start, the manager stores the current IP/interface
  snapshot as the binding snapshot.
- `UIApplication.didBecomeActiveNotification` immediately compares the current
  network snapshot with the binding snapshot. An IP or active-interface
  mismatch schedules the same debounced rebind.
- Every watchdog cycle performs that comparison before its existing localhost
  health request. The `127.0.0.1` request still detects a dead local process,
  but it is no longer treated as proof that the listener is reachable from the
  current LAN interface: localhost can remain healthy while the external socket
  is stale.

## N3 - wildcard bind

- The pre-V8 code already used `0.0.0.0`. N3 preserves that behavior as the
  explicit immutable `VaporServer.wildcardBindHost` invariant, so every new
  listener accepts connections on all IPv4 interfaces.
- Network-event rebinds remain necessary because an interface can disappear
  and return even when the configured host is wildcard.

## N4 - health diagnostics

`GET /health` now includes:

```json
{
  "network": {
    "bound_ip": "192.168.1.20",
    "current_ip": "192.168.1.20",
    "socket_rebinds": 1,
    "path_status": "satisfied",
    "interface": "en0:wifi"
  }
}
```

`bound_ip` is the device IP snapshot taken immediately after the current Vapor
listener starts. `current_ip` is resolved when health is generated. A mismatch
is the stale-binding signal used by foreground/watchdog recovery and should only
be transient while the 2.5-second debounce is pending.

## Verification performed

- Parsed all 40 Swift source files with tree-sitter-swift 0.7.2: zero syntax
  errors.
- Parsed all four inline JavaScript blocks with Node's JavaScript parser.
- Syntax-compiled both Python tools with `py_compile` using a temporary cache.
- Parsed all three plain JSON OCR resource files.
- Passed 13 static V8 coverage checks for `NWPathMonitor`, path/interface/IP
  events, debounce, foreground recovery, bound/current comparison, watchdog
  wiring, wildcard bind, all five health fields, both version configurations,
  and the synchronized Xcode source group.
- Confirmed `git diff --check` passes and the V8 product diff does not touch
  keep-alive, governor, OCR, or admin source files.

## Not verified

- This machine has no Apple SDK, Swift compiler, or `xcodebuild`. Apple-framework
  and Vapor type-checking, linking, unsigned IPA packaging, and signing are not
  proven locally. The self-check proves syntax and static wiring, not a full
  Xcode compile.
- No physical iPhone was available. Screen-off Wi-Fi sleep/wake, DHCP/IP changes,
  actual `NWPathMonitor` callback delivery while backgrounded, debounce timing,
  Vapor socket replacement, Bonjour rediscovery, and runtime `/health` JSON are
  device checks.
- The stale-socket root cause supplied in the spec was not independently
  reproduced here, so the real-world symptom is not claimed fixed until a phone
  survives a lock/Wi-Fi-change/unlock test without a manual restart.
