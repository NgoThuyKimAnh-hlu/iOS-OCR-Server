//
//  ServiceStatusMonitor.swift
//  OcrServer
//

import Combine
import Foundation

enum ComputeServiceState: Equatable, Sendable {
    case ready
    case degraded
    case disabled
}

struct ComputeServiceStatus: Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String
    let state: ComputeServiceState
    let detail: String
}

@MainActor
final class ServiceStatusMonitor: ObservableObject {
    @Published private(set) var services: [ComputeServiceStatus] = []

    func refresh() async {
        let speechReady = await SpeechService.shared.isAvailable(locale: "vi-VN")
        let embeddingReady = await EmbeddingService.shared.isVietnameseAvailable()
        let coreMLReady = await CoreMLService.shared.isAvailable()
        let translationReady = TranslationService.shared.isReady
        let synthReady = SynthService.shared.isVoiceAvailable(language: "vi-VN")

        let llmReady: Bool
        if #available(iOS 26.0, *) {
            llmReady = await LLMService.shared.isAvailable()
        } else {
            llmReady = false
        }

        let docOCRReady: Bool
        if #available(iOS 26.0, *) {
            docOCRReady = true
        } else {
            docOCRReady = false
        }

        services = [
            ComputeServiceStatus(
                id: "ocr",
                name: "OCR",
                icon: "text.viewfinder",
                state: .ready,
                detail: "Vision text recognition"
            ),
            ComputeServiceStatus(
                id: "dococr",
                name: "docOCR",
                icon: "doc.text.viewfinder",
                state: docOCRReady ? .ready : .degraded,
                detail: docOCRReady ? "Ready" : "Requires iOS 26"
            ),
            ComputeServiceStatus(
                id: "translate",
                name: "Translate",
                icon: "character.book.closed",
                state: translationReady ? .ready : .degraded,
                detail: translationReady ? "Translation host ready" : "Host unavailable"
            ),
            ComputeServiceStatus(
                id: "stt",
                name: "STT",
                icon: "waveform.badge.mic",
                state: speechReady ? .ready : .degraded,
                detail: speechReady ? "vi-VN on-device" : "Recognizer or permission unavailable"
            ),
            ComputeServiceStatus(
                id: "tts",
                name: "TTS",
                icon: "speaker.wave.2",
                state: synthReady ? .ready : .degraded,
                detail: synthReady ? "vi-VN voice installed" : "vi-VN voice unavailable"
            ),
            ComputeServiceStatus(
                id: "llm",
                name: "LLM",
                icon: "apple.intelligence",
                state: llmReady ? .ready : .degraded,
                detail: llmReady ? "Foundation Models ready" : "OS, device, or model unavailable"
            ),
            ComputeServiceStatus(
                id: "ner",
                name: "NER",
                icon: "person.text.rectangle",
                state: .ready,
                detail: "Natural Language + legal patterns"
            ),
            ComputeServiceStatus(
                id: "embed",
                name: "Embed",
                icon: "point.3.connected.trianglepath.dotted",
                state: embeddingReady ? .ready : .degraded,
                detail: embeddingReady ? "Vietnamese embedding installed" : "Returns 501 without vi embedding"
            ),
            ComputeServiceStatus(
                id: "coreml",
                name: "CoreML",
                icon: "cpu",
                state: coreMLReady ? .ready : .degraded,
                detail: coreMLReady ? "Model storage ready" : "Model storage unavailable"
            )
        ]
    }
}
