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

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var silentBuffer: AVAudioPCMBuffer?
    private var isEngineConfigured = false
    private var observers: [NSObjectProtocol] = []

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

    func start() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            try configureEngineIfNeeded()

            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            if !playerNode.isPlaying, let silentBuffer {
                playerNode.scheduleBuffer(silentBuffer, at: nil, options: .loops)
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
            channel.initialize(repeating: 0, count: Int(buffer.frameLength))
        }

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        playerNode.volume = 0
        silentBuffer = buffer
        isEngineConfigured = true
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
        "Unable to create the silent keep-alive audio buffer"
    }
}
