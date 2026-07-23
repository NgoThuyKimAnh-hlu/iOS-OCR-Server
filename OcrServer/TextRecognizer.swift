//
//  TextRecognizer.swift
//  OcrServer
//
//  Created by Riddle Ling on 2025/8/1.
//

import Foundation
import ImageIO
import Vision

struct VisionNormalizedBox: Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct OCRCandidateValue: Sendable {
    let text: String
    let confidence: Double
}

struct OCRVisionLine: Sendable {
    let candidates: [OCRCandidateValue]
    let normalizedBox: VisionNormalizedBox
    let pixelBox: OCRBoxItem

    var text: String { candidates.first?.text ?? "" }
    var confidence: Double { candidates.first?.confidence ?? 0 }
    var candidateGap: Double {
        guard candidates.count > 1 else { return confidence }
        return max(0, confidence - candidates[1].confidence)
    }

    func replacingCandidates(_ candidates: [OCRCandidateValue]) -> OCRVisionLine {
        OCRVisionLine(
            candidates: candidates,
            normalizedBox: normalizedBox,
            pixelBox: OCRBoxItem(
                text: candidates.first?.text ?? pixelBox.text,
                x: pixelBox.x,
                y: pixelBox.y,
                w: pixelBox.w,
                h: pixelBox.h,
                rect: pixelBox.rect
            )
        )
    }
}

struct OCRVisionOutput: Sendable {
    let imageWidth: Int
    let imageHeight: Int
    var lines: [OCRVisionLine]
    let visionMilliseconds: Double

    var text: String {
        lines.map(\.text).joined(separator: "\n")
    }

    var meanConfidence: Double {
        guard !lines.isEmpty else { return 0 }
        return lines.map(\.confidence).reduce(0, +) / Double(lines.count)
    }

    var result: OCRResult {
        OCRResult(
            text: text,
            image_width: imageWidth,
            image_height: imageHeight,
            boxes: lines.map(\.pixelBox)
        )
    }
}

final class TextRecognizer {
    let recognitionLevel: RecognizeTextRequest.RecognitionLevel
    let recognitionLanguages: [String]
    let usesLanguageCorrection: Bool
    let automaticallyDetectsLanguage: Bool
    let minimumTextHeight: Double
    let visionRevision: Int

    init(
        recognitionLevel: RecognizeTextRequest.RecognitionLevel = .accurate,
        recognitionLanguages: [String] = ["vi-VT", "en"],
        usesLanguageCorrection: Bool = true,
        automaticallyDetectsLanguage: Bool = true,
        minimumTextHeight: Double = 0,
        visionRevision: Int = 0
    ) {
        self.recognitionLevel = recognitionLevel
        self.recognitionLanguages = recognitionLanguages
        self.usesLanguageCorrection = usesLanguageCorrection
        self.automaticallyDetectsLanguage = automaticallyDetectsLanguage
        self.minimumTextHeight = minimumTextHeight
        self.visionRevision = visionRevision
    }

    func getOcrResult(data: Data, customWords: [String] = []) async -> OCRResult? {
        await recognizeDetailed(
            data: data,
            customWords: customWords,
            maximumCandidates: 1
        )?.result
    }

    func recognizeDetailed(
        data: Data,
        customWords: [String],
        maximumCandidates: Int = 2
    ) async -> OCRVisionOutput? {
        guard let (width, height) = Self.imagePixelSize(from: data) else {
            return nil
        }

        var request = RecognizeTextRequest(visionRevision == 3 ? .revision3 : nil)
        request.recognitionLevel = recognitionLevel
        request.usesLanguageCorrection = usesLanguageCorrection
        request.automaticallyDetectsLanguage = automaticallyDetectsLanguage
        request.recognitionLanguages = recognitionLanguages.map {
            Locale.Language(identifier: $0)
        }
        request.minimumTextHeightFraction = Float(minimumTextHeight)
        if !customWords.isEmpty {
            request.customWords = customWords
        }

        let started = DispatchTime.now().uptimeNanoseconds
        let observations = (try? await request.perform(on: data)) ?? []
        let visionMilliseconds = Self.elapsedMilliseconds(since: started)
        var lines: [OCRVisionLine] = []
        lines.reserveCapacity(observations.count)

        func toPixel(_ point: NormalizedPoint) -> (Double, Double) {
            let x = Double(point.x * Double(width))
            let y = Double((1 - point.y) * Double(height))
            return (x, y)
        }

        for observation in observations {
            let recognized = observation.topCandidates(max(1, maximumCandidates))
            guard let best = recognized.first else { continue }
            let candidates = recognized.map {
                OCRCandidateValue(text: $0.string, confidence: Double($0.confidence))
            }

            let normalizedX = [
                Double(observation.topLeft.x),
                Double(observation.topRight.x),
                Double(observation.bottomLeft.x),
                Double(observation.bottomRight.x),
            ]
            let normalizedY = [
                Double(observation.topLeft.y),
                Double(observation.topRight.y),
                Double(observation.bottomLeft.y),
                Double(observation.bottomRight.y),
            ]
            let minNormalizedX = normalizedX.min() ?? 0
            let maxNormalizedX = normalizedX.max() ?? 0
            let minNormalizedY = normalizedY.min() ?? 0
            let maxNormalizedY = normalizedY.max() ?? 0

            let corners = [
                CGPoint(
                    x: observation.topLeft.x * CGFloat(width),
                    y: (1 - observation.topLeft.y) * CGFloat(height)
                ),
                CGPoint(
                    x: observation.topRight.x * CGFloat(width),
                    y: (1 - observation.topRight.y) * CGFloat(height)
                ),
                CGPoint(
                    x: observation.bottomRight.x * CGFloat(width),
                    y: (1 - observation.bottomRight.y) * CGFloat(height)
                ),
                CGPoint(
                    x: observation.bottomLeft.x * CGFloat(width),
                    y: (1 - observation.bottomLeft.y) * CGFloat(height)
                ),
            ]
            let minX = corners.map(\.x).min() ?? 0
            let maxX = corners.map(\.x).max() ?? 0
            let minY = corners.map(\.y).min() ?? 0
            let maxY = corners.map(\.y).max() ?? 0

            var rectItem: OCRRectItem?
            if let rect = best.boundingBox(for: best.string.startIndex..<best.string.endIndex) {
                let topLeft = toPixel(rect.topLeft)
                let topRight = toPixel(rect.topRight)
                let bottomLeft = toPixel(rect.bottomLeft)
                let bottomRight = toPixel(rect.bottomRight)
                rectItem = OCRRectItem(
                    topLeft_x: topLeft.0,
                    topLeft_y: topLeft.1,
                    topRight_x: topRight.0,
                    topRight_y: topRight.1,
                    bottomLeft_x: bottomLeft.0,
                    bottomLeft_y: bottomLeft.1,
                    bottomRight_x: bottomRight.0,
                    bottomRight_y: bottomRight.1
                )
            }

            lines.append(
                OCRVisionLine(
                    candidates: candidates,
                    normalizedBox: VisionNormalizedBox(
                        x: minNormalizedX,
                        y: minNormalizedY,
                        width: maxNormalizedX - minNormalizedX,
                        height: maxNormalizedY - minNormalizedY
                    ),
                    pixelBox: OCRBoxItem(
                        text: best.string,
                        x: Double(minX),
                        y: Double(minY),
                        w: Double(maxX - minX),
                        h: Double(maxY - minY),
                        rect: rectItem
                    )
                )
            )
        }

        return OCRVisionOutput(
            imageWidth: width,
            imageHeight: height,
            lines: lines,
            visionMilliseconds: visionMilliseconds
        )
    }

    private static func imagePixelSize(from data: Data) -> (Int, Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                0,
                nil
              ) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue else {
            return nil
        }
        return (width, height)
    }

    private static func elapsedMilliseconds(since started: UInt64) -> Double {
        let elapsed = DispatchTime.now().uptimeNanoseconds - started
        return Double(elapsed) / 1_000_000
    }
}
