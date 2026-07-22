//
//  ContentView.swift
//  OcrServer
//

import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var serverManager: VaporServerManager
    @StateObject private var telemetry = ServerTelemetry.shared
    @StateObject private var sampler = Sampler()
    @StateObject private var serviceMonitor = ServiceStatusMonitor()

    @State private var showingReadme = false
    @State private var showingSettings = false
    @State private var showingMonitor = false
    @State private var showingDonation = false
    @State private var copiedAddress = false

    private let serviceColumns = [
        GridItem(.adaptive(minimum: 96), spacing: 10)
    ]
    private let metricColumns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 4
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ConsolePalette.background
                    .ignoresSafeArea()

                Circle()
                    .fill(ConsolePalette.teal.opacity(0.13))
                    .frame(width: 310, height: 310)
                    .blur(radius: 70)
                    .offset(x: 150, y: -310)

                ScrollView {
                    VStack(spacing: 18) {
                        addressCard
                        serviceGrid
                        requestMetrics
                        systemMonitorCard
                        logTail
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Compute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ConsolePalette.background.opacity(0.92), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("LOCAL / ON-DEVICE")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(ConsolePalette.muted)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }

                    Menu {
                        Button("README", systemImage: "text.page") {
                            showingReadme = true
                        }
                        Button("Donation", systemImage: "cup.and.saucer") {
                            showingDonation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .tint(ConsolePalette.teal)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingReadme) {
            ReadmeView()
        }
        .sheet(isPresented: $showingMonitor) {
            DashboardView()
        }
        .sheet(isPresented: $showingDonation) {
            DonationView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(serverManager: serverManager)
                .preferredColorScheme(.dark)
        }
        .onAppear {
            serverManager.refreshNetworkAddresses()
            sampler.start()
        }
        .onDisappear {
            sampler.stop()
        }
        .task {
            while !Task.isCancelled {
                await serviceMonitor.refresh()
                do {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private var addressCard: some View {
        Button {
            guard let addressURL else { return }
            UIPasteboard.general.string = addressURL
            withAnimation(.easeOut(duration: 0.2)) {
                copiedAddress = true
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                withAnimation(.easeIn(duration: 0.2)) {
                    copiedAddress = false
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("PRIMARY ADDRESS")
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(ConsolePalette.muted)
                        Text(addressLabel)
                            .font(.system(size: 25, weight: .bold, design: .monospaced))
                            .minimumScaleFactor(0.55)
                            .lineLimit(1)
                            .foregroundStyle(.white)
                    }
                    Spacer(minLength: 10)
                    serverBadge
                }

                HStack(spacing: 8) {
                    Image(systemName: copiedAddress ? "checkmark" : "doc.on.doc")
                    Text(copiedAddress ? "Copied" : "Tap to copy")
                    Spacer()
                    Text("compute.local:\(serverManager.port)")
                        .font(.caption.monospaced())
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(copiedAddress ? ConsolePalette.green : ConsolePalette.muted)

                if let primaryIPAddress {
                    Text("Admin: http://\(primaryIPAddress):\(serverManager.port)/admin")
                        .font(.caption2.monospaced())
                        .foregroundStyle(ConsolePalette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [ConsolePalette.panel, ConsolePalette.panelRaised],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(ConsolePalette.teal)
                    .frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ConsolePalette.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var serverBadge: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(serverManager.isRunning ? ConsolePalette.green : ConsolePalette.red)
                        .frame(width: 7, height: 7)
                    Text(serverManager.isRunning ? "RUNNING" : "STOPPED")
                }
                .font(.caption2.monospaced().weight(.heavy))
                .foregroundStyle(serverManager.isRunning ? ConsolePalette.green : ConsolePalette.red)

                Text(uptimeText(now: context.date))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ConsolePalette.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.black.opacity(0.24))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var serviceGrid: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionHeader("SERVICES", value: "\(serviceMonitor.services.count) modules")
            LazyVGrid(columns: serviceColumns, spacing: 10) {
                ForEach(serviceMonitor.services) { service in
                    ServiceTile(
                        service: service,
                        forcedDisabled: !serverManager.isRunning
                    )
                }
            }
        }
    }

    private var requestMetrics: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionHeader("TRAFFIC", value: "live counters")
            LazyVGrid(columns: metricColumns, spacing: 8) {
                MetricCell(label: "TOTAL", value: telemetry.requestsTotal, color: ConsolePalette.teal)
                MetricCell(label: "OK", value: telemetry.requestsOK, color: ConsolePalette.green)
                MetricCell(label: "FAIL", value: telemetry.requestsFail, color: ConsolePalette.red)
                MetricCell(label: "RESTART", value: telemetry.autoRestarts, color: ConsolePalette.orange)
            }
        }
    }

    private var systemMonitorCard: some View {
        Button {
            showingMonitor = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("DEVICE", value: "tap for monitor")

                HStack(spacing: 0) {
                    DeviceReading(
                        icon: batteryIcon,
                        label: "BATTERY",
                        value: batteryText,
                        color: ConsolePalette.green
                    )
                    DeviceReading(
                        icon: "thermometer.medium",
                        label: "THERMAL",
                        value: thermalText.uppercased(),
                        color: thermalColor
                    )
                    DeviceReading(
                        icon: "memorychip",
                        label: "RAM FREE",
                        value: memoryFreeText,
                        color: ConsolePalette.teal
                    )
                }

                HStack(spacing: 10) {
                    SparklineCard(
                        title: "CPU",
                        value: latestSnapshot.map { "\(Int($0.cpuTotal * 100))%" } ?? "--",
                        values: sampler.snapshots.suffix(45).map(\.cpuTotal),
                        color: ConsolePalette.orange
                    )
                    SparklineCard(
                        title: "RAM",
                        value: memoryUsedText,
                        values: sampler.snapshots.suffix(45).map { snapshot in
                            guard snapshot.memoryTotal > 0 else { return 0 }
                            return Double(snapshot.memoryUsed) / Double(snapshot.memoryTotal)
                        },
                        color: ConsolePalette.teal
                    )
                }
            }
            .padding(16)
            .background(ConsolePalette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ConsolePalette.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var logTail: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionHeader("REQUEST LOG", value: "last \(min(200, telemetry.logs.count))")

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(telemetry.logs.reversed())) { entry in
                            RequestLogRow(entry: entry)
                                .id(entry.id)
                            Divider()
                                .overlay(ConsolePalette.border)
                        }

                        if telemetry.logs.isEmpty {
                            Text("Waiting for the first request...")
                                .font(.caption.monospaced())
                                .foregroundStyle(ConsolePalette.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                        }
                    }
                }
                .frame(minHeight: 150, maxHeight: 290)
                .onChange(of: telemetry.logs.last?.id) { _, latestID in
                    guard let latestID else { return }
                    proxy.scrollTo(latestID, anchor: .top)
                }
            }
            .background(.black.opacity(0.24))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ConsolePalette.border, lineWidth: 1)
            }
        }
    }

    private func sectionHeader(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.monospaced().weight(.heavy))
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.caption2.monospaced())
                .foregroundStyle(ConsolePalette.muted)
        }
    }

    private var primaryIPAddress: String? {
        if let wifi = serverManager.networkAddresses["en0"] {
            return wifi
        }
        return serverManager.networkAddresses
            .sorted { $0.key < $1.key }
            .first?.value
    }

    private var addressURL: String? {
        primaryIPAddress.map { "http://\($0):\(serverManager.port)" }
    }

    private var addressLabel: String {
        primaryIPAddress.map { "\($0):\(serverManager.port)" } ?? "Waiting for LAN address"
    }

    private func uptimeText(now: Date) -> String {
        guard serverManager.isRunning, let startedAt = telemetry.serverStartedAt else {
            return "uptime --:--:--"
        }
        let total = max(0, Int(now.timeIntervalSince(startedAt)))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        return String(format: "uptime %02d:%02d:%02d", hours, minutes, seconds)
    }

    private var latestSnapshot: ResourceSnapshot? {
        sampler.snapshots.last
    }

    private var batteryText: String {
        guard let snapshot = latestSnapshot, let level = snapshot.batteryLevel else { return "--" }
        let suffix: String
        switch snapshot.batteryState {
        case .charging:
            suffix = " CHG"
        case .full:
            suffix = " FULL"
        default:
            suffix = ""
        }
        return "\(Int(level * 100))%\(suffix)"
    }

    private var batteryIcon: String {
        latestSnapshot?.batteryState == .charging ? "battery.100percent.bolt" : "battery.75percent"
    }

    private var thermalText: String {
        guard let state = latestSnapshot?.thermalState else { return "--" }
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private var thermalColor: Color {
        guard let state = latestSnapshot?.thermalState else {
            return ConsolePalette.green
        }
        switch state {
        case .serious, .critical:
            return ConsolePalette.red
        case .fair:
            return ConsolePalette.orange
        default:
            return ConsolePalette.green
        }
    }

    private var memoryFreeText: String {
        guard let bytes = latestSnapshot?.memoryFree else { return "--" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    private var memoryUsedText: String {
        guard let snapshot = latestSnapshot, snapshot.memoryTotal > 0 else { return "--" }
        return "\(Int(Double(snapshot.memoryUsed) / Double(snapshot.memoryTotal) * 100))%"
    }
}

private struct ServiceTile: View {
    let service: ComputeServiceStatus
    let forcedDisabled: Bool

    private var state: ComputeServiceState {
        forcedDisabled ? .disabled : service.state
    }

    private var color: Color {
        switch state {
        case .ready: return ConsolePalette.green
        case .degraded: return ConsolePalette.orange
        case .disabled: return ConsolePalette.muted
        }
    }

    private var stateLabel: String {
        switch state {
        case .ready: return "READY"
        case .degraded: return "DEGRADED"
        case .disabled: return "OFF"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Image(systemName: service.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                Spacer()
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .shadow(color: color.opacity(0.7), radius: state == .disabled ? 0 : 4)
            }
            Text(service.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(stateLabel)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .padding(12)
        .background(ConsolePalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ConsolePalette.border, lineWidth: 1)
        }
        .accessibilityLabel("\(service.name), \(stateLabel), \(service.detail)")
    }
}

private struct MetricCell: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value.formatted())
                .font(.title3.monospacedDigit().weight(.black))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(ConsolePalette.panel)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(color)
                .frame(height: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct DeviceReading: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(ConsolePalette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SparklineCard: View {
    let title: String
    let value: String
    let values: [Double]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption2.monospaced().weight(.heavy))
                    .foregroundStyle(ConsolePalette.muted)
                Spacer()
                Text(value)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(color)
            }
            LineChart(values: values, color: color)
                .frame(height: 42)
        }
        .padding(11)
        .background(.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct RequestLogRow: View {
    let entry: RequestLogEntry

    private var statusColor: Color {
        if entry.status == 0 { return ConsolePalette.orange }
        if (200..<400).contains(entry.status) { return ConsolePalette.green }
        return ConsolePalette.red
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(entry.method)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(ConsolePalette.teal)
                .frame(width: 58, alignment: .leading)
            Text(entry.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 5)
            Text(entry.status == 0 ? "SYS" : "\(entry.status)")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(statusColor)
            Text(String(format: "%.0fms", entry.duration_ms))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(ConsolePalette.muted)
                .frame(width: 49, alignment: .trailing)
            Text(ByteCountFormatter.string(fromByteCount: Int64(entry.size), countStyle: .file))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(ConsolePalette.muted)
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
    }
}

private enum ConsolePalette {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.065)
    static let panel = Color(red: 0.075, green: 0.105, blue: 0.115)
    static let panelRaised = Color(red: 0.10, green: 0.14, blue: 0.15)
    static let border = Color.white.opacity(0.09)
    static let muted = Color(red: 0.50, green: 0.58, blue: 0.59)
    static let teal = Color(red: 0.16, green: 0.83, blue: 0.76)
    static let green = Color(red: 0.40, green: 0.90, blue: 0.49)
    static let orange = Color(red: 1.0, green: 0.66, blue: 0.24)
    static let red = Color(red: 1.0, green: 0.34, blue: 0.30)
}

#Preview {
    ContentView(serverManager: VaporServerManager())
}

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var fullVersion: String {
        "\(appVersion) (\(buildNumber))"
    }
}
