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
}

private struct WaitingAdmission {
    let continuation: CheckedContinuation<ThermalAdmissionDecision, Never>
}

actor ThermalGovernor {
    static let shared = ThermalGovernor()

    private var thermalState = ProcessInfo.processInfo.thermalState
    private var throttling = false
    private var inFlight = 0
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

        if guardEnabled && throttling {
            return thermalRejection()
        }

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

    func finish() {
        inFlight = max(0, inFlight - 1)
        sampleThermalState()
        promoteWaiters()
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

        if guardEnabled && throttling {
            rejectWaitingRequests()
        }
    }

    private func reserveSlot(thermal: String) -> ThermalAdmissionDecision {
        inFlight += 1
        return ThermalAdmissionDecision(
            admitted: true,
            thermal: thermal,
            reason: "admitted",
            retryAfter: 0,
            startDelayNanoseconds: fairAdmissionDelay()
        )
    }

    private func promoteWaiters() {
        guard !(guardEnabled && throttling) else {
            rejectWaitingRequests()
            return
        }
        let thermal = ThermalStatus.name(for: thermalState)
        while inFlight < maximumInFlight, !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.continuation.resume(returning: reserveSlot(thermal: thermal))
        }
    }

    private func rejectWaitingRequests() {
        guard !waiters.isEmpty else { return }
        let rejection = thermalRejection()
        let waiting = waiters
        waiters.removeAll(keepingCapacity: true)
        for waiter in waiting {
            waiter.continuation.resume(returning: rejection)
        }
    }

    private func thermalRejection() -> ThermalAdmissionDecision {
        let baseRetry = thermalState == .critical ? 8 : 3
        return ThermalAdmissionDecision(
            admitted: false,
            thermal: ThermalStatus.name(for: thermalState),
            reason: thermalState == .critical ? "thermal_critical" : "thermal_serious",
            retryAfter: baseRetry + Int.random(in: 0...2),
            startDelayNanoseconds: 0
        )
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

        if decision.startDelayNanoseconds > 0 {
            do {
                try await Task.sleep(nanoseconds: decision.startDelayNanoseconds)
            } catch {
                await ThermalGovernor.shared.finish()
                throw error
            }
        }

        do {
            let response = try await next.respond(to: request)
            await ThermalGovernor.shared.finish()
            return response
        } catch {
            await ThermalGovernor.shared.finish()
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
