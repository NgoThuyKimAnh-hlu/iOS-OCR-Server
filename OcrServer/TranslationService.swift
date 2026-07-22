//
//  TranslationService.swift
//  OcrServer
//

import Foundation
import SwiftUI
import Translation

struct TranslationOutput: Sendable {
    let translated: String
    let source: String
    let target: String
}

enum TranslationServiceError: LocalizedError {
    case emptyText
    case missingTarget
    case timedOut

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "'text' must not be empty"
        case .missingTarget:
            return "'target' must not be empty"
        case .timedOut:
            return "Translation timed out while waiting for the UI translation session"
        }
    }
}

@MainActor
final class TranslationService: ObservableObject {
    static let shared = TranslationService()

    fileprivate struct Request: Identifiable {
        let id: UUID
        let text: String
        let source: String?
        let target: String
        let continuation: CheckedContinuation<TranslationOutput, Error>
    }

    @Published fileprivate private(set) var activeRequest: Request?
    private var queuedRequests: [Request] = []

    private init() {}

    func translate(text: String, source: String?, target: String) async throws -> TranslationOutput {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = source?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { throw TranslationServiceError.emptyText }
        guard !target.isEmpty else { throw TranslationServiceError.missingTarget }

        let requestID = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            queuedRequests.append(
                Request(
                    id: requestID,
                    text: text,
                    source: source?.isEmpty == false ? source : nil,
                    target: target,
                    continuation: continuation
                )
            )
            activateNextRequest()

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 120_000_000_000)
                self?.failIfPending(id: requestID, error: TranslationServiceError.timedOut)
            }
        }
    }

    fileprivate func complete(id: UUID, result: Result<TranslationOutput, Error>) {
        guard activeRequest?.id == id else { return }

        let request = activeRequest
        activeRequest = nil
        request?.continuation.resume(with: result)
        activateNextRequest()
    }

    private func activateNextRequest() {
        guard activeRequest == nil, !queuedRequests.isEmpty else { return }
        activeRequest = queuedRequests.removeFirst()
    }

    private func failIfPending(id: UUID, error: Error) {
        if activeRequest?.id == id {
            complete(id: id, result: .failure(error))
            return
        }

        guard let index = queuedRequests.firstIndex(where: { $0.id == id }) else { return }
        let request = queuedRequests.remove(at: index)
        request.continuation.resume(throwing: error)
    }
}

struct TranslationServiceHost: View {
    @ObservedObject var service: TranslationService
    @State private var configuration: TranslationSession.Configuration?
    @State private var configuredRequestID: UUID?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                configure(for: service.activeRequest)
            }
            .onChange(of: service.activeRequest?.id) { _, _ in
                configure(for: service.activeRequest)
            }
            .translationTask(configuration) { session in
                Task { @MainActor in
                    guard let request = service.activeRequest,
                          request.id == configuredRequestID else {
                        return
                    }

                    do {
                        let response = try await session.translate(request.text)
                        service.complete(
                            id: request.id,
                            result: .success(
                                TranslationOutput(
                                    translated: response.targetText,
                                    source: response.sourceLanguage.minimalIdentifier,
                                    target: response.targetLanguage.minimalIdentifier
                                )
                            )
                        )
                    } catch {
                        service.complete(id: request.id, result: .failure(error))
                    }
                }
            }
    }

    private func configure(for request: TranslationService.Request?) {
        guard let request else {
            configuredRequestID = nil
            configuration = nil
            return
        }

        configuredRequestID = request.id
        let sourceLanguage = request.source.map(Locale.Language.init(identifier:))
        let targetLanguage = Locale.Language(identifier: request.target)

        if configuration?.source == sourceLanguage,
           configuration?.target == targetLanguage {
            configuration?.invalidate()
        } else {
            configuration = TranslationSession.Configuration(
                source: sourceLanguage,
                target: targetLanguage
            )
        }
    }
}
