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
}

struct OCRImprovementConfiguration: Sendable {
    let confidenceThreshold: Double
    let multipassEnabled: Bool
    let roiUpscale: Double
    let maximumROIs: Int
    let correctorGroups: Set<CorrectorGroup>

    static let `default` = OCRImprovementConfiguration(
        confidenceThreshold: 0.55,
        multipassEnabled: true,
        roiUpscale: 2,
        maximumROIs: 4,
        correctorGroups: Set(CorrectorGroup.allCases)
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
    let pack: DomainPackSelection
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

private actor DomainPackManager {
    static let shared = DomainPackManager()

    private var catalog: DomainPackCatalog?

    func select(metadata: OCRDomainMetadata) throws -> DomainPackSelection {
        let catalog = try loadCatalog()
        let requested = metadata.requestedPack?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if requested == "none" || requested == "off" {
            return DomainPackSelection(id: "none", version: "disabled", hash: "", words: [])
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
            return DomainPackSelection(id: "none", version: "missing", hash: "", words: [])
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
            words: Array(Set(words)).sorted()
        )
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
    private static let validLegalID = try! NSRegularExpression(
        pattern: "\\b\\d{1,4}/\\d{4}/[A-ZĐ][A-ZĐ0-9-]*\\b",
        options: [.caseInsensitive]
    )
    private static let possibleLegalID = try! NSRegularExpression(
        pattern: "\\b[0-9OIl]{1,4}\\s*[/|]\\s*[0-9OIl]{2,4}\\s*[/|]\\s*[A-ZĐ0-9][A-ZĐ0-9 -]{1,20}",
        options: [.caseInsensitive]
    )

    static func assess(
        text: String,
        lines: [OCRVisionLine],
        confidenceThreshold: Double,
        pageNumber: Int?,
        pageCount: Int?
    ) -> OCRQualityAssessment {
        let lineScores = lines.enumerated().map { index, line in
            let gapScore = min(1, line.candidateGap / 0.20)
            let score = Self.clamp(line.confidence * 0.82 + gapScore * 0.18)
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
            return line.confidence < confidenceThreshold
                || (line.candidateGap < 0.015 && line.confidence < 0.80)
        }
        let invalidLegalIDIndexes = lines.indices.filter {
            containsInvalidLegalID(lines[$0].text)
        }

        var flags: [String] = []
        if containsInvalidLegalID(text) {
            flags.append("invalid_legal_id")
        }
        if !lowConfidenceIndexes.isEmpty || lines.isEmpty {
            flags.append("low_confidence")
        }
        if isMissingPageNumber(text: text, pageNumber: pageNumber, pageCount: pageCount) {
            flags.append("missing_page_number")
        }
        if hasBrokenTable(text) {
            flags.append("broken_table")
        }

        let baseScore = lineScores.isEmpty
            ? 0
            : lineScores.map(\.score).reduce(0, +) / Double(lineScores.count)
        let penalty = flags.reduce(0.0) { partial, flag in
            partial + (flag == "invalid_legal_id" || flag == "broken_table" ? 0.14 : 0.09)
        }
        let retryIndexes = Array(
            Set(lowConfidenceIndexes + invalidLegalIDIndexes)
        ).sorted {
            lines[$0].confidence < lines[$1].confidence
        }
        return OCRQualityAssessment(
            pageScore: clamp(baseScore - penalty),
            lineScores: lineScores,
            flags: flags,
            needsPass2: !flags.isEmpty,
            retryLineIndexes: retryIndexes
        )
    }

    static func containsInvalidLegalID(_ text: String) -> Bool {
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
        pageCount: Int?
    ) -> Bool {
        guard let pageNumber, let pageCount, pageCount > 1 else { return false }
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

    private static func hasBrokenTable(_ text: String) -> Bool {
        let tableLines = text.components(separatedBy: .newlines).filter { $0.contains("|") }
        guard !tableLines.isEmpty else { return false }
        let malformed = tableLines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.filter { $0 == "|" }.count >= 2
                && (!trimmed.hasPrefix("|") || !trimmed.hasSuffix("|"))
        }
        if malformed { return true }
        let columnCounts = tableLines.map { max(0, $0.split(separator: "|", omittingEmptySubsequences: false).count - 2) }
        return tableLines.count >= 2 && Set(columnCounts).count > 1
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

actor OCRImprovementService {
    static let shared = OCRImprovementService()

    private init() {}

    func processImage(
        data: Data,
        recognitionLevel: RecognizeTextRequest.RecognitionLevel,
        usesLanguageCorrection: Bool,
        automaticallyDetectsLanguage: Bool,
        metadata: OCRDomainMetadata,
        improve: Bool,
        pageNumber: Int? = nil,
        pageCount: Int? = nil,
        configuration: OCRImprovementConfiguration = .default,
        collectTrace: Bool = false
    ) async throws -> OCRImprovementResult? {
        try await process(
            data: data,
            documentText: nil,
            recognitionLevel: recognitionLevel,
            usesLanguageCorrection: usesLanguageCorrection,
            automaticallyDetectsLanguage: automaticallyDetectsLanguage,
            metadata: metadata,
            improve: improve,
            pageNumber: pageNumber,
            pageCount: pageCount,
            configuration: configuration,
            collectTrace: collectTrace
        )
    }

    func processDocument(
        data: Data,
        documentText: String,
        recognitionLevel: RecognizeTextRequest.RecognitionLevel,
        usesLanguageCorrection: Bool,
        automaticallyDetectsLanguage: Bool,
        metadata: OCRDomainMetadata,
        improve: Bool,
        pageNumber: Int? = nil,
        pageCount: Int? = nil,
        configuration: OCRImprovementConfiguration = .default,
        collectTrace: Bool = false
    ) async throws -> OCRImprovementResult? {
        try await process(
            data: data,
            documentText: documentText,
            recognitionLevel: recognitionLevel,
            usesLanguageCorrection: usesLanguageCorrection,
            automaticallyDetectsLanguage: automaticallyDetectsLanguage,
            metadata: metadata,
            improve: improve,
            pageNumber: pageNumber,
            pageCount: pageCount,
            configuration: configuration,
            collectTrace: collectTrace
        )
    }

    private func process(
        data: Data,
        documentText: String?,
        recognitionLevel: RecognizeTextRequest.RecognitionLevel,
        usesLanguageCorrection: Bool,
        automaticallyDetectsLanguage: Bool,
        metadata: OCRDomainMetadata,
        improve: Bool,
        pageNumber: Int?,
        pageCount: Int?,
        configuration: OCRImprovementConfiguration,
        collectTrace: Bool
    ) async throws -> OCRImprovementResult? {
        let pack = try await DomainPackManager.shared.select(metadata: metadata)
        let recognizer = TextRecognizer(
            recognitionLevel: recognitionLevel,
            usesLanguageCorrection: usesLanguageCorrection,
            automaticallyDetectsLanguage: automaticallyDetectsLanguage
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
                confidenceThreshold: configuration.confidenceThreshold,
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
                    let fixesLegalID = OCRQualityAnalyzer.containsInvalidLegalID(originalLine.text)
                        && !OCRQualityAnalyzer.containsInvalidLegalID(retryLine.text)
                    let lengthRatio = Double(retryLine.text.count)
                        / Double(max(1, originalLine.text.count))
                    let comparableLength = (0.60...1.60).contains(lengthRatio)
                    if comparableLength
                        && (retryLine.confidence >= originalLine.confidence + 0.02
                            || (fixesLegalID
                                && retryLine.confidence >= originalLine.confidence - 0.05)) {
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
        if improve {
            let started = DispatchTime.now().uptimeNanoseconds
            let correction = try await VNLegalCorrector.shared.correct(
                textBeforeCorrection,
                groups: configuration.correctorGroups,
                collectTrace: collectTrace
            )
            correctedText = correction.text
            correctionCount = correction.correctionsApplied
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
            confidenceThreshold: configuration.confidenceThreshold,
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
            pack: pack,
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
