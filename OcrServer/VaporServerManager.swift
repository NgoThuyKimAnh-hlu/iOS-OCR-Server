//
//  VaporServerManager.swift
//  OcrServer
//
//  Created by Riddle Ling on 2025/8/21.
//

import SwiftUI
import Combine
import Vision
import Foundation

@MainActor
final class VaporServerManager: ObservableObject {
    private let server = VaporServer()
    private var cancellables = Set<AnyCancellable>()
    private var lifecycleTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var bonjourService: NetService?
    private let primaryPort = 8000
    private let fallbackPorts = 8001...8010
    
    @Published private(set) var port: Int = 8000

    @Published var status: String = ""
    @Published var networkAddresses: [String: String] = [:]
    @Published var isRestarting = false
    @Published private(set) var isRunning = false

    let networkInterfaces = ["en0", "en1", "en2", "en3", "en4", "en5"]

    init() {
        Settings.shared.httpPort = primaryPort
        NotificationCenter.default.publisher(for: .vaporServerShouldRestart)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.beginRestart(reason: "/server/crash")
                }
            }
            .store(in: &cancellables)
        startServer()
    }
    
    func startServer() {
        guard lifecycleTask == nil else { return }
        lifecycleTask = Task { [weak self] in
            guard let self else { return }
            await self.performStart()
            self.lifecycleTask = nil
        }
    }

    func stopServer() {
        guard lifecycleTask == nil else { return }
        lifecycleTask = Task { [weak self] in
            guard let self else { return }
            self.isRestarting = true
            self.watchdogTask?.cancel()
            self.watchdogTask = nil
            self.stopBonjour()
            await self.server.stop()
            KeepAliveService.shared.stop()
            ServerTelemetry.shared.markServerStopped()
            self.isRunning = false
            self.status = String(localized: "server stopped")
            self.isRestarting = false
            self.lifecycleTask = nil
        }
    }

    func restartServer() {
        beginRestart(reason: nil)
    }

    func setKeepAliveEnabled(_ enabled: Bool) {
        KeepAliveService.shared.setEnabled(enabled)
    }

    private func configureServer(port: Int) async {
        let level: RecognizeTextRequest.RecognitionLevel =
                (Settings.shared.recognitionLevel == "Fast") ? .fast : .accurate
        
        await server.configure(
            port: port,
            recognitionLevel: level,
            usesLanguageCorrection: Settings.shared.languageCorrection,
            automaticallyDetectsLanguage: Settings.shared.automaticallyDetectsLanguage,
        )
    }

    private func performStart() async {
        isRestarting = true
        status = String(localized: "server restarting...")
        KeepAliveService.shared.setEnabled(Settings.shared.keepAliveEnabled)

        await server.setAutoRestart(true)
        await server.setOnStopped { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.stopBonjour()
                self.isRunning = false
                ServerTelemetry.shared.markServerStopped()
                self.status = String(localized: "server stopped")
            }
        }

        do {
            let selectedPort = try await startUsingPortPolicy()
            port = selectedPort
            isRunning = true
            status = String(localized: "server is running")
            ServerTelemetry.shared.markServerStarted()
            refreshNetworkAddresses()
            publishBonjour(port: selectedPort)
            startWatchdog()
        } catch {
            isRunning = false
            status = String(localized: "unable to start the server")
            ServerTelemetry.shared.recordSystemEvent(
                method: "SERVER",
                path: "/start",
                status: 500
            )
        }
        isRestarting = false
    }

    private func beginRestart(reason: String?) {
        guard lifecycleTask == nil else { return }
        if let reason {
            ServerTelemetry.shared.recordAutomaticRestart(reason: reason)
        }

        lifecycleTask = Task { [weak self] in
            guard let self else { return }
            self.isRestarting = true
            self.status = String(localized: "server restarting...")
            self.watchdogTask?.cancel()
            self.watchdogTask = nil
            self.stopBonjour()

            if reason != nil {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            await self.server.stop()
            self.isRunning = false
            await self.performStart()
            self.lifecycleTask = nil
        }
    }

    private func startUsingPortPolicy() async throws -> Int {
        var lastError: Error?

        for attempt in 1...5 {
            await configureServer(port: primaryPort)
            do {
                try await server.start()
                return primaryPort
            } catch {
                lastError = error
                ServerTelemetry.shared.recordSystemEvent(
                    method: "BIND",
                    path: ":\(primaryPort)/attempt/\(attempt)",
                    status: 503
                )
                if attempt < 5 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }

        for fallbackPort in fallbackPorts {
            await configureServer(port: fallbackPort)
            do {
                try await server.start()
                return fallbackPort
            } catch {
                lastError = error
            }
        }

        throw lastError ?? ServerManagerError.noAvailablePort
    }

    private func startWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            var consecutiveFailures = 0

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch {
                    return
                }

                guard let self, self.isRunning, !self.isRestarting else { continue }
                if await self.healthCheck() {
                    consecutiveFailures = 0
                } else {
                    consecutiveFailures += 1
                    ServerTelemetry.shared.recordSystemEvent(
                        method: "WATCHDOG",
                        path: "/health/failure/\(consecutiveFailures)",
                        status: 503
                    )
                    if consecutiveFailures >= 2 {
                        self.beginRestart(reason: "/health/unresponsive")
                        return
                    }
                }
            }
        }
    }

    private func healthCheck() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else {
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["status"] as? String == "ok" else {
                return false
            }
            return true
        } catch {
            return false
        }
    }

    private func publishBonjour(port: Int) {
        stopBonjour()
        let service = NetService(
            domain: "local.",
            type: "_http._tcp.",
            name: "compute",
            port: Int32(port)
        )
        service.includesPeerToPeer = true
        service.publish()
        bonjourService = service
    }

    private func stopBonjour() {
        bonjourService?.stop()
        bonjourService = nil
    }

    func refreshNetworkAddresses() {
        networkAddresses.removeAll()
        for interface in networkInterfaces {
            if let ip = getIP(for: interface) {
                networkAddresses[interface] = ip
            }
        }
        //print("\(networkAddresses)")
    }

    private func getIP(for interface: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interfaceName = String(cString: ptr.pointee.ifa_name)

            if interfaceName == interface {
                let flags = Int32(ptr.pointee.ifa_flags)
                var addr = ptr.pointee.ifa_addr.pointee

                // Filter out loopback and inactive interfaces
                let isRunning = (flags & (IFF_UP|IFF_RUNNING)) == (IFF_UP|IFF_RUNNING)
                let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
                if !isRunning || isLoopback {
                    continue
                }

                // IPv4 only
                if addr.sa_family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(&addr,
                                   socklen_t(addr.sa_len),
                                   &hostname,
                                   socklen_t(hostname.count),
                                   nil, 0,
                                   NI_NUMERICHOST) == 0 {
                        return String(cString: hostname)
                    }
                }
            }
        }

        return nil
    }
}

private enum ServerManagerError: Error {
    case noAvailablePort
}
