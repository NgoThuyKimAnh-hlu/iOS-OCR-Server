//
//  OCRImprovementService.swift
//  OcrServer
//

import Foundation
import Vapor
import Vision

struct OCRDomainMetadata: Sendable {
    let documentType: String?
    let agency: String?
    let year: String?
    let requestedPack: String?
}

struct OCRNormalizedBoxResponse: Content, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct OCRLineScoreResponse: Content, Sendable {
    let line: Int
    let confidence: Double
    let candidate_gap: Double
    let score: Double
    let bbox: OCRNormalizedBoxResponse
}

struct DomainPackSelection: Sendable {
    let id: String
    let version: String
    let hash: String
    let words: [String]
    let overrides: [String: String]
}

struct OCRImprovementConfiguration: Sendable {
    let confidenceThreshold: Double
    let multipassEnabled: Bool
    let roiUpscale: Double
    let maximumROIs: Int
    let correctorGroups: Set<CorrectorGroup>
    let pageScorePass2Threshold: Double
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

    static let `default` = OCRImprovementConfiguration(
        confidenceThreshold: 0.55,
        multipassEnabled: true,
        roiUpscale: 2,
        maximumROIs: 4,
        correctorGroups: Set(CorrectorGroup.allCases),
        pageScorePass2Threshold: 0.70,
        legalIDRegex: "\\b\\d{1,4}/\\d{4}/[A-ZĐ][A-ZĐ0-9-]*\\b",
        possibleLegalIDRegex: "\\b[0-9OIl]{1,4}\\s*[/|]\\s*[0-9OIl]{2,4}\\s*[/|]\\s*[A-ZĐ0-9][A-ZĐ0-9 -]{1,20}",
        candidateGapThreshold: 0.015,
        candidateGapConfidenceThreshold: 0.80,
        candidateGapNormalizer: 0.20,
        lineConfidenceWeight: 0.82,
        missingPageNumberMinimumPages: 2,
        brokenTableMinimumLines: 2,
        lowConfidencePenalty: 0.09,
        invalidLegalIDPenalty: 0.14,
        missingPageNumberPenalty: 0.09,
        brokenTablePenalty: 0.14,
        multipassMinimumConfidenceGain: 0.02,
        multipassLegalIDTolerance: 0.05,
        multipassMinimumLengthRatio: 0.60,
        multipassMaximumLengthRatio: 1.60
    )
}

struct OCRImprovementResult: Sendable {
    let raw: String
    let improved: String
    let selectedText: String
    let ocrResult: OCRResult
    let meanConfidence: Double
    let pageScore: Double
    let lineScores: [OCRLineScoreResponse]
    let flags: [String]
    let needsPass2: Bool
    let correctionsApplied: Int
    let improveMilliseconds: Double
    let visionMilliseconds: Double
    let multipassMilliseconds: Double
    let correctMilliseconds: Double
    let totalMilliseconds: Double
    let pack: DomainPackSelection
    let customWordsCount: Int
    let rawVisionLines: [OCRVisionLine]
    let visionLines: [OCRVisionLine]
    let correctionTrace: [OCRCorrectionTraceItem]
}

private struct DomainPackCatalog: Decodable {
    let schema_version: Int
    let default_pack: String
    let packs: [DomainPackRecord]
}

private struct DomainPackRecord: Decodable {
    let id: String
    let version: String
    let sha256: String
    let metadata: [String: [String]]
    let words: [String]
}

actor DomainPackManager {
    static let shared = DomainPackManager()

    private var catalog: DomainPackCatalog?

    func select(metadata: OCRDomainMetadata) throws -> DomainPackSelection {
        let catalog = try loadCatalog()
        let requested = metadata.requestedPack?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if requested == "none" || requested == "off" {
            return DomainPackSelection(
                id: "none",
                version: "disabled",
                hash: "",
                words: [],
                overrides: [:]
            )
        }

        let selected: DomainPackRecord
        if let requested, requested != "auto",
           let exact = catalog.packs.first(where: { $0.id.lowercased() == requested }) {
            selected = exact
        } else if let matched = bestMetadataMatch(in: catalog.packs, metadata: metadata) {
            selected = matched
        } else if let fallback = catalog.packs.first(where: { $0.id == catalog.default_pack }) {
            selected = fallback
        } else if let first = catalog.packs.first {
            selected = first
        } else {
            return DomainPackSelection(
                id: "none",
                version: "missing",
                hash: "",
                words: [],
                overrides: [:]
            )
        }

        var words = selected.words
        for value in [metadata.documentType, metadata.agency, metadata.year] {
            if let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                words.append(value)
            }
        }
        return DomainPackSelection(
            id: selected.id,
            version: selected.version,
            hash: selected.sha256,
            words: Array(Set(words)).sorted(),
            overrides: [:]
        )
    }

    func packSummaries() throws -> [OCRPackSummaryResponse] {
        try loadCatalog().packs.map {
            OCRPackSummaryResponse(
                id: $0.id,
                version: $0.version,
                hash: $0.sha256,
                word_count: $0.words.count,
                override_count: 0,
                source: "bundle"
            )
        }.sorted { $0.id < $1.id }
    }

    func packIDs() throws -> Set<String> {
        Set(try loadCatalog().packs.map(\.id))
    }

    private func loadCatalog() throws -> DomainPackCatalog {
        if let catalog { return catalog }
        guard let url = Bundle.main.url(forResource: "domain_packs", withExtension: "json") else {
            throw VNLegalCorrectorError.missingResource("domain_packs.json")
        }
        let loaded = try JSONDecoder().decode(
            DomainPackCatalog.self,
            from: Data(contentsOf: url)
        )
        catalog = loaded
        return loaded
    }

    private func bestMetadataMatch(
        in packs: [DomainPackRecord],
        metadata: OCRDomainMetadata
    ) -> DomainPackRecord? {
        let documentType = metadata.documentType?.lowercased() ?? ""
        let agency = metadata.agency?.lowercased() ?? ""
        return packs.first { pack in
            let documentTerms = pack.metadata["document_type"] ?? []
            let agencyTerms = pack.metadata["agency"] ?? []
            return documentTerms.contains { documentType.contains($0) }
                || agencyTerms.contains { agency.contains($0) }
        }
    }
}

private struct OCRQualityAssessment {
    let pageScore: Double
    let lineScores: [OCRLineScoreResponse]
    let flags: [String]
    let needsPass2: Bool
    let retryLineIndexes: [Int]
}

private enum OCRQualityAnalyzer {
    static func assess(
        text: String,
        lines: [OCRVisionLine],
        configuration: OCRImprovementConfiguration,
        pageNumber: Int?,
        pageCount: Int?
    ) -> OCRQualityAssessment {
        let lineScores = lines.enumerated().map { index, line in
            let gapScore = min(
                1,
                line.candidateGap / max(0.0001, configuration.candidateGapNormalizer)
            )
            let confidenceWeight = configuration.lineConfidenceWeight
            let score = Self.clamp(
                line.confidence * confidenceWeight + gapScore * (1 - confidenceWeight)
            )
            return OCRLineScoreResponse(
                line: index + 1,
                confidence: line.confidence,
                candidate_gap: line.candidateGap,
                score: score,
                bbox: OCRNormalizedBoxResponse(
                    x: line.normalizedBox.x,
                    y: line.normalizedBox.y,
                    width: line.normalizedBox.width,
                    height: line.normalizedBox.height
                )
            )
        }

        let lowConfidenceIndexes = lines.indices.filter { index in
            let line = lines[index]
            return line.confidence < configuration.confidenceThreshold
                || (line.candidateGap < configuration.candidateGapThreshold
                    && line.confidence < configuration.candidateGapConfidenceThreshold)
        }
        let invalidLegalIDIndexes = lines.indices.filter {
            containsInvalidLegalID(lines[$0].text, configuration: configuration)
        }

        var flags: [String] = []
        if containsInvalidLegalID(text, configuration: configuration) {
            flags.append("invalid_legal_id")
        }
        if !lowConfidenceIndexes.isEmpty || lines.isEmpty {
            flags.append("low_confidence")
        }
        if isMissingPageNumber(
            text: text,
            pageNumber: pageNumber,
            pageCount: pageCount,
            minimumPages: configuration.missingPageNumberMinimumPages
        ) {
            flags.append("missing_page_number")
        }
        if hasBrokenTable(text, minimumLines: configuration.brokenTableMinimumLines) {
            flags.append("broken_table")
        }

        let baseScore = lineScores.isEmpty
            ? 0
            : lineScores.map(\.score).reduce(0, +) / Double(lineScores.count)
        let penalty = flags.reduce(0.0) { partial, flag in
            switch flag {
            case "invalid_legal_id":
                return partial + configuration.invalidLegalIDPenalty
            case "low_confidence":
                return partial + configuration.lowConfidencePenalty
            case "missing_page_number":
                return partial + configuration.missingPageNumberPenalty
            case "broken_table":
                return partial + configuration.brokenTablePenalty
            default:
                return partial
            }
        }
        let pageScore = clamp(baseScore - penalty)
        let retryIndexes = Array(
            Set(lowConfidenceIndexes + invalidLegalIDIndexes)
        ).sorted {
            lines[$0].confidence < lines[$1].confidence
        }
        return OCRQualityAssessment(
            pageScore: pageScore,
            lineScores: lineScores,
            flags: flags,
            needsPass2: !flags.isEmpty
                || pageScore < configuration.pageScorePass2Threshold,
            retryLineIndexes: retryIndexes
        )
    }

    static func containsInvalidLegalID(
        _ text: String,
        configuration: OCRImprovementConfiguration
    ) -> Bool {
        guard let validLegalID = try? NSRegularExpression(
            pattern: configuration.legalIDRegex,
            options: [.caseInsensitive]
        ), let possibleLegalID = try? NSRegularExpression(
            pattern: configuration.possibleLegalIDRegex,
            options: [.caseInsensitive]
        ) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        let possible = possibleLegalID.matches(in: text, range: range)
        guard !possible.isEmpty else { return false }
        return possible.contains { match in
            guard let matchRange = Range(match.range, in: text) else { return false }
            let candidate = String(text[matchRange])
            return validLegalID.firstMatch(
                in: candidate,
                range: NSRange(candidate.startIndex..., in: candidate)
            ) == nil
        }
    }

    private static func isMissingPageNumber(
        text: String,
        pageNumber: Int?,
        pageCount: Int?,
        minimumPages: Int
    ) -> Bool {
        guard let pageNumber, let pageCount, pageCount >= minimumPages else { return false }
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let edgeLines = Array(lines.prefix(3)) + Array(lines.suffix(3))
        let escapedPage = NSRegularExpression.escapedPattern(for: String(pageNumber))
        let patterns = [
            "(?i)\\btrang\\s*\(escapedPage)(?:\\s*/\\s*\\d+)?\\b",
            "^\\s*[-–—]?\\s*\(escapedPage)(?:\\s*/\\s*\\d+)?\\s*[-–—]?\\s*$",
        ]
        return !edgeLines.contains { line in
            patterns.contains { pattern in
                line.range(of: pattern, options: .regularExpression) != nil
            }
        }
    }

    private static func hasBrokenTable(_ text: String, minimumLines: Int) -> Bool {
        let tableLines = text.components(separatedBy: .newlines).filter { $0.contains("|") }
        guard !tableLines.isEmpty else { return false }
        let malformed = tableLines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.filter { $0 == "|" }.count >= 2
                && (!trimmed.hasPrefix("|") || !trimmed.hasSuffix("|"))
        }
        if malformed { return true }
        let columnCounts = tableLines.map { max(0, $0.split(separator: "|", omittingEmptySubsequences: false).count - 2) }
        return tableLines.count >= minimumLines && Set(columnCounts).count > 1
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

actor OCRImprovementService {
    static let shared = OCRImprovementService()

    private init() {}

    func resolvePack(metadata: OCRDomainMetadata) async throws -> DomainPackSelection {
        let bundle = try await DomainPackManager.shared.select(metadata: metadata)
        return try await OCRCustomizationStore.shared.resolve(
            bundleSelection: bundle,
            requestedPack: metadata.requestedPack
        )
    }

    func processImage(
        data: Data,
        visionConfiguration: OCRVisionConfiguration,
        metadata: OCRDomainMetadata,
        improve: Bool,
        pageNumber: Int? = nil,
        pageCount: Int? = nil,
        configuration: OCRImprovementConfiguration = .default,
        collectTrace: Bool = false,
        resolvedPack: DomainPackSelection? = nil
    ) async throws -> OCRImprovementResult? {
        try await process(
            data: data,
            documentText: nil,
            visionConfiguration: visionConfiguration,
            metadata: metadata,
            improve: improve,
            pageNumber: pageNumber,
            pageCount: pageCount,
            configuration: configuration,
            collectTrace: collectTrace,
            resolvedPack: resolvedPack
        )
    }

    func processDocument(
        data: Data,
        documentText: String,
        visionConfiguration: OCRVisionConfiguration,
        metadata: OCRDomainMetadata,
        improve: Bool,
        pageNumber: Int? = nil,
        pageCount: Int? = nil,
        configuration: OCRImprovementConfiguration = .default,
        collectTrace: Bool = false,
        resolvedPack: DomainPackSelection? = nil
    ) async throws -> OCRImprovementResult? {
        try await process(
            data: data,
            documentText: documentText,
            visionConfiguration: visionConfiguration,
            metadata: metadata,
            improve: improve,
            pageNumber: pageNumber,
            pageCount: pageCount,
            configuration: configuration,
            collectTrace: collectTrace,
            resolvedPack: resolvedPack
        )
    }

    private func process(
        data: Data,
        documentText: String?,
        visionConfiguration: OCRVisionConfiguration,
        metadata: OCRDomainMetadata,
        improve: Bool,
        pageNumber: Int?,
        pageCount: Int?,
        configuration: OCRImprovementConfiguration,
        collectTrace: Bool,
        resolvedPack: DomainPackSelection?
    ) async throws -> OCRImprovementResult? {
        let pipelineStarted = DispatchTime.now().uptimeNanoseconds
        let pack: DomainPackSelection
        if let resolvedPack {
            pack = resolvedPack
        } else {
            pack = try await resolvePack(metadata: metadata)
        }
        let recognizer = TextRecognizer(
            recognitionLevel: visionConfiguration.recognitionLevel,
            recognitionLanguages: visionConfiguration.recognitionLanguages,
            usesLanguageCorrection: visionConfiguration.usesLanguageCorrection,
            automaticallyDetectsLanguage: visionConfiguration.automaticallyDetectsLanguage,
            minimumTextHeight: visionConfiguration.minimumTextHeight,
            visionRevision: visionConfiguration.visionRevision
        )
        guard let initial = await recognizer.recognizeDetailed(
            data: data,
            customWords: pack.words,
            maximumCandidates: collectTrace ? 3 : 2
        ) else {
            return nil
        }

        let rawText = documentText ?? initial.text
        var selectedVision = initial
        var multipassMilliseconds = 0.0
        if improve && configuration.multipassEnabled {
            let initialQuality = OCRQualityAnalyzer.assess(
                text: initial.text,
                lines: initial.lines,
                configuration: configuration,
                pageNumber: pageNumber,
                pageCount: pageCount
            )
            let retryIndexes = Array(
                initialQuality.retryLineIndexes.prefix(max(0, configuration.maximumROIs))
            )
            if !retryIndexes.isEmpty {
                let started = DispatchTime.now().uptimeNanoseconds
                for index in retryIndexes {
                    guard selectedVision.lines.indices.contains(index),
                          let crop = await ImageProcessingService.shared.upscaledCrop(
                            data: data,
                            normalizedBox: selectedVision.lines[index].normalizedBox,
                            scale: configuration.roiUpscale
                          ),
                          let retry = await recognizer.recognizeDetailed(
                            data: crop,
                            customWords: pack.words,
                            maximumCandidates: collectTrace ? 3 : 2
                          ),
                          let retryLine = retry.lines.max(by: { $0.confidence < $1.confidence }) else {
                        continue
                    }
                    let originalLine = selectedVision.lines[index]
                    let fixesLegalID = OCRQualityAnalyzer.containsInvalidLegalID(
                        originalLine.text,
                        configuration: configuration
                    ) && !OCRQualityAnalyzer.containsInvalidLegalID(
                        retryLine.text,
                        configuration: configuration
                    )
                    let lengthRatio = Double(retryLine.text.count)
                        / Double(max(1, originalLine.text.count))
                    let acceptedLengthRange = configuration.multipassMinimumLengthRatio
                        ... configuration.multipassMaximumLengthRatio
                    let comparableLength = acceptedLengthRange.contains(lengthRatio)
                    if comparableLength
                        && (retryLine.confidence
                                >= originalLine.confidence
                                    + configuration.multipassMinimumConfidenceGain
                            || (fixesLegalID
                                && retryLine.confidence
                                    >= originalLine.confidence
                                        - configuration.multipassLegalIDTolerance)) {
                        selectedVision.lines[index] = originalLine.replacingCandidates(
                            retryLine.candidates
                        )
                    }
                }
                multipassMilliseconds = Self.elapsedMilliseconds(since: started)
            }
        }

        let textBeforeCorrection = documentText ?? selectedVision.text
        var correctedText = textBeforeCorrection
        var correctionCount = 0
        var correctionTrace: [OCRCorrectionTraceItem] = []
        var correctMilliseconds = 0.0
        if improve || collectTrace {
            let started = DispatchTime.now().uptimeNanoseconds
            let correction = try await VNLegalCorrector.shared.correct(
                textBeforeCorrection,
                groups: improve ? configuration.correctorGroups : [],
                overrides: improve ? pack.overrides : [:],
                collectTrace: collectTrace
            )
            correctedText = improve ? correction.text : textBeforeCorrection
            correctionCount = improve ? correction.correctionsApplied : 0
            correctionTrace = correction.trace
            correctMilliseconds = Self.elapsedMilliseconds(since: started)
            if correctionCount > 0 {
                await MainActor.run {
                    ServerTelemetry.shared.recordOCRCorrections(correctionCount)
                }
            }
        }

        let finalQuality = OCRQualityAnalyzer.assess(
            text: correctedText,
            lines: selectedVision.lines,
            configuration: configuration,
            pageNumber: pageNumber,
            pageCount: pageCount
        )
        let selectedText = improve ? correctedText : rawText
        let boxText = documentText == nil && improve ? correctedText : selectedVision.text
        let boxes = Self.boxes(from: selectedVision, replacementText: boxText)
        let result = OCRResult(
            text: selectedText,
            image_width: selectedVision.imageWidth,
            image_height: selectedVision.imageHeight,
            boxes: boxes
        )
        return OCRImprovementResult(
            raw: rawText,
            improved: improve ? correctedText : rawText,
            selectedText: selectedText,
            ocrResult: result,
            meanConfidence: selectedVision.meanConfidence,
            pageScore: finalQuality.pageScore,
            lineScores: finalQuality.lineScores,
            flags: finalQuality.flags,
            needsPass2: finalQuality.needsPass2,
            correctionsApplied: correctionCount,
            improveMilliseconds: multipassMilliseconds + correctMilliseconds,
            visionMilliseconds: initial.visionMilliseconds,
            multipassMilliseconds: multipassMilliseconds,
            correctMilliseconds: correctMilliseconds,
            totalMilliseconds: Self.elapsedMilliseconds(since: pipelineStarted),
            pack: pack,
            customWordsCount: initial.customWordsCount,
            rawVisionLines: initial.lines,
            visionLines: selectedVision.lines,
            correctionTrace: correctionTrace
        )
    }

    private static func boxes(
        from output: OCRVisionOutput,
        replacementText: String
    ) -> [OCRBoxItem] {
        let replacementLines = replacementText.components(separatedBy: .newlines)
        guard replacementLines.count == output.lines.count else {
            return output.lines.map(\.pixelBox)
        }
        return output.lines.enumerated().map { index, line in
            OCRBoxItem(
                text: replacementLines[index],
                x: line.pixelBox.x,
                y: line.pixelBox.y,
                w: line.pixelBox.w,
                h: line.pixelBox.h,
                rect: line.pixelBox.rect
            )
        }
    }

    private static func elapsedMilliseconds(since started: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
    }
}
