//
//  CoreMLService.swift
//  OcrServer
//

import CoreGraphics
import CoreImage
import CoreML
import CoreVideo
import CryptoKit
import Foundation
import ImageIO
import UIKit
import ZIPFoundation

indirect enum CoreMLJSONValue: Codable, Sendable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([CoreMLJSONValue])
    case object([String: CoreMLJSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([CoreMLJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: CoreMLJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.typeMismatch(
                CoreMLJSONValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported JSON value"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

struct CoreMLFeatureInfo: Codable, Sendable {
    let name: String
    let type: String
    let optional: Bool
    let constraints: [String: CoreMLJSONValue]
}

struct CoreMLModelInfo: Sendable {
    let modelID: String
    let inputs: [CoreMLFeatureInfo]
    let outputs: [CoreMLFeatureInfo]
}

struct CoreMLPredictionResult: Sendable {
    let outputs: [String: CoreMLJSONValue]
    let inferenceMilliseconds: Double
}

enum CoreMLServiceError: LocalizedError {
    case invalidUpload(String)
    case invalidModelID
    case modelNotFound(String)
    case missingInput(String)
    case invalidInput(String)
    case unsupportedFeatureType(String)
    case internalFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidUpload(let message):
            return message
        case .invalidModelID:
            return "Invalid 'model_id'"
        case .modelNotFound(let modelID):
            return "Core ML model not found: \(modelID)"
        case .missingInput(let name):
            return "Missing required input: \(name)"
        case .invalidInput(let message):
            return message
        case .unsupportedFeatureType(let type):
            return "unsupported feature type: \(type)"
        case .internalFailure(let message):
            return message
        }
    }
}

actor CoreMLService {
    static let shared = CoreMLService()

    private struct LoadedModel {
        let model: MLModel
        let compiledURL: URL
    }

    private let fileManager = FileManager.default
    private let maximumExpandedArchiveBytes: UInt64 = 2 * 1024 * 1024 * 1024
    private var loadedModels: [String: LoadedModel] = [:]

    private init() {}

    func upload(data: Data, filename: String) async throws -> CoreMLModelInfo {
        guard !data.isEmpty else {
            throw CoreMLServiceError.invalidUpload("Missing or empty 'file' part")
        }

        let originalName = URL(fileURLWithPath: filename).lastPathComponent
        guard !originalName.isEmpty else {
            throw CoreMLServiceError.invalidUpload("Uploaded model must have a filename")
        }

        let workingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("coreml-upload-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: workingDirectory,
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: workingDirectory) }

        let sourceURL = try prepareModelSource(
            data: data,
            filename: originalName,
            workingDirectory: workingDirectory
        )

        let sourceExtension = sourceURL.pathExtension.lowercased()
        let compiledSourceURL: URL
        if sourceExtension == "mlmodelc" {
            compiledSourceURL = sourceURL
        } else {
            do {
                compiledSourceURL = try await MLModel.compileModel(at: sourceURL)
            } catch {
                throw CoreMLServiceError.invalidUpload(
                    "Core ML could not compile the uploaded \(sourceExtension) model: \(error.localizedDescription)"
                )
            }
        }

        let modelID = Self.makeModelID(filename: originalName, data: data)
        let storageRoot = try modelsDirectory()
        let finalDirectory = storageRoot.appendingPathComponent(modelID, isDirectory: true)
        let finalCompiledURL = finalDirectory.appendingPathComponent("model.mlmodelc", isDirectory: true)

        if fileManager.fileExists(atPath: finalCompiledURL.path) {
            do {
                let record = try loadModel(at: finalCompiledURL)
                loadedModels[modelID] = record
                return Self.modelInfo(modelID: modelID, model: record.model)
            } catch {
                loadedModels.removeValue(forKey: modelID)
            }
        }

        let stageDirectory = storageRoot
            .appendingPathComponent(".stage-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stageDirectory, withIntermediateDirectories: true)
        let stagedCompiledURL = stageDirectory
            .appendingPathComponent("model.mlmodelc", isDirectory: true)
        do {
            try fileManager.copyItem(at: compiledSourceURL, to: stagedCompiledURL)
        } catch {
            try? fileManager.removeItem(at: stageDirectory)
            throw CoreMLServiceError.internalFailure(
                "Could not store the compiled Core ML model: \(error.localizedDescription)"
            )
        }

        do {
            _ = try loadModel(at: stagedCompiledURL)
        } catch {
            try? fileManager.removeItem(at: stageDirectory)
            throw CoreMLServiceError.invalidUpload(
                "Core ML could not load the uploaded model: \(error.localizedDescription)"
            )
        }

        let backupDirectory = storageRoot
            .appendingPathComponent(".backup-\(UUID().uuidString)", isDirectory: true)
        var hasBackup = false
        do {
            if fileManager.fileExists(atPath: finalDirectory.path) {
                try fileManager.moveItem(at: finalDirectory, to: backupDirectory)
                hasBackup = true
            }
            try fileManager.moveItem(at: stageDirectory, to: finalDirectory)
        } catch {
            try? fileManager.removeItem(at: stageDirectory)
            if hasBackup {
                try? fileManager.moveItem(at: backupDirectory, to: finalDirectory)
            }
            throw CoreMLServiceError.internalFailure(
                "Could not activate the uploaded Core ML model: \(error.localizedDescription)"
            )
        }
        if hasBackup {
            try? fileManager.removeItem(at: backupDirectory)
        }

        do {
            let record = try loadModel(at: finalCompiledURL)
            loadedModels[modelID] = record
            return Self.modelInfo(modelID: modelID, model: record.model)
        } catch {
            throw CoreMLServiceError.internalFailure(
                "Stored model could not be reloaded: \(error.localizedDescription)"
            )
        }
    }

    func info(modelID: String) throws -> CoreMLModelInfo {
        let record = try modelRecord(modelID: modelID)
        return Self.modelInfo(modelID: modelID, model: record.model)
    }

    func predict(
        modelID: String,
        inputs: [String: CoreMLJSONValue]
    ) throws -> CoreMLPredictionResult {
        let record = try modelRecord(modelID: modelID)
        let descriptions = record.model.modelDescription.inputDescriptionsByName

        for suppliedName in inputs.keys where descriptions[suppliedName] == nil {
            throw CoreMLServiceError.invalidInput("Unknown model input: \(suppliedName)")
        }

        var featureValues: [String: MLFeatureValue] = [:]
        for name in descriptions.keys.sorted() {
            guard let description = descriptions[name] else { continue }
            guard let input = inputs[name] else {
                if description.isOptional { continue }
                throw CoreMLServiceError.missingInput(name)
            }

            let featureValue = try Self.featureValue(
                from: input,
                description: description,
                featureName: name
            )
            guard description.isAllowedValue(featureValue) else {
                throw CoreMLServiceError.invalidInput(
                    "Input '\(name)' does not satisfy the model constraints"
                )
            }
            featureValues[name] = featureValue
        }

        let provider: MLDictionaryFeatureProvider
        do {
            provider = try MLDictionaryFeatureProvider(dictionary: featureValues)
        } catch {
            throw CoreMLServiceError.invalidInput(
                "Could not create the dynamic feature provider: \(error.localizedDescription)"
            )
        }

        let startedAt = CFAbsoluteTimeGetCurrent()
        let prediction: any MLFeatureProvider
        do {
            prediction = try record.model.prediction(from: provider)
        } catch {
            throw CoreMLServiceError.internalFailure(
                "Core ML prediction failed: \(error.localizedDescription)"
            )
        }
        let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000

        var outputs: [String: CoreMLJSONValue] = [:]
        for name in prediction.featureNames.sorted() {
            guard let value = prediction.featureValue(for: name) else { continue }
            outputs[name] = try Self.jsonValue(from: value, featureName: name)
        }

        return CoreMLPredictionResult(
            outputs: outputs,
            inferenceMilliseconds: elapsedMilliseconds
        )
    }

    func delete(modelID: String) throws {
        try Self.validateModelID(modelID)
        let directory = try modelsDirectory().appendingPathComponent(modelID, isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else {
            loadedModels.removeValue(forKey: modelID)
            throw CoreMLServiceError.modelNotFound(modelID)
        }

        loadedModels.removeValue(forKey: modelID)
        do {
            try fileManager.removeItem(at: directory)
        } catch {
            throw CoreMLServiceError.internalFailure(
                "Could not delete Core ML model '\(modelID)': \(error.localizedDescription)"
            )
        }
    }

    private func modelRecord(modelID: String) throws -> LoadedModel {
        try Self.validateModelID(modelID)
        if let loaded = loadedModels[modelID] {
            return loaded
        }

        let compiledURL = try modelsDirectory()
            .appendingPathComponent(modelID, isDirectory: true)
            .appendingPathComponent("model.mlmodelc", isDirectory: true)
        guard fileManager.fileExists(atPath: compiledURL.path) else {
            throw CoreMLServiceError.modelNotFound(modelID)
        }

        do {
            let record = try loadModel(at: compiledURL)
            loadedModels[modelID] = record
            return record
        } catch {
            throw CoreMLServiceError.internalFailure(
                "Could not load Core ML model '\(modelID)': \(error.localizedDescription)"
            )
        }
    }

    private func loadModel(at compiledURL: URL) throws -> LoadedModel {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        let model = try MLModel(contentsOf: compiledURL, configuration: configuration)
        return LoadedModel(model: model, compiledURL: compiledURL)
    }

    private func modelsDirectory() throws -> URL {
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CoreMLServiceError.internalFailure(
                "Application Support directory is unavailable"
            )
        }

        let directory = applicationSupport
            .appendingPathComponent("OcrServer", isDirectory: true)
            .appendingPathComponent("CoreMLModels", isDirectory: true)
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory
        } catch {
            throw CoreMLServiceError.internalFailure(
                "Could not create Core ML storage: \(error.localizedDescription)"
            )
        }
    }

    private func prepareModelSource(
        data: Data,
        filename: String,
        workingDirectory: URL
    ) throws -> URL {
        let filenameURL = URL(fileURLWithPath: filename)
        let declaredExtension = filenameURL.pathExtension.lowercased()
        let isArchive = data.prefix(2) == Data([0x50, 0x4b])

        if isArchive {
            let archiveURL = workingDirectory.appendingPathComponent("upload.zip")
            let extractedURL = workingDirectory.appendingPathComponent("extracted", isDirectory: true)
            do {
                try data.write(to: archiveURL, options: .atomic)
                let archive = try Archive(url: archiveURL, accessMode: .read)
                var expandedBytes: UInt64 = 0
                for entry in archive {
                    let result = expandedBytes.addingReportingOverflow(entry.uncompressedSize)
                    guard !result.overflow, result.partialValue <= maximumExpandedArchiveBytes else {
                        throw CoreMLServiceError.invalidUpload(
                            "Expanded model archive exceeds the 2 GB limit"
                        )
                    }
                    expandedBytes = result.partialValue
                }
                try fileManager.unzipItem(at: archiveURL, to: extractedURL)
            } catch let error as CoreMLServiceError {
                throw error
            } catch {
                throw CoreMLServiceError.invalidUpload(
                    "Uploaded model archive is invalid: \(error.localizedDescription)"
                )
            }

            let candidates = try modelCandidates(in: extractedURL)
            if candidates.count == 1, let candidate = candidates.first {
                return candidate
            }
            if candidates.count > 1 {
                throw CoreMLServiceError.invalidUpload(
                    "Model archive must contain exactly one .mlmodel, .mlpackage, or .mlmodelc"
                )
            }

            guard ["mlmodel", "mlpackage", "mlmodelc"].contains(declaredExtension) else {
                throw CoreMLServiceError.invalidUpload(
                    "ZIP archive must contain one .mlmodel, .mlpackage, or .mlmodelc"
                )
            }

            let root = try normalizedArchiveRoot(extractedURL)
            let normalizedURL = workingDirectory
                .appendingPathComponent("uploaded.\(declaredExtension)", isDirectory: declaredExtension != "mlmodel")
            do {
                try fileManager.moveItem(at: root, to: normalizedURL)
                return normalizedURL
            } catch {
                throw CoreMLServiceError.invalidUpload(
                    "Could not normalize the model archive: \(error.localizedDescription)"
                )
            }
        }

        guard declaredExtension == "mlmodel" else {
            if declaredExtension == "mlpackage" || declaredExtension == "mlmodelc" {
                throw CoreMLServiceError.invalidUpload(
                    ".\(declaredExtension) is a directory; ZIP it and upload the archive with the original filename"
                )
            }
            throw CoreMLServiceError.invalidUpload(
                "Supported model types are .mlmodel, .mlpackage, and .mlmodelc"
            )
        }

        let sourceURL = workingDirectory.appendingPathComponent("uploaded.mlmodel")
        do {
            try data.write(to: sourceURL, options: .atomic)
            return sourceURL
        } catch {
            throw CoreMLServiceError.internalFailure(
                "Could not stage the uploaded model: \(error.localizedDescription)"
            )
        }
    }

    private func modelCandidates(in directory: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var candidates: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            let ext = item.pathExtension.lowercased()
            guard ["mlmodel", "mlpackage", "mlmodelc"].contains(ext) else { continue }

            let isDirectory = try item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            if ext == "mlmodel", !isDirectory {
                candidates.append(item)
            } else if ext != "mlmodel", isDirectory {
                candidates.append(item)
                enumerator.skipDescendants()
            }
        }
        return candidates
    }

    private func normalizedArchiveRoot(_ extractedURL: URL) throws -> URL {
        let contents = try fileManager.contentsOfDirectory(
            at: extractedURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.lastPathComponent != "__MACOSX" }

        if contents.count == 1, let onlyItem = contents.first {
            return onlyItem
        }
        return extractedURL
    }

    private static func modelInfo(modelID: String, model: MLModel) -> CoreMLModelInfo {
        CoreMLModelInfo(
            modelID: modelID,
            inputs: featureInfo(from: model.modelDescription.inputDescriptionsByName),
            outputs: featureInfo(from: model.modelDescription.outputDescriptionsByName)
        )
    }

    private static func featureInfo(
        from descriptions: [String: MLFeatureDescription]
    ) -> [CoreMLFeatureInfo] {
        descriptions.keys.sorted().compactMap { name in
            guard let description = descriptions[name] else { return nil }
            var constraints: [String: CoreMLJSONValue] = [:]

            if let multiArray = description.multiArrayConstraint {
                constraints["shape"] = .array(
                    multiArray.shape.map { .int(Int64($0.intValue)) }
                )
                constraints["data_type"] = .string(
                    String(describing: multiArray.dataType)
                )
            }
            if let image = description.imageConstraint {
                constraints["width"] = .int(Int64(image.pixelsWide))
                constraints["height"] = .int(Int64(image.pixelsHigh))
                constraints["pixel_format"] = .int(Int64(image.pixelFormatType))
            }
            if let dictionary = description.dictionaryConstraint {
                constraints["key_type"] = .string(featureTypeName(dictionary.keyType))
            }

            return CoreMLFeatureInfo(
                name: name,
                type: featureTypeSummary(description),
                optional: description.isOptional,
                constraints: constraints
            )
        }
    }

    private static func featureTypeSummary(_ description: MLFeatureDescription) -> String {
        switch description.type {
        case .multiArray:
            let shape = description.multiArrayConstraint?.shape.map { $0.intValue } ?? []
            guard !shape.isEmpty else { return "multiArray" }
            return "multiArray[\(shape.map(String.init).joined(separator: "x"))]"
        case .image:
            guard let image = description.imageConstraint else { return "image" }
            return "image[\(image.pixelsWide)x\(image.pixelsHigh)]"
        case .dictionary:
            let keyType = description.dictionaryConstraint
                .map { featureTypeName($0.keyType) } ?? "unknown"
            return "dictionary[\(keyType)]"
        default:
            return featureTypeName(description.type)
        }
    }

    private static func featureTypeName(_ type: MLFeatureType) -> String {
        switch type {
        case .int64:
            return "int64"
        case .double:
            return "double"
        case .string:
            return "string"
        case .image:
            return "image"
        case .multiArray:
            return "multiArray"
        case .dictionary:
            return "dictionary"
        case .sequence:
            return "sequence"
        case .state:
            return "state"
        case .invalid:
            return "invalid"
        @unknown default:
            return String(describing: type)
        }
    }

    private static func featureValue(
        from json: CoreMLJSONValue,
        description: MLFeatureDescription,
        featureName: String
    ) throws -> MLFeatureValue {
        switch description.type {
        case .double:
            switch json {
            case .double(let value):
                return MLFeatureValue(double: value)
            case .int(let value):
                return MLFeatureValue(double: Double(value))
            default:
                throw CoreMLServiceError.invalidInput(
                    "Input '\(featureName)' must be a JSON number"
                )
            }
        case .int64:
            guard case .int(let value) = json else {
                throw CoreMLServiceError.invalidInput(
                    "Input '\(featureName)' must be a JSON integer"
                )
            }
            return MLFeatureValue(int64: value)
        case .string:
            guard case .string(let value) = json else {
                throw CoreMLServiceError.invalidInput(
                    "Input '\(featureName)' must be a JSON string"
                )
            }
            return MLFeatureValue(string: value)
        case .multiArray:
            guard let constraint = description.multiArrayConstraint else {
                throw CoreMLServiceError.invalidInput(
                    "Input '\(featureName)' has no multi-array constraints"
                )
            }
            let flattened = try flattenNumericArray(json, featureName: featureName)
            let modelShape = constraint.shape.map { $0.intValue }
            let targetShape = modelShape.isEmpty ? flattened.shape : modelShape
            guard !targetShape.isEmpty, targetShape.allSatisfy({ $0 > 0 }) else {
                throw CoreMLServiceError.invalidInput(
                    "Input '\(featureName)' has an invalid or unknown shape"
                )
            }

            let expectedCount = try elementCount(
                for: targetShape,
                featureName: featureName
            )
            guard flattened.values.count == expectedCount else {
                throw CoreMLServiceError.invalidInput(
                    "Input '\(featureName)' expected \(expectedCount) values for shape \(targetShape), got \(flattened.values.count)"
                )
            }
            if flattened.shape.count > 1, flattened.shape != targetShape {
                throw CoreMLServiceError.invalidInput(
                    "Input '\(featureName)' has shape \(flattened.shape), expected \(targetShape)"
                )
            }

            let array = try MLMultiArray(
                shape: targetShape.map { NSNumber(value: $0) },
                dataType: constraint.dataType
            )
            for (index, value) in flattened.values.enumerated() {
                array[index] = NSNumber(value: value)
            }
            return MLFeatureValue(multiArray: array)
        case .image:
            guard case .string(let encodedImage) = json else {
                throw CoreMLServiceError.invalidInput(
                    "Input '\(featureName)' must be a base64 image string"
                )
            }
            guard let constraint = description.imageConstraint else {
                throw CoreMLServiceError.invalidInput(
                    "Input '\(featureName)' has no image constraints"
                )
            }
            let base64 = encodedImage.hasPrefix("data:")
                ? String(encodedImage.split(separator: ",", maxSplits: 1).last ?? "")
                : encodedImage
            guard let imageData = Data(base64Encoded: base64),
                  let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw CoreMLServiceError.invalidInput(
                    "Input '\(featureName)' is not a valid base64 image"
                )
            }
            let pixelBuffer = try makePixelBuffer(
                image: image,
                constraint: constraint,
                featureName: featureName
            )
            return MLFeatureValue(pixelBuffer: pixelBuffer)
        default:
            throw CoreMLServiceError.unsupportedFeatureType(
                featureTypeName(description.type)
            )
        }
    }

    private static func flattenNumericArray(
        _ value: CoreMLJSONValue,
        featureName: String
    ) throws -> (values: [Double], shape: [Int]) {
        guard case .array(let items) = value else {
            throw CoreMLServiceError.invalidInput(
                "Input '\(featureName)' must be a numeric JSON array"
            )
        }
        guard !items.isEmpty else {
            return ([], [0])
        }

        var scalarValues: [Double] = []
        var nestedValues: [Double] = []
        var nestedShape: [Int]?
        var containsScalars = false
        var containsArrays = false

        for item in items {
            switch item {
            case .int(let number):
                containsScalars = true
                scalarValues.append(Double(number))
            case .double(let number):
                containsScalars = true
                scalarValues.append(number)
            case .array:
                containsArrays = true
                let child = try flattenNumericArray(item, featureName: featureName)
                if let nestedShape, nestedShape != child.shape {
                    throw CoreMLServiceError.invalidInput(
                        "Input '\(featureName)' must be a rectangular numeric array"
                    )
                }
                nestedShape = child.shape
                nestedValues.append(contentsOf: child.values)
            default:
                throw CoreMLServiceError.invalidInput(
                    "Input '\(featureName)' must contain only JSON numbers"
                )
            }
        }

        guard !(containsScalars && containsArrays) else {
            throw CoreMLServiceError.invalidInput(
                "Input '\(featureName)' must be a rectangular numeric array"
            )
        }
        if containsArrays {
            return (nestedValues, [items.count] + (nestedShape ?? []))
        }
        return (scalarValues, [items.count])
    }

    private static func elementCount(
        for shape: [Int],
        featureName: String
    ) throws -> Int {
        var count = 1
        for dimension in shape {
            let result = count.multipliedReportingOverflow(by: dimension)
            guard !result.overflow else {
                throw CoreMLServiceError.invalidInput(
                    "Input '\(featureName)' shape is too large"
                )
            }
            count = result.partialValue
        }
        return count
    }

    private static func makePixelBuffer(
        image: CGImage,
        constraint: MLImageConstraint,
        featureName: String
    ) throws -> CVPixelBuffer {
        let width = constraint.pixelsWide > 0 ? constraint.pixelsWide : image.width
        let height = constraint.pixelsHigh > 0 ? constraint.pixelsHigh : image.height
        guard width > 0, height > 0 else {
            throw CoreMLServiceError.invalidInput(
                "Input '\(featureName)' has invalid image dimensions"
            )
        }

        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            constraint.pixelFormatType,
            attributes,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw CoreMLServiceError.invalidInput(
                "Could not allocate an image buffer for input '\(featureName)'"
            )
        }

        let scaleX = CGFloat(width) / CGFloat(image.width)
        let scaleY = CGFloat(height) / CGFloat(image.height)
        let scaledImage = CIImage(cgImage: image)
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        CIContext(options: nil).render(scaledImage, to: pixelBuffer)
        return pixelBuffer
    }

    private static func jsonValue(
        from value: MLFeatureValue,
        featureName: String
    ) throws -> CoreMLJSONValue {
        switch value.type {
        case .double:
            return try finiteJSONNumber(value.doubleValue, featureName: featureName)
        case .int64:
            return .int(value.int64Value)
        case .string:
            return .string(value.stringValue)
        case .multiArray:
            guard let array = value.multiArrayValue else {
                throw CoreMLServiceError.internalFailure(
                    "Output '\(featureName)' did not contain a multi-array"
                )
            }
            var numbers: [CoreMLJSONValue] = []
            numbers.reserveCapacity(array.count)
            for index in 0..<array.count {
                numbers.append(
                    try finiteJSONNumber(
                        array[index].doubleValue,
                        featureName: featureName
                    )
                )
            }
            return .array(numbers)
        case .dictionary:
            var dictionary: [String: CoreMLJSONValue] = [:]
            for (key, number) in value.dictionaryValue {
                dictionary[String(describing: key)] = try finiteJSONNumber(
                    number.doubleValue,
                    featureName: featureName
                )
            }
            return .object(dictionary)
        case .image:
            guard let pixelBuffer = value.imageBufferValue else {
                throw CoreMLServiceError.internalFailure(
                    "Output '\(featureName)' did not contain an image buffer"
                )
            }
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext(options: nil)
            guard let image = context.createCGImage(ciImage, from: ciImage.extent),
                  let pngData = UIImage(cgImage: image).pngData() else {
                throw CoreMLServiceError.internalFailure(
                    "Could not encode image output '\(featureName)'"
                )
            }
            return .string(pngData.base64EncodedString())
        default:
            throw CoreMLServiceError.unsupportedFeatureType(
                featureTypeName(value.type)
            )
        }
    }

    private static func finiteJSONNumber(
        _ value: Double,
        featureName: String
    ) throws -> CoreMLJSONValue {
        guard value.isFinite else {
            throw CoreMLServiceError.internalFailure(
                "Output '\(featureName)' contains a non-finite number"
            )
        }
        return .double(value)
    }

    private static func makeModelID(filename: String, data: Data) -> String {
        var filenameURL = URL(fileURLWithPath: filename)
        if filenameURL.pathExtension.lowercased() == "zip" {
            filenameURL.deletePathExtension()
        }
        filenameURL.deletePathExtension()

        var base = filenameURL.lastPathComponent.lowercased()
            .replacingOccurrences(
                of: "[^a-z0-9]+",
                with: "-",
                options: .regularExpression
            )
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if base.isEmpty { base = "model" }
        base = String(base.prefix(48))

        let digest = SHA256.hash(data: data)
        let hash = digest.prefix(8).map {
            String(format: "%02x", Int($0))
        }.joined()
        return "\(base)-\(hash)"
    }

    private static func validateModelID(_ modelID: String) throws {
        guard !modelID.isEmpty,
              modelID.count <= 96,
              modelID.range(
                of: "^[a-z0-9][a-z0-9-]*$",
                options: .regularExpression
              ) != nil else {
            throw CoreMLServiceError.invalidModelID
        }
    }
}
