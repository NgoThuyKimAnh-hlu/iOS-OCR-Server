//
//  NetworkMonitor.swift
//  OcrServer
//

import Foundation
import Network

struct NetworkInterfaceSnapshot: Equatable, Sendable {
    let name: String
    let type: String

    var identity: String {
        "\(name):\(type)"
    }
}

struct NetworkSnapshot: Equatable, Sendable {
    let pathStatus: String
    let isSatisfied: Bool
    let availableInterfaces: [NetworkInterfaceSnapshot]
    let interfaceName: String?
    let interfaceType: String
    let currentIP: String?

    var interfaceIdentity: String {
        guard let interfaceName else { return interfaceType }
        return "\(interfaceName):\(interfaceType)"
    }
}

final class NetworkMonitor: @unchecked Sendable {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "site.riddleling.compute.network-path")
    private let lock = NSLock()
    private var started = false
    private var boundSnapshot: NetworkSnapshot?
    private var updateHandler: ((NetworkSnapshot) -> Void)?

    private init() {}

    func start(updateHandler: @escaping (NetworkSnapshot) -> Void) {
        lock.lock()
        self.updateHandler = updateHandler
        let shouldStart = !started
        started = true
        lock.unlock()

        guard shouldStart else { return }
        monitor.pathUpdateHandler = { [weak self] path in
            self?.receive(path)
        }
        monitor.start(queue: queue)
    }

    func currentSnapshot() -> NetworkSnapshot {
        Self.makeSnapshot(from: monitor.currentPath)
    }

    func markServerBound(to snapshot: NetworkSnapshot) {
        lock.lock()
        boundSnapshot = snapshot
        lock.unlock()
    }

    func clearServerBinding() {
        lock.lock()
        boundSnapshot = nil
        lock.unlock()
    }

    func serverBoundSnapshot() -> NetworkSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return boundSnapshot
    }

    private func receive(_ path: NWPath) {
        let snapshot = Self.makeSnapshot(from: path)
        lock.lock()
        let handler = updateHandler
        lock.unlock()
        handler?(snapshot)
    }

    private static func makeSnapshot(from path: NWPath) -> NetworkSnapshot {
        let addresses = activeIPv4Addresses()
        let available = path.availableInterfaces.sorted { lhs, rhs in
            let lhsPriority = interfacePriority(lhs.type)
            let rhsPriority = interfacePriority(rhs.type)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            return lhs.name < rhs.name
        }
        let active = available.filter { path.usesInterfaceType($0.type) }
        let fallbackAddress = addresses.sorted { lhs, rhs in
            lhs.key < rhs.key
        }.first
        let fallbackInterface = fallbackAddress.flatMap { address in
            available.first { $0.name == address.key }
        }
        let selectedWithAddress = active.first { addresses[$0.name] != nil }
            ?? available.first { addresses[$0.name] != nil }
        let selected = selectedWithAddress
            ?? active.first
            ?? fallbackInterface
            ?? available.first

        return NetworkSnapshot(
            pathStatus: pathStatusName(path.status),
            isSatisfied: path.status == .satisfied,
            availableInterfaces: available.map {
                NetworkInterfaceSnapshot(
                    name: $0.name,
                    type: interfaceTypeName($0.type)
                )
            },
            interfaceName: selected?.name ?? fallbackAddress?.key,
            interfaceType: selected.map { interfaceTypeName($0.type) } ?? "none",
            currentIP: selectedWithAddress.flatMap { addresses[$0.name] }
                ?? fallbackAddress?.value
        )
    }

    private static func activeIPv4Addresses() -> [String: String] {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddress = ifaddr else {
            return [:]
        }
        defer { freeifaddrs(ifaddr) }

        var addresses: [String: String] = [:]
        for pointer in sequence(first: firstAddress, next: { $0.pointee.ifa_next }) {
            guard let addressPointer = pointer.pointee.ifa_addr else { continue }
            let flags = Int32(pointer.pointee.ifa_flags)
            let isRunning = (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING)
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            guard isRunning, !isLoopback, addressPointer.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            var address = addressPointer.pointee
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(
                &address,
                socklen_t(address.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 else {
                continue
            }
            addresses[String(cString: pointer.pointee.ifa_name)] = String(cString: hostname)
        }
        return addresses
    }

    private static func pathStatusName(_ status: NWPath.Status) -> String {
        switch status {
        case .satisfied: return "satisfied"
        case .unsatisfied: return "unsatisfied"
        case .requiresConnection: return "requires_connection"
        @unknown default: return "unknown"
        }
    }

    private static func interfaceTypeName(_ type: NWInterface.InterfaceType) -> String {
        switch type {
        case .wifi: return "wifi"
        case .wiredEthernet: return "wired_ethernet"
        case .cellular: return "cellular"
        case .loopback: return "loopback"
        case .other: return "other"
        @unknown default: return "unknown"
        }
    }

    private static func interfacePriority(_ type: NWInterface.InterfaceType) -> Int {
        switch type {
        case .wifi: return 0
        case .wiredEthernet: return 1
        case .cellular: return 2
        case .other: return 3
        case .loopback: return 4
        @unknown default: return 5
        }
    }
}
