//
//  ImageProcessingService.swift
//  OcrServer
//

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import Vision

struct RenderedPDFPage: Sendable {
    let pageNumber: Int
    let imageData: Data
}

struct PDFRenderOutput: Sendable {
    let pages: [RenderedPDFPage]
    let totalPageCount: Int
}

struct RectifiedImage: Sendable {
    let data: Data
    let rectified: Bool
}

struct DetectedBarcode: Sendable {
    let payload: String
    let symbology: String
    let confidence: Double
}

enum ImageProcessingError: LocalizedError {
    case invalidPDF
    case invalidPDFOptions(String)
    case pageTooLarge(Int)
    case renderFailed(Int)
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "The uploaded PDF could not be opened"
        case .invalidPDFOptions(let message):
            return message
        case .pageTooLarge(let page):
            return "PDF page \(page) is too large to render safely at the requested DPI"
        case .renderFailed(let page):
            return "Could not render PDF page \(page)"
        case .invalidImage:
            return "The uploaded file is not a supported image"
        }
    }
}

actor ImageProcessingService {
    static let shared = ImageProcessingService()

    private let ciContext = CIContext(options: [.cacheIntermediates: true])
    private let maximumPixelCount = 80_000_000
    private let maximumDimension = 16_384

    private init() {}

    func renderPDF(data: Data, dpi: Int, maximumPages: Int) throws -> PDFRenderOutput {
        guard (72...300).contains(dpi) else {
            throw ImageProcessingError.invalidPDFOptions("'dpi' must be between 72 and 300")
        }
        guard (1...200).contains(maximumPages) else {
            throw ImageProcessingError.invalidPDFOptions("'max_pages' must be between 1 and 200")
        }
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw ImageProcessingError.invalidPDF
        }
        guard document.pageCount <= maximumPages else {
            throw ImageProcessingError.invalidPDFOptions(
                "PDF has \(document.pageCount) pages; pdf_max_pages is \(maximumPages)"
            )
        }

        let pageLimit = document.pageCount
        let scale = CGFloat(dpi) / 72
        var renderedPages: [RenderedPDFPage] = []
        renderedPages.reserveCapacity(pageLimit)

        for pageIndex in 0..<pageLimit {
            guard let page = document.page(at: pageIndex) else {
                throw ImageProcessingError.renderFailed(pageIndex + 1)
            }

            let bounds = page.bounds(for: .mediaBox)
            let width = Int(ceil(bounds.width * scale))
            let height = Int(ceil(bounds.height * scale))
            guard width > 0, height > 0,
                  width <= maximumDimension,
                  height <= maximumDimension,
                  width <= maximumPixelCount / max(1, height) else {
                throw ImageProcessingError.pageTooLarge(pageIndex + 1)
            }

            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw ImageProcessingError.renderFailed(pageIndex + 1)
            }

            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(
                CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
            )
            context.saveGState()
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: scale, y: -scale)
            context.translateBy(x: -bounds.minX, y: -bounds.minY)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()

            guard let image = context.makeImage(),
                  let pngData = Self.pngData(from: image) else {
                throw ImageProcessingError.renderFailed(pageIndex + 1)
            }
            renderedPages.append(
                RenderedPDFPage(pageNumber: pageIndex + 1, imageData: pngData)
            )
        }

        return PDFRenderOutput(
            pages: renderedPages,
            totalPageCount: document.pageCount
        )
    }

    func rectify(data: Data) -> RectifiedImage {
        guard let inputImage = CIImage(
            data: data,
            options: [.applyOrientationProperty: true]
        ) else {
            return RectifiedImage(data: data, rectified: false)
        }

        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(ciImage: inputImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return RectifiedImage(data: data, rectified: false)
        }

        guard let rectangle = request.results?.first,
              let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            return RectifiedImage(data: data, rectified: false)
        }

        let extent = inputImage.extent
        func imagePoint(_ normalizedPoint: CGPoint) -> CIVector {
            CIVector(
                x: extent.minX + normalizedPoint.x * extent.width,
                y: extent.minY + normalizedPoint.y * extent.height
            )
        }

        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(imagePoint(rectangle.topLeft), forKey: "inputTopLeft")
        filter.setValue(imagePoint(rectangle.topRight), forKey: "inputTopRight")
        filter.setValue(imagePoint(rectangle.bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(imagePoint(rectangle.bottomRight), forKey: "inputBottomRight")

        guard let outputImage = filter.outputImage,
              let output = ciContext.createCGImage(outputImage, from: outputImage.extent),
              let outputData = Self.pngData(from: output) else {
            return RectifiedImage(data: data, rectified: false)
        }

        return RectifiedImage(data: outputData, rectified: true)
    }

    func detectBarcodes(data: Data) throws -> [DetectedBarcode] {
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(data: data, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw ImageProcessingError.invalidImage
        }

        return (request.results ?? []).map { observation in
            DetectedBarcode(
                payload: observation.payloadStringValue ?? "",
                symbology: observation.symbology.rawValue,
                confidence: Double(observation.confidence)
            )
        }
    }

    func upscaledCrop(
        data: Data,
        normalizedBox: VisionNormalizedBox,
        scale: Double
    ) -> Data? {
        guard let inputImage = CIImage(
            data: data,
            options: [.applyOrientationProperty: true]
        ) else {
            return nil
        }

        let extent = inputImage.extent
        let paddingX = max(0.006, normalizedBox.width * 0.08)
        let paddingY = max(0.006, normalizedBox.height * 0.25)
        let normalizedCrop = CGRect(
            x: max(0, normalizedBox.x - paddingX),
            y: max(0, normalizedBox.y - paddingY),
            width: min(1, normalizedBox.width + 2 * paddingX),
            height: min(1, normalizedBox.height + 2 * paddingY)
        )
        let cropRect = CGRect(
            x: extent.minX + normalizedCrop.minX * extent.width,
            y: extent.minY + normalizedCrop.minY * extent.height,
            width: normalizedCrop.width * extent.width,
            height: normalizedCrop.height * extent.height
        ).intersection(extent)
        guard !cropRect.isNull, cropRect.width >= 8, cropRect.height >= 8 else {
            return nil
        }

        let boundedScale = CGFloat(min(4, max(1, scale)))
        let outputWidth = Int(ceil(cropRect.width * boundedScale))
        let outputHeight = Int(ceil(cropRect.height * boundedScale))
        guard outputWidth <= maximumDimension,
              outputHeight <= maximumDimension,
              outputWidth <= maximumPixelCount / max(1, outputHeight) else {
            return nil
        }

        let outputImage = inputImage
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(scaleX: boundedScale, y: boundedScale))
        guard let image = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        return Self.pngData(from: image)
    }

    private static func pngData(from image: CGImage) -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                mutableData,
                UTType.png.identifier as CFString,
                1,
                nil
              ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}
