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

    var engineRunning: Bool { audioEngine.isRunning }
    var playerPlaying: Bool { playerNode.isPlaying }

    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var keepAliveBuffer: AVAudioPCMBuffer?
    private var isEngineConfigured = false
    private var observers: [NSObjectProtocol] = []
    private var watchdogTimer: Timer?
    private var recoveryTask: Task<Void, Never>?
    private var interruptionActive = false
    private var watchdogResumeAllowed = true

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
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleMediaServicesReset()
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    self?.handleRouteChange(notification)
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
        watchdogResumeAllowed = true
        startWithRetry(reason: "start")
    }

    func stop() {
        stopWatchdog()
        recoveryTask?.cancel()
        recoveryTask = nil
        interruptionActive = false
        watchdogResumeAllowed = true
        playerNode.stop()
        audioEngine.pause()
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
        isActive = false
    }

    private func startWithRetry(reason: String) {
        recoveryTask?.cancel()
        recoveryTask = nil
        guard Settings.shared.keepAliveEnabled,
              !interruptionActive,
              watchdogResumeAllowed else { return }

        do {
            try startAudio()
            return
        } catch {
            recordStartFailure(error, reason: reason)
        }

        recoveryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for delay in [500_000_000, 1_000_000_000, 2_000_000_000] as [UInt64] {
                do {
                    try await Task.sleep(nanoseconds: delay)
                } catch {
                    return
                }
                guard Settings.shared.keepAliveEnabled,
                      !self.interruptionActive,
                      self.watchdogResumeAllowed else { return }
                do {
                    try self.startAudio()
                    self.recoveryTask = nil
                    return
                } catch {
                    self.recordStartFailure(error, reason: reason)
                }
            }
            self.recoveryTask = nil
        }
    }

    private func startAudio() throws {
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

        guard audioEngine.isRunning, playerNode.isPlaying else {
            throw KeepAliveError.audioGraphDidNotStart
        }
        lastError = nil
        isActive = true
    }

    private func recordStartFailure(_ error: Error, reason: String) {
        lastError = "\(reason): \(error.localizedDescription)"
        isActive = false
        ServerTelemetry.shared.recordSystemEvent(
            method: "KEEPALIVE",
            path: "/audio/\(reason)",
            status: 500
        )
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
        guard !interruptionActive, watchdogResumeAllowed else { return }
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
        startWithRetry(reason: "watchdog")
    }

    private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

        switch type {
        case .began:
            interruptionActive = true
            recoveryTask?.cancel()
            recoveryTask = nil
            isActive = false
        case .ended:
            interruptionActive = false
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey]
                as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            watchdogResumeAllowed = options.contains(.shouldResume)
            guard Settings.shared.keepAliveEnabled, watchdogResumeAllowed else { return }
            startWithRetry(reason: "interruption-ended")
        @unknown default:
            return
        }
    }

    private func handleMediaServicesReset() {
        let shouldRestart = Settings.shared.keepAliveEnabled
        resetAudioGraph()
        interruptionActive = false
        watchdogResumeAllowed = true
        guard shouldRestart else { return }
        ServerTelemetry.shared.recordSystemEvent(
            method: "KEEPALIVE",
            path: "/audio/media-services-reset",
            status: 0
        )
        startWithRetry(reason: "media-services-reset")
    }

    private func handleRouteChange(_ notification: Notification) {
        guard Settings.shared.keepAliveEnabled else { return }
        let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey]
            as? UInt ?? 0
        ServerTelemetry.shared.recordSystemEvent(
            method: "KEEPALIVE",
            path: "/audio/route-change/\(rawReason)",
            status: 0
        )
        watchdogResumeAllowed = true
        startWithRetry(reason: "route-change")
    }

    private func resetAudioGraph() {
        recoveryTask?.cancel()
        recoveryTask = nil
        playerNode.stop()
        audioEngine.stop()
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        keepAliveBuffer = nil
        isEngineConfigured = false
        isActive = false
    }

    private func resumeIfEnabled() {
        guard Settings.shared.keepAliveEnabled else { return }
        start()
    }
}

private enum KeepAliveError: LocalizedError {
    case audioBufferUnavailable
    case audioGraphDidNotStart

    var errorDescription: String? {
        switch self {
        case .audioBufferUnavailable:
            return "Unable to create the keep-alive audio buffer"
        case .audioGraphDidNotStart:
            return "The keep-alive audio graph did not start"
        }
    }
}
