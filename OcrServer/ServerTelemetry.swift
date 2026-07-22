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
    let keep_alive: Bool
    let battery: ServerBatteryStatus
    let thermal: String
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
        method: String,
        path: String,
        status: Int,
        durationMilliseconds: Double,
        size: Int
    ) {
        requestsTotal += 1
        if (200..<400).contains(status) {
            requestsOK += 1
        } else {
            requestsFail += 1
        }

        appendLog(
            RequestLogEntry(
                id: UUID(),
                timestamp: Date(),
                method: method,
                path: path,
                status: status,
                duration_ms: durationMilliseconds,
                size: max(0, size)
            )
        )
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

    func recordOCRCorrections(_ count: Int) {
        ocrCorrectionsTotal += max(0, count)
    }

    func recentLogs(limit: Int) -> [RequestLogEntry] {
        Array(logs.suffix(max(0, limit)))
    }

    func healthResponse(port: Int, keepAlive: Bool) -> ServerHealthResponse {
        let device = UIDevice.current
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
            keep_alive: keepAlive,
            battery: ServerBatteryStatus(
                level: level,
                state: Self.batteryStateName(device.batteryState)
            ),
            thermal: Self.thermalStateName(ProcessInfo.processInfo.thermalState),
            mem_free_mb: Self.freeMemoryMegabytes(),
            ocr_improve: OCRImproveHealthStatus(
                enabled: Settings.shared.improveEnabled,
                correction_rules: VNLegalCorrector.correctionRuleCount,
                unigram_entries: VNLegalCorrector.unigramEntryCount,
                corrections_total: ocrCorrectionsTotal,
                default_pack: "minimal",
                pack_version: "2026.07.22.1"
            )
        )
    }

    func statsResponse(port: Int, keepAlive: Bool) -> ServerStatsResponse {
        let health = healthResponse(port: port, keepAlive: keepAlive)
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
            keep_alive: health.keep_alive,
            battery: health.battery,
            thermal: health.thermal,
            mem_free_mb: health.mem_free_mb,
            ocr_improve: health.ocr_improve,
            logs: recentLogs(limit: 20)
        )
    }

    func debugDeviceSnapshot() -> OCRDebugDeviceSnapshot {
        let device = UIDevice.current
        let level = device.batteryLevel >= 0
            ? Int((device.batteryLevel * 100).rounded())
            : nil
        return OCRDebugDeviceSnapshot(
            thermal: Self.thermalStateName(ProcessInfo.processInfo.thermalState),
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

    private static func thermalStateName(_ state: ProcessInfo.ThermalState) -> String {
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
        await ServerTelemetry.shared.recordRequest(
            method: request.method.string,
            path: request.url.path,
            status: status,
            durationMilliseconds: Double(elapsed) / 1_000_000,
            size: size
        )
    }
}
