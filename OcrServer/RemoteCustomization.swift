//
//  RemoteCustomization.swift
//  OcrServer
//

import CryptoKit
import Foundation
import Vapor

enum ComputeServiceName: String, CaseIterable, Codable, Sendable {
    case ocr
    case dococr
    case translate
    case transcribe
    case synthesize
    case llm
    case ner
    case embed
    case coreml
    case barcode
}

struct OCRCustomizationSummary: Content, Sendable {
    let version: Int
    let hash: String
    let custom_words: Int
    let custom_overrides: Int
    let custom_packs: Int
}

struct OCRCustomWordsResponse: Content, Sendable {
    let words: [String]
    let count: Int
    let version: Int
    let hash: String
}

struct OCRCorrectionsResponse: Content, Sendable {
    let overrides: [String: String]
    let count: Int
    let version: Int
    let hash: String
}

struct OCRPackSummaryResponse: Content, Sendable {
    let id: String
    let version: String
    let hash: String
    let word_count: Int
    let override_count: Int
    let source: String
}

struct OCRPacksResponse: Content, Sendable {
    let packs: [OCRPackSummaryResponse]
    let active_pack: String
}

struct OCRLexiconResetResponse: Content, Sendable {
    let reset: Bool
    let version: Int
    let hash: String
}

private struct StoredCustomPack: Codable, Sendable {
    let id: String
    let words: [String]
    let overrides: [String: String]
    let version: Int
}

private struct StoredOCRCustomization: Codable, Sendable {
    var schemaVersion = 1
    var version = 0
    var customWords: [String] = []
    var overrides: [String: String] = [:]
    var packs: [String: StoredCustomPack] = [:]
}

actor OCRCustomizationStore {
    static let shared = OCRCustomizationStore()

    private var state: StoredOCRCustomization?

    private init() {}

    func customWords() throws -> OCRCustomWordsResponse {
        let state = try load()
        return OCRCustomWordsResponse(
            words: state.customWords,
            count: state.customWords.count,
            version: state.version,
            hash: try stateHash(state)
        )
    }

    func setCustomWords(_ words: [String], append: Bool) throws -> OCRCustomWordsResponse {
        var state = try load()
        let combined = append ? state.customWords + words : words
        state.customWords = Self.normalizedWords(combined)
        try persist(&state)
        return try customWords()
    }

    func corrections() throws -> OCRCorrectionsResponse {
        let state = try load()
        return OCRCorrectionsResponse(
            overrides: state.overrides,
            count: state.overrides.count,
            version: state.version,
            hash: try stateHash(state)
        )
    }

    func mergeCorrections(_ overrides: [String: String]) throws -> OCRCorrectionsResponse {
        var state = try load()
        for (source, target) in Self.normalizedOverrides(overrides) {
            state.overrides[source] = target
        }
        try persist(&state)
        return try corrections()
    }

    func savePack(
        id: String,
        words: [String],
        overrides: [String: String]
    ) throws -> OCRPackSummaryResponse {
        var state = try load()
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pack = StoredCustomPack(
            id: normalizedID,
            words: Self.normalizedWords(words),
            overrides: Self.normalizedOverrides(overrides),
            version: state.version + 1
        )
        state.packs[normalizedID] = pack
        try persist(&state)
        return try packSummary(pack)
    }

    func packSummaries() throws -> [OCRPackSummaryResponse] {
        let state = try load()
        return try state.packs.values.map { try packSummary($0) }.sorted { $0.id < $1.id }
    }

    func packIDs() throws -> Set<String> {
        Set(try load().packs.keys)
    }

    func resolve(
        bundleSelection: DomainPackSelection,
        requestedPack: String?
    ) throws -> DomainPackSelection {
        let state = try load()
        let requested = requestedPack?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let customPack = requested.flatMap { state.packs[$0] }
        let baseWords = customPack?.words ?? bundleSelection.words
        var overrides = customPack?.overrides ?? bundleSelection.overrides
        for (source, target) in state.overrides {
            overrides[source] = target
        }
        let words = Self.normalizedWords(baseWords + state.customWords)
        let id = customPack?.id ?? bundleSelection.id
        let version = customPack.map { "custom-\($0.version)" } ?? bundleSelection.version
        let hash = try Self.hash(
            EncodablePack(id: id, version: version, words: words, overrides: overrides)
        )
        return DomainPackSelection(
            id: id,
            version: version,
            hash: hash,
            words: words,
            overrides: overrides
        )
    }

    func summary() throws -> OCRCustomizationSummary {
        let state = try load()
        return OCRCustomizationSummary(
            version: state.version,
            hash: try stateHash(state),
            custom_words: state.customWords.count,
            custom_overrides: state.overrides.count,
            custom_packs: state.packs.count
        )
    }

    func reset() throws -> OCRLexiconResetResponse {
        var fresh = StoredOCRCustomization()
        state = nil
        let url = try storageURL()
        try? FileManager.default.removeItem(at: url)
        try persist(&fresh)
        return OCRLexiconResetResponse(
            reset: true,
            version: fresh.version,
            hash: try stateHash(fresh)
        )
    }

    private struct EncodablePack: Encodable {
        let id: String
        let version: String
        let words: [String]
        let overrides: [String: String]
    }

    private func load() throws -> StoredOCRCustomization {
        if let state { return state }
        let url = try storageURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            let fresh = StoredOCRCustomization()
            state = fresh
            return fresh
        }
        let loaded = try JSONDecoder().decode(
            StoredOCRCustomization.self,
            from: Data(contentsOf: url)
        )
        state = loaded
        return loaded
    }

    private func persist(_ updated: inout StoredOCRCustomization) throws {
        updated.version = max(1, updated.version + 1)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(updated)
        try data.write(to: storageURL(), options: .atomic)
        state = updated
    }

    private func storageURL() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let directory = applicationSupport.appendingPathComponent("Compute", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("ocr-customization.json")
    }

    private func stateHash(_ state: StoredOCRCustomization) throws -> String {
        try Self.hash(state)
    }

    private func packSummary(_ pack: StoredCustomPack) throws -> OCRPackSummaryResponse {
        OCRPackSummaryResponse(
            id: pack.id,
            version: "custom-\(pack.version)",
            hash: try Self.hash(pack),
            word_count: pack.words.count,
            override_count: pack.overrides.count,
            source: "custom"
        )
    }

    private static func normalizedWords(_ words: [String]) -> [String] {
        Array(
            Set(words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        ).filter { !$0.isEmpty }.sorted()
    }

    private static func normalizedOverrides(_ overrides: [String: String]) -> [String: String] {
        var normalized: [String: String] = [:]
        for (source, target) in overrides {
            let cleanSource = source
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .precomposedStringWithCanonicalMapping
                .lowercased()
            let cleanTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanSource.isEmpty, !cleanTarget.isEmpty else { continue }
            normalized[cleanSource] = cleanTarget
        }
        return normalized
    }

    private static func hash<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let digest = SHA256.hash(data: try encoder.encode(value))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
