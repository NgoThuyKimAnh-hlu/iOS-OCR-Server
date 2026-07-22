//
//  SpeechService.swift
//  OcrServer
//

import Foundation
import Speech

struct SpeechOutput: Sendable {
    let text: String
    let locale: String
}

enum SpeechServiceError: LocalizedError {
    case authorizationDenied
    case recognizerUnavailable(String)
    case onDeviceRecognitionUnavailable(String)
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Speech recognition permission was not granted"
        case .recognizerUnavailable(let locale):
            return "Speech recognizer is unavailable for locale \(locale)"
        case .onDeviceRecognitionUnavailable(let locale):
            return "On-device speech recognition is unavailable for locale \(locale)"
        case .recognitionFailed:
            return "Speech recognition did not return a final result"
        }
    }
}

actor SpeechService {
    static let shared = SpeechService()

    func transcribe(data: Data, fileExtension: String, locale: String) async throws -> SpeechOutput {
        let authorization = await requestAuthorization()
        guard authorization == .authorized else {
            throw SpeechServiceError.authorizationDenied
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) else {
            throw SpeechServiceError.recognizerUnavailable(locale)
        }
        guard recognizer.isAvailable else {
            throw SpeechServiceError.recognizerUnavailable(locale)
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw SpeechServiceError.onDeviceRecognitionUnavailable(locale)
        }

        let requestedExtension = fileExtension.lowercased()
        let supportedExtensions = ["m4a", "wav", "mp3", "caf"]
        let normalizedExtension = supportedExtensions.contains(requestedExtension)
            ? requestedExtension
            : "m4a"
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(normalizedExtension)
        try data.write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        let text = try await recognize(using: recognizer, request: request)
        return SpeechOutput(text: text, locale: locale)
    }

    private func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        guard currentStatus == .notDetermined else { return currentStatus }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func recognize(
        using recognizer: SFSpeechRecognizer,
        request: SFSpeechURLRecognitionRequest
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let state = SpeechRecognitionState(continuation: continuation)
            let task = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    state.finish(.failure(error))
                    return
                }

                guard let result, result.isFinal else { return }
                state.finish(.success(result.bestTranscription.formattedString))
            }
            state.setTask(task)

            Task {
                try? await Task.sleep(nanoseconds: 120_000_000_000)
                state.finish(.failure(SpeechServiceError.recognitionFailed))
            }
        }
    }
}

private final class SpeechRecognitionState: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private let continuation: CheckedContinuation<String, Error>
    private var task: SFSpeechRecognitionTask?

    init(continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
    }

    func setTask(_ task: SFSpeechRecognitionTask) {
        lock.lock()
        if completed {
            lock.unlock()
            task.cancel()
            return
        }
        self.task = task
        lock.unlock()
    }

    func finish(_ result: Result<String, Error>) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        let task = task
        self.task = nil
        lock.unlock()

        task?.cancel()
        continuation.resume(with: result)
    }
}
