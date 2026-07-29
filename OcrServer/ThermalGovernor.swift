//
//  ThermalGovernor.swift
//  OcrServer
//

import Foundation
import Vapor

struct ThermalStatusSnapshot: Sendable {
    let thermal: String
    let thermalThrottling: Bool
}

enum ThermalStatus {
    static func current(guardEnabled: Bool = Settings.shared.thermalGuard) -> ThermalStatusSnapshot {
        let state = ProcessInfo.processInfo.thermalState
        return ThermalStatusSnapshot(
            thermal: name(for: state),
            thermalThrottling: guardEnabled && isHot(state)
        )
    }

    static func name(for state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }

    static func isHot(_ state: ProcessInfo.ThermalState) -> Bool {
        state == .serious || state == .critical
    }
}

private struct OCRThrottleResponse: Content, Sendable {
    let throttled: Bool
    let thermal: String
    let reason: String
}

private struct ThermalAdmissionDecision: Sendable {
    let admitted: Bool
    let thermal: String
    let reason: String
    let retryAfter: Int
    let startDelayNanoseconds: UInt64
    var permit: UUID? = nil
}

private struct WaitingAdmission {
    let continuation: CheckedContinuation<ThermalAdmissionDecision, Never>
}

actor ThermalGovernor {
    static let shared = ThermalGovernor()

    private var thermalState = ProcessInfo.processInfo.thermalState
    // Each admitted request holds a permit with its own start time, so a stuck one can be reclaimed
    // individually and a late release from it becomes a no-op instead of stealing someone's slot.
    private var permits: [UUID: Date] = [:]
    private let permitDeadline: TimeInterval = 300
    private var throttling = false
    private var inFlight: Int { permits.count }
    private var waiters: [WaitingAdmission] = []
    private var guardEnabled = true
    private var maximumInFlight = 2
    private var maximumQueueDepth = 8
    private var fairGapMilliseconds = 300
    private var nextFairStartNanoseconds: UInt64 = 0
    private var notificationTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?

    private init() {
        throttling = ThermalStatus.isHot(thermalState)
    }

    func startMonitoring() {
        sampleThermalState()
        guard notificationTask == nil, pollTask == nil else { return }

        notificationTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: ProcessInfo.thermalStateDidChangeNotification
            )
            for await _ in notifications {
                guard !Task.isCancelled else { break }
                await self?.sampleThermalState()
            }
        }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.sampleThermalState()
            }
        }
    }

    fileprivate func admit(
        guardEnabled: Bool,
        maximumQueueDepth: Int,
        maximumInFlight: Int,
        fairGapMilliseconds: Int
    ) async -> ThermalAdmissionDecision {
        self.guardEnabled = guardEnabled
        self.maximumQueueDepth = max(0, maximumQueueDepth)
        self.maximumInFlight = max(1, maximumInFlight)
        self.fairGapMilliseconds = max(0, fairGapMilliseconds)
        sampleThermalState()
        let thermal = ThermalStatus.name(for: thermalState)

        reclaimStalePermits()

        // 2026-07-29 REMOVED: rejecting work because ProcessInfo.thermalState reads .serious.
        //
        // Measured on the live farm, not theorised: a phone reporting thermal=serious served 6/6
        // serial /upload requests at 826 ms with clean output, and its flag fell back to nominal on
        // its own once load stopped. Yet two concurrent requests to that same phone returned
        // {"reason":"thermal_serious"} 128 times out of 128 in 40 s. iOS raises .serious for ambient
        // heat and charging, not for "Vision cannot run" — so this gate refused work the device was
        // demonstrably able to do, and cost the farm roughly 3x its throughput (560 -> 182 p/min)
        // once the client was tuned down to avoid the 429s it produced.
        //
        // Back-pressure still exists and is honest: maximumInFlight bounds concurrent work and
        // maximumQueueDepth bounds the wait queue below. Those reflect real capacity. Thermal state
        // stays REPORTED in /health for observability; it no longer gates admission.

        if inFlight < self.maximumInFlight {
            return reserveSlot(thermal: thermal)
        }

        if waiters.count >= self.maximumQueueDepth {
            return ThermalAdmissionDecision(
                admitted: false,
                thermal: thermal,
                reason: "queue_full",
                retryAfter: 1 + Int.random(in: 0...1),
                startDelayNanoseconds: 0
            )
        }

        return await withCheckedContinuation { continuation in
            waiters.append(WaitingAdmission(continuation: continuation))
        }
    }

    func finish(permit: UUID?) {
        // A release for a permit we already reclaimed is a no-op: it must not free somebody else's
        // slot. That is the whole reason permits are identified rather than counted.
        if let permit { permits.removeValue(forKey: permit) }
        sampleThermalState()
        promoteWaiters()
    }

    /// Reclaim slots whose request has been gone far longer than any real page takes. Individual,
    /// never a global reset: zeroing the count would double-release the requests still running.
    private func reclaimStalePermits() {
        let cutoff = Date().addingTimeInterval(-permitDeadline)
        permits = permits.filter { $0.value > cutoff }
    }

    func snapshot(guardEnabled: Bool) -> ThermalStatusSnapshot {
        sampleThermalState()
        return ThermalStatusSnapshot(
            thermal: ThermalStatus.name(for: thermalState),
            thermalThrottling: guardEnabled && throttling
        )
    }

    private func sampleThermalState() {
        let sampled = ProcessInfo.processInfo.thermalState
        thermalState = sampled
        if throttling {
            // Farm ambient may never reach nominal, so fair is the resume boundary.
            if sampled == .nominal || sampled == .fair {
                throttling = false
            }
        } else if ThermalStatus.isHot(sampled) {
            throttling = true
        }

        // Thermal state changing no longer cancels queued work — see the note in admit().
    }

    private func reserveSlot(thermal: String) -> ThermalAdmissionDecision {
        let permit = UUID()
        permits[permit] = Date()
        return ThermalAdmissionDecision(
            admitted: true,
            thermal: thermal,
            reason: "admitted",
            retryAfter: 0,
            startDelayNanoseconds: fairAdmissionDelay(),
            permit: permit
        )
    }

    private func promoteWaiters() {
        // Waiters are promoted purely on freed capacity; the thermal flag is observability only.
        let thermal = ThermalStatus.name(for: thermalState)
        while inFlight < maximumInFlight, !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.continuation.resume(returning: reserveSlot(thermal: thermal))
        }
    }


    private func fairAdmissionDelay() -> UInt64 {
        guard thermalState == .fair, fairGapMilliseconds > 0 else {
            nextFairStartNanoseconds = 0
            return 0
        }

        let now = DispatchTime.now().uptimeNanoseconds
        let scheduled = max(now, nextFairStartNanoseconds)
        let gap = UInt64(fairGapMilliseconds) * 1_000_000
        nextFairStartNanoseconds = scheduled + gap
        return scheduled - now
    }
}

struct OCRAdmissionMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        guard Self.isOCRRequest(request) else {
            return try await next.respond(to: request)
        }

        let settings = await MainActor.run {
            (
                Settings.shared.thermalGuard,
                Settings.shared.maximumQueueDepth,
                Settings.shared.maximumOCRInflight,
                Settings.shared.fairGapMilliseconds
            )
        }
        await ThermalGovernor.shared.startMonitoring()
        let decision = await ThermalGovernor.shared.admit(
            guardEnabled: settings.0,
            maximumQueueDepth: settings.1,
            maximumInFlight: settings.2,
            fairGapMilliseconds: settings.3
        )
        guard decision.admitted else {
            var headers = HTTPHeaders()
            headers.add(name: "Retry-After", value: String(decision.retryAfter))
            let response = Response(status: .tooManyRequests, headers: headers)
            try response.content.encode(
                OCRThrottleResponse(
                    throttled: true,
                    thermal: decision.thermal,
                    reason: decision.reason
                ),
                as: .json
            )
            return response
        }

        // Observed: phones answered {"reason":"queue_full"} at zero load with thermal=nominal
        // (503 and 656 refusals/min on two idle devices) while a third ran with 0 failures, and
        // /admin/restart did not clear it — so admission slots were being accounted but never
        // returned. The exact escape path is NOT established: Vapor bridges this middleware with
        // EventLoopPromise.completeWithTask, which SwiftNIO documents as NOT honouring
        // cancellation, so a client timeout should still reach the release below.
        //
        // Rather than guess the path, make the accounting survive whatever it is: releasing through
        // a detached task means a cancelled parent cannot skip it, and permits carry their own start
        // time so a slot that is never returned is reclaimed individually in admit(). A late release
        // for a reclaimed permit is a no-op and cannot free another request's slot.
        let permit = decision.permit
        func releaseSlot() {
            Task.detached(priority: .high) { await ThermalGovernor.shared.finish(permit: permit) }
        }

        if decision.startDelayNanoseconds > 0 {
            do {
                try await Task.sleep(nanoseconds: decision.startDelayNanoseconds)
            } catch {
                releaseSlot()
                throw error
            }
        }

        do {
            let response = try await next.respond(to: request)
            releaseSlot()
            return response
        } catch {
            releaseSlot()
            throw error
        }
    }

    private static func isOCRRequest(_ request: Request) -> Bool {
        guard request.method == .POST else { return false }
        return [
            "/upload",
            "/docOCR",
            "/batch",
            "/batch/ocr",
            "/batch/markdown",
            "/batch/docx",
            "/debug/ocr",
        ].contains(request.url.path)
    }
}
