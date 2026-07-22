//
//  EmbeddingService.swift
//  OcrServer
//

import Foundation
import NaturalLanguage

struct EmbeddingOutput: Sendable {
    let vector: [Double]
    let dimension: Int
}

enum EmbeddingServiceError: LocalizedError {
    case emptyText
    case unsupportedVietnamese

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "'text' must not be empty"
        case .unsupportedVietnamese:
            return "NLEmbedding chưa hỗ trợ vi, cần Core ML embedding model sau"
        }
    }
}

actor EmbeddingService {
    static let shared = EmbeddingService()

    private init() {}

    func isVietnameseAvailable() -> Bool {
        NLEmbedding.sentenceEmbedding(for: .vietnamese) != nil
            || NLEmbedding.wordEmbedding(for: .vietnamese) != nil
    }

    func embed(_ input: String) throws -> EmbeddingOutput {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw EmbeddingServiceError.emptyText }

        if let embedding = NLEmbedding.sentenceEmbedding(for: .vietnamese),
           let vector = embedding.vector(for: text) {
            return EmbeddingOutput(vector: vector, dimension: vector.count)
        }

        if let embedding = NLEmbedding.wordEmbedding(for: .vietnamese),
           let vector = Self.averageWordVectors(in: text, using: embedding) {
            return EmbeddingOutput(vector: vector, dimension: vector.count)
        }

        throw EmbeddingServiceError.unsupportedVietnamese
    }

    private static func averageWordVectors(
        in text: String,
        using embedding: NLEmbedding
    ) -> [Double]? {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var accumulated: [Double] = []
        var vectorCount = 0

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            guard let vector = embedding.vector(for: String(text[range])) else {
                return true
            }

            if accumulated.isEmpty {
                accumulated = Array(repeating: 0, count: vector.count)
            }
            guard accumulated.count == vector.count else { return true }

            for index in vector.indices {
                accumulated[index] += vector[index]
            }
            vectorCount += 1
            return true
        }

        guard vectorCount > 0 else { return nil }
        return accumulated.map { $0 / Double(vectorCount) }
    }
}
