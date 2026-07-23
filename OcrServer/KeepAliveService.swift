//
//  KeepAliveService.swift
//  OcrServer
//

import AVFoundation
import Combine
import UIKit

@MainActor
final class KeepAliveService: ObservableObject {
    static let shared = KeepAliveService()

    @Published private(set) var isActive = false
    @Published private(set) var lastError: String?
    @Published private(set) var reheals = 0

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var keepAliveBuffer: AVAudioPCMBuffer?
    private var isEngineConfigured = false
    private var observers: [NSObjectProtocol] = []
    private var watchdogTimer: Timer?

    private init() {
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    self?.handleInterruption(notification)
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.resumeIfEnabled()
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.resumeIfEnabled()
                }
            }
        )
    }

    func setEnabled(_ enabled: Bool) {
        Settings.shared.keepAliveEnabled = enabled
        enabled ? start() : stop()
    }

    func setOwnSession(_ ownSession: Bool) {
        let changed = Settings.shared.keepAliveOwnSession != ownSession
        Settings.shared.keepAliveOwnSession = ownSession
        guard changed else { return }

        if !ownSession {
            ServerTelemetry.shared.recordSystemEvent(
                method: "KEEPALIVE",
                path: "/audio/mixed-session/less-reliable",
                status: 0
            )
        }
        if Settings.shared.keepAliveEnabled {
            start()
        }
    }

    func start() {
        startWatchdogIfNeeded()
        do {
            let session = AVAudioSession.sharedInstance()
            let options: AVAudioSession.CategoryOptions = Settings.shared.keepAliveOwnSession
                ? []
                : [.mixWithOthers]
            try session.setCategory(.playback, mode: .default, options: options)
            try session.setActive(true)
            try configureEngineIfNeeded()

            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            if !playerNode.isPlaying, let keepAliveBuffer {
                playerNode.scheduleBuffer(keepAliveBuffer, at: nil, options: .loops)
                playerNode.play()
            }

            lastError = nil
            isActive = audioEngine.isRunning && playerNode.isPlaying
        } catch {
            lastError = error.localizedDescription
            isActive = false
            ServerTelemetry.shared.recordSystemEvent(
                method: "KEEPALIVE",
                path: "/audio/start",
                status: 500
            )
        }
    }

    func stop() {
        stopWatchdog()
        playerNode.stop()
        audioEngine.pause()
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
        isActive = false
    }

    private func configureEngineIfNeeded() throws {
        guard !isEngineConfigured else { return }
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: 44_100,
            channels: 1
        ), let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: 44_100
        ) else {
            throw KeepAliveError.audioBufferUnavailable
        }

        buffer.frameLength = buffer.frameCapacity
        if let channel = buffer.floatChannelData?[0] {
            let amplitude: Float = 0.0001
            let samplesPerCycle = max(1, Int(format.sampleRate / 20))
            for frame in 0..<Int(buffer.frameLength) {
                let phase = Float(frame % samplesPerCycle) / Float(samplesPerCycle)
                let triangle = 1 - (4 * abs(phase - 0.5))
                channel[frame] = amplitude * triangle
            }
        }

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        playerNode.volume = 0.001
        keepAliveBuffer = buffer
        isEngineConfigured = true
    }

    private func startWatchdogIfNeeded() {
        guard watchdogTimer == nil else { return }
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.healIfNeeded()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdogTimer = timer
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func healIfNeeded() {
        guard Settings.shared.keepAliveEnabled else {
            stopWatchdog()
            return
        }
        guard !audioEngine.isRunning || !playerNode.isPlaying else {
            isActive = true
            return
        }

        reheals += 1
        isActive = false
        ServerTelemetry.shared.recordSystemEvent(
            method: "KEEPALIVE",
            path: "/audio/reheal",
            status: 0
        )
        start()
    }

    private func handleInterruption(_ notification: Notification) {
        guard Settings.shared.keepAliveEnabled,
              let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType),
              type == .ended else {
            if let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
               AVAudioSession.InterruptionType(rawValue: rawType) == .began {
                isActive = false
            }
            return
        }

        start()
    }

    private func resumeIfEnabled() {
        guard Settings.shared.keepAliveEnabled else { return }
        start()
    }
}

private enum KeepAliveError: LocalizedError {
    case audioBufferUnavailable

    var errorDescription: String? {
        "Unable to create the keep-alive audio buffer"
    }
}
