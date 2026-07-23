//
//  RequestSecurityMiddleware.swift
//  OcrServer
//

import Foundation
import Vapor

private struct RequestLimitErrorResponse: Content, Sendable {
    let success: Bool
    let message: String
}

struct AdminAuthMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        let path = request.url.path
        guard path.hasPrefix("/admin/"), path != "/admin/" else {
            return try await next.respond(to: request)
        }

        let token = await MainActor.run {
            Settings.shared.adminToken.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard token.isEmpty || request.headers.first(name: "X-Admin-Token") == token else {
            let response = Response(status: .unauthorized)
            try response.content.encode(
                RequestLimitErrorResponse(
                    success: false,
                    message: "Missing or invalid X-Admin-Token"
                ),
                as: .json
            )
            return response
        }
        return try await next.respond(to: request)
    }
}

struct UploadLimitMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        guard request.method == .POST, Self.isLimitedUploadPath(request.url.path) else {
            return try await next.respond(to: request)
        }

        let maximumMB = await MainActor.run { Settings.shared.maximumUploadMegabytes }
        let maximumBytes = Int64(maximumMB) * 1_048_576
        if let value = request.headers.first(name: "Content-Length"),
           let contentLength = Int64(value),
           contentLength > maximumBytes {
            let response = Response(status: .payloadTooLarge)
            try response.content.encode(
                RequestLimitErrorResponse(
                    success: false,
                    message: "Upload body exceeds max_upload_mb (\(maximumMB) MB)"
                ),
                as: .json
            )
            return response
        }
        return try await next.respond(to: request)
    }

    private static func isLimitedUploadPath(_ path: String) -> Bool {
        [
            "/upload",
            "/docOCR",
            "/batch",
            "/batch/ocr",
            "/batch/markdown",
            "/batch/docx",
            "/debug/ocr",
            "/barcode",
        ].contains(path)
    }
}
