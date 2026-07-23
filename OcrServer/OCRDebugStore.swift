//
//  OCRDebugStore.swift
//  OcrServer
//

import Foundation
import Vapor

struct OCRDebugVisionCandidate: Content, Sendable {
    let text: String
    let confidence: Double
}

struct OCRDebugVisionObservation: Content, Sendable {
    let line: Int
    let candidates: [OCRDebugVisionCandidate]
    let top1_top2_gap: Double
    let bbox: OCRNormalizedBoxResponse
}

struct OCRDebugQualityEnvelope: Content, Sendable {
    let mean_confidence: Double
    let page_score: Double
    let line_scores: [OCRLineScoreResponse]
    let flags: [String]
    let needs_pass2: Bool
}

struct OCRDebugTiming: Content, Sendable {
    let vision_ms: Double
    let multipass_ms: Double
    let correct_ms: Double
    let total_ms: Double
}

struct OCRDebugDeviceSnapshot: Content, Sendable {
    let thermal: String
    let thermal_throttling: Bool
    let mem_free_mb: Int
    let battery: ServerBatteryStatus
}

struct OCRDebugConfigSnapshot: Content, Sendable {
    let pack_id: String
    let pack_version: String
    let pack_hash: String
    let customwords_count: Int
    let confidence_threshold: Double
    let recognition_languages: [String]
    let recognition_level: String
    let language_correction: Bool
    let automatically_detects_language: Bool
    let minimum_text_height: Double
    let vision_revision: Int
    let multipass: Bool
    let roi_upscale: Double
    let page_score_pass2_threshold: Double
    let legal_id_regex: String
    let corrector_groups: [String]
    let active_pack: String
    let improve: Bool
    let debug_verbose: Bool
}

struct OCRDebugTraceResponse: Content, Sendable {
    let id: UUID
    let timestamp: Date
    let endpoint: String
    let build_version: String
    let raw: String
    let improved: String
    let corrections_applied: Int
    let vision: [OCRDebugVisionObservation]
    let corrector_trace: [OCRCorrectionTraceItem]
    let quality: OCRDebugQualityEnvelope
    let timing: OCRDebugTiming
    let device: OCRDebugDeviceSnapshot
    let config_snapshot: OCRDebugConfigSnapshot
}

struct OCRDebugLastResponse: Content, Sendable {
    let traces: [OCRDebugTraceResponse]
    let request_logs: [RequestLogEntry]
}

actor OCRDebugStore {
    static let shared = OCRDebugStore()

    private let maximumTraceCount = 30
    private var traces: [OCRDebugTraceResponse] = []

    private init() {}

    func append(_ trace: OCRDebugTraceResponse) {
        traces.append(trace)
        if traces.count > maximumTraceCount {
            traces.removeFirst(traces.count - maximumTraceCount)
        }
    }

    func recent(limit: Int) -> [OCRDebugTraceResponse] {
        Array(
            Array(traces.suffix(min(max(0, limit), maximumTraceCount))).reversed()
        )
    }
}

enum OCRDebugTraceFactory {
    static func make(
        endpoint: String,
        result: OCRImprovementResult,
        runtime: OCRRuntimeSettingsSnapshot,
        improve: Bool,
        recognitionLevel: String,
        usesLanguageCorrection: Bool,
        automaticallyDetectsLanguage: Bool
    ) async -> OCRDebugTraceResponse {
        let device = await MainActor.run {
            ServerTelemetry.shared.debugDeviceSnapshot()
        }
        let vision = result.rawVisionLines.enumerated().map { index, line in
            OCRDebugVisionObservation(
                line: index + 1,
                candidates: line.candidates.prefix(3).map {
                    OCRDebugVisionCandidate(text: $0.text, confidence: $0.confidence)
                },
                top1_top2_gap: line.candidateGap,
                bbox: OCRNormalizedBoxResponse(
                    x: line.normalizedBox.x,
                    y: line.normalizedBox.y,
                    width: line.normalizedBox.width,
                    height: line.normalizedBox.height
                )
            )
        }
        return OCRDebugTraceResponse(
            id: UUID(),
            timestamp: Date(),
            endpoint: endpoint,
            build_version: BuildInfo.versionStamp,
            raw: result.raw,
            improved: result.improved,
            corrections_applied: result.correctionsApplied,
            vision: vision,
            corrector_trace: result.correctionTrace,
            quality: OCRDebugQualityEnvelope(
                mean_confidence: result.meanConfidence,
                page_score: result.pageScore,
                line_scores: result.lineScores,
                flags: result.flags,
                needs_pass2: result.needsPass2
            ),
            timing: OCRDebugTiming(
                vision_ms: result.visionMilliseconds,
                multipass_ms: result.multipassMilliseconds,
                correct_ms: result.correctMilliseconds,
                total_ms: result.totalMilliseconds
            ),
            device: device,
            config_snapshot: OCRDebugConfigSnapshot(
                pack_id: result.pack.id,
                pack_version: result.pack.version,
                pack_hash: result.pack.hash,
                customwords_count: result.customWordsCount,
                confidence_threshold: runtime.confidenceThreshold,
                recognition_languages: runtime.recognitionLanguages,
                recognition_level: recognitionLevel,
                language_correction: usesLanguageCorrection,
                automatically_detects_language: automaticallyDetectsLanguage,
                minimum_text_height: runtime.minimumTextHeight,
                vision_revision: runtime.visionRevision,
                multipass: runtime.multipassEnabled,
                roi_upscale: runtime.roiUpscale,
                page_score_pass2_threshold: runtime.pageScorePass2Threshold,
                legal_id_regex: runtime.legalIDRegex,
                corrector_groups: runtime.correctorGroups.map(\.rawValue).sorted(),
                active_pack: runtime.activePack,
                improve: improve,
                debug_verbose: runtime.debugVerbose
            )
        )
    }
}
