//
//  VNLegalCorrector.swift
//  OcrServer
//

import Compression
import Foundation
import Vapor

enum CorrectorGroup: String, CaseIterable, Codable, Sendable {
    case allcapsDiacritic = "allcaps_diacritic"
    case undiacriticMap = "undiacritic_map"
    case legalIDNormalize = "legalid_normalize"
    case ambiguousSkip = "ambiguous_skip"
}

struct OCRCorrectionTraceItem: Content, Sendable {
    let token_raw: String
    let token_out: String
    let rule_id: String
    let action: String
}

struct OCRCorrectionResult: Sendable {
    let text: String
    let correctionsApplied: Int
    let trace: [OCRCorrectionTraceItem]
}

enum VNLegalCorrectorError: LocalizedError {
    case missingResource(String)
    case invalidCompressedResource(String)
    case resourceTooLarge(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Missing OCR resource: \(name)"
        case .invalidCompressedResource(let name):
            return "Invalid compressed OCR resource: \(name)"
        case .resourceTooLarge(let name):
            return "OCR resource is too large to decode safely: \(name)"
        }
    }
}

actor VNLegalCorrector {
    static let shared = VNLegalCorrector()
    static let correctionRuleCount = 923_186
    static let unigramEntryCount = 97_197

    private struct TextPart {
        var text: String
        let isWord: Bool
    }

    private struct RankedWord {
        let word: String
        let count: Int
    }

    private struct SafeCorrectionRule: Decodable {
        let source: String
        let target: String
        let case_insensitive: Bool
        let rule_id: String
    }

    private let ambiguousAdminSyllables: Set<String> = [
        "ban", "bao", "bo", "can", "cao", "chanh", "chi", "chinh", "chu",
        "chuc", "cong", "cuc", "dan", "dia", "dieu", "dinh", "doc", "don",
        "dung", "giam", "giay", "han", "hien", "hoi", "huong", "kiem", "lap",
        "nghi", "nhan", "nhiem", "noi", "phan", "pho", "quan", "quy", "quyen",
        "so", "tham", "thanh", "thi", "thong", "thu", "thuc", "tich", "tra",
        "trung", "truong", "tuc", "uong", "uy", "van", "vien", "viet", "vu",
    ]
    private let wordRegex = try! NSRegularExpression(
        pattern: "[A-Za-zÀ-ỹĐđ]+|[^A-Za-zÀ-ỹĐđ]+"
    )
    private let legalIDRegex = try! NSRegularExpression(
        pattern: "\\b([0-9OIl]{1,4})\\s*[/|]\\s*([0-9OIl]{4})\\s*[/|]\\s*([A-ZĐ0-9]+(?:\\s*-\\s*[A-ZĐ0-9]+)*)\\b",
        options: [.caseInsensitive]
    )

    private var correctionMap: [String: String]?
    private var safeCorrections: [SafeCorrectionRule]?
    private var allCapsWordMap: [String: String]?

    private init() {}

    func correct(
        _ text: String,
        groups: Set<CorrectorGroup> = Set(CorrectorGroup.allCases),
        collectTrace: Bool = false
    ) throws -> OCRCorrectionResult {
        guard !text.isEmpty else {
            return OCRCorrectionResult(text: text, correctionsApplied: 0, trace: [])
        }

        var output = text
        var applied = 0
        var trace: [OCRCorrectionTraceItem] = []

        if groups.contains(.allcapsDiacritic) || groups.contains(.undiacriticMap) {
            let result = try applySafeCorrections(
                to: output,
                groups: groups,
                collectTrace: collectTrace
            )
            output = result.text
            applied += result.correctionsApplied
            trace.append(contentsOf: result.trace)
        }

        if groups.contains(.undiacriticMap) {
            let result = try applyCorpusMap(to: output, collectTrace: collectTrace)
            output = result.text
            applied += result.correctionsApplied
            trace.append(contentsOf: result.trace)
        }

        if groups.contains(.allcapsDiacritic) {
            let result = try applyAllCapsWords(
                to: output,
                skipAmbiguous: groups.contains(.ambiguousSkip),
                collectTrace: collectTrace
            )
            output = result.text
            applied += result.correctionsApplied
            trace.append(contentsOf: result.trace)
        }

        if groups.contains(.legalIDNormalize) {
            let result = normalizeLegalIDs(in: output, collectTrace: collectTrace)
            output = result.text
            applied += result.correctionsApplied
            trace.append(contentsOf: result.trace)
        }

        return OCRCorrectionResult(
            text: output,
            correctionsApplied: applied,
            trace: trace
        )
    }

    private func applySafeCorrections(
        to text: String,
        groups: Set<CorrectorGroup>,
        collectTrace: Bool
    ) throws -> OCRCorrectionResult {
        let corrections = try loadSafeCorrections()
        var output = text
        var applied = 0
        var trace: [OCRCorrectionTraceItem] = []

        for rule in corrections {
            let words = rule.source.split(separator: " ").map(String.init)
            let body = words
                .map { NSRegularExpression.escapedPattern(for: $0) }
                .joined(separator: "[ \\t]+")
            let pattern = "(?<![A-Za-zÀ-ỹĐđ])\(body)(?![A-Za-zÀ-ỹĐđ])"
            let options: NSRegularExpression.Options = rule.case_insensitive ? [.caseInsensitive] : []
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
                continue
            }
            let matches = regex.matches(
                in: output,
                range: NSRange(output.startIndex..., in: output)
            )
            for match in matches.reversed() {
                guard let range = Range(match.range, in: output) else { continue }
                let original = String(output[range])
                let allCaps = Self.isAllCapsPhrase(original)
                let group: CorrectorGroup = allCaps ? .allcapsDiacritic : .undiacriticMap
                guard groups.contains(group) else { continue }
                let replacement = rule.case_insensitive
                    ? Self.casePhrase(source: original, replacement: rule.target)
                    : rule.target
                guard replacement != original else { continue }
                output.replaceSubrange(range, with: replacement)
                applied += 1
                if collectTrace {
                    trace.append(
                        OCRCorrectionTraceItem(
                            token_raw: original,
                            token_out: replacement,
                            rule_id: "\(rule.rule_id):\(rule.source)",
                            action: allCaps ? "diacritized" : "normalized"
                        )
                    )
                }
            }
        }

        return OCRCorrectionResult(text: output, correctionsApplied: applied, trace: trace)
    }

    private func applyCorpusMap(
        to text: String,
        collectTrace: Bool
    ) throws -> OCRCorrectionResult {
        let map = try loadCorrectionMap()
        var parts = tokenize(text)
        let wordPartIndexes = parts.indices.filter { parts[$0].isWord }
        let words = wordPartIndexes.map { parts[$0].text }
        var replacements: [Int: String] = [:]
        var applied = 0
        var trace: [OCRCorrectionTraceItem] = []
        var index = 0

        while index < words.count {
            var matched = false
            for length in [3, 2] where index + length <= words.count {
                let sourceWords = Array(words[index..<(index + length)])
                let key = sourceWords.joined(separator: " ").lowercased()
                guard let target = map[key] else { continue }
                let targetWords = target.split(separator: " ").map(String.init)
                guard targetWords.count == length else { continue }

                var changed = false
                for offset in 0..<length {
                    let replacement = Self.caseWord(
                        source: sourceWords[offset],
                        replacement: targetWords[offset]
                    )
                    replacements[wordPartIndexes[index + offset]] = replacement
                    changed = changed || replacement != sourceWords[offset]
                    if collectTrace, replacement != sourceWords[offset] {
                        trace.append(
                            OCRCorrectionTraceItem(
                                token_raw: sourceWords[offset],
                                token_out: replacement,
                                rule_id: "corpus:\(key)",
                                action: "diacritized"
                            )
                        )
                    }
                }
                if changed { applied += 1 }
                index += length
                matched = true
                break
            }
            if !matched { index += 1 }
        }

        for (partIndex, replacement) in replacements {
            parts[partIndex].text = replacement
        }
        return OCRCorrectionResult(
            text: parts.map(\.text).joined(),
            correctionsApplied: applied,
            trace: trace
        )
    }

    private func applyAllCapsWords(
        to text: String,
        skipAmbiguous: Bool,
        collectTrace: Bool
    ) throws -> OCRCorrectionResult {
        let map = try loadAllCapsWordMap()
        var parts = tokenize(text)
        var applied = 0
        var trace: [OCRCorrectionTraceItem] = []

        for index in parts.indices where parts[index].isWord {
            let original = parts[index].text
            guard original.count >= 3,
                  original == original.uppercased(),
                  original.unicodeScalars.allSatisfy({ $0.isASCII }) else {
                continue
            }
            let key = original.lowercased()
            if skipAmbiguous, ambiguousAdminSyllables.contains(key) {
                if collectTrace {
                    trace.append(
                        OCRCorrectionTraceItem(
                            token_raw: original,
                            token_out: original,
                            rule_id: "ambiguous:\(key)",
                            action: "skipped_ambiguous"
                        )
                    )
                }
                continue
            }
            guard let target = map[key] else { continue }
            let replacement = target.uppercased()
            guard replacement != original else { continue }
            parts[index].text = replacement
            applied += 1
            if collectTrace {
                trace.append(
                    OCRCorrectionTraceItem(
                        token_raw: original,
                        token_out: replacement,
                        rule_id: "allcaps:\(key)",
                        action: "diacritized"
                    )
                )
            }
        }

        return OCRCorrectionResult(
            text: parts.map(\.text).joined(),
            correctionsApplied: applied,
            trace: trace
        )
    }

    private func normalizeLegalIDs(
        in text: String,
        collectTrace: Bool
    ) -> OCRCorrectionResult {
        var output = text
        var applied = 0
        var trace: [OCRCorrectionTraceItem] = []
        let matches = legalIDRegex.matches(
            in: output,
            range: NSRange(output.startIndex..., in: output)
        )

        for match in matches.reversed() {
            guard match.numberOfRanges == 4,
                  let fullRange = Range(match.range(at: 0), in: output),
                  let numberRange = Range(match.range(at: 1), in: output),
                  let yearRange = Range(match.range(at: 2), in: output),
                  let suffixRange = Range(match.range(at: 3), in: output) else {
                continue
            }
            let original = String(output[fullRange])
            let number = Self.normalizedDigits(String(output[numberRange]))
            let year = Self.normalizedDigits(String(output[yearRange]))
            guard let yearValue = Int(year), (1900...2099).contains(yearValue) else { continue }
            let suffix = String(output[suffixRange])
                .uppercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "—", with: "-")
            let replacement = "\(number)/\(year)/\(suffix)"
            guard replacement != original else { continue }
            output.replaceSubrange(fullRange, with: replacement)
            applied += 1
            if collectTrace {
                trace.append(
                    OCRCorrectionTraceItem(
                        token_raw: original,
                        token_out: replacement,
                        rule_id: "legalid_normalize",
                        action: "normalized"
                    )
                )
            }
        }

        return OCRCorrectionResult(text: output, correctionsApplied: applied, trace: trace)
    }

    private func tokenize(_ text: String) -> [TextPart] {
        wordRegex.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let value = String(text[range])
            return TextPart(
                text: value,
                isWord: value.unicodeScalars.first.map(Self.isVietnameseLetter) ?? false
            )
        }
    }

    private func loadCorrectionMap() throws -> [String: String] {
        if let correctionMap { return correctionMap }
        let loaded: [String: String] = try Self.decodeCompressedJSON(
            resource: "correction_map.json",
            extension: "zlib"
        )
        correctionMap = loaded
        return loaded
    }

    private func loadSafeCorrections() throws -> [SafeCorrectionRule] {
        if let safeCorrections { return safeCorrections }
        guard let url = Bundle.main.url(forResource: "safe_corrections", withExtension: "json") else {
            throw VNLegalCorrectorError.missingResource("safe_corrections.json")
        }
        let loaded = try JSONDecoder().decode(
            [SafeCorrectionRule].self,
            from: Data(contentsOf: url)
        )
        safeCorrections = loaded
        return loaded
    }

    private func loadAllCapsWordMap() throws -> [String: String] {
        if let allCapsWordMap { return allCapsWordMap }
        let unigrams: [String: Int] = try Self.decodeCompressedJSON(
            resource: "unigram.json",
            extension: "zlib"
        )
        var groups: [String: [RankedWord]] = [:]
        for (word, count) in unigrams where !word.contains(" ") && word.count <= 20 {
            let key = Self.stripDiacritics(word).lowercased()
            guard key != word.lowercased(), key.count >= 3 else { continue }
            groups[key, default: []].append(RankedWord(word: word, count: count))
        }

        var result: [String: String] = [:]
        for (key, candidates) in groups {
            let ranked = candidates.sorted { $0.count > $1.count }
            guard let first = ranked.first, first.count >= 50 else { continue }
            if ranked.count > 1, first.count < ranked[1].count * 4 { continue }
            result[key] = first.word
        }
        allCapsWordMap = result
        return result
    }

    private static func decodeCompressedJSON<T: Decodable>(
        resource: String,
        extension fileExtension: String
    ) throws -> T {
        let filename = "\(resource).\(fileExtension)"
        guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension) else {
            throw VNLegalCorrectorError.missingResource(filename)
        }
        let packed = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard packed.count >= 12,
              String(decoding: packed.prefix(4), as: UTF8.self) == "CZL1" else {
            throw VNLegalCorrectorError.invalidCompressedResource(filename)
        }

        let sizeBytes = packed[4..<12]
        let expectedSize = sizeBytes.enumerated().reduce(UInt64(0)) { partial, item in
            partial | (UInt64(item.element) << UInt64(item.offset * 8))
        }
        guard expectedSize > 0, expectedSize <= 128 * 1024 * 1024 else {
            throw VNLegalCorrectorError.resourceTooLarge(filename)
        }

        let compressed = packed.dropFirst(12)
        var output = Data(count: Int(expectedSize))
        let decodedSize = output.withUnsafeMutableBytes { destinationBuffer in
            compressed.withUnsafeBytes { sourceBuffer in
                guard let destination = destinationBuffer.bindMemory(to: UInt8.self).baseAddress,
                      let source = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    destination,
                    Int(expectedSize),
                    source,
                    compressed.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard decodedSize == Int(expectedSize) else {
            throw VNLegalCorrectorError.invalidCompressedResource(filename)
        }
        return try JSONDecoder().decode(T.self, from: output)
    }

    private static func isVietnameseLetter(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isAlphabetic
    }

    private static func stripDiacritics(_ value: String) -> String {
        value
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "vi_VN"))
    }

    private static func caseWord(source: String, replacement: String) -> String {
        if source.count > 1, source == source.uppercased() {
            return replacement.uppercased()
        }
        guard source.first?.isUppercase == true, let first = replacement.first else {
            return replacement
        }
        return String(first).uppercased() + String(replacement.dropFirst())
    }

    private static func casePhrase(source: String, replacement: String) -> String {
        let sourceWords = source.split(whereSeparator: \.isWhitespace).map(String.init)
        let replacementWords = replacement.split(separator: " ").map(String.init)
        guard sourceWords.count == replacementWords.count else { return replacement }
        return zip(sourceWords, replacementWords)
            .map { caseWord(source: $0.0, replacement: $0.1) }
            .joined(separator: " ")
    }

    private static func isAllCapsPhrase(_ value: String) -> Bool {
        let letters = value.filter { $0.isLetter }
        return letters.count > 1 && letters == letters.uppercased()
    }

    private static func normalizedDigits(_ value: String) -> String {
        value.map { character in
            switch character {
            case "O", "o": return "0"
            case "I", "i", "l": return "1"
            default: return String(character)
            }
        }.joined()
    }
}
