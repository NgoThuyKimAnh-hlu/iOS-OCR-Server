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
}

actor ThermalGovernor {
    static let shared = ThermalGovernor()

    private var thermalState = ProcessInfo.processInfo.thermalState
    private var throttling = false
    private var inFlight = 0
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
        maximumQueueDepth: Int
    ) -> ThermalAdmissionDecision {
        sampleThermalState()
        let thermal = ThermalStatus.name(for: thermalState)

        if guardEnabled && throttling {
            let baseRetry = thermalState == .critical ? 8 : 3
            return ThermalAdmissionDecision(
                admitted: false,
                thermal: thermal,
                reason: thermalState == .critical ? "thermal_critical" : "thermal_serious",
                retryAfter: baseRetry + Int.random(in: 0...2)
            )
        }

        // T1 bounds total admitted work; T2 turns excess work into a short wait queue.
        if inFlight >= max(1, maximumQueueDepth) {
            return ThermalAdmissionDecision(
                admitted: false,
                thermal: thermal,
                reason: "queue_full",
                retryAfter: 1 + Int.random(in: 0...1)
            )
        }

        inFlight += 1
        return ThermalAdmissionDecision(
            admitted: true,
            thermal: thermal,
            reason: "admitted",
            retryAfter: 0
        )
    }

    func finish() {
        inFlight = max(0, inFlight - 1)
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
            (Settings.shared.thermalGuard, Settings.shared.maximumQueueDepth)
        }
        await ThermalGovernor.shared.startMonitoring()
        let decision = await ThermalGovernor.shared.admit(
            guardEnabled: settings.0,
            maximumQueueDepth: settings.1
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
