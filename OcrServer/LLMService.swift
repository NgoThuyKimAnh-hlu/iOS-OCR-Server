//
//  LLMService.swift
//  OcrServer
//

import Foundation
import FoundationModels

enum LLMServiceError: LocalizedError {
    case emptyPrompt
    case invalidMaximumTokens
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "'prompt' must not be empty"
        case .invalidMaximumTokens:
            return "'max' must be greater than zero"
        case .unavailable(let reason):
            return "Foundation Models is unavailable: \(reason)"
        }
    }
}

@available(iOS 26.0, *)
actor LLMService {
    static let shared = LLMService()

    private init() {}

    func respond(prompt: String, system: String?, maximumTokens: Int?) async throws -> String {
        let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let system = system?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !prompt.isEmpty else { throw LLMServiceError.emptyPrompt }
        if let maximumTokens, maximumTokens <= 0 {
            throw LLMServiceError.invalidMaximumTokens
        }

        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw LLMServiceError.unavailable(Self.description(for: reason))
        }

        let session = LanguageModelSession(
            model: model,
            instructions: system?.isEmpty == false ? system : nil
        )
        let options = GenerationOptions(maximumResponseTokens: maximumTokens)
        let response = try await session.respond(to: prompt, options: options)
        return response.content
    }

    private static func description(
        for reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled"
        case .deviceNotEligible:
            return "this device is not eligible"
        case .modelNotReady:
            return "the on-device model is not ready"
        @unknown default:
            return String(describing: reason)
        }
    }
}
