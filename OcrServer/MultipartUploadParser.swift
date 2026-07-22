//
//  MultipartUploadParser.swift
//  OcrServer
//

import Foundation
import Vapor

struct ParsedMultipartFile: Sendable {
    let filename: String
    let data: Data
}

enum MultipartUploadError: LocalizedError {
    case invalidContentType
    case missingBody
    case missingFiles(String)

    var errorDescription: String? {
        switch self {
        case .invalidContentType:
            return "Expected multipart/form-data with a boundary"
        case .missingBody:
            return "The multipart request body is empty"
        case .missingFiles(let fieldName):
            return "No non-empty '\(fieldName)' file parts were found"
        }
    }
}

enum MultipartUploadParser {
    static func files(from request: Request, fieldName: String) throws -> [ParsedMultipartFile] {
        guard let contentType = request.headers.contentType,
              contentType.type.lowercased() == "multipart",
              contentType.subType.lowercased() == "form-data",
              let rawBoundary = contentType.parameters["boundary"] else {
            throw MultipartUploadError.invalidContentType
        }
        guard let buffer = request.body.data else {
            throw MultipartUploadError.missingBody
        }

        let boundary = rawBoundary.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let body = byteBufferToData(buffer)
        guard !body.isEmpty else { throw MultipartUploadError.missingBody }

        let marker = Data("--\(boundary)".utf8)
        let headerSeparator = Data("\r\n\r\n".utf8)
        var searchStart = body.startIndex
        var files: [ParsedMultipartFile] = []

        while let markerRange = body.range(
            of: marker,
            options: [],
            in: searchStart..<body.endIndex
        ) {
            let partStart = markerRange.upperBound
            guard let nextMarker = body.range(
                of: marker,
                options: [],
                in: partStart..<body.endIndex
            ) else {
                break
            }

            var part = Data(body[partStart..<nextMarker.lowerBound])
            trimCRLF(from: &part)
            searchStart = nextMarker.lowerBound

            guard let separatorRange = part.range(of: headerSeparator) else { continue }
            let headerData = Data(part[..<separatorRange.lowerBound])
            var fileData = Data(part[separatorRange.upperBound...])
            trimTrailingCRLF(from: &fileData)

            guard !fileData.isEmpty,
                  let headerText = String(data: headerData, encoding: .utf8),
                  let disposition = headerText
                    .components(separatedBy: "\r\n")
                    .first(where: { $0.lowercased().hasPrefix("content-disposition:") }),
                  parameter("name", in: disposition) == fieldName,
                  let filename = parameter("filename", in: disposition),
                  !filename.isEmpty else {
                continue
            }

            files.append(ParsedMultipartFile(filename: filename, data: fileData))
        }

        guard !files.isEmpty else {
            throw MultipartUploadError.missingFiles(fieldName)
        }
        return files
    }

    private static func parameter(_ name: String, in header: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = #"(?:^|;)\s*"# + escapedName + #"=(?:\"([^\"]*)\"|([^;\s]*))"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let fullRange = NSRange(header.startIndex..<header.endIndex, in: header)
        guard let match = regex.firstMatch(in: header, range: fullRange) else { return nil }
        for captureIndex in 1...2 {
            let range = match.range(at: captureIndex)
            if range.location != NSNotFound, let swiftRange = Range(range, in: header) {
                return String(header[swiftRange])
            }
        }
        return nil
    }

    private static func byteBufferToData(_ buffer: ByteBuffer) -> Data {
        var buffer = buffer
        guard let bytes = buffer.readBytes(length: buffer.readableBytes) else {
            return Data()
        }
        return Data(bytes)
    }

    private static func trimCRLF(from data: inout Data) {
        if data.count >= 2,
           data[data.startIndex] == 13,
           data[data.index(after: data.startIndex)] == 10 {
            data.removeFirst(2)
        }
    }

    private static func trimTrailingCRLF(from data: inout Data) {
        if data.count >= 2 {
            let last = data.index(before: data.endIndex)
            let previous = data.index(before: last)
            guard data[previous] == 13, data[last] == 10 else { return }
            data.removeLast(2)
        }
    }
}
