//
//  SynthService.swift
//  OcrServer
//

import AVFoundation
import Foundation

enum SynthServiceError: LocalizedError {
    case emptyText
    case voiceUnavailable(String)
    case invalidAudioBuffer
    case noAudioGenerated

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "'text' must not be empty"
        case .voiceUnavailable(let language):
            return "No speech synthesis voice is available for \(language)"
        case .invalidAudioBuffer:
            return "Speech synthesizer returned an unsupported audio buffer"
        case .noAudioGenerated:
            return "Speech synthesizer did not generate audio"
        }
    }
}

@MainActor
final class SynthService {
    static let shared = SynthService()

    private var jobs: [UUID: SynthesisJob] = [:]

    private init() {}

    func isVoiceAvailable(language: String) -> Bool {
        AVSpeechSynthesisVoice(language: language) != nil
    }

    func synthesize(text: String, language: String, rate: Float) async throws -> Data {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw SynthServiceError.emptyText }
        guard let voice = AVSpeechSynthesisVoice(language: language) else {
            throw SynthServiceError.voiceUnavailable(language)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = min(
            AVSpeechUtteranceMaximumSpeechRate,
            max(AVSpeechUtteranceMinimumSpeechRate, rate)
        )

        return try await withCheckedThrowingContinuation { continuation in
            let id = UUID()
            let job = SynthesisJob(id: id, utterance: utterance) { [weak self] result in
                Task { @MainActor in
                    self?.jobs.removeValue(forKey: id)
                    continuation.resume(with: result)
                }
            }
            jobs[id] = job
            job.start()
        }
    }
}

private final class SynthesisJob {
    private let utterance: AVSpeechUtterance
    private let synthesizer = AVSpeechSynthesizer()
    private let completion: (Result<Data, Error>) -> Void
    private let outputURL: URL
    private let lock = NSLock()
    private var audioFile: AVAudioFile?
    private var completed = false
    private var wroteAudio = false

    init(
        id: UUID,
        utterance: AVSpeechUtterance,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        self.utterance = utterance
        self.completion = completion
        self.outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(id.uuidString)
            .appendingPathExtension("caf")
    }

    func start() {
        synthesizer.write(utterance) { [weak self] buffer in
            self?.consume(buffer)
        }
    }

    private func consume(_ buffer: AVAudioBuffer) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }

        guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
            finishLocked(.failure(SynthServiceError.invalidAudioBuffer))
            return
        }

        if pcmBuffer.frameLength == 0 {
            guard wroteAudio else {
                finishLocked(.failure(SynthServiceError.noAudioGenerated))
                return
            }

            audioFile = nil
            completed = true
            lock.unlock()

            let result: Result<Data, Error> = Result { try Data(contentsOf: outputURL) }
            try? FileManager.default.removeItem(at: outputURL)
            completion(result)
            return
        }

        do {
            if audioFile == nil {
                audioFile = try AVAudioFile(
                    forWriting: outputURL,
                    settings: pcmBuffer.format.settings
                )
            }
            try audioFile?.write(from: pcmBuffer)
            wroteAudio = true
            lock.unlock()
        } catch {
            finishLocked(.failure(error))
        }
    }

    private func finishLocked(_ result: Result<Data, Error>) {
        completed = true
        audioFile = nil
        lock.unlock()
        try? FileManager.default.removeItem(at: outputURL)
        completion(result)
    }
}
