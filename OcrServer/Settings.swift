//
//  Settings.swift
//  OcrServer
//

import Foundation
import Vision

struct OCRVisionConfiguration: Sendable {
    let recognitionLevel: RecognizeTextRequest.RecognitionLevel
    let recognitionLanguages: [String]
    let usesLanguageCorrection: Bool
    let automaticallyDetectsLanguage: Bool
    let minimumTextHeight: Double
    let visionRevision: Int
}

struct OCRRuntimeSettingsSnapshot: Sendable {
    let recognitionLevel: String
    let recognitionLanguages: [String]
    let usesLanguageCorrection: Bool
    let automaticallyDetectsLanguage: Bool
    let minimumTextHeight: Double
    let visionRevision: Int
    let confidenceThreshold: Double
    let multipassEnabled: Bool
    let roiUpscale: Double
    let maximumROIs: Int
    let correctorGroups: Set<CorrectorGroup>
    let activePack: String
    let improveEnabled: Bool
    let debugVerbose: Bool
    let pageScorePass2Threshold: Double
    let pass2FallbackRatio: Double
    let legalIDRegex: String
    let possibleLegalIDRegex: String
    let candidateGapThreshold: Double
    let candidateGapConfidenceThreshold: Double
    let candidateGapNormalizer: Double
    let lineConfidenceWeight: Double
    let missingPageNumberMinimumPages: Int
    let brokenTableMinimumLines: Int
    let lowConfidencePenalty: Double
    let invalidLegalIDPenalty: Double
    let missingPageNumberPenalty: Double
    let brokenTablePenalty: Double
    let multipassMinimumConfidenceGain: Double
    let multipassLegalIDTolerance: Double
    let multipassMinimumLengthRatio: Double
    let multipassMaximumLengthRatio: Double
    let pdfDPI: Int
    let hotDPI: Int
    let pdfMaximumPages: Int
    let rectifyDefault: Bool

    var visionConfiguration: OCRVisionConfiguration {
        OCRVisionConfiguration(
            recognitionLevel: recognitionLevel.lowercased() == "fast" ? .fast : .accurate,
            recognitionLanguages: recognitionLanguages,
            usesLanguageCorrection: usesLanguageCorrection,
            automaticallyDetectsLanguage: automaticallyDetectsLanguage,
            minimumTextHeight: minimumTextHeight,
            visionRevision: visionRevision
        )
    }

    var improvementConfiguration: OCRImprovementConfiguration {
        OCRImprovementConfiguration(
            confidenceThreshold: confidenceThreshold,
            multipassEnabled: multipassEnabled,
            roiUpscale: roiUpscale,
            maximumROIs: maximumROIs,
            correctorGroups: correctorGroups,
            pageScorePass2Threshold: pageScorePass2Threshold,
            pass2FallbackRatio: pass2FallbackRatio,
            legalIDRegex: legalIDRegex,
            possibleLegalIDRegex: possibleLegalIDRegex,
            candidateGapThreshold: candidateGapThreshold,
            candidateGapConfidenceThreshold: candidateGapConfidenceThreshold,
            candidateGapNormalizer: candidateGapNormalizer,
            lineConfidenceWeight: lineConfidenceWeight,
            missingPageNumberMinimumPages: missingPageNumberMinimumPages,
            brokenTableMinimumLines: brokenTableMinimumLines,
            lowConfidencePenalty: lowConfidencePenalty,
            invalidLegalIDPenalty: invalidLegalIDPenalty,
            missingPageNumberPenalty: missingPageNumberPenalty,
            brokenTablePenalty: brokenTablePenalty,
            multipassMinimumConfidenceGain: multipassMinimumConfidenceGain,
            multipassLegalIDTolerance: multipassLegalIDTolerance,
            multipassMinimumLengthRatio: multipassMinimumLengthRatio,
            multipassMaximumLengthRatio: multipassMaximumLengthRatio
        )
    }

    func applying(
        recognitionLevel: String? = nil,
        recognitionLanguages: [String]? = nil,
        multipassEnabled: Bool? = nil,
        confidenceThreshold: Double? = nil,
        roiUpscale: Double? = nil,
        correctorGroups: Set<CorrectorGroup>? = nil,
        activePack: String? = nil
    ) -> OCRRuntimeSettingsSnapshot {
        OCRRuntimeSettingsSnapshot(
            recognitionLevel: recognitionLevel ?? self.recognitionLevel,
            recognitionLanguages: recognitionLanguages ?? self.recognitionLanguages,
            usesLanguageCorrection: usesLanguageCorrection,
            automaticallyDetectsLanguage: automaticallyDetectsLanguage,
            minimumTextHeight: minimumTextHeight,
            visionRevision: visionRevision,
            confidenceThreshold: confidenceThreshold ?? self.confidenceThreshold,
            multipassEnabled: multipassEnabled ?? self.multipassEnabled,
            roiUpscale: roiUpscale ?? self.roiUpscale,
            maximumROIs: maximumROIs,
            correctorGroups: correctorGroups ?? self.correctorGroups,
            activePack: activePack ?? self.activePack,
            improveEnabled: improveEnabled,
            debugVerbose: debugVerbose,
            pageScorePass2Threshold: pageScorePass2Threshold,
            pass2FallbackRatio: pass2FallbackRatio,
            legalIDRegex: legalIDRegex,
            possibleLegalIDRegex: possibleLegalIDRegex,
            candidateGapThreshold: candidateGapThreshold,
            candidateGapConfidenceThreshold: candidateGapConfidenceThreshold,
            candidateGapNormalizer: candidateGapNormalizer,
            lineConfidenceWeight: lineConfidenceWeight,
            missingPageNumberMinimumPages: missingPageNumberMinimumPages,
            brokenTableMinimumLines: brokenTableMinimumLines,
            lowConfidencePenalty: lowConfidencePenalty,
            invalidLegalIDPenalty: invalidLegalIDPenalty,
            missingPageNumberPenalty: missingPageNumberPenalty,
            brokenTablePenalty: brokenTablePenalty,
            multipassMinimumConfidenceGain: multipassMinimumConfidenceGain,
            multipassLegalIDTolerance: multipassLegalIDTolerance,
            multipassMinimumLengthRatio: multipassMinimumLengthRatio,
            multipassMaximumLengthRatio: multipassMaximumLengthRatio,
            pdfDPI: pdfDPI,
            hotDPI: hotDPI,
            pdfMaximumPages: pdfMaximumPages,
            rectifyDefault: rectifyDefault
        )
    }
}

final class Settings {
    static let shared = Settings()

    private static let correctorConfigurationVersion = 2
    private static let defaultCorrectorGroups = CorrectorGroup.allCases.map(\.rawValue)
    private let defaults = UserDefaults.standard

    private init() {}

    private func integer(_ key: String, _ initialValue: Int) -> Int {
        return (defaults.object(forKey: key) as? Int) ?? initialValue
    }

    private func double(_ key: String, _ initialValue: Double) -> Double {
        return (defaults.object(forKey: key) as? Double) ?? initialValue
    }

    private func boolean(_ key: String, _ initialValue: Bool) -> Bool {
        return (defaults.object(forKey: key) as? Bool) ?? initialValue
    }

    var httpPort: Int {
        get { integer("httpPort", 8000) }
        set { defaults.set(newValue, forKey: "httpPort") }
    }

    var recognitionLevel: String {
        get { defaults.string(forKey: "recognitionLevel") ?? "accurate" }
        set { defaults.set(newValue.lowercased(), forKey: "recognitionLevel") }
    }

    var recognitionLanguages: [String] {
        get { defaults.stringArray(forKey: "recognitionLanguages") ?? ["vi-VT"] }
        set { defaults.set(newValue, forKey: "recognitionLanguages") }
    }

    var languageCorrection: Bool {
        get { boolean("languageCorrection", true) }
        set { defaults.set(newValue, forKey: "languageCorrection") }
    }

    var automaticallyDetectsLanguage: Bool {
        get { boolean("automaticallyDetectsLanguage", false) }
        set { defaults.set(newValue, forKey: "automaticallyDetectsLanguage") }
    }

    var minimumTextHeight: Double {
        get { double("minimumTextHeight", 0) }
        set { defaults.set(newValue, forKey: "minimumTextHeight") }
    }

    var visionRevision: Int {
        get { integer("visionRevision", 0) }
        set { defaults.set(newValue, forKey: "visionRevision") }
    }

    var keepAliveEnabled: Bool {
        get { boolean("keepAliveEnabled", true) }
        set { defaults.set(newValue, forKey: "keepAliveEnabled") }
    }

    var watchdogIntervalSeconds: Double {
        get { double("watchdogIntervalSeconds", 60) }
        set { defaults.set(newValue, forKey: "watchdogIntervalSeconds") }
    }

    var adminToken: String {
        get { defaults.string(forKey: "adminToken") ?? "" }
        set { defaults.set(newValue, forKey: "adminToken") }
    }

    var thermalGuard: Bool {
        get { boolean("thermalGuard", true) }
        set { defaults.set(newValue, forKey: "thermalGuard") }
    }

    var maximumQueueDepth: Int {
        get { integer("maximumQueueDepth", 8) }
        set { defaults.set(newValue, forKey: "maximumQueueDepth") }
    }

    var maximumOCRInflight: Int {
        get { integer("maximumOCRInflight", 2) }
        set { defaults.set(newValue, forKey: "maximumOCRInflight") }
    }

    var fairGapMilliseconds: Int {
        get { integer("fairGapMilliseconds", 300) }
        set { defaults.set(newValue, forKey: "fairGapMilliseconds") }
    }

    var improveEnabled: Bool {
        get { boolean("improveEnabled", true) }
        set { defaults.set(newValue, forKey: "improveEnabled") }
    }

    var confidenceThreshold: Double {
        get { double("confidenceThreshold", 0.55) }
        set { defaults.set(newValue, forKey: "confidenceThreshold") }
    }

    var multipassEnabled: Bool {
        get { boolean("multipassEnabled", true) }
        set { defaults.set(newValue, forKey: "multipassEnabled") }
    }

    var roiUpscale: Double {
        get { double("roiUpscale", 2) }
        set { defaults.set(newValue, forKey: "roiUpscale") }
    }

    var maximumROIs: Int {
        get { integer("maximumROIs", 4) }
        set { defaults.set(newValue, forKey: "maximumROIs") }
    }

    var correctorGroupNames: [String] {
        get {
            if defaults.integer(forKey: "correctorConfigurationVersion")
                < Self.correctorConfigurationVersion {
                defaults.set(
                    Self.correctorConfigurationVersion,
                    forKey: "correctorConfigurationVersion"
                )
                defaults.set(Self.defaultCorrectorGroups, forKey: "correctorGroupNames")
                return Self.defaultCorrectorGroups
            }
            return defaults.stringArray(forKey: "correctorGroupNames")
                ?? Self.defaultCorrectorGroups
        }
        set { defaults.set(newValue, forKey: "correctorGroupNames") }
    }

    var activePack: String {
        get { defaults.string(forKey: "activePack") ?? "auto" }
        set { defaults.set(newValue.lowercased(), forKey: "activePack") }
    }

    var debugVerbose: Bool {
        get { boolean("debugVerbose", true) }
        set { defaults.set(newValue, forKey: "debugVerbose") }
    }

    var pageScorePass2Threshold: Double {
        get { double("pageScorePass2Threshold", 0.70) }
        set { defaults.set(newValue, forKey: "pageScorePass2Threshold") }
    }

    var pass2FallbackRatio: Double {
        get { double("pass2FallbackRatio", 0.40) }
        set { defaults.set(newValue, forKey: "pass2FallbackRatio") }
    }

    var legalIDRegex: String {
        get {
            defaults.string(forKey: "legalIDRegex")
                ?? "\\b\\d{1,4}/\\d{4}/[A-ZĐ][A-ZĐ0-9-]*\\b"
        }
        set { defaults.set(newValue, forKey: "legalIDRegex") }
    }

    var possibleLegalIDRegex: String {
        get {
            defaults.string(forKey: "possibleLegalIDRegex")
                ?? "\\b[0-9OIl]{1,4}\\s*[/|]\\s*[0-9OIl]{2,4}\\s*[/|]\\s*[A-ZĐ0-9][A-ZĐ0-9 -]{1,20}"
        }
        set { defaults.set(newValue, forKey: "possibleLegalIDRegex") }
    }

    var candidateGapThreshold: Double {
        get { double("candidateGapThreshold", 0.015) }
        set { defaults.set(newValue, forKey: "candidateGapThreshold") }
    }

    var candidateGapConfidenceThreshold: Double {
        get { double("candidateGapConfidenceThreshold", 0.80) }
        set { defaults.set(newValue, forKey: "candidateGapConfidenceThreshold") }
    }

    var candidateGapNormalizer: Double {
        get { double("candidateGapNormalizer", 0.20) }
        set { defaults.set(newValue, forKey: "candidateGapNormalizer") }
    }

    var lineConfidenceWeight: Double {
        get { double("lineConfidenceWeight", 0.82) }
        set { defaults.set(newValue, forKey: "lineConfidenceWeight") }
    }

    var missingPageNumberMinimumPages: Int {
        get { integer("missingPageNumberMinimumPages", 2) }
        set { defaults.set(newValue, forKey: "missingPageNumberMinimumPages") }
    }

    var brokenTableMinimumLines: Int {
        get { integer("brokenTableMinimumLines", 2) }
        set { defaults.set(newValue, forKey: "brokenTableMinimumLines") }
    }

    var lowConfidencePenalty: Double {
        get { double("lowConfidencePenalty", 0.09) }
        set { defaults.set(newValue, forKey: "lowConfidencePenalty") }
    }

    var invalidLegalIDPenalty: Double {
        get { double("invalidLegalIDPenalty", 0.14) }
        set { defaults.set(newValue, forKey: "invalidLegalIDPenalty") }
    }

    var missingPageNumberPenalty: Double {
        get { double("missingPageNumberPenalty", 0.09) }
        set { defaults.set(newValue, forKey: "missingPageNumberPenalty") }
    }

    var brokenTablePenalty: Double {
        get { double("brokenTablePenalty", 0.14) }
        set { defaults.set(newValue, forKey: "brokenTablePenalty") }
    }

    var multipassMinimumConfidenceGain: Double {
        get { double("multipassMinimumConfidenceGain", 0.02) }
        set { defaults.set(newValue, forKey: "multipassMinimumConfidenceGain") }
    }

    var multipassLegalIDTolerance: Double {
        get { double("multipassLegalIDTolerance", 0.05) }
        set { defaults.set(newValue, forKey: "multipassLegalIDTolerance") }
    }

    var multipassMinimumLengthRatio: Double {
        get { double("multipassMinimumLengthRatio", 0.60) }
        set { defaults.set(newValue, forKey: "multipassMinimumLengthRatio") }
    }

    var multipassMaximumLengthRatio: Double {
        get { double("multipassMaximumLengthRatio", 1.60) }
        set { defaults.set(newValue, forKey: "multipassMaximumLengthRatio") }
    }

    var pdfDPI: Int {
        get { integer("pdfDPI", 150) }
        set { defaults.set(newValue, forKey: "pdfDPI") }
    }

    var hotDPI: Int {
        get { integer("hotDPI", 120) }
        set { defaults.set(newValue, forKey: "hotDPI") }
    }

    var pdfMaximumPages: Int {
        get { integer("pdfMaximumPages", 50) }
        set { defaults.set(newValue, forKey: "pdfMaximumPages") }
    }

    var rectifyDefault: Bool {
        get { boolean("rectifyDefault", false) }
        set { defaults.set(newValue, forKey: "rectifyDefault") }
    }

    func serviceEnabled(_ service: ComputeServiceName) -> Bool {
        boolean("service.\(service.rawValue)", true)
    }

    func setService(_ service: ComputeServiceName, enabled: Bool) {
        defaults.set(enabled, forKey: "service.\(service.rawValue)")
    }

    func serviceStates() -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: ComputeServiceName.allCases.map {
            ($0.rawValue, serviceEnabled($0))
        })
    }

    func ocrRuntimeSnapshot() -> OCRRuntimeSettingsSnapshot {
        OCRRuntimeSettingsSnapshot(
            recognitionLevel: recognitionLevel.lowercased(),
            recognitionLanguages: recognitionLanguages,
            usesLanguageCorrection: languageCorrection,
            automaticallyDetectsLanguage: automaticallyDetectsLanguage,
            minimumTextHeight: minimumTextHeight,
            visionRevision: visionRevision,
            confidenceThreshold: confidenceThreshold,
            multipassEnabled: multipassEnabled,
            roiUpscale: roiUpscale,
            maximumROIs: maximumROIs,
            correctorGroups: Set(correctorGroupNames.compactMap(CorrectorGroup.init(rawValue:))),
            activePack: activePack,
            improveEnabled: improveEnabled,
            debugVerbose: debugVerbose,
            pageScorePass2Threshold: pageScorePass2Threshold,
            pass2FallbackRatio: pass2FallbackRatio,
            legalIDRegex: legalIDRegex,
            possibleLegalIDRegex: possibleLegalIDRegex,
            candidateGapThreshold: candidateGapThreshold,
            candidateGapConfidenceThreshold: candidateGapConfidenceThreshold,
            candidateGapNormalizer: candidateGapNormalizer,
            lineConfidenceWeight: lineConfidenceWeight,
            missingPageNumberMinimumPages: missingPageNumberMinimumPages,
            brokenTableMinimumLines: brokenTableMinimumLines,
            lowConfidencePenalty: lowConfidencePenalty,
            invalidLegalIDPenalty: invalidLegalIDPenalty,
            missingPageNumberPenalty: missingPageNumberPenalty,
            brokenTablePenalty: brokenTablePenalty,
            multipassMinimumConfidenceGain: multipassMinimumConfidenceGain,
            multipassLegalIDTolerance: multipassLegalIDTolerance,
            multipassMinimumLengthRatio: multipassMinimumLengthRatio,
            multipassMaximumLengthRatio: multipassMaximumLengthRatio,
            pdfDPI: pdfDPI,
            hotDPI: hotDPI,
            pdfMaximumPages: pdfMaximumPages,
            rectifyDefault: rectifyDefault
        )
    }
}
