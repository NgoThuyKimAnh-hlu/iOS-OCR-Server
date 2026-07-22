//
//  NERService.swift
//  OcrServer
//

import Foundation
import NaturalLanguage

struct NEREntity: Sendable {
    let text: String
    let type: String
}

struct NEROutput: Sendable {
    let entities: [NEREntity]
    let documentNumbers: [String]
    let legalReferences: [String]
}

enum NERServiceError: LocalizedError {
    case emptyText

    var errorDescription: String? {
        "'text' must not be empty"
    }
}

actor NERService {
    static let shared = NERService()

    private init() {}

    func extract(from input: String) throws -> NEROutput {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw NERServiceError.emptyText }

        return NEROutput(
            entities: namedEntities(in: text),
            documentNumbers: Self.matches(
                pattern: #"\b\d{1,4}/\d{4}/(?:NĐ-CP|QĐ-TTg|TT-[A-ZĐ]+|QH\d+)\b"#,
                in: text
            ),
            legalReferences: Self.matches(
                pattern: #"\b(?:Điều\s+\d+[a-zđ]?(?:\s*,?\s*khoản\s+\d+[a-zđ]?)?(?:\s*,?\s*điểm\s+[a-zđ])?|khoản\s+\d+[a-zđ]?(?:\s*,?\s*điểm\s+[a-zđ])?|điểm\s+[a-zđ])\b"#,
                in: text,
                options: [.caseInsensitive]
            )
        )
    }

    private func namedEntities(in text: String) -> [NEREntity] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var entities: [NEREntity] = []
        var seen: Set<String> = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, range in
            guard let tag else { return true }

            let type: String
            switch tag {
            case .organizationName:
                type = "organization"
            case .placeName:
                type = "place"
            case .personalName:
                type = "person"
            default:
                return true
            }

            let value = String(text[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let key = "\(type)\u{0}\(value)"
            if !value.isEmpty, seen.insert(key).inserted {
                entities.append(NEREntity(text: value, type: type))
            }
            return true
        }

        return entities
    }

    private static func matches(
        pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var values: [String] = []
        var seen: Set<String> = []

        for match in regex.matches(in: text, range: fullRange) {
            guard let range = Range(match.range, in: text) else { continue }
            let value = String(text[range])
            let key = value.lowercased()
            if seen.insert(key).inserted {
                values.append(value)
            }
        }

        return values
    }
}
