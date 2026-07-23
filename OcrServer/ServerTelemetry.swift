//
//  ServerTelemetry.swift
//  OcrServer
//

import Combine
import Foundation
import UIKit
import Vapor

struct RequestLogEntry: Content, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let method: String
    let path: String
    let status: Int
    let duration_ms: Double
    let size: Int
}

actor RequestLogStore {
    static let shared = RequestLogStore()

    private let maximumLogCount = 200
    private var entries: [RequestLogEntry] = []

    private init() {}

    func append(_ entry: RequestLogEntry) {
        entries.append(entry)
        if entries.count > maximumLogCount {
            entries.removeFirst(entries.count - maximumLogCount)
        }
    }

    func recent(limit: Int) -> [RequestLogEntry] {
        Array(entries.suffix(min(max(0, limit), maximumLogCount)))
    }
}

struct ServerBatteryStatus: Content, Sendable {
    let level: Int?
    let state: String
}

struct OCRImproveHealthStatus: Content, Sendable {
    let enabled: Bool
    let correction_rules: Int
    let unigram_entries: Int
    let corrections_total: Int
    let default_pack: String
    let pack_version: String
    let active_pack: String
    let customization_version: Int
    let customization_hash: String
    let customwords_count: Int
    let custom_words: Int
    let custom_overrides: Int
    let custom_packs: Int
}

struct KeepAliveHealthStatus: Content, Sendable {
    let active: Bool
    let own_session: Bool
    let reheals: Int
    let last_error: String?
    let engine_running: Bool
    let player_playing: Bool
}

struct ServerNetworkHealthStatus: Content, Sendable {
    let bound_ip: String?
    let current_ip: String?
    let socket_rebinds: Int
    let path_status: String
    let interface: String
}

struct ServerHealthResponse: Content, Sendable {
    let status: String
    let uptime_s: Int
    let port: Int
    let version: String
    let build_version: String
    let requests_total: Int
    let requests_ok: Int
    let requests_fail: Int
    let auto_restarts: Int
    let network: ServerNetworkHealthStatus
    let keep_alive: KeepAliveHealthStatus
    let battery: ServerBatteryStatus
    let thermal: String
    let thermal_throttling: Bool
    let mem_free_mb: Int
    let ocr_improve: OCRImproveHealthStatus
}

struct ServerStatsResponse: Content, Sendable {
    let status: String
    let uptime_s: Int
    let port: Int
    let version: String
    let build_version: String
    let requests_total: Int
    let requests_ok: Int
    let requests_fail: Int
    let auto_restarts: Int
    let keep_alive: Bool
    let battery: ServerBatteryStatus
    let thermal: String
    let thermal_throttling: Bool
    let mem_free_mb: Int
    let ocr_improve: OCRImproveHealthStatus
    let logs: [RequestLogEntry]
}

@MainActor
final class ServerTelemetry: ObservableObject {
    static let shared = ServerTelemetry()

    @Published private(set) var requestsTotal = 0
    @Published private(set) var requestsOK = 0
    @Published private(set) var requestsFail = 0
    @Published private(set) var autoRestarts = 0
    @Published private(set) var socketRebinds = 0
    @Published private(set) var ocrCorrectionsTotal = 0
    @Published private(set) var logs: [RequestLogEntry] = []
    @Published private(set) var serverStartedAt: Date?

    private let maximumLogCount = 200

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    func markServerStarted() {
        serverStartedAt = Date()
    }

    func markServerStopped() {
        serverStartedAt = nil
    }

    func recordRequest(
        _ entry: RequestLogEntry
    ) {
        requestsTotal += 1
        if (200..<400).contains(entry.status) {
            requestsOK += 1
        } else {
            requestsFail += 1
        }
        appendLog(entry)
    }

    func recordSystemEvent(method: String, path: String, status: Int) {
        appendLog(
            RequestLogEntry(
                id: UUID(),
                timestamp: Date(),
                method: method,
                path: path,
                status: status,
                duration_ms: 0,
                size: 0
            )
        )
    }

    func recordAutomaticRestart(reason: String) {
        autoRestarts += 1
        recordSystemEvent(method: "WATCHDOG", path: reason, status: 0)
    }

    func recordSocketRebind(reason: String) {
        socketRebinds += 1
        recordSystemEvent(
            method: "REBIND",
            path: "/network/\(reason)",
            status: 202
        )
    }

    func recordOCRCorrections(_ count: Int) {
        ocrCorrectionsTotal += max(0, count)
    }

    func recentLogs(limit: Int) -> [RequestLogEntry] {
        Array(logs.suffix(max(0, limit)))
    }

    func healthResponse(
        port: Int,
        customization: OCRCustomizationSummary,
        customWordsCount: Int,
        thermalStatus: ThermalStatusSnapshot
    ) -> ServerHealthResponse {
        let device = UIDevice.current
        let keepAlive = KeepAliveService.shared
        let currentNetwork = NetworkMonitor.shared.currentSnapshot()
        let boundNetwork = NetworkMonitor.shared.serverBoundSnapshot()
        let level = device.batteryLevel >= 0
            ? Int((device.batteryLevel * 100).rounded())
            : nil
        return ServerHealthResponse(
            status: "ok",
            uptime_s: serverStartedAt.map {
                max(0, Int(Date().timeIntervalSince($0)))
            } ?? 0,
            port: port,
            version: BuildInfo.versionStamp,
            build_version: BuildInfo.versionStamp,
            requests_total: requestsTotal,
            requests_ok: requestsOK,
            requests_fail: requestsFail,
            auto_restarts: autoRestarts,
            network: ServerNetworkHealthStatus(
                bound_ip: boundNetwork?.currentIP,
                current_ip: currentNetwork.currentIP,
                socket_rebinds: socketRebinds,
                path_status: currentNetwork.pathStatus,
                interface: currentNetwork.interfaceIdentity
            ),
            keep_alive: KeepAliveHealthStatus(
                active: keepAlive.isActive,
                own_session: Settings.shared.keepAliveOwnSession,
                reheals: keepAlive.reheals,
                last_error: keepAlive.lastError,
                engine_running: keepAlive.engineRunning,
                player_playing: keepAlive.playerPlaying
            ),
            battery: ServerBatteryStatus(
                level: level,
                state: Self.batteryStateName(device.batteryState)
            ),
            thermal: thermalStatus.thermal,
            thermal_throttling: thermalStatus.thermalThrottling,
            mem_free_mb: Self.freeMemoryMegabytes(),
            ocr_improve: OCRImproveHealthStatus(
                enabled: Settings.shared.improveEnabled,
                correction_rules: VNLegalCorrector.correctionRuleCount,
                unigram_entries: VNLegalCorrector.unigramEntryCount,
                corrections_total: ocrCorrectionsTotal,
                default_pack: "minimal",
                pack_version: "2026.07.22.1",
                active_pack: Settings.shared.activePack,
                customization_version: customization.version,
                customization_hash: customization.hash,
                customwords_count: customWordsCount,
                custom_words: customization.custom_words,
                custom_overrides: customization.custom_overrides,
                custom_packs: customization.custom_packs
            )
        )
    }

    func statsResponse(
        port: Int,
        customization: OCRCustomizationSummary,
        customWordsCount: Int,
        thermalStatus: ThermalStatusSnapshot
    ) -> ServerStatsResponse {
        let health = healthResponse(
            port: port,
            customization: customization,
            customWordsCount: customWordsCount,
            thermalStatus: thermalStatus
        )
        return ServerStatsResponse(
            status: health.status,
            uptime_s: health.uptime_s,
            port: health.port,
            version: health.version,
            build_version: health.build_version,
            requests_total: health.requests_total,
            requests_ok: health.requests_ok,
            requests_fail: health.requests_fail,
            auto_restarts: health.auto_restarts,
            keep_alive: health.keep_alive.active,
            battery: health.battery,
            thermal: health.thermal,
            thermal_throttling: health.thermal_throttling,
            mem_free_mb: health.mem_free_mb,
            ocr_improve: health.ocr_improve,
            logs: recentLogs(limit: 20)
        )
    }

    func debugDeviceSnapshot() -> OCRDebugDeviceSnapshot {
        let device = UIDevice.current
        let thermalStatus = ThermalStatus.current()
        let level = device.batteryLevel >= 0
            ? Int((device.batteryLevel * 100).rounded())
            : nil
        return OCRDebugDeviceSnapshot(
            thermal: thermalStatus.thermal,
            thermal_throttling: thermalStatus.thermalThrottling,
            mem_free_mb: Self.freeMemoryMegabytes(),
            battery: ServerBatteryStatus(
                level: level,
                state: Self.batteryStateName(device.batteryState)
            )
        )
    }

    private func appendLog(_ entry: RequestLogEntry) {
        logs.append(entry)
        if logs.count > maximumLogCount {
            logs.removeFirst(logs.count - maximumLogCount)
        }
    }

    private static func batteryStateName(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unplugged:
            return "unplugged"
        case .charging:
            return "charging"
        case .full:
            return "full"
        case .unknown:
            return "unknown"
        @unknown default:
            return "unknown"
        }
    }

    private static func freeMemoryMegabytes() -> Int {
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        var statistics = vm_statistics64()
        let result = withUnsafeMutablePointer(to: &statistics) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let pageSize = UInt64(vm_kernel_page_size)
        let available = (
            UInt64(statistics.free_count) + UInt64(statistics.inactive_count)
        ) * pageSize
        return Int(available / 1_048_576)
    }
}

struct RequestMetricsMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        let started = DispatchTime.now().uptimeNanoseconds

        do {
            let response = try await next.respond(to: request)
            await record(
                request: request,
                status: Int(response.status.code),
                size: response.body.count,
                started: started
            )
            return response
        } catch {
            let status = (error as? AbortError)?.status.code
                ?? HTTPResponseStatus.internalServerError.code
            await record(
                request: request,
                status: Int(status),
                size: 0,
                started: started
            )
            throw error
        }
    }

    private func record(
        request: Request,
        status: Int,
        size: Int,
        started: UInt64
    ) async {
        let elapsed = DispatchTime.now().uptimeNanoseconds - started
        let entry = RequestLogEntry(
            id: UUID(),
            timestamp: Date(),
            method: request.method.string,
            path: request.url.path,
            status: status,
            duration_ms: Double(elapsed) / 1_000_000,
            size: max(0, size)
        )
        await RequestLogStore.shared.append(entry)
        await ServerTelemetry.shared.recordRequest(entry)
    }
}
