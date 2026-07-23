//
//  VaporServer.swift
//  OcrServer
//
//  Created by Riddle Ling on 2025/8/21.
//

import Vapor
import Vision

struct OCRRectItem: Content, Sendable {
    let topLeft_x: Double
    let topLeft_y: Double
    let topRight_x: Double
    let topRight_y: Double
    let bottomLeft_x: Double
    let bottomLeft_y: Double
    let bottomRight_x: Double
    let bottomRight_y: Double
}

struct OCRBoxItem: Content, Sendable {
    let text: String
    let x: Double
    let y: Double
    let w: Double
    let h: Double
    let rect: OCRRectItem?
}

struct OCRResult: Content, Sendable {
    let text: String
    let image_width: Int
    let image_height: Int
    let orientation: Int
    let boxes: [OCRBoxItem]
}

private enum OCRContract {
    // The PC engine depends on these response fields remaining stable.
    static let schemaVersion = 1
    static let bboxCoordinateSystem = "vision_normalized_origin_bottom_left_range_0_1"
}

struct DocOCRResult: Content {
    let success: Bool
    let message: String
    let ocr_text: String
    let rectified: Bool?
    let raw: String
    let improved: String
    let mean_confidence: Double
    let page_score: Double
    let line_scores: [OCRLineScoreResponse]
    let flags: [String]
    let needs_pass2: Bool
    let corrections_applied: Int
    let improve_ms: Double
    let pack_id: String
    let pack_version: String
    let pack_hash: String
    let build_version: String
    let schema_version: Int
    let dpi_used: Int?
    let thermal_throttling: Bool
    let thermal: String

    init(
        success: Bool,
        message: String,
        ocr_text: String,
        rectified: Bool? = nil,
        improvement: OCRImprovementResult? = nil,
        dpi_used: Int? = nil
    ) {
        self.success = success
        self.message = message
        self.ocr_text = ocr_text
        self.rectified = rectified
        self.raw = improvement?.raw ?? ocr_text
        self.improved = improvement?.improved ?? ocr_text
        self.mean_confidence = improvement?.meanConfidence ?? 0
        self.page_score = improvement?.pageScore ?? 0
        self.line_scores = improvement?.lineScores ?? []
        self.flags = improvement?.flags ?? []
        self.needs_pass2 = improvement?.needsPass2 ?? false
        self.corrections_applied = improvement?.correctionsApplied ?? 0
        self.improve_ms = improvement?.improveMilliseconds ?? 0
        self.pack_id = improvement?.pack.id ?? "none"
        self.pack_version = improvement?.pack.version ?? ""
        self.pack_hash = improvement?.pack.hash ?? ""
        self.build_version = BuildInfo.versionStamp
        self.schema_version = OCRContract.schemaVersion
        self.dpi_used = dpi_used
        let thermalStatus = ThermalStatus.current()
        self.thermal_throttling = thermalStatus.thermalThrottling
        self.thermal = thermalStatus.thermal
    }
}

struct UploadResponse: Content {
    let success: Bool
    let message: String
    let ocr_result: String
    let image_width: Int
    let image_height: Int
    let ocr_boxes: [OCRBoxItem]
    let rectified: Bool?
    let raw: String
    let improved: String
    let mean_confidence: Double
    let page_score: Double
    let line_scores: [OCRLineScoreResponse]
    let flags: [String]
    let needs_pass2: Bool
    let pass2_regions: [OCRPass2RegionResponse]
    let full_page_fallback: Bool
    let bbox_coordinate_system: String
    let orientation: Int?
    let corrections_applied: Int
    let improve_ms: Double
    let pack_id: String
    let pack_version: String
    let pack_hash: String
    let build_version: String
    let schema_version: Int
    let dpi_used: Int?
    let thermal_throttling: Bool
    let thermal: String

    init(
        success: Bool,
        message: String,
        ocr_result: String,
        image_width: Int,
        image_height: Int,
        ocr_boxes: [OCRBoxItem],
        rectified: Bool? = nil,
        improvement: OCRImprovementResult? = nil,
        dpi_used: Int? = nil
    ) {
        self.success = success
        self.message = message
        self.ocr_result = ocr_result
        self.image_width = image_width
        self.image_height = image_height
        self.ocr_boxes = ocr_boxes
        self.rectified = rectified
        self.raw = improvement?.raw ?? ocr_result
        self.improved = improvement?.improved ?? ocr_result
        self.mean_confidence = improvement?.meanConfidence ?? 0
        self.page_score = improvement?.pageScore ?? 0
        self.line_scores = improvement?.lineScores ?? []
        self.flags = improvement?.flags ?? []
        self.needs_pass2 = improvement?.needsPass2 ?? false
        self.pass2_regions = improvement?.pass2Regions ?? []
        self.full_page_fallback = improvement?.fullPageFallback ?? false
        self.bbox_coordinate_system = OCRContract.bboxCoordinateSystem
        self.orientation = improvement?.ocrResult.orientation
        self.corrections_applied = improvement?.correctionsApplied ?? 0
        self.improve_ms = improvement?.improveMilliseconds ?? 0
        self.pack_id = improvement?.pack.id ?? "none"
        self.pack_version = improvement?.pack.version ?? ""
        self.pack_hash = improvement?.pack.hash ?? ""
        self.build_version = BuildInfo.versionStamp
        self.schema_version = OCRContract.schemaVersion
        self.dpi_used = dpi_used
        let thermalStatus = ThermalStatus.current()
        self.thermal_throttling = thermalStatus.thermalThrottling
        self.thermal = thermalStatus.thermal
    }
}

struct PDFUploadPageResponse: Content {
    let page: Int
    let success: Bool
    let message: String
    let ocr_result: String
    let image_width: Int
    let image_height: Int
    let ocr_boxes: [OCRBoxItem]
    let rectified: Bool?
    let raw: String
    let improved: String
    let mean_confidence: Double
    let page_score: Double
    let line_scores: [OCRLineScoreResponse]
    let flags: [String]
    let needs_pass2: Bool
    let pass2_regions: [OCRPass2RegionResponse]
    let full_page_fallback: Bool
    let bbox_coordinate_system: String
    let orientation: Int?
    let corrections_applied: Int
    let improve_ms: Double
    let pack_id: String
    let pack_version: String
    let pack_hash: String
    let build_version: String
    let schema_version: Int
    let dpi_used: Int
    let thermal_throttling: Bool
    let thermal: String

    init(
        page: Int,
        success: Bool,
        message: String,
        improvement: OCRImprovementResult?,
        rectified: Bool?,
        dpi_used: Int
    ) {
        self.page = page
        self.success = success
        self.message = message
        self.ocr_result = improvement?.selectedText ?? ""
        self.image_width = improvement?.ocrResult.image_width ?? 0
        self.image_height = improvement?.ocrResult.image_height ?? 0
        self.ocr_boxes = improvement?.ocrResult.boxes ?? []
        self.rectified = rectified
        self.raw = improvement?.raw ?? ""
        self.improved = improvement?.improved ?? ""
        self.mean_confidence = improvement?.meanConfidence ?? 0
        self.page_score = improvement?.pageScore ?? 0
        self.line_scores = improvement?.lineScores ?? []
        self.flags = improvement?.flags ?? []
        self.needs_pass2 = improvement?.needsPass2 ?? true
        self.pass2_regions = improvement?.pass2Regions ?? []
        self.full_page_fallback = improvement?.fullPageFallback ?? true
        self.bbox_coordinate_system = OCRContract.bboxCoordinateSystem
        self.orientation = improvement?.ocrResult.orientation
        self.corrections_applied = improvement?.correctionsApplied ?? 0
        self.improve_ms = improvement?.improveMilliseconds ?? 0
        self.pack_id = improvement?.pack.id ?? "none"
        self.pack_version = improvement?.pack.version ?? ""
        self.pack_hash = improvement?.pack.hash ?? ""
        self.build_version = BuildInfo.versionStamp
        self.schema_version = OCRContract.schemaVersion
        self.dpi_used = dpi_used
        let thermalStatus = ThermalStatus.current()
        self.thermal_throttling = thermalStatus.thermalThrottling
        self.thermal = thermalStatus.thermal
    }
}

struct PDFUploadResponse: Content {
    let success: Bool
    let message: String
    let pages: [PDFUploadPageResponse]
    let page_count: Int
    let raw: String
    let improved: String
    let page_score: Double
    let line_scores: [OCRLineScoreResponse]
    let flags: [String]
    let needs_pass2: Bool
    let full_page_fallback: Bool
    let mean_confidence: Double
    let corrections_applied: Int
    let build_version: String
    let schema_version: Int
    let dpi_used: Int
    let thermal_throttling: Bool
    let thermal: String

    init(success: Bool, message: String, pages: [PDFUploadPageResponse]) {
        self.success = success
        self.message = message
        self.pages = pages
        self.page_count = pages.count
        self.raw = pages.map(\.raw).joined(separator: "\n\n")
        self.improved = pages.map(\.improved).joined(separator: "\n\n")
        self.page_score = pages.map(\.page_score).min() ?? 0
        self.line_scores = pages.flatMap(\.line_scores)
        self.flags = Array(Set(pages.flatMap(\.flags))).sorted()
        self.needs_pass2 = pages.contains { $0.needs_pass2 }
        self.full_page_fallback = pages.contains { $0.full_page_fallback }
        self.mean_confidence = Self.mean(pages.map(\.mean_confidence))
        self.corrections_applied = pages.reduce(0) { $0 + $1.corrections_applied }
        self.build_version = BuildInfo.versionStamp
        self.schema_version = OCRContract.schemaVersion
        self.dpi_used = pages.first?.dpi_used ?? 0
        let thermalStatus = ThermalStatus.current()
        self.thermal_throttling = thermalStatus.thermalThrottling
        self.thermal = thermalStatus.thermal
    }

    private static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}

struct PDFDocOCRPageResponse: Content {
    let page: Int
    let success: Bool
    let message: String
    let ocr_text: String
    let rectified: Bool?
    let raw: String
    let improved: String
    let mean_confidence: Double
    let page_score: Double
    let line_scores: [OCRLineScoreResponse]
    let flags: [String]
    let needs_pass2: Bool
    let corrections_applied: Int
    let improve_ms: Double
    let pack_id: String
    let pack_version: String
    let pack_hash: String
    let build_version: String
    let schema_version: Int
    let dpi_used: Int
    let thermal_throttling: Bool
    let thermal: String

    init(
        page: Int,
        success: Bool,
        message: String,
        improvement: OCRImprovementResult?,
        rectified: Bool?,
        dpi_used: Int
    ) {
        self.page = page
        self.success = success
        self.message = message
        self.ocr_text = improvement?.selectedText ?? ""
        self.rectified = rectified
        self.raw = improvement?.raw ?? ""
        self.improved = improvement?.improved ?? ""
        self.mean_confidence = improvement?.meanConfidence ?? 0
        self.page_score = improvement?.pageScore ?? 0
        self.line_scores = improvement?.lineScores ?? []
        self.flags = improvement?.flags ?? []
        self.needs_pass2 = improvement?.needsPass2 ?? true
        self.corrections_applied = improvement?.correctionsApplied ?? 0
        self.improve_ms = improvement?.improveMilliseconds ?? 0
        self.pack_id = improvement?.pack.id ?? "none"
        self.pack_version = improvement?.pack.version ?? ""
        self.pack_hash = improvement?.pack.hash ?? ""
        self.build_version = BuildInfo.versionStamp
        self.schema_version = OCRContract.schemaVersion
        self.dpi_used = dpi_used
        let thermalStatus = ThermalStatus.current()
        self.thermal_throttling = thermalStatus.thermalThrottling
        self.thermal = thermalStatus.thermal
    }
}

struct PDFDocOCRResponse: Content {
    let success: Bool
    let message: String
    let pages: [PDFDocOCRPageResponse]
    let page_count: Int
    let raw: String
    let improved: String
    let page_score: Double
    let line_scores: [OCRLineScoreResponse]
    let flags: [String]
    let needs_pass2: Bool
    let mean_confidence: Double
    let corrections_applied: Int
    let build_version: String
    let schema_version: Int
    let dpi_used: Int
    let thermal_throttling: Bool
    let thermal: String

    init(success: Bool, message: String, pages: [PDFDocOCRPageResponse]) {
        self.success = success
        self.message = message
        self.pages = pages
        self.page_count = pages.count
        self.raw = pages.map(\.raw).joined(separator: "\n\n")
        self.improved = pages.map(\.improved).joined(separator: "\n\n")
        self.page_score = pages.map(\.page_score).min() ?? 0
        self.line_scores = pages.flatMap(\.line_scores)
        self.flags = Array(Set(pages.flatMap(\.flags))).sorted()
        self.needs_pass2 = pages.contains { $0.needs_pass2 }
        self.mean_confidence = Self.mean(pages.map(\.mean_confidence))
        self.corrections_applied = pages.reduce(0) { $0 + $1.corrections_applied }
        self.build_version = BuildInfo.versionStamp
        self.schema_version = OCRContract.schemaVersion
        self.dpi_used = pages.first?.dpi_used ?? 0
        let thermalStatus = ThermalStatus.current()
        self.thermal_throttling = thermalStatus.thermalThrottling
        self.thermal = thermalStatus.thermal
    }

    private static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}

struct BatchUploadResponse: Content {
    let filename: String
    let success: Bool
    let message: String
    let ocr_result: String
    let image_width: Int
    let image_height: Int
    let ocr_boxes: [OCRBoxItem]
    let thermal_throttling: Bool
    let thermal: String

    init(
        filename: String,
        success: Bool,
        message: String,
        ocr_result: String,
        image_width: Int,
        image_height: Int,
        ocr_boxes: [OCRBoxItem]
    ) {
        self.filename = filename
        self.success = success
        self.message = message
        self.ocr_result = ocr_result
        self.image_width = image_width
        self.image_height = image_height
        self.ocr_boxes = ocr_boxes
        let thermalStatus = ThermalStatus.current()
        self.thermal_throttling = thermalStatus.thermalThrottling
        self.thermal = thermalStatus.thermal
    }
}

struct FieldBatchResult: Content, Sendable {
    let filename: String
    let success: Bool
    let message: String
    let completed: Int
    let total: Int
    let format: String
    let text: String
    let raw: String
    let improved: String
    let page_score: Double
    let line_scores: [OCRLineScoreResponse]
    let flags: [String]
    let needs_pass2: Bool
    let mean_confidence: Double
    let corrections_applied: Int
    let build_version: String
    let schema_version: Int
    let dpi_used: Int?
    let thermal_throttling: Bool
    let thermal: String

    init(
        filename: String,
        completed: Int,
        total: Int,
        format: String,
        results: [OCRImprovementResult],
        pageSeparator: String,
        dpi_used: Int? = nil
    ) {
        self.filename = filename
        self.success = !results.isEmpty
        self.message = results.isEmpty ? "OCR failed" : "OCR completed successfully"
        self.completed = completed
        self.total = total
        self.format = format
        self.text = results.map(\.selectedText).joined(separator: pageSeparator)
        self.raw = results.map(\.raw).joined(separator: "\n\n")
        self.improved = results.map(\.improved).joined(separator: "\n\n")
        self.page_score = results.map(\.pageScore).min() ?? 0
        self.line_scores = results.flatMap(\.lineScores)
        self.flags = Array(Set(results.flatMap(\.flags))).sorted()
        self.needs_pass2 = results.isEmpty || results.contains { $0.needsPass2 }
        self.mean_confidence = Self.mean(results.map(\.meanConfidence))
        self.corrections_applied = results.reduce(0) { $0 + $1.correctionsApplied }
        self.build_version = BuildInfo.versionStamp
        self.schema_version = OCRContract.schemaVersion
        self.dpi_used = dpi_used
        let thermalStatus = ThermalStatus.current()
        self.thermal_throttling = thermalStatus.thermalThrottling
        self.thermal = thermalStatus.thermal
    }

    init(
        filename: String,
        completed: Int,
        total: Int,
        format: String,
        error: Error,
        dpi_used: Int? = nil
    ) {
        self.filename = filename
        self.success = false
        self.message = error.localizedDescription
        self.completed = completed
        self.total = total
        self.format = format
        self.text = ""
        self.raw = ""
        self.improved = ""
        self.page_score = 0
        self.line_scores = []
        self.flags = ["ocr_failed"]
        self.needs_pass2 = true
        self.mean_confidence = 0
        self.corrections_applied = 0
        self.build_version = BuildInfo.versionStamp
        self.schema_version = OCRContract.schemaVersion
        self.dpi_used = dpi_used
        let thermalStatus = ThermalStatus.current()
        self.thermal_throttling = thermalStatus.thermalThrottling
        self.thermal = thermalStatus.thermal
    }

    private static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}

struct BarcodeItemResponse: Content {
    let payload: String
    let symbology: String
    let confidence: Double
}

struct BarcodeResponse: Content {
    let codes: [BarcodeItemResponse]
}

struct TranslateRequestBody: Content {
    let text: String
    let target: String
    let source: String?
}

struct TranslateResponse: Content {
    let success: Bool
    let translated: String
    let source: String
    let target: String
}

struct TranscribeResponse: Content {
    let success: Bool
    let text: String
    let locale: String
}

struct SynthesizeRequestBody: Content {
    let text: String
    let lang: String?
    let rate: Float?
}

struct LLMRequestBody: Content {
    let prompt: String
    let system: String?
    let max: Int?
}

struct LLMResponse: Content {
    let success: Bool
    let text: String
}

struct NERRequestBody: Content {
    let text: String
}

struct NEREntityResponse: Content {
    let text: String
    let type: String
}

struct NERResponse: Content {
    let success: Bool
    let entities: [NEREntityResponse]
    let so_hieu: [String]
    let dieu_khoan: [String]
}

struct EmbedRequestBody: Content {
    let text: String
}

struct EmbedResponse: Content {
    let success: Bool
    let vector: [Double]
    let dim: Int
}

struct CoreMLPredictRequestBody: Content {
    let model_id: String
    let inputs: [String: CoreMLJSONValue]
}

struct CoreMLModelResponse: Content {
    let success: Bool
    let model_id: String
    let input: [CoreMLFeatureInfo]
    let output: [CoreMLFeatureInfo]
}

struct CoreMLPredictResponse: Content {
    let success: Bool
    let outputs: [String: CoreMLJSONValue]
    let compute: String
    let inference_ms: Double
}

struct CoreMLDeleteResponse: Content {
    let success: Bool
    let model_id: String
}

struct ComputeErrorResponse: Content {
    let success: Bool
    let message: String
}

struct AdminSettingDescriptor: Content, Sendable {
    let key: String
    let type: String
    let minimum: Double?
    let maximum: Double?
    let options: [String]?
    let requires_restart: Bool
    let secret: Bool
}

struct AdminSettingsResponse: Content, Sendable {
    let schema: [AdminSettingDescriptor]
    let recognition_level: String
    let recognition_languages: [String]
    let uses_language_correction: Bool
    let language_correction: Bool
    let automatically_detects_language: Bool
    let minimum_text_height: Double
    let vision_revision: Int
    let improve: Bool
    let corrector_groups: [String]
    let active_pack: String
    let ambiguous_skip: Bool
    let confidence_threshold: Double
    let multipass: Bool
    let roi_upscale: Double
    let max_roi_count: Int
    let page_score_pass2_threshold: Double
    let pass2_fallback_ratio: Double
    let legal_id_regex: String
    let possible_legal_id_regex: String
    let candidate_gap_threshold: Double
    let candidate_gap_confidence_threshold: Double
    let candidate_gap_normalizer: Double
    let line_confidence_weight: Double
    let missing_page_number_min_pages: Int
    let broken_table_min_lines: Int
    let low_confidence_penalty: Double
    let invalid_legal_id_penalty: Double
    let missing_page_number_penalty: Double
    let broken_table_penalty: Double
    let multipass_min_confidence_gain: Double
    let multipass_legal_id_tolerance: Double
    let multipass_min_length_ratio: Double
    let multipass_max_length_ratio: Double
    let pdf_dpi: Int
    let hot_dpi: Int
    let pdf_max_pages: Int
    let rectify_default: Bool
    let http_port: Int
    let keep_alive: Bool
    let keep_alive_own_session: Bool
    let auto_blackout_idle_s: Int
    let blackout: Bool
    let watchdog_interval_s: Double
    let debug_verbose: Bool
    let admin_token: String
    let admin_token_configured: Bool
    let thermal_guard: Bool
    let max_queue: Int
    let max_inflight: Int
    let fair_gap_ms: Int
    let max_upload_mb: Int
    let max_batch_files: Int
}

struct AdminSettingsPatch: Content, Sendable {
    let recognition_level: String?
    let recognition_languages: [String]?
    let uses_language_correction: Bool?
    let language_correction: Bool?
    let automatically_detects_language: Bool?
    let minimum_text_height: Double?
    let vision_revision: Int?
    let improve: Bool?
    let corrector_groups: [String]?
    let active_pack: String?
    let ambiguous_skip: Bool?
    let confidence_threshold: Double?
    let multipass: Bool?
    let roi_upscale: Double?
    let max_roi_count: Int?
    let page_score_pass2_threshold: Double?
    let pass2_fallback_ratio: Double?
    let legal_id_regex: String?
    let possible_legal_id_regex: String?
    let candidate_gap_threshold: Double?
    let candidate_gap_confidence_threshold: Double?
    let candidate_gap_normalizer: Double?
    let line_confidence_weight: Double?
    let missing_page_number_min_pages: Int?
    let broken_table_min_lines: Int?
    let low_confidence_penalty: Double?
    let invalid_legal_id_penalty: Double?
    let missing_page_number_penalty: Double?
    let broken_table_penalty: Double?
    let multipass_min_confidence_gain: Double?
    let multipass_legal_id_tolerance: Double?
    let multipass_min_length_ratio: Double?
    let multipass_max_length_ratio: Double?
    let pdf_dpi: Int?
    let hot_dpi: Int?
    let pdf_max_pages: Int?
    let rectify_default: Bool?
    let http_port: Int?
    let keep_alive: Bool?
    let keep_alive_own_session: Bool?
    let auto_blackout_idle_s: Int?
    let blackout: Bool?
    let watchdog_interval_s: Double?
    let debug_verbose: Bool?
    let admin_token: String?
    let thermal_guard: Bool?
    let max_queue: Int?
    let max_inflight: Int?
    let fair_gap_ms: Int?
    let max_upload_mb: Int?
    let max_batch_files: Int?
}

struct AdminApplyResponse: Content, Sendable {
    let applied: [String]
    let rejected: [String]
    let restarted: Bool

    init(applied: [String], rejected: [String] = [], restarted: Bool) {
        self.applied = applied
        self.rejected = rejected
        self.restarted = restarted
    }
}

struct AdminRestartResponse: Content, Sendable {
    let ok: Bool
}

struct AdminKeepAliveRequest: Content, Sendable {
    let on: Bool
}

struct AdminLogResponse: Content, Sendable {
    let logs: [RequestLogEntry]
    let entries: [RequestLogEntry]
    let count: Int
}

struct AdminCustomWordsRequest: Content, Sendable { let words: [String] }
struct AdminCorrectionsRequest: Content, Sendable { let overrides: [String: String] }
struct AdminPackRequest: Content, Sendable {
    let id: String
    let words: [String]
    let overrides: [String: String]
}

struct AdminServicesPatch: Content, Sendable {
    let ocr: Bool?
    let dococr: Bool?
    let console: Bool?
    let batch_ocr: Bool?
    let batch_markdown: Bool?
    let batch_docx: Bool?
    let translate: Bool?
    let transcribe: Bool?
    let synthesize: Bool?
    let llm: Bool?
    let ner: Bool?
    let embed: Bool?
    let coreml: Bool?
    let barcode: Bool?
}

struct AdminServicesResponse: Content, Sendable {
    let services: [String: Bool]
    let applied: [String]
}

private struct OCRRequestOptions: Decodable {
    let dpi: Int?
    let max_pages: Int?
    let rectify: String?
    let improve: String?
    let raw: String?
    let groups: String?
    let level: String?
    let langs: String?
    let multipass: String?
    let conf: Double?
    let upscale: Double?
    let loai_van_ban: String?
    let co_quan: String?
    let nam: String?
    let pack: String?
}

private struct OCRUploadPayload: Content {
    var file: File
    var loai_van_ban: String?
    var co_quan: String?
    var nam: String?
    var pack: String?
}

private enum FieldBatchMode: Equatable {
    case ocr
    case markdown
    case docx

    var responseFormat: String {
        switch self {
        case .ocr: return "ocr"
        case .markdown: return "markdown"
        case .docx: return "docx-source"
        }
    }

    var pageSeparator: String {
        self == .markdown ? "\n\n---\n\n" : "\n\n"
    }
}

private enum FieldBatchError: LocalizedError {
    case documentRecognitionUnavailable
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .documentRecognitionUnavailable:
            return "Markdown and Word batch require iOS 26 document recognition"
        case .recognitionFailed:
            return "OCR failed"
        }
    }
}

actor VaporServer {
    private static let wildcardBindHost = "0.0.0.0"

    private var app: Application?
    private var runTask: Task<Void, Never>?
    
    // 自動重啟設定
    private var shouldAutoRestart = true
    
    // 當伺服器停止時發通知
    private var onStopped: (@Sendable () -> Void)?

    let environment: Environment = .production
    
    // 可由外部設置
    var port: Int = 8000

    // OCR 參數
    var recognitionLevel: RecognizeTextRequest.RecognitionLevel = .accurate
    var usesLanguageCorrection: Bool = true
    var automaticallyDetectsLanguage: Bool = false

    private(set) var isRunning: Bool = false

    // MARK: - Public API

    // 設定停止時回呼
    func setOnStopped(_ handler: @escaping @Sendable () -> Void) {
        self.onStopped = handler
    }
    
    // 開關自動重啟
    func setAutoRestart(_ enabled: Bool) {
        self.shouldAutoRestart = enabled
    }

    func start() async throws {
        guard runTask == nil, app == nil else { return }

        let app = try await Application.make(environment)
        app.http.server.configuration.hostname = Self.wildcardBindHost
        app.http.server.configuration.port = port
        app.http.server.configuration.reuseAddress = true
        app.middleware.use(RequestMetricsMiddleware(), at: .beginning)
        app.middleware.use(AdminAuthMiddleware(), at: .end)
        app.middleware.use(UploadLimitMiddleware(), at: .end)
        app.middleware.use(OCRAdmissionMiddleware(), at: .end)
        await ThermalGovernor.shared.startMonitoring()

        try routes(app)

        do {
            try await app.startup()
        } catch {
            try? await app.asyncShutdown()
            throw error
        }

        self.app = app
        isRunning = true
        runTask = Task { [weak app, weak self] in
            guard let app, let self else { return }
            var hadError = false
            do {
                if let running = app.running {
                    try await running.onStop.get()
                } else {
                    hadError = true
                }
            } catch {
                hadError = true
            }

            await self.handleStopped(hadError: hadError)
        }
    }

    func stop() async {
        guard let app = app else { return }
        try? await app.asyncShutdown()   // 非同步關閉
        self.cleanupAfterStop()
    }

    func restart() async throws {
        await stop()
        try await start()
    }
    
    func running() -> Bool { isRunning }
    
    func configure(
        port: Int? = nil,
        recognitionLevel: RecognizeTextRequest.RecognitionLevel? = nil,
        usesLanguageCorrection: Bool? = nil,
        automaticallyDetectsLanguage: Bool? = nil,
    ) {
        if let v = port { self.port = v }
        if let v = recognitionLevel { self.recognitionLevel = v }
        if let v = usesLanguageCorrection { self.usesLanguageCorrection = v }
        if let v = automaticallyDetectsLanguage { self.automaticallyDetectsLanguage = v }
    }
    
    // MARK: - Cleanup After Stop
    
    private func cleanupAfterStop() {
        runTask = nil
        app = nil
        isRunning = false
    }

    private func handleStopped(hadError: Bool) {
        cleanupAfterStop()
        if let onStopped { onStopped() }

        if shouldAutoRestart && hadError {
            NotificationCenter.default.post(
                name: .vaporServerShouldRestart,
                object: nil,
                userInfo: ["reason": "/server/crash", "automatic": true]
            )
        }
    }

    // MARK: - Routes

    private func routes(_ app: Application) throws {
        app.get("health") { [weak self] req async throws -> Response in
            guard let self else { throw Abort(.internalServerError) }
            let port = await self.port
            let customization = try await OCRCustomizationStore.shared.summary()
            let customWordsCount = try await Self.appliedCustomWordsCount()
            let thermalGuard = await MainActor.run { Settings.shared.thermalGuard }
            let thermalStatus = await ThermalGovernor.shared.snapshot(
                guardEnabled: thermalGuard
            )
            let health = await MainActor.run {
                ServerTelemetry.shared.healthResponse(
                    port: port,
                    customization: customization,
                    customWordsCount: customWordsCount,
                    thermalStatus: thermalStatus
                )
            }
            return try Self.jsonResponse(.ok, health)
        }

        app.get("stats") { [weak self] req async throws -> Response in
            guard let self else { throw Abort(.internalServerError) }
            let port = await self.port
            let customization = try await OCRCustomizationStore.shared.summary()
            let customWordsCount = try await Self.appliedCustomWordsCount()
            let thermalGuard = await MainActor.run { Settings.shared.thermalGuard }
            let thermalStatus = await ThermalGovernor.shared.snapshot(
                guardEnabled: thermalGuard
            )
            let stats = await MainActor.run {
                ServerTelemetry.shared.statsResponse(
                    port: port,
                    customization: customization,
                    customWordsCount: customWordsCount,
                    thermalStatus: thermalStatus
                )
            }
            return try Self.jsonResponse(.ok, stats)
        }

        app.get("admin") { [weak self] req async throws -> Response in
            guard let self else { throw Abort(.internalServerError) }
            return Self.htmlResponse(Self.adminHTMLV3(port: await self.port))
        }

        app.get("admin", "settings") { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            let settings = await MainActor.run { Self.adminSettingsSnapshot() }
            return try Self.jsonResponse(.ok, settings)
        }

        app.on(.POST, "admin", "settings", body: .collect(maxSize: "8mb")) { req async throws -> Response in
            try await Self.requireAdminToken(request: req)

            let patch: AdminSettingsPatch
            do {
                patch = try req.content.decode(AdminSettingsPatch.self)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(
                        success: false,
                        message: "Expected a partial settings JSON object"
                    )
                )
            }

            do {
                let bundlePackIDs = try await DomainPackManager.shared.packIDs()
                let customPackIDs = try await OCRCustomizationStore.shared.packIDs()
                let outcome = try await MainActor.run {
                    Self.applyAdminSettings(
                        patch,
                        knownPackIDs: bundlePackIDs.union(customPackIDs)
                    )
                }
                if outcome.restarted {
                    Self.scheduleServerRestart(reason: "/admin/settings")
                }
                return try Self.jsonResponse(.ok, outcome)
            } catch {
                return try Self.jsonResponse(
                    .internalServerError,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
        }

        app.post("admin", "restart") { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            Self.scheduleServerRestart(reason: "/admin/restart")
            return try Self.jsonResponse(.ok, AdminRestartResponse(ok: true))
        }

        app.post("admin", "keepalive") { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            let payload: AdminKeepAliveRequest
            do {
                payload = try req.content.decode(AdminKeepAliveRequest.self)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: "Expected JSON field: on")
                )
            }
            await MainActor.run {
                KeepAliveService.shared.setEnabled(payload.on)
            }
            return try Self.jsonResponse(
                .ok,
                AdminApplyResponse(applied: ["keep_alive"], restarted: false)
            )
        }

        app.get("admin", "log") { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            let logs = await RequestLogStore.shared.recent(limit: 200)
            return try Self.jsonResponse(
                .ok,
                AdminLogResponse(logs: logs, entries: logs, count: logs.count)
            )
        }

        app.get("admin", "customwords") { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            return try Self.jsonResponse(
                .ok,
                try await OCRCustomizationStore.shared.customWords()
            )
        }

        app.on(.POST, "admin", "customwords", body: .collect(maxSize: "8mb")) { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            let payload = try req.content.decode(AdminCustomWordsRequest.self)
            try Self.validateWords(payload.words)
            let mode = ((try? req.query.get(String.self, at: "mode")) ?? "replace").lowercased()
            guard mode == "replace" || mode == "append" else {
                throw Abort(.badRequest, reason: "mode must be replace or append")
            }
            let response = try await OCRCustomizationStore.shared.setCustomWords(
                payload.words,
                append: mode == "append"
            )
            return try Self.jsonResponse(.ok, response)
        }

        app.get("admin", "corrections") { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            return try Self.jsonResponse(
                .ok,
                try await OCRCustomizationStore.shared.corrections()
            )
        }

        app.on(.POST, "admin", "corrections", body: .collect(maxSize: "8mb")) { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            let payload = try req.content.decode(AdminCorrectionsRequest.self)
            try Self.validateOverrides(payload.overrides)
            return try Self.jsonResponse(
                .ok,
                try await OCRCustomizationStore.shared.mergeCorrections(payload.overrides)
            )
        }

        app.on(.POST, "admin", "pack", body: .collect(maxSize: "8mb")) { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            let payload = try req.content.decode(AdminPackRequest.self)
            try Self.validatePackID(payload.id)
            try Self.validateWords(payload.words)
            try Self.validateOverrides(payload.overrides)
            return try Self.jsonResponse(
                .ok,
                try await OCRCustomizationStore.shared.savePack(
                    id: payload.id,
                    words: payload.words,
                    overrides: payload.overrides
                )
            )
        }

        app.get("admin", "packs") { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            let bundled = try await DomainPackManager.shared.packSummaries()
            let custom = try await OCRCustomizationStore.shared.packSummaries()
            let activePack = await MainActor.run { Settings.shared.activePack }
            return try Self.jsonResponse(
                .ok,
                OCRPacksResponse(
                    packs: (bundled + custom).sorted { $0.id < $1.id },
                    active_pack: activePack
                )
            )
        }

        app.post("admin", "lexicon", "reset") { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            let response = try await OCRCustomizationStore.shared.reset()
            await MainActor.run { Settings.shared.activePack = "auto" }
            return try Self.jsonResponse(.ok, response)
        }

        app.get("admin", "services") { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            let services = await MainActor.run { Settings.shared.serviceStates() }
            return try Self.jsonResponse(
                .ok,
                AdminServicesResponse(services: services, applied: [])
            )
        }

        app.post("admin", "services") { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            let patch = try req.content.decode(AdminServicesPatch.self)
            let response = await MainActor.run { Self.applyServices(patch) }
            return try Self.jsonResponse(.ok, response)
        }

        app.get("console") { [weak self] req async throws -> Response in
            try await Self.requireService(.console)
            guard let self else { throw Abort(.internalServerError) }
            return Self.htmlResponse(FieldConsole.html(port: await self.port))
        }

        app.on(.POST, "batch", "ocr", body: .collect(maxSize: "100mb")) { req async throws -> Response in
            try await Self.requireService(.batchOCR)
            try await Self.requireUploadWithinLimit(req)
            return try await Self.fieldBatchResponse(request: req, mode: .ocr)
        }

        app.on(.POST, "batch", "markdown", body: .collect(maxSize: "100mb")) { req async throws -> Response in
            try await Self.requireService(.batchMarkdown)
            try await Self.requireUploadWithinLimit(req)
            return try await Self.fieldBatchResponse(request: req, mode: .markdown)
        }

        app.on(.POST, "batch", "docx", body: .collect(maxSize: "100mb")) { req async throws -> Response in
            try await Self.requireService(.batchDocx)
            try await Self.requireUploadWithinLimit(req)
            return try await Self.fieldBatchResponse(request: req, mode: .docx)
        }

        app.on(.POST, "debug", "ocr", body: .collect(maxSize: "100mb")) { [weak self] req async throws -> Response in
            try await Self.requireDebugEnabled()
            try await Self.requireAdminToken(request: req)
            try await Self.requireService(.ocr)
            try await Self.requireUploadWithinLimit(req)
            guard let self else { throw Abort(.internalServerError) }

            let upload: OCRUploadPayload
            do {
                upload = try req.content.decode(OCRUploadPayload.self)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: "Missing or empty 'file' part")
                )
            }
            guard upload.file.data.readableBytes > 0 else {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: "Missing or empty 'file' part")
                )
            }

            let options: OCRRequestOptions
            do {
                options = try Self.requestOptions(from: req)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }

            let data = Self.byteBufferToData(upload.file.data)
            guard !Self.isPDF(data) else {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: "/debug/ocr accepts one image, not PDF")
                )
            }
            let baseRuntime = await MainActor.run { Settings.shared.ocrRuntimeSnapshot() }
            let runtime = try Self.runtimeSettings(options: options, base: baseRuntime)
            let rectify = Self.booleanValue(options.rectify) ?? runtime.rectifyDefault
            let processed: RectifiedImage
            if rectify {
                processed = await ImageProcessingService.shared.rectify(data: data)
            } else {
                processed = RectifiedImage(data: data, rectified: false)
            }
            let improve = Self.improveRequested(options: options, runtime: runtime)
            let metadata = Self.domainMetadata(
                options: options,
                upload: upload,
                activePack: runtime.activePack
            )

            do {
                guard let result = try await OCRImprovementService.shared.processImage(
                    data: processed.data,
                    visionConfiguration: runtime.visionConfiguration,
                    metadata: metadata,
                    improve: improve,
                    configuration: runtime.improvementConfiguration,
                    collectTrace: true
                ) else {
                    return try Self.jsonResponse(
                        .internalServerError,
                        ComputeErrorResponse(success: false, message: "OCR failed")
                    )
                }
                let trace = await OCRDebugTraceFactory.make(
                    endpoint: "/debug/ocr",
                    result: result,
                    runtime: runtime,
                    improve: improve,
                    recognitionLevel: runtime.recognitionLevel,
                    usesLanguageCorrection: runtime.usesLanguageCorrection,
                    automaticallyDetectsLanguage: runtime.automaticallyDetectsLanguage
                )
                await OCRDebugStore.shared.append(trace)
                return try Self.jsonResponse(.ok, trace)
            } catch {
                return try Self.jsonResponse(
                    Self.ocrErrorStatus(error),
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
        }

        app.get("debug", "last") { req async throws -> Response in
            try await Self.requireDebugEnabled()
            try await Self.requireAdminToken(request: req)
            let limit = (try? req.query.get(Int.self, at: "n")) ?? 10
            guard (1...30).contains(limit) else {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: "n must be between 1 and 30")
                )
            }
            let traces = await OCRDebugStore.shared.recent(limit: limit)
            let requestLogs = await RequestLogStore.shared.recent(limit: limit)
            return try Self.jsonResponse(
                .ok,
                OCRDebugLastResponse(traces: traces, request_logs: requestLogs)
            )
        }

        // GET /
        app.get { [weak self] req async throws -> Response in
            guard let self else { throw Abort(.internalServerError) }

            // 從 actor 讀取屬性要 await
            let port = await self.port
            
            var docOcrCheckBox = ""
            var docOcrApiPre = ""
            if #available(iOS 26, *) {
                docOcrCheckBox = """
                <div>
                    <input type="checkbox" id="docOcr" name="docOcr"/>
                    <label for="docOcr">Document Paragraph Detection</label>
                </div><br>
                """
                
                docOcrApiPre = """
                OR
                <h3>Upload an image via <code>docOCR</code> API:</h3>
                <pre><code>curl -H "Accept: application/json" \\
                  -X POST http://&lt;YOUR IP&gt;:\(port)/docOCR \\
                  -F "file=@01.png"</code></pre>
                """
            } else {
                docOcrCheckBox = ""
                docOcrApiPre = ""
            }

            let html = """
            <!doctype html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Compute Server</title>
                <style>
                    body {
                        max-width: 920px;
                        margin: 0 auto;
                        padding: 24px;
                        color: #e9f2f1;
                        background: #091014;
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    }
                    a { color: #2bd4c2; }
                    code {
                        color: #c7fff7;
                        background: #162429;
                        padding: 2px 6px;
                        font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
                        font-size: 0.85em;
                        font-weight: 600;
                        border-radius: 5px;
                    }
                    pre {
                        color: #d9e5e3;
                        background: #101b1f;
                        padding: 16px;
                        overflow: auto;
                        font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
                        font-size: 0.85em;
                        line-height: 1.45;
                        border-radius: 5px;
                    }
                    pre code {
                        background: transparent;
                        padding: 0;
                        font-size: inherit;
                        color: inherit;
                        font-weight: normal;
                    }
                </style>
            </head>
            <body>
                <h1>Compute Server</h1>
                <h3>Upload an image via <code>upload</code> API:</h3>
                <pre><code>curl -H "Accept: application/json" \\
              -X POST http://&lt;YOUR IP&gt;:\(port)/upload \\
              -F "file=@01.png"</code></pre>
                \(docOcrApiPre)
                <hr>
                <h2>Translation, Speech-to-Text, and Text-to-Speech</h2>
                <h3>Translate text via <code>translate</code> API:</h3>
                <pre><code>curl -H "Content-Type: application/json" \\
              -X POST http://&lt;YOUR IP&gt;:\(port)/translate \\
              -d '{"text":"Xin chào","source":"vi","target":"en"}'</code></pre>
                <h3>Transcribe audio via <code>transcribe</code> API:</h3>
                <pre><code>curl -H "Accept: application/json" \\
              -X POST 'http://&lt;YOUR IP&gt;:\(port)/transcribe?locale=vi-VN' \\
              -F "file=@speech.m4a"</code></pre>
                <h3>Synthesize speech via <code>synthesize</code> API:</h3>
                <pre><code>curl -H "Content-Type: application/json" \\
              -X POST http://&lt;YOUR IP&gt;:\(port)/synthesize \\
              -d '{"text":"Xin chào","lang":"vi-VN","rate":0.5}' \\
              --output speech.caf</code></pre>
                <hr>
                <h2>On-device Intelligence</h2>
                <h3>Generate text via <code>llm</code> API (iOS 26):</h3>
                <pre><code>curl -H "Content-Type: application/json" \\
              -X POST http://&lt;YOUR IP&gt;:\(port)/llm \\
              -d '{"prompt":"Tóm tắt Điều 5 trong 3 ý","system":"Bạn là trợ lý pháp luật Việt Nam","max":256}'</code></pre>
                <h3>Extract entities via <code>ner</code> API:</h3>
                <pre><code>curl -H "Content-Type: application/json" \\
              -X POST http://&lt;YOUR IP&gt;:\(port)/ner \\
              -d '{"text":"Bộ Tài chính ban hành 255/2024/NĐ-CP, Điều 5 khoản 2."}'</code></pre>
                <h3>Create a Vietnamese embedding via <code>embed</code> API:</h3>
                <pre><code>curl -H "Content-Type: application/json" \\
              -X POST http://&lt;YOUR IP&gt;:\(port)/embed \\
              -d '{"text":"quy định về hóa đơn điện tử"}'</code></pre>
                <hr>
                <h2>Core ML Runner</h2>
                <p>Endpoints: <code>coreml/upload</code>, <code>coreml/info</code>,
                <code>coreml/predict</code>, and <code>coreml/delete</code>.</p>
                <h3>Upload and load a Core ML model:</h3>
                <pre><code>curl -H "Accept: application/json" \\
              -X POST http://&lt;YOUR IP&gt;:\(port)/coreml/upload \\
              -F "file=@VietnameseLegal.mlmodel"</code></pre>
                <p>For directory-based <code>.mlpackage</code> or <code>.mlmodelc</code>, ZIP the
                directory and preserve the original multipart filename.</p>
                <pre><code>zip -qr VietnameseLegal.mlpackage.zip VietnameseLegal.mlpackage
                curl -H "Accept: application/json" \\
              -X POST http://&lt;YOUR IP&gt;:\(port)/coreml/upload \\
              -F "file=@VietnameseLegal.mlpackage.zip;filename=VietnameseLegal.mlpackage"</code></pre>
                <h3>Run dynamic Core ML inference:</h3>
                <pre><code>curl -H "Content-Type: application/json" \\
              -X POST http://&lt;YOUR IP&gt;:\(port)/coreml/predict \\
              -d '{"model_id":"vietnameselegal-HASH","inputs":{"input_ids":[[1,2,3,4]]}}'</code></pre>
                <hr>
                <h2>Compute v2</h2>
                <p><code>GET /health</code> returns live server health. <code>GET /stats</code>
                adds the latest 20 request-log entries.</p>
                <p>Remote control: <a href="/admin"><code>GET /admin</code></a>.</p>
                <p>Offline field appliance: <a href="/console"><code>GET /console</code></a>
                for sequential OCR, Markdown, and client-side Word batches.</p>
                <h3>OCR a PDF or rectify a photographed scan:</h3>
                <pre><code>curl -H "Accept: application/json" \\
              -X POST 'http://&lt;YOUR IP&gt;:\(port)/upload?dpi=150&amp;max_pages=50&amp;rectify=1' \\
              -F "file=@document.pdf"</code></pre>
                <p><code>/docOCR</code> accepts the same PDF and rectify query parameters on iOS 26.</p>
                <p>Auto-improve is on by default. Use <code>?raw=1</code> or
                <code>?improve=0</code> for the uncorrected Vision text. Optional
                <code>pack=minimal|legal|tax|customs|none</code> and metadata fields
                <code>loai_van_ban</code>, <code>co_quan</code>, <code>nam</code> select a small domain pack.</p>
                <p>Debug tuning: <code>POST /debug/ocr</code> returns the full top-3,
                corrector, quality, timing, device, and config trace;
                <code>GET /debug/last?n=10</code> returns recent traces. Both honor the
                optional admin token and the live <code>debug_verbose</code> setting.</p>
                <h3>Sequential image batch:</h3>
                <pre><code>curl -H "Accept: application/json" \\
              -X POST http://&lt;YOUR IP&gt;:\(port)/batch \\
              -F "file=@page-1.png" \\
              -F "file=@page-2.jpg"</code></pre>
                <h3>Detect barcodes:</h3>
                <pre><code>curl -H "Accept: application/json" \\
              -X POST http://&lt;YOUR IP&gt;:\(port)/barcode \\
              -F "file=@barcode.png"</code></pre>
                <p>PDF safety limits: <code>dpi=72...300</code>, <code>max_pages=1...200</code>.</p>
                <hr>
                <h3>OCR Test:</h3>
                <form id="ocrForm" action="/upload" method="post" enctype="multipart/form-data">
                    \(docOcrCheckBox)
                    <label>
                        Choose file:
                        <input type="file" name="file" accept="image/*,application/pdf" required>
                    </label>
                    <br><br>
                    <input type="submit" value="Upload file">
                </form>
            </body>
            <script>
                const form = document.getElementById("ocrForm");
                const docOcr = document.getElementById("docOcr");

                form.addEventListener("submit", function () {
                    if (docOcr && docOcr.checked) {
                        form.action = "/docOCR";
                    } else {
                        form.action = "/upload";
                    }
                });
            </script>
            </html>
            """
            return Self.htmlResponse(html)
        }

        // POST /upload
        app.on(.POST, "upload", body: .collect(maxSize: "100mb")) { [weak self] req async throws -> Response in
            try await Self.requireService(.ocr)
            try await Self.requireUploadWithinLimit(req)
            guard let self else { throw Abort(.internalServerError) }

            let upload: OCRUploadPayload
            do {
                upload = try req.content.decode(OCRUploadPayload.self)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    UploadResponse(
                        success: false,
                        message: "Missing or empty 'file' part",
                        ocr_result: "",
                        image_width: 0,
                        image_height: 0,
                        ocr_boxes: []
                    )
                )
            }

            guard upload.file.data.readableBytes > 0 else {
                return try Self.jsonResponse(
                    .badRequest,
                    UploadResponse(
                        success: false,
                        message: "Missing or empty 'file' part",
                        ocr_result: "",
                        image_width: 0,
                        image_height: 0,
                        ocr_boxes: []
                    )
                )
            }

            let options: OCRRequestOptions
            do {
                options = try Self.requestOptions(from: req)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    UploadResponse(
                        success: false,
                        message: error.localizedDescription,
                        ocr_result: "",
                        image_width: 0,
                        image_height: 0,
                        ocr_boxes: []
                    )
                )
            }

            let data = Self.byteBufferToData(upload.file.data)
            let baseRuntime = await MainActor.run { Settings.shared.ocrRuntimeSnapshot() }
            let runtime: OCRRuntimeSettingsSnapshot
            do {
                runtime = try Self.runtimeSettings(options: options, base: baseRuntime)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    UploadResponse(
                        success: false,
                        message: error.localizedDescription,
                        ocr_result: "",
                        image_width: 0,
                        image_height: 0,
                        ocr_boxes: []
                    )
                )
            }
            let rectify = Self.booleanValue(options.rectify) ?? runtime.rectifyDefault
            let improve = Self.improveRequested(options: options, runtime: runtime)
            let metadata = Self.domainMetadata(
                options: options,
                upload: upload,
                activePack: runtime.activePack
            )

            if Self.isPDF(data) {
                let dpiUsed = Self.effectivePDFDPI(
                    requested: options.dpi,
                    runtime: runtime
                )
                do {
                    let rendered = try await ImageProcessingService.shared.renderPDF(
                        data: data,
                        dpi: dpiUsed,
                        maximumPages: options.max_pages ?? runtime.pdfMaximumPages
                    )
                    var pages: [PDFUploadPageResponse] = []
                    pages.reserveCapacity(rendered.pages.count)

                    for page in rendered.pages {
                        let processed: RectifiedImage
                        if rectify {
                            processed = await ImageProcessingService.shared.rectify(data: page.imageData)
                        } else {
                            processed = RectifiedImage(data: page.imageData, rectified: false)
                        }
                        let result = try await OCRImprovementService.shared.processImage(
                            data: processed.data,
                            visionConfiguration: runtime.visionConfiguration,
                            metadata: metadata,
                            improve: improve,
                            pageNumber: page.pageNumber,
                            pageCount: rendered.totalPageCount,
                            configuration: runtime.improvementConfiguration,
                            collectTrace: runtime.debugVerbose
                        )
                        if let result {
                            await Self.recordDebugTraceIfNeeded(
                                endpoint: "/upload?page=\(page.pageNumber)",
                                result: result,
                                runtime: runtime,
                                improve: improve,
                                recognitionLevel: runtime.recognitionLevel,
                                usesLanguageCorrection: runtime.usesLanguageCorrection,
                                automaticallyDetectsLanguage: runtime.automaticallyDetectsLanguage
                            )
                        }
                        pages.append(
                            PDFUploadPageResponse(
                                page: page.pageNumber,
                                success: result != nil,
                                message: result == nil ? "OCR failed" : "OCR completed successfully",
                                improvement: result,
                                rectified: rectify ? processed.rectified : nil,
                                dpi_used: dpiUsed
                            )
                        )
                    }

                    let succeeded = pages.allSatisfy(\.success)
                    return try Self.jsonResponse(
                        .ok,
                        PDFUploadResponse(
                            success: succeeded,
                            message: "Processed \(pages.count) of \(rendered.totalPageCount) PDF pages",
                            pages: pages
                        )
                    )
                } catch {
                    return try Self.jsonResponse(
                        Self.ocrErrorStatus(error),
                        UploadResponse(
                            success: false,
                            message: error.localizedDescription,
                            ocr_result: "",
                            image_width: 0,
                            image_height: 0,
                            ocr_boxes: [],
                            dpi_used: dpiUsed
                        )
                    )
                }
            }

            let processed: RectifiedImage
            if rectify {
                processed = await ImageProcessingService.shared.rectify(data: data)
            } else {
                processed = RectifiedImage(data: data, rectified: false)
            }
            let accept = (req.headers.first(name: .accept) ?? "").lowercased()
            let result: OCRImprovementResult?
            do {
                result = try await OCRImprovementService.shared.processImage(
                    data: processed.data,
                    visionConfiguration: runtime.visionConfiguration,
                    metadata: metadata,
                    improve: improve,
                    configuration: runtime.improvementConfiguration,
                    collectTrace: runtime.debugVerbose
                )
            } catch {
                return try Self.jsonResponse(
                    Self.ocrErrorStatus(error),
                    UploadResponse(
                        success: false,
                        message: error.localizedDescription,
                        ocr_result: "",
                        image_width: 0,
                        image_height: 0,
                        ocr_boxes: [],
                        rectified: rectify ? processed.rectified : nil
                    )
                )
            }
            if let result {
                await Self.recordDebugTraceIfNeeded(
                    endpoint: "/upload",
                    result: result,
                    runtime: runtime,
                    improve: improve,
                    recognitionLevel: runtime.recognitionLevel,
                    usesLanguageCorrection: runtime.usesLanguageCorrection,
                    automaticallyDetectsLanguage: runtime.automaticallyDetectsLanguage
                )
            }
            
            if result == nil && accept.contains("application/json") {
                return try Self.jsonResponse(
                    .internalServerError,
                    UploadResponse(
                        success: false,
                        message: "OCR failed",
                        ocr_result: "",
                        image_width: 0,
                        image_height: 0,
                        ocr_boxes: [],
                        rectified: rectify ? processed.rectified : nil
                    )
                )
            }
            
            if accept.contains("application/json") {
                return try Self.jsonResponse(
                    .ok,
                    UploadResponse(
                        success: true,
                        message: "File uploaded successfully",
                        ocr_result: result?.selectedText ?? "",
                        image_width: result?.ocrResult.image_width ?? 0,
                        image_height: result?.ocrResult.image_height ?? 0,
                        ocr_boxes: result?.ocrResult.boxes ?? [],
                        rectified: rectify ? processed.rectified : nil,
                        improvement: result
                    )
                )
            } else {
                let escaped = Self.htmlEscape(result?.selectedText ?? "")
                let html = """
                <!doctype html>
                <html>
                <head>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Compute Server</title>
                </head>
                <body>
                    <h2>OCR Result:</h2>
                    <pre>\(escaped)</pre>
                </body>
                </html>
                """
                return Self.htmlResponse(html)
            }
        }

        // POST /batch
        app.on(.POST, "batch", body: .collect(maxSize: "100mb")) { [weak self] req async throws -> Response in
            try await Self.requireService(.ocr)
            try await Self.requireUploadWithinLimit(req)
            guard let self else { throw Abort(.internalServerError) }

            let files: [ParsedMultipartFile]
            do {
                files = try MultipartUploadParser.files(from: req, fieldName: "file")
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
            try await Self.requireBatchFileLimit(files.count)

            let runtime = await MainActor.run { Settings.shared.ocrRuntimeSnapshot() }
            let metadata = OCRDomainMetadata(
                documentType: nil,
                agency: nil,
                year: nil,
                requestedPack: runtime.activePack
            )
            let pack = try await OCRImprovementService.shared.resolvePack(metadata: metadata)
            let textRecognizer = TextRecognizer(
                recognitionLevel: runtime.visionConfiguration.recognitionLevel,
                recognitionLanguages: runtime.recognitionLanguages,
                usesLanguageCorrection: runtime.usesLanguageCorrection,
                automaticallyDetectsLanguage: runtime.automaticallyDetectsLanguage,
                minimumTextHeight: runtime.minimumTextHeight,
                visionRevision: runtime.visionRevision
            )

            var responses: [BatchUploadResponse] = []
            responses.reserveCapacity(files.count)
            for file in files {
                guard !Self.isPDF(file.data) else {
                    responses.append(
                        BatchUploadResponse(
                            filename: file.filename,
                            success: false,
                            message: "PDF is not supported by /batch; use /upload",
                            ocr_result: "",
                            image_width: 0,
                            image_height: 0,
                            ocr_boxes: []
                        )
                    )
                    continue
                }

                let result = await textRecognizer.getOcrResult(
                    data: file.data,
                    customWords: pack.words
                )
                responses.append(
                    BatchUploadResponse(
                        filename: file.filename,
                        success: result != nil,
                        message: result == nil ? "OCR failed" : "OCR completed successfully",
                        ocr_result: result?.text ?? "",
                        image_width: result?.image_width ?? 0,
                        image_height: result?.image_height ?? 0,
                        ocr_boxes: result?.boxes ?? []
                    )
                )
            }

            return try Self.jsonResponse(.ok, responses)
        }

        // POST /barcode
        app.on(.POST, "barcode", body: .collect(maxSize: "100mb")) { req async throws -> Response in
            try await Self.requireService(.barcode)
            try await Self.requireUploadWithinLimit(req)
            struct BarcodeUpload: Content { var file: File }

            let upload: BarcodeUpload
            do {
                upload = try req.content.decode(BarcodeUpload.self)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: "Missing or empty 'file' part")
                )
            }
            guard upload.file.data.readableBytes > 0 else {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: "Missing or empty 'file' part")
                )
            }

            do {
                let codes = try await ImageProcessingService.shared.detectBarcodes(
                    data: Self.byteBufferToData(upload.file.data)
                )
                return try Self.jsonResponse(
                    .ok,
                    BarcodeResponse(
                        codes: codes.map {
                            BarcodeItemResponse(
                                payload: $0.payload,
                                symbology: $0.symbology,
                                confidence: $0.confidence
                            )
                        }
                    )
                )
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
        }
        
        // POST /translate
        app.on(.POST, "translate", body: .collect(maxSize: "2mb")) { req async throws -> Response in
            try await Self.requireService(.translate)
            let payload: TranslateRequestBody
            do {
                payload = try req.content.decode(TranslateRequestBody.self)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(
                        success: false,
                        message: "Expected JSON fields: text, target, source (optional)"
                    )
                )
            }

            do {
                let output = try await TranslationService.shared.translate(
                    text: payload.text,
                    source: payload.source,
                    target: payload.target
                )
                return try Self.jsonResponse(
                    .ok,
                    TranslateResponse(
                        success: true,
                        translated: output.translated,
                        source: output.source,
                        target: output.target
                    )
                )
            } catch let error as TranslationServiceError {
                let status: HTTPResponseStatus
                switch error {
                case .timedOut:
                    status = .serviceUnavailable
                case .emptyText, .missingTarget:
                    status = .badRequest
                }
                return try Self.jsonResponse(
                    status,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            } catch {
                return try Self.jsonResponse(
                    .internalServerError,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
        }

        // POST /transcribe
        app.on(.POST, "transcribe", body: .collect(maxSize: "100mb")) { req async throws -> Response in
            try await Self.requireService(.transcribe)
            let contentType = (req.headers.first(name: .contentType) ?? "").lowercased()
            let audioData: Data
            let fileExtension: String

            if contentType.contains("multipart/form-data") {
                struct AudioUpload: Content { var file: File }

                let upload: AudioUpload
                do {
                    upload = try req.content.decode(AudioUpload.self)
                } catch {
                    return try Self.jsonResponse(
                        .badRequest,
                        ComputeErrorResponse(success: false, message: "Missing or empty 'file' part")
                    )
                }

                guard upload.file.data.readableBytes > 0 else {
                    return try Self.jsonResponse(
                        .badRequest,
                        ComputeErrorResponse(success: false, message: "Missing or empty 'file' part")
                    )
                }

                audioData = Self.byteBufferToData(upload.file.data)
                fileExtension = URL(fileURLWithPath: upload.file.filename).pathExtension.lowercased()
            } else {
                guard let buffer = req.body.data, buffer.readableBytes > 0 else {
                    return try Self.jsonResponse(
                        .badRequest,
                        ComputeErrorResponse(success: false, message: "Request body must contain audio data")
                    )
                }

                audioData = Self.byteBufferToData(buffer)
                fileExtension = Self.audioFileExtension(for: contentType)
            }

            let locale = (try? req.query.get(String.self, at: "locale")) ?? "vi-VN"

            do {
                let output = try await SpeechService.shared.transcribe(
                    data: audioData,
                    fileExtension: fileExtension,
                    locale: locale
                )
                return try Self.jsonResponse(
                    .ok,
                    TranscribeResponse(success: true, text: output.text, locale: output.locale)
                )
            } catch let error as SpeechServiceError {
                let status: HTTPResponseStatus
                switch error {
                case .authorizationDenied:
                    status = .forbidden
                case .recognizerUnavailable,
                     .onDeviceRecognitionUnavailable,
                     .recognitionFailed:
                    status = .serviceUnavailable
                }
                return try Self.jsonResponse(
                    status,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            } catch {
                return try Self.jsonResponse(
                    .internalServerError,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
        }

        // POST /synthesize
        app.on(.POST, "synthesize", body: .collect(maxSize: "2mb")) { req async throws -> Response in
            try await Self.requireService(.synthesize)
            let payload: SynthesizeRequestBody
            do {
                payload = try req.content.decode(SynthesizeRequestBody.self)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(
                        success: false,
                        message: "Expected JSON fields: text, lang (optional), rate (optional)"
                    )
                )
            }

            do {
                let audioData = try await SynthService.shared.synthesize(
                    text: payload.text,
                    language: payload.lang ?? "vi-VN",
                    rate: payload.rate ?? 0.5
                )
                var headers = HTTPHeaders()
                headers.add(name: .contentType, value: "audio/x-caf")
                headers.add(name: .contentDisposition, value: "attachment; filename=\"speech.caf\"")
                return Response(status: .ok, headers: headers, body: .init(data: audioData))
            } catch let error as SynthServiceError {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            } catch {
                return try Self.jsonResponse(
                    .internalServerError,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
        }

        // POST /llm
        app.on(.POST, "llm", body: .collect(maxSize: "2mb")) { req async throws -> Response in
            try await Self.requireService(.llm)
            let payload: LLMRequestBody
            do {
                payload = try req.content.decode(LLMRequestBody.self)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(
                        success: false,
                        message: "Expected JSON fields: prompt, system (optional), max (optional)"
                    )
                )
            }

            guard #available(iOS 26.0, *) else {
                return try Self.jsonResponse(
                    .serviceUnavailable,
                    ComputeErrorResponse(
                        success: false,
                        message: "Foundation Models requires iOS 26 or later"
                    )
                )
            }

            do {
                let text = try await LLMService.shared.respond(
                    prompt: payload.prompt,
                    system: payload.system,
                    maximumTokens: payload.max
                )
                return try Self.jsonResponse(
                    .ok,
                    LLMResponse(success: true, text: text)
                )
            } catch let error as LLMServiceError {
                let status: HTTPResponseStatus
                switch error {
                case .emptyPrompt, .invalidMaximumTokens:
                    status = .badRequest
                case .unavailable:
                    status = .serviceUnavailable
                }
                return try Self.jsonResponse(
                    status,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            } catch {
                return try Self.jsonResponse(
                    .internalServerError,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
        }

        // POST /ner
        app.on(.POST, "ner", body: .collect(maxSize: "2mb")) { req async throws -> Response in
            try await Self.requireService(.ner)
            let payload: NERRequestBody
            do {
                payload = try req.content.decode(NERRequestBody.self)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: "Expected JSON field: text")
                )
            }

            do {
                let output = try await NERService.shared.extract(from: payload.text)
                return try Self.jsonResponse(
                    .ok,
                    NERResponse(
                        success: true,
                        entities: output.entities.map {
                            NEREntityResponse(text: $0.text, type: $0.type)
                        },
                        so_hieu: output.documentNumbers,
                        dieu_khoan: output.legalReferences
                    )
                )
            } catch let error as NERServiceError {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            } catch {
                return try Self.jsonResponse(
                    .internalServerError,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
        }

        // POST /embed
        app.on(.POST, "embed", body: .collect(maxSize: "2mb")) { req async throws -> Response in
            try await Self.requireService(.embed)
            let payload: EmbedRequestBody
            do {
                payload = try req.content.decode(EmbedRequestBody.self)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: "Expected JSON field: text")
                )
            }

            do {
                let output = try await EmbeddingService.shared.embed(payload.text)
                return try Self.jsonResponse(
                    .ok,
                    EmbedResponse(
                        success: true,
                        vector: output.vector,
                        dim: output.dimension
                    )
                )
            } catch let error as EmbeddingServiceError {
                let status: HTTPResponseStatus
                switch error {
                case .emptyText:
                    status = .badRequest
                case .unsupportedVietnamese:
                    status = .notImplemented
                }
                return try Self.jsonResponse(
                    status,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            } catch {
                return try Self.jsonResponse(
                    .internalServerError,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
        }

        // POST /coreml/upload
        app.on(.POST, "coreml", "upload", body: .collect(maxSize: "500mb")) { req async throws -> Response in
            try await Self.requireService(.coreml)
            struct ModelUpload: Content { var file: File }

            let upload: ModelUpload
            do {
                upload = try req.content.decode(ModelUpload.self)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: "Missing or empty 'file' part")
                )
            }

            guard upload.file.data.readableBytes > 0 else {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: "Missing or empty 'file' part")
                )
            }

            do {
                let info = try await CoreMLService.shared.upload(
                    data: Self.byteBufferToData(upload.file.data),
                    filename: upload.file.filename
                )
                return try Self.jsonResponse(
                    .ok,
                    CoreMLModelResponse(
                        success: true,
                        model_id: info.modelID,
                        input: info.inputs,
                        output: info.outputs
                    )
                )
            } catch let error as CoreMLServiceError {
                return try Self.jsonResponse(
                    Self.coreMLStatus(for: error),
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            } catch {
                return try Self.jsonResponse(
                    .internalServerError,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
        }

        // GET /coreml/info?model_id=...
        app.get("coreml", "info") { req async throws -> Response in
            try await Self.requireService(.coreml)
            guard let modelID = try? req.query.get(String.self, at: "model_id"),
                  !modelID.isEmpty else {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: "Missing query parameter: model_id")
                )
            }

            do {
                let info = try await CoreMLService.shared.info(modelID: modelID)
                return try Self.jsonResponse(
                    .ok,
                    CoreMLModelResponse(
                        success: true,
                        model_id: info.modelID,
                        input: info.inputs,
                        output: info.outputs
                    )
                )
            } catch let error as CoreMLServiceError {
                return try Self.jsonResponse(
                    Self.coreMLStatus(for: error),
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            } catch {
                return try Self.jsonResponse(
                    .internalServerError,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
        }

        // POST /coreml/predict
        app.on(.POST, "coreml", "predict", body: .collect(maxSize: "100mb")) { req async throws -> Response in
            try await Self.requireService(.coreml)
            let payload: CoreMLPredictRequestBody
            do {
                payload = try req.content.decode(CoreMLPredictRequestBody.self)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(
                        success: false,
                        message: "Expected JSON fields: model_id, inputs"
                    )
                )
            }

            do {
                let result = try await CoreMLService.shared.predict(
                    modelID: payload.model_id,
                    inputs: payload.inputs
                )
                return try Self.jsonResponse(
                    .ok,
                    CoreMLPredictResponse(
                        success: true,
                        outputs: result.outputs,
                        compute: "neuralEngine/all",
                        inference_ms: result.inferenceMilliseconds
                    )
                )
            } catch let error as CoreMLServiceError {
                return try Self.jsonResponse(
                    Self.coreMLStatus(for: error),
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            } catch {
                return try Self.jsonResponse(
                    .internalServerError,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
        }

        // POST /coreml/delete?model_id=...
        app.post("coreml", "delete") { req async throws -> Response in
            try await Self.requireService(.coreml)
            guard let modelID = try? req.query.get(String.self, at: "model_id"),
                  !modelID.isEmpty else {
                return try Self.jsonResponse(
                    .badRequest,
                    ComputeErrorResponse(success: false, message: "Missing query parameter: model_id")
                )
            }

            do {
                try await CoreMLService.shared.delete(modelID: modelID)
                return try Self.jsonResponse(
                    .ok,
                    CoreMLDeleteResponse(success: true, model_id: modelID)
                )
            } catch let error as CoreMLServiceError {
                return try Self.jsonResponse(
                    Self.coreMLStatus(for: error),
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            } catch {
                return try Self.jsonResponse(
                    .internalServerError,
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
        }

        // POST /docOCR
        app.on(.POST, "docOCR", body: .collect(maxSize: "100mb")) { [weak self] req async throws -> Response in
            try await Self.requireService(.dococr)
            try await Self.requireUploadWithinLimit(req)
            if #unavailable(iOS 26) {
                return try Self.jsonResponse(
                    .ok,
                    DocOCRResult(
                        success: false,
                        message: "This API is only supported on iOS 26 and later",
                        ocr_text: ""
                    )
                )
            }
            
            guard let self else { throw Abort(.internalServerError) }

            let upload: OCRUploadPayload
            do {
                upload = try req.content.decode(OCRUploadPayload.self)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    DocOCRResult(
                        success: false,
                        message: "Missing or empty 'file' part",
                        ocr_text: ""
                    )
                )
            }

            guard upload.file.data.readableBytes > 0 else {
                return try Self.jsonResponse(
                    .badRequest,
                    DocOCRResult(
                        success: false,
                        message: "Missing or empty 'file' part",
                        ocr_text: ""
                    )
                )
            }

            let options: OCRRequestOptions
            do {
                options = try Self.requestOptions(from: req)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    DocOCRResult(
                        success: false,
                        message: error.localizedDescription,
                        ocr_text: ""
                    )
                )
            }

            let data = Self.byteBufferToData(upload.file.data)
            let baseRuntime = await MainActor.run { Settings.shared.ocrRuntimeSnapshot() }
            let runtime: OCRRuntimeSettingsSnapshot
            do {
                runtime = try Self.runtimeSettings(options: options, base: baseRuntime)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
                    DocOCRResult(
                        success: false,
                        message: error.localizedDescription,
                        ocr_text: ""
                    )
                )
            }
            let rectify = Self.booleanValue(options.rectify) ?? runtime.rectifyDefault
            let improve = Self.improveRequested(options: options, runtime: runtime)
            let metadata = Self.domainMetadata(
                options: options,
                upload: upload,
                activePack: runtime.activePack
            )
            let pack: DomainPackSelection
            do {
                pack = try await OCRImprovementService.shared.resolvePack(metadata: metadata)
            } catch {
                return try Self.jsonResponse(
                    Self.ocrErrorStatus(error),
                    DocOCRResult(
                        success: false,
                        message: error.localizedDescription,
                        ocr_text: ""
                    )
                )
            }

            if #available(iOS 26, *) {
                let docRecognizer = DocRecognizer(
                    usesLanguageCorrection: runtime.usesLanguageCorrection,
                    automaticallyDetectsLanguage: runtime.automaticallyDetectsLanguage,
                    recognitionLanguages: runtime.recognitionLanguages,
                    minimumTextHeight: runtime.minimumTextHeight,
                    customWords: pack.words
                )

                if Self.isPDF(data) {
                    let dpiUsed = Self.effectivePDFDPI(
                        requested: options.dpi,
                        runtime: runtime
                    )
                    do {
                        let rendered = try await ImageProcessingService.shared.renderPDF(
                            data: data,
                            dpi: dpiUsed,
                            maximumPages: options.max_pages ?? runtime.pdfMaximumPages
                        )
                        var pages: [PDFDocOCRPageResponse] = []
                        pages.reserveCapacity(rendered.pages.count)

                        for page in rendered.pages {
                            let processed: RectifiedImage
                            if rectify {
                                processed = await ImageProcessingService.shared.rectify(
                                    data: page.imageData
                                )
                            } else {
                                processed = RectifiedImage(
                                    data: page.imageData,
                                    rectified: false
                                )
                            }
                            let text = await docRecognizer.recognizeParagraphText(
                                from: processed.data
                            )
                            let result = try await OCRImprovementService.shared.processDocument(
                                data: processed.data,
                                documentText: text,
                                visionConfiguration: runtime.visionConfiguration,
                                metadata: metadata,
                                improve: improve,
                                pageNumber: page.pageNumber,
                                pageCount: rendered.totalPageCount,
                                configuration: runtime.improvementConfiguration,
                                collectTrace: runtime.debugVerbose,
                                resolvedPack: pack
                            )
                            if let result {
                                await Self.recordDebugTraceIfNeeded(
                                    endpoint: "/docOCR?page=\(page.pageNumber)",
                                    result: result,
                                    runtime: runtime,
                                    improve: improve,
                                    recognitionLevel: runtime.recognitionLevel,
                                    usesLanguageCorrection: runtime.usesLanguageCorrection,
                                    automaticallyDetectsLanguage: runtime.automaticallyDetectsLanguage
                                )
                            }
                            pages.append(
                                PDFDocOCRPageResponse(
                                    page: page.pageNumber,
                                    success: result != nil,
                                    message: result == nil ? "OCR failed" : "OCR completed successfully",
                                    improvement: result,
                                    rectified: rectify ? processed.rectified : nil,
                                    dpi_used: dpiUsed
                                )
                            )
                        }

                        let succeeded = pages.allSatisfy(\.success)
                        return try Self.jsonResponse(
                            .ok,
                            PDFDocOCRResponse(
                                success: succeeded,
                                message: "Processed \(pages.count) of \(rendered.totalPageCount) PDF pages",
                                pages: pages
                            )
                        )
                    } catch {
                        return try Self.jsonResponse(
                            Self.ocrErrorStatus(error),
                            DocOCRResult(
                                success: false,
                                message: error.localizedDescription,
                                ocr_text: "",
                                dpi_used: dpiUsed
                            )
                        )
                    }
                }

                let processed: RectifiedImage
                if rectify {
                    processed = await ImageProcessingService.shared.rectify(data: data)
                } else {
                    processed = RectifiedImage(data: data, rectified: false)
                }
                let resultText = await docRecognizer.recognizeParagraphText(from: processed.data)
                let accept = (req.headers.first(name: .accept) ?? "").lowercased()
                let result: OCRImprovementResult?
                do {
                    result = try await OCRImprovementService.shared.processDocument(
                        data: processed.data,
                        documentText: resultText,
                        visionConfiguration: runtime.visionConfiguration,
                        metadata: metadata,
                        improve: improve,
                        configuration: runtime.improvementConfiguration,
                        collectTrace: runtime.debugVerbose,
                        resolvedPack: pack
                    )
                } catch {
                    return try Self.jsonResponse(
                        Self.ocrErrorStatus(error),
                        DocOCRResult(
                            success: false,
                            message: error.localizedDescription,
                            ocr_text: "",
                            rectified: rectify ? processed.rectified : nil
                        )
                    )
                }
                if let result {
                    await Self.recordDebugTraceIfNeeded(
                        endpoint: "/docOCR",
                        result: result,
                        runtime: runtime,
                        improve: improve,
                        recognitionLevel: runtime.recognitionLevel,
                        usesLanguageCorrection: runtime.usesLanguageCorrection,
                        automaticallyDetectsLanguage: runtime.automaticallyDetectsLanguage
                    )
                }

                if accept.contains("application/json") {
                    return try Self.jsonResponse(
                        .ok,
                        DocOCRResult(
                            success: result != nil,
                            message: result == nil ? "OCR quality analysis failed" : "OCR completed successfully",
                            ocr_text: result?.selectedText ?? resultText,
                            rectified: rectify ? processed.rectified : nil,
                            improvement: result
                        )
                    )
                }

                let escaped = Self.htmlEscape(result?.selectedText ?? resultText)
                let html = """
                <!doctype html>
                <html>
                <head>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Compute Server</title>
                    <style>
                        pre {
                            width: 100%;
                            max-width: 100%;
                            box-sizing: border-box;
                            white-space: pre-wrap;
                            word-wrap: break-word;
                            overflow-wrap: break-word;
                        }
                    </style>
                </head>
                <body>
                    <h2>OCR Result:</h2>
                    <hr>
                    <pre>\(escaped)</pre>
                </body>
                </html>
                """
                return Self.htmlResponse(html)
            }

            return try Self.jsonResponse(
                .serviceUnavailable,
                DocOCRResult(
                    success: false,
                    message: "This API is only supported on iOS 26 and later",
                    ocr_text: ""
                )
            )
        }
    }

    // MARK: - Helpers

    private static func requireAdminToken(request: Request) async throws {
        let configuredToken = await MainActor.run {
            Settings.shared.adminToken.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard configuredToken.isEmpty
                || request.headers.first(name: "X-Admin-Token") == configuredToken else {
            throw Abort(.unauthorized, reason: "Missing or invalid X-Admin-Token")
        }
    }

    private static func requireDebugEnabled() async throws {
        let enabled = await MainActor.run { Settings.shared.debugVerbose }
        guard enabled else {
            throw Abort(.forbidden, reason: "OCR debug mode is disabled")
        }
    }

    private static func requireService(_ service: ComputeServiceName) async throws {
        let enabled = await MainActor.run { Settings.shared.serviceEnabled(service) }
        guard enabled else {
            throw Abort(.serviceUnavailable, reason: "\(service.rawValue) disabled")
        }
    }

    private static func requireUploadWithinLimit(_ request: Request) async throws {
        guard let body = request.body.data else { return }
        let maximumMB = await MainActor.run { Settings.shared.maximumUploadMegabytes }
        let maximumBytes = maximumMB * 1_048_576
        guard body.readableBytes <= maximumBytes else {
            throw Abort(
                .payloadTooLarge,
                reason: "Upload body exceeds max_upload_mb (\(maximumMB) MB)"
            )
        }
    }

    private static func requireBatchFileLimit(_ count: Int) async throws {
        let maximum = await MainActor.run { Settings.shared.maximumBatchFiles }
        guard count <= maximum else {
            throw Abort(
                .badRequest,
                reason: "Batch contains \(count) files; max_batch_files is \(maximum)"
            )
        }
    }

    private static func fieldBatchResponse(
        request: Request,
        mode: FieldBatchMode
    ) async throws -> Response {
        let files: [ParsedMultipartFile]
        do {
            files = try MultipartUploadParser.files(from: request, fieldName: "file")
        } catch {
            return try jsonResponse(
                .badRequest,
                ComputeErrorResponse(success: false, message: error.localizedDescription)
            )
        }
        try await requireBatchFileLimit(files.count)

        let options: OCRRequestOptions
        do {
            options = try requestOptions(from: request)
        } catch {
            return try jsonResponse(
                .badRequest,
                ComputeErrorResponse(success: false, message: error.localizedDescription)
            )
        }

        let baseRuntime = await MainActor.run { Settings.shared.ocrRuntimeSnapshot() }
        let runtime: OCRRuntimeSettingsSnapshot
        do {
            runtime = try runtimeSettings(options: options, base: baseRuntime)
        } catch {
            return try jsonResponse(
                .badRequest,
                ComputeErrorResponse(success: false, message: error.localizedDescription)
            )
        }
        let improve = improveRequested(options: options, runtime: runtime)
        let metadata = OCRDomainMetadata(
            documentType: options.loai_van_ban,
            agency: options.co_quan,
            year: options.nam,
            requestedPack: options.pack ?? runtime.activePack
        )
        let pack: DomainPackSelection
        do {
            pack = try await OCRImprovementService.shared.resolvePack(metadata: metadata)
        } catch {
            return try jsonResponse(
                ocrErrorStatus(error),
                ComputeErrorResponse(success: false, message: error.localizedDescription)
            )
        }

        let rectify = booleanValue(options.rectify) ?? runtime.rectifyDefault
        var responses: [FieldBatchResult] = []
        responses.reserveCapacity(files.count)
        for (index, file) in files.enumerated() {
            let dpiUsed = isPDF(file.data)
                ? effectivePDFDPI(requested: options.dpi, runtime: runtime)
                : nil
            do {
                let results = try await processFieldBatchFile(
                    file,
                    mode: mode,
                    runtime: runtime,
                    metadata: metadata,
                    pack: pack,
                    improve: improve,
                    rectify: rectify,
                    dpi: dpiUsed ?? runtime.pdfDPI,
                    maximumPages: options.max_pages ?? runtime.pdfMaximumPages
                )
                responses.append(
                    FieldBatchResult(
                        filename: file.filename,
                        completed: index + 1,
                        total: files.count,
                        format: mode.responseFormat,
                        results: results,
                        pageSeparator: mode.pageSeparator,
                        dpi_used: dpiUsed
                    )
                )
            } catch {
                responses.append(
                    FieldBatchResult(
                        filename: file.filename,
                        completed: index + 1,
                        total: files.count,
                        format: mode.responseFormat,
                        error: error,
                        dpi_used: dpiUsed
                    )
                )
            }
        }
        return try jsonResponse(.ok, responses)
    }

    private static func processFieldBatchFile(
        _ file: ParsedMultipartFile,
        mode: FieldBatchMode,
        runtime: OCRRuntimeSettingsSnapshot,
        metadata: OCRDomainMetadata,
        pack: DomainPackSelection,
        improve: Bool,
        rectify: Bool,
        dpi: Int,
        maximumPages: Int
    ) async throws -> [OCRImprovementResult] {
        let pages: [RenderedPDFPage]
        let pageCount: Int?
        if isPDF(file.data) {
            let rendered = try await ImageProcessingService.shared.renderPDF(
                data: file.data,
                dpi: dpi,
                maximumPages: maximumPages
            )
            pages = rendered.pages
            pageCount = rendered.totalPageCount
        } else {
            pages = [RenderedPDFPage(pageNumber: 1, imageData: file.data)]
            pageCount = nil
        }

        var results: [OCRImprovementResult] = []
        results.reserveCapacity(pages.count)
        for page in pages {
            let processed: RectifiedImage
            if rectify {
                processed = await ImageProcessingService.shared.rectify(data: page.imageData)
            } else {
                processed = RectifiedImage(data: page.imageData, rectified: false)
            }

            let result: OCRImprovementResult?
            switch mode {
            case .ocr:
                result = try await OCRImprovementService.shared.processImage(
                    data: processed.data,
                    visionConfiguration: runtime.visionConfiguration,
                    metadata: metadata,
                    improve: improve,
                    pageNumber: pageCount == nil ? nil : page.pageNumber,
                    pageCount: pageCount,
                    configuration: runtime.improvementConfiguration,
                    collectTrace: false,
                    resolvedPack: pack
                )
            case .markdown, .docx:
                if #available(iOS 26, *) {
                    let recognizer = DocRecognizer(
                        usesLanguageCorrection: runtime.usesLanguageCorrection,
                        automaticallyDetectsLanguage: runtime.automaticallyDetectsLanguage,
                        recognitionLanguages: runtime.recognitionLanguages,
                        minimumTextHeight: runtime.minimumTextHeight,
                        customWords: pack.words
                    )
                    let documentText = await recognizer.recognizeParagraphText(
                        from: processed.data
                    )
                    result = try await OCRImprovementService.shared.processDocument(
                        data: processed.data,
                        documentText: documentText,
                        visionConfiguration: runtime.visionConfiguration,
                        metadata: metadata,
                        improve: improve,
                        pageNumber: pageCount == nil ? nil : page.pageNumber,
                        pageCount: pageCount,
                        configuration: runtime.improvementConfiguration,
                        collectTrace: false,
                        resolvedPack: pack
                    )
                } else {
                    throw FieldBatchError.documentRecognitionUnavailable
                }
            }
            guard let result else { throw FieldBatchError.recognitionFailed }
            results.append(result)
        }
        return results
    }

    private static func appliedCustomWordsCount() async throws -> Int {
        let activePack = await MainActor.run { Settings.shared.activePack }
        let pack = try await OCRImprovementService.shared.resolvePack(
            metadata: OCRDomainMetadata(
                documentType: nil,
                agency: nil,
                year: nil,
                requestedPack: activePack
            )
        )
        return pack.words.count
    }

    @MainActor
    private static func adminSettingsSnapshot() -> AdminSettingsResponse {
        let settings = Settings.shared
        return AdminSettingsResponse(
            schema: adminSettingSchema(),
            recognition_level: settings.recognitionLevel.lowercased(),
            recognition_languages: settings.recognitionLanguages,
            uses_language_correction: settings.languageCorrection,
            language_correction: settings.languageCorrection,
            automatically_detects_language: settings.automaticallyDetectsLanguage,
            minimum_text_height: settings.minimumTextHeight,
            vision_revision: settings.visionRevision,
            improve: settings.improveEnabled,
            corrector_groups: settings.correctorGroupNames,
            active_pack: settings.activePack,
            ambiguous_skip: settings.correctorGroupNames.contains(CorrectorGroup.ambiguousSkip.rawValue),
            confidence_threshold: settings.confidenceThreshold,
            multipass: settings.multipassEnabled,
            roi_upscale: settings.roiUpscale,
            max_roi_count: settings.maximumROIs,
            page_score_pass2_threshold: settings.pageScorePass2Threshold,
            pass2_fallback_ratio: settings.pass2FallbackRatio,
            legal_id_regex: settings.legalIDRegex,
            possible_legal_id_regex: settings.possibleLegalIDRegex,
            candidate_gap_threshold: settings.candidateGapThreshold,
            candidate_gap_confidence_threshold: settings.candidateGapConfidenceThreshold,
            candidate_gap_normalizer: settings.candidateGapNormalizer,
            line_confidence_weight: settings.lineConfidenceWeight,
            missing_page_number_min_pages: settings.missingPageNumberMinimumPages,
            broken_table_min_lines: settings.brokenTableMinimumLines,
            low_confidence_penalty: settings.lowConfidencePenalty,
            invalid_legal_id_penalty: settings.invalidLegalIDPenalty,
            missing_page_number_penalty: settings.missingPageNumberPenalty,
            broken_table_penalty: settings.brokenTablePenalty,
            multipass_min_confidence_gain: settings.multipassMinimumConfidenceGain,
            multipass_legal_id_tolerance: settings.multipassLegalIDTolerance,
            multipass_min_length_ratio: settings.multipassMinimumLengthRatio,
            multipass_max_length_ratio: settings.multipassMaximumLengthRatio,
            pdf_dpi: settings.pdfDPI,
            hot_dpi: settings.hotDPI,
            pdf_max_pages: settings.pdfMaximumPages,
            rectify_default: settings.rectifyDefault,
            http_port: settings.httpPort,
            keep_alive: settings.keepAliveEnabled,
            keep_alive_own_session: settings.keepAliveOwnSession,
            auto_blackout_idle_s: settings.autoBlackoutIdleSeconds,
            blackout: DisplayModeController.shared.isBlackout,
            watchdog_interval_s: settings.watchdogIntervalSeconds,
            debug_verbose: settings.debugVerbose,
            admin_token: settings.adminToken,
            admin_token_configured: !settings.adminToken
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            thermal_guard: settings.thermalGuard,
            max_queue: settings.maximumQueueDepth,
            max_inflight: settings.maximumOCRInflight,
            fair_gap_ms: settings.fairGapMilliseconds,
            max_upload_mb: settings.maximumUploadMegabytes,
            max_batch_files: settings.maximumBatchFiles
        )
    }

    @MainActor
    private static func applyAdminSettings(
        _ patch: AdminSettingsPatch,
        knownPackIDs: Set<String>
    ) -> AdminApplyResponse {
        let settings = Settings.shared
        var applied: [String] = []
        var rejected: [String] = []
        var requiresRestart = false

        if let value = patch.recognition_level {
            let normalized = value.lowercased()
            if ["accurate", "fast"].contains(normalized) {
                settings.recognitionLevel = normalized
                applied.append("recognition_level")
            } else {
                rejected.append("recognition_level: expected accurate or fast")
            }
        }
        if let value = patch.recognition_languages {
            let cleaned = value.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            var seen = Set<String>()
            let unique = cleaned.filter { seen.insert($0).inserted }
            if !unique.isEmpty, unique.count <= 8,
               unique.allSatisfy(Self.isValidLanguageIdentifier) {
                settings.recognitionLanguages = unique
                applied.append("recognition_languages")
            } else {
                rejected.append("recognition_languages: expected 1-8 BCP-47-style identifiers")
            }
        }
        if let value = patch.uses_language_correction ?? patch.language_correction {
            settings.languageCorrection = value
            applied.append("uses_language_correction")
        }
        if let value = patch.automatically_detects_language {
            settings.automaticallyDetectsLanguage = value
            applied.append("automatically_detects_language")
        }
        if let value = patch.minimum_text_height {
            applyDouble(value, key: "minimum_text_height", range: 0...1, applied: &applied, rejected: &rejected) {
                settings.minimumTextHeight = $0
            }
        }
        if let value = patch.vision_revision {
            if value == 0 || value == 3 {
                settings.visionRevision = value
                applied.append("vision_revision")
            } else {
                rejected.append("vision_revision: supported values are 0 (latest) and 3")
            }
        }
        if let value = patch.improve {
            settings.improveEnabled = value
            applied.append("improve")
        }
        if let value = patch.corrector_groups {
            let groups = value.compactMap(CorrectorGroup.init(rawValue:))
            if groups.count == value.count {
                settings.correctorGroupNames = Array(Set(groups.map(\.rawValue))).sorted()
                applied.append("corrector_groups")
            } else {
                rejected.append("corrector_groups: contains an unknown group")
            }
        }
        if let value = patch.ambiguous_skip {
            var groups = Set(settings.correctorGroupNames)
            if value {
                groups.insert(CorrectorGroup.ambiguousSkip.rawValue)
            } else {
                groups.remove(CorrectorGroup.ambiguousSkip.rawValue)
            }
            settings.correctorGroupNames = groups.sorted()
            applied.append("ambiguous_skip")
        }
        if let value = patch.active_pack {
            let normalized = value.lowercased()
            if normalized == "auto" || normalized == "none" || knownPackIDs.contains(normalized) {
                settings.activePack = normalized
                applied.append("active_pack")
            } else {
                rejected.append("active_pack: pack does not exist")
            }
        }
        if let value = patch.confidence_threshold {
            applyDouble(value, key: "confidence_threshold", range: 0...1, applied: &applied, rejected: &rejected) {
                settings.confidenceThreshold = $0
            }
        }
        if let value = patch.multipass {
            settings.multipassEnabled = value
            applied.append("multipass")
        }
        if let value = patch.roi_upscale {
            applyDouble(value, key: "roi_upscale", range: 1...4, applied: &applied, rejected: &rejected) {
                settings.roiUpscale = $0
            }
        }
        if let value = patch.max_roi_count {
            applyInteger(value, key: "max_roi_count", range: 0...20, applied: &applied, rejected: &rejected) {
                settings.maximumROIs = $0
            }
        }
        if let value = patch.page_score_pass2_threshold {
            applyDouble(value, key: "page_score_pass2_threshold", range: 0...1, applied: &applied, rejected: &rejected) {
                settings.pageScorePass2Threshold = $0
            }
        }
        if let value = patch.pass2_fallback_ratio {
            applyDouble(value, key: "pass2_fallback_ratio", range: 0...1, applied: &applied, rejected: &rejected) {
                settings.pass2FallbackRatio = $0
            }
        }
        if let value = patch.legal_id_regex {
            applyRegex(value, key: "legal_id_regex", applied: &applied, rejected: &rejected) {
                settings.legalIDRegex = $0
            }
        }
        if let value = patch.possible_legal_id_regex {
            applyRegex(value, key: "possible_legal_id_regex", applied: &applied, rejected: &rejected) {
                settings.possibleLegalIDRegex = $0
            }
        }
        let doubles: [(Double?, String, ClosedRange<Double>, (Double) -> Void)] = [
            (patch.candidate_gap_threshold, "candidate_gap_threshold", 0...1, { settings.candidateGapThreshold = $0 }),
            (patch.candidate_gap_confidence_threshold, "candidate_gap_confidence_threshold", 0...1, { settings.candidateGapConfidenceThreshold = $0 }),
            (patch.candidate_gap_normalizer, "candidate_gap_normalizer", 0.001...1, { settings.candidateGapNormalizer = $0 }),
            (patch.line_confidence_weight, "line_confidence_weight", 0...1, { settings.lineConfidenceWeight = $0 }),
            (patch.low_confidence_penalty, "low_confidence_penalty", 0...1, { settings.lowConfidencePenalty = $0 }),
            (patch.invalid_legal_id_penalty, "invalid_legal_id_penalty", 0...1, { settings.invalidLegalIDPenalty = $0 }),
            (patch.missing_page_number_penalty, "missing_page_number_penalty", 0...1, { settings.missingPageNumberPenalty = $0 }),
            (patch.broken_table_penalty, "broken_table_penalty", 0...1, { settings.brokenTablePenalty = $0 }),
            (patch.multipass_min_confidence_gain, "multipass_min_confidence_gain", 0...1, { settings.multipassMinimumConfidenceGain = $0 }),
            (patch.multipass_legal_id_tolerance, "multipass_legal_id_tolerance", 0...1, { settings.multipassLegalIDTolerance = $0 }),
            (patch.watchdog_interval_s, "watchdog_interval_s", 10...3600, { settings.watchdogIntervalSeconds = $0 }),
        ]
        for (value, key, range, setter) in doubles {
            if let value {
                applyDouble(value, key: key, range: range, applied: &applied, rejected: &rejected, setter: setter)
            }
        }
        let proposedMinimumLengthRatio = patch.multipass_min_length_ratio
            ?? settings.multipassMinimumLengthRatio
        let proposedMaximumLengthRatio = patch.multipass_max_length_ratio
            ?? settings.multipassMaximumLengthRatio
        let minimumLengthRatioValid = proposedMinimumLengthRatio.isFinite
            && (0.1...2).contains(proposedMinimumLengthRatio)
        let maximumLengthRatioValid = proposedMaximumLengthRatio.isFinite
            && (0.5...4).contains(proposedMaximumLengthRatio)
        if patch.multipass_min_length_ratio != nil, !minimumLengthRatioValid {
            rejected.append("multipass_min_length_ratio: expected 0.1-2.0")
        }
        if patch.multipass_max_length_ratio != nil, !maximumLengthRatioValid {
            rejected.append("multipass_max_length_ratio: expected 0.5-4.0")
        }
        if minimumLengthRatioValid, maximumLengthRatioValid,
           proposedMinimumLengthRatio <= proposedMaximumLengthRatio {
            if patch.multipass_min_length_ratio != nil {
                settings.multipassMinimumLengthRatio = proposedMinimumLengthRatio
                applied.append("multipass_min_length_ratio")
            }
            if patch.multipass_max_length_ratio != nil {
                settings.multipassMaximumLengthRatio = proposedMaximumLengthRatio
                applied.append("multipass_max_length_ratio")
            }
        } else if minimumLengthRatioValid, maximumLengthRatioValid,
                  patch.multipass_min_length_ratio != nil
                    || patch.multipass_max_length_ratio != nil {
            rejected.append("multipass length ratios: minimum must not exceed maximum")
        }
        if let value = patch.missing_page_number_min_pages {
            applyInteger(value, key: "missing_page_number_min_pages", range: 2...10_000, applied: &applied, rejected: &rejected) {
                settings.missingPageNumberMinimumPages = $0
            }
        }
        if let value = patch.broken_table_min_lines {
            applyInteger(value, key: "broken_table_min_lines", range: 1...100, applied: &applied, rejected: &rejected) {
                settings.brokenTableMinimumLines = $0
            }
        }
        if let value = patch.pdf_dpi {
            applyInteger(value, key: "pdf_dpi", range: 72...300, applied: &applied, rejected: &rejected) {
                settings.pdfDPI = $0
            }
        }
        if let value = patch.hot_dpi {
            applyInteger(value, key: "hot_dpi", range: 72...300, applied: &applied, rejected: &rejected) {
                settings.hotDPI = $0
            }
        }
        if let value = patch.pdf_max_pages {
            applyInteger(value, key: "pdf_max_pages", range: 1...200, applied: &applied, rejected: &rejected) {
                settings.pdfMaximumPages = $0
            }
        }
        if let value = patch.rectify_default {
            settings.rectifyDefault = value
            applied.append("rectify_default")
        }
        if let value = patch.http_port {
            if (1024...65_535).contains(value) {
                requiresRestart = settings.httpPort != value
                settings.httpPort = value
                applied.append("http_port")
            } else {
                rejected.append("http_port: expected 1024-65535")
            }
        }
        if let value = patch.keep_alive {
            KeepAliveService.shared.setEnabled(value)
            applied.append("keep_alive")
        }
        if let value = patch.keep_alive_own_session {
            KeepAliveService.shared.setOwnSession(value)
            applied.append("keep_alive_own_session")
        }
        if let value = patch.auto_blackout_idle_s {
            if value >= 0 {
                settings.autoBlackoutIdleSeconds = value
                DisplayModeController.shared.refreshAutoBlackoutSchedule()
                applied.append("auto_blackout_idle_s")
            } else {
                rejected.append("auto_blackout_idle_s: expected 0 or more seconds")
            }
        }
        if let value = patch.blackout {
            DisplayModeController.shared.setBlackout(value)
            applied.append("blackout")
        }
        if let value = patch.debug_verbose {
            settings.debugVerbose = value
            applied.append("debug_verbose")
        }
        if let value = patch.admin_token {
            if value.count <= 512 {
                settings.adminToken = value.trimmingCharacters(in: .whitespacesAndNewlines)
                applied.append("admin_token")
            } else {
                rejected.append("admin_token: maximum length is 512")
            }
        }
        if let value = patch.thermal_guard {
            settings.thermalGuard = value
            applied.append("thermal_guard")
        }
        if let value = patch.max_queue {
            applyInteger(value, key: "max_queue", range: 0...100, applied: &applied, rejected: &rejected) {
                settings.maximumQueueDepth = $0
            }
        }
        if let value = patch.max_inflight {
            applyInteger(value, key: "max_inflight", range: 1...8, applied: &applied, rejected: &rejected) {
                settings.maximumOCRInflight = $0
            }
        }
        if let value = patch.fair_gap_ms {
            applyInteger(value, key: "fair_gap_ms", range: 0...10_000, applied: &applied, rejected: &rejected) {
                settings.fairGapMilliseconds = $0
            }
        }
        if let value = patch.max_upload_mb {
            applyInteger(value, key: "max_upload_mb", range: 1...100, applied: &applied, rejected: &rejected) {
                settings.maximumUploadMegabytes = $0
            }
        }
        if let value = patch.max_batch_files {
            applyInteger(value, key: "max_batch_files", range: 1...200, applied: &applied, rejected: &rejected) {
                settings.maximumBatchFiles = $0
            }
        }

        if applied.isEmpty, rejected.isEmpty {
            rejected.append("No supported setting was provided")
        }
        return AdminApplyResponse(
            applied: applied,
            rejected: rejected,
            restarted: requiresRestart
        )
    }

    @MainActor
    private static func applyServices(_ patch: AdminServicesPatch) -> AdminServicesResponse {
        let values: [(ComputeServiceName, Bool?)] = [
            (.ocr, patch.ocr), (.dococr, patch.dococr), (.console, patch.console),
            (.batchOCR, patch.batch_ocr), (.batchMarkdown, patch.batch_markdown),
            (.batchDocx, patch.batch_docx), (.translate, patch.translate),
            (.transcribe, patch.transcribe), (.synthesize, patch.synthesize),
            (.llm, patch.llm), (.ner, patch.ner), (.embed, patch.embed),
            (.coreml, patch.coreml), (.barcode, patch.barcode),
        ]
        var applied: [String] = []
        for (service, value) in values where value != nil {
            Settings.shared.setService(service, enabled: value ?? true)
            applied.append(service.rawValue)
        }
        return AdminServicesResponse(
            services: Settings.shared.serviceStates(),
            applied: applied
        )
    }

    private static func adminSettingSchema() -> [AdminSettingDescriptor] {
        func item(
            _ key: String,
            _ type: String,
            _ minimum: Double? = nil,
            _ maximum: Double? = nil,
            _ options: [String]? = nil,
            restart: Bool = false,
            secret: Bool = false
        ) -> AdminSettingDescriptor {
            AdminSettingDescriptor(
                key: key,
                type: type,
                minimum: minimum,
                maximum: maximum,
                options: options,
                requires_restart: restart,
                secret: secret
            )
        }
        let groups = CorrectorGroup.allCases.map(\.rawValue).sorted()
        return [
            item("recognition_level", "enum", nil, nil, ["accurate", "fast"]),
            item("recognition_languages", "string_array", 1, 8),
            item("uses_language_correction", "bool"),
            item("automatically_detects_language", "bool"),
            item("minimum_text_height", "double", 0, 1),
            item("vision_revision", "int", 0, 3, ["0", "3"]),
            item("improve", "bool"),
            item("corrector_groups", "string_array", 0, Double(groups.count), groups),
            item("active_pack", "string", 1, 64),
            item("ambiguous_skip", "bool"),
            item("confidence_threshold", "double", 0, 1),
            item("multipass", "bool"),
            item("roi_upscale", "double", 1, 4),
            item("max_roi_count", "int", 0, 20),
            item("page_score_pass2_threshold", "double", 0, 1),
            item("pass2_fallback_ratio", "double", 0, 1),
            item("legal_id_regex", "string", 1, 2_000),
            item("possible_legal_id_regex", "string", 1, 2_000),
            item("candidate_gap_threshold", "double", 0, 1),
            item("candidate_gap_confidence_threshold", "double", 0, 1),
            item("candidate_gap_normalizer", "double", 0.001, 1),
            item("line_confidence_weight", "double", 0, 1),
            item("missing_page_number_min_pages", "int", 2, 10_000),
            item("broken_table_min_lines", "int", 1, 100),
            item("low_confidence_penalty", "double", 0, 1),
            item("invalid_legal_id_penalty", "double", 0, 1),
            item("missing_page_number_penalty", "double", 0, 1),
            item("broken_table_penalty", "double", 0, 1),
            item("multipass_min_confidence_gain", "double", 0, 1),
            item("multipass_legal_id_tolerance", "double", 0, 1),
            item("multipass_min_length_ratio", "double", 0.1, 2),
            item("multipass_max_length_ratio", "double", 0.5, 4),
            item("pdf_dpi", "int", 72, 300),
            item("hot_dpi", "int", 72, 300),
            item("pdf_max_pages", "int", 1, 200),
            item("rectify_default", "bool"),
            item("http_port", "int", 1024, 65_535, restart: true),
            item("keep_alive", "bool"),
            item("keep_alive_own_session", "bool"),
            item("auto_blackout_idle_s", "int", 0),
            item("blackout", "bool"),
            item("watchdog_interval_s", "double", 10, 3600),
            item("debug_verbose", "bool"),
            item("admin_token", "string", 0, 512, secret: true),
            item("thermal_guard", "bool"),
            item("max_queue", "int", 0, 100),
            item("max_inflight", "int", 1, 8),
            item("fair_gap_ms", "int", 0, 10_000),
            item("max_upload_mb", "int", 1, 100),
            item("max_batch_files", "int", 1, 200),
        ]
    }

    private static func applyDouble(
        _ value: Double,
        key: String,
        range: ClosedRange<Double>,
        applied: inout [String],
        rejected: inout [String],
        setter: (Double) -> Void
    ) {
        guard value.isFinite, range.contains(value) else {
            rejected.append("\(key): expected \(range.lowerBound)-\(range.upperBound)")
            return
        }
        setter(value)
        applied.append(key)
    }

    private static func applyInteger(
        _ value: Int,
        key: String,
        range: ClosedRange<Int>,
        applied: inout [String],
        rejected: inout [String],
        setter: (Int) -> Void
    ) {
        guard range.contains(value) else {
            rejected.append("\(key): expected \(range.lowerBound)-\(range.upperBound)")
            return
        }
        setter(value)
        applied.append(key)
    }

    private static func applyRegex(
        _ value: String,
        key: String,
        applied: inout [String],
        rejected: inout [String],
        setter: (String) -> Void
    ) {
        guard !value.isEmpty, value.count <= 2_000,
              (try? NSRegularExpression(pattern: value)) != nil else {
            rejected.append("\(key): invalid regular expression")
            return
        }
        setter(value)
        applied.append(key)
    }

    private static func validateWords(_ words: [String]) throws {
        guard words.count <= 50_000,
              words.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 200 }) else {
            throw Abort(.badRequest, reason: "words must contain at most 50000 non-empty items of 200 characters")
        }
    }

    private static func validateOverrides(_ overrides: [String: String]) throws {
        guard overrides.count <= 50_000,
              overrides.allSatisfy({
                !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && $0.key.count <= 500
                    && $0.value.count <= 500
              }) else {
            throw Abort(.badRequest, reason: "overrides must contain at most 50000 non-empty pairs of 500 characters")
        }
    }

    private static func validatePackID(_ id: String) throws {
        guard id.range(of: "^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$", options: .regularExpression) != nil,
              !["auto", "none", "off"].contains(id.lowercased()) else {
            throw Abort(.badRequest, reason: "id must be 1-64 safe characters and not auto/none/off")
        }
    }

    private static func scheduleServerRestart(reason: String) {
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            NotificationCenter.default.post(
                name: .vaporServerShouldRestart,
                object: nil,
                userInfo: ["reason": reason, "automatic": false]
            )
        }
    }

    private static func adminHTMLV3(port: Int) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <title>Compute Control Plane</title>
          <style>
            :root{color-scheme:dark;--bg:#061014;--panel:#0c1b20;--line:#244149;--ink:#eaf7f4;--muted:#88a6a3;--accent:#25d7be;--warn:#ffb45e;--bad:#ff776f}
            *{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 85% 0,#16424a 0,transparent 32%),linear-gradient(145deg,#061014,#09171b 65%);color:var(--ink);font:14px ui-monospace,SFMono-Regular,Menlo,monospace}
            main{width:min(1280px,calc(100% - 24px));margin:24px auto 70px}h1{font-size:clamp(27px,5vw,48px);letter-spacing:-2px;margin:0}h2{font-size:12px;letter-spacing:1.5px;text-transform:uppercase;color:var(--accent);margin:0 0 13px}.sub{color:var(--muted);margin:6px 0 20px}
            .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:13px}.wide{grid-column:1/-1}section{background:linear-gradient(145deg,#10242a,#09161a);border:1px solid var(--line);border-radius:15px;padding:16px;box-shadow:0 18px 55px #0006}
            .fields{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:9px 13px}label{display:grid;gap:5px;color:var(--muted)}input,select,textarea,button{width:100%;border:1px solid var(--line);border-radius:8px;padding:9px 10px;background:#061216;color:var(--ink);font:inherit}textarea{min-height:110px;resize:vertical}.check{display:flex;align-items:center;gap:8px}.check input{width:auto}.actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}.actions button{width:auto;min-width:150px;background:#12343a;font-weight:800;cursor:pointer}.danger{background:#4a2020!important;color:#ffd6d2}.pill{display:inline-block;border:1px solid var(--line);border-radius:999px;padding:5px 9px;color:var(--muted)}pre{white-space:pre-wrap;overflow:auto;max-height:420px;font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;color:#bdd2cf}.message{min-height:20px;color:var(--warn);margin:10px 0}.service{display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #ffffff10;padding:7px 0}.service input{width:auto}@media(max-width:620px){main{width:min(100% - 14px,1280px);margin-top:12px}.fields{grid-template-columns:1fr}.actions button{width:100%}}
          </style>
        </head>
        <body><main>
          <h1>COMPUTE / CONTROL PLANE</h1>
          <p class="sub">Port \(port) · persistent defaults + per-request overrides + hot resources</p>
          <section>
            <h2>Access</h2>
            <div class="fields"><label>X-Admin-Token<input id="token" type="password" autocomplete="off"></label></div>
            <div class="actions"><button id="remember">Remember token</button><button id="refresh">Refresh all</button><button id="restart" class="danger">Restart server</button></div>
            <div id="message" class="message"></div>
          </section>
          <div class="grid">
            <section><h2>Health</h2><span id="healthPill" class="pill">loading</span><pre id="health"></pre></section>
            <section><h2>Services</h2><div id="services"></div><div class="actions"><button id="saveServices">Apply services</button></div></section>
            <section class="wide"><h2>All persistent settings</h2><div id="settings" class="fields"></div><div class="actions"><button id="saveSettings">Apply settings</button></div></section>
            <section><h2>Vision customWords</h2><textarea id="customWords" placeholder="one word or phrase per line"></textarea><div class="actions"><button data-mode="replace" class="saveWords">Replace</button><button data-mode="append" class="saveWords">Append</button></div></section>
            <section><h2>Post-corrector overrides</h2><textarea id="corrections" placeholder='{"bad":"good"}'></textarea><div class="actions"><button id="saveCorrections">Merge overrides</button></div></section>
            <section><h2>Custom domain pack</h2><textarea id="pack" placeholder='{"id":"my-pack","words":[],"overrides":{}}'></textarea><div class="actions"><button id="savePack">Save pack</button><button id="resetLexicon" class="danger">Reset custom lexicon</button></div><pre id="packs"></pre></section>
            <section class="wide"><h2>Request log · 5s refresh</h2><pre id="logs">loading</pre></section>
          </div>
        </main>
        <script>
          const $=id=>document.getElementById(id); let settingsSnapshot=null;
          $('token').value=localStorage.getItem('computeAdminToken')||'';
          const headers=()=>{const h={'Content-Type':'application/json'};if($('token').value)h['X-Admin-Token']=$('token').value;return h};
          async function api(path,options={}){const r=await fetch(path,{...options,headers:{...headers(),...(options.headers||{})}});const text=await r.text();let data={};try{data=JSON.parse(text)}catch{data={message:text}}if(!r.ok)throw new Error(data.reason||data.message||r.statusText);return data}
          const msg=value=>$('message').textContent=value;
          function control(d,value){const id='setting_'+d.key;let input;if(d.type==='bool'){input=document.createElement('input');input.type='checkbox';input.checked=!!value}else if(d.options&&d.type!=='string_array'){input=document.createElement('select');d.options.forEach(v=>{const o=document.createElement('option');o.value=v;o.textContent=v;input.appendChild(o)});input.value=String(value)}else if(d.type==='string_array'){input=document.createElement('input');input.value=(value||[]).join(',')}else if(d.type==='int'||d.type==='double'){input=document.createElement('input');input.type='number';input.step=d.type==='int'?'1':'any';if(d.minimum!==null)input.min=d.minimum;if(d.maximum!==null)input.max=d.maximum;input.value=value}else{input=document.createElement(d.key.includes('regex')?'textarea':'input');input.value=value??'';if(d.secret)input.type='password'}input.id=id;input.dataset.type=d.type;const label=document.createElement('label');label.textContent=d.key+(d.requires_restart?' · restart':'');label.appendChild(input);return label}
          function renderSettings(data){settingsSnapshot=data;const root=$('settings');root.replaceChildren();data.schema.forEach(d=>root.appendChild(control(d,data[d.key])))}
          function settingPayload(){const out={};settingsSnapshot.schema.forEach(d=>{const el=$('setting_'+d.key);if(d.type==='bool')out[d.key]=el.checked;else if(d.type==='int')out[d.key]=Number.parseInt(el.value,10);else if(d.type==='double')out[d.key]=Number(el.value);else if(d.type==='string_array')out[d.key]=el.value.split(',').map(x=>x.trim()).filter(Boolean);else out[d.key]=el.value});return out}
          function renderServices(data){const root=$('services');root.replaceChildren();Object.entries(data.services).forEach(([name,on])=>{const row=document.createElement('label');row.className='service';row.textContent=name;const toggle=document.createElement('input');toggle.type='checkbox';toggle.checked=on;toggle.dataset.service=name;row.appendChild(toggle);root.appendChild(row)})}
          async function refresh(){try{const [health,settings,services,words,corrections,packs,log]=await Promise.all([api('/health'),api('/admin/settings'),api('/admin/services'),api('/admin/customwords'),api('/admin/corrections'),api('/admin/packs'),api('/admin/log')]);$('healthPill').textContent=health.status.toUpperCase()+' · '+health.uptime_s+'s';$('health').textContent=JSON.stringify(health,null,2);renderSettings(settings);renderServices(services);$('customWords').value=words.words.join('\n');$('corrections').value=JSON.stringify(corrections.overrides,null,2);$('packs').textContent=JSON.stringify(packs,null,2);$('logs').textContent=log.logs.slice().reverse().map(x=>`${x.timestamp} ${x.method.padEnd(8)} ${String(x.status).padStart(3)} ${x.duration_ms.toFixed(1).padStart(8)}ms ${x.size}B ${x.path}`).join('\n');msg('')}catch(e){msg(e.message)}}
          $('remember').onclick=()=>{localStorage.setItem('computeAdminToken',$('token').value);msg('Token saved locally')};$('refresh').onclick=refresh;$('restart').onclick=async()=>{try{await api('/admin/restart',{method:'POST',body:'{}'});msg('Restart requested')}catch(e){msg(e.message)}};
          $('saveSettings').onclick=async()=>{try{const payload=settingPayload();const result=await api('/admin/settings',{method:'POST',body:JSON.stringify(payload)});if(payload.admin_token!==undefined){$('token').value=payload.admin_token;localStorage.setItem('computeAdminToken',payload.admin_token)}if(result.restarted){msg('Settings applied; server restart requested. Reconnect on port '+payload.http_port+'.')}else{await refresh();msg(JSON.stringify(result))}}catch(e){msg(e.message)}};
          $('saveServices').onclick=async()=>{try{const payload={};document.querySelectorAll('[data-service]').forEach(x=>payload[x.dataset.service]=x.checked);msg(JSON.stringify(await api('/admin/services',{method:'POST',body:JSON.stringify(payload)})))}catch(e){msg(e.message)}};
          document.querySelectorAll('.saveWords').forEach(button=>button.onclick=async()=>{try{const words=$('customWords').value.split('\n').map(x=>x.trim()).filter(Boolean);await api('/admin/customwords?mode='+button.dataset.mode,{method:'POST',body:JSON.stringify({words})});await refresh()}catch(e){msg(e.message)}});
          $('saveCorrections').onclick=async()=>{try{await api('/admin/corrections',{method:'POST',body:JSON.stringify({overrides:JSON.parse($('corrections').value||'{}')})});await refresh()}catch(e){msg(e.message)}};
          $('savePack').onclick=async()=>{try{await api('/admin/pack',{method:'POST',body:JSON.stringify(JSON.parse($('pack').value))});await refresh()}catch(e){msg(e.message)}};$('resetLexicon').onclick=async()=>{try{await api('/admin/lexicon/reset',{method:'POST',body:'{}'});await refresh()}catch(e){msg(e.message)}};
          refresh();setInterval(async()=>{try{const log=await api('/admin/log');$('logs').textContent=log.logs.slice().reverse().map(x=>`${x.timestamp} ${x.method.padEnd(8)} ${String(x.status).padStart(3)} ${x.duration_ms.toFixed(1).padStart(8)}ms ${x.size}B ${x.path}`).join('\n')}catch{}},5000);
        </script></body></html>
        """
    }

    private static func adminHTML(port: Int) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <title>Compute Admin</title>
          <style>
            :root { color-scheme:dark; --bg:#071014; --panel:#0e1c21; --line:#244047; --ink:#e8f5f3; --muted:#88a5a2; --accent:#23d2bd; --warn:#ffb454; }
            * { box-sizing:border-box; }
            body { margin:0; background:radial-gradient(circle at top right,#12333a 0,transparent 42%),var(--bg); color:var(--ink); font:15px -apple-system,BlinkMacSystemFont,sans-serif; }
            main { width:min(980px,calc(100% - 28px)); margin:28px auto 64px; }
            h1 { margin:0; font:800 34px ui-monospace,SFMono-Regular,Menlo,monospace; letter-spacing:-1px; }
            .sub { color:var(--muted); margin:6px 0 22px; }
            .grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(280px,1fr)); gap:14px; }
            section { margin:14px 0; background:linear-gradient(145deg,#102329,#0a171b); border:1px solid var(--line); border-radius:16px; padding:18px; box-shadow:0 18px 50px #0005; }
            h2 { margin:0 0 14px; font-size:13px; text-transform:uppercase; letter-spacing:1.4px; color:var(--accent); }
            label { display:grid; gap:6px; color:var(--muted); margin:10px 0; }
            input,select,button { width:100%; border:1px solid var(--line); border-radius:9px; padding:10px 12px; color:var(--ink); background:#071216; font:inherit; }
            input[type=checkbox] { width:auto; }
            .check { display:flex; align-items:center; gap:9px; }
            button { cursor:pointer; background:#133138; font-weight:700; }
            button:hover { border-color:var(--accent); }
            button.danger { margin-top:10px; color:#ffd8d3; background:#4b2020; }
            .row { display:flex; gap:9px; margin-top:10px; }
            .pill { display:inline-block; padding:5px 9px; border:1px solid var(--line); border-radius:999px; color:var(--muted); font:12px ui-monospace,SFMono-Regular,Menlo,monospace; }
            pre { min-height:230px; max-height:420px; overflow:auto; white-space:pre-wrap; color:#b9cfcc; font:12px/1.55 ui-monospace,SFMono-Regular,Menlo,monospace; }
            #message { min-height:20px; color:var(--warn); margin:12px 0; }
          </style>
        </head>
        <body><main>
          <h1>COMPUTE / ADMIN</h1>
          <p class="sub">Live control for port \(port). Tokens stay only in this browser.</p>
          <section>
            <h2>Access</h2>
            <label>Current X-Admin-Token <input id="token" type="password" autocomplete="off"></label>
            <button id="remember">Remember current token locally</button>
            <label>New token (blank clears protection) <input id="newToken" type="password" autocomplete="new-password"></label>
            <button id="applyToken">Set / clear server token</button>
            <div id="message"></div>
          </section>
          <div class="grid">
            <section><h2>Health</h2><div id="health" class="pill">loading</div><pre id="healthData"></pre></section>
            <section>
              <h2>Settings</h2>
              <label>Recognition level <select id="level"><option>Accurate</option><option>Fast</option></select></label>
              <label class="check"><input id="correction" type="checkbox"> Language correction</label>
              <label class="check"><input id="detect" type="checkbox"> Auto-detect language</label>
              <label class="check"><input id="improve" type="checkbox"> Auto-improve OCR</label>
              <label>Confidence threshold <input id="confidence" type="number" min="0.05" max="0.99" step="0.01"></label>
              <label class="check"><input id="multipass" type="checkbox"> Quality-gated multipass</label>
              <label>ROI upscale <input id="roiUpscale" type="number" min="1" max="4" step="0.25"></label>
              <label>Active domain pack <select id="activePack"><option>auto</option><option>none</option><option>minimal</option><option>legal</option><option>tax</option><option>customs</option></select></label>
              <label>Corrector groups (comma-separated) <input id="correctorGroups" type="text"></label>
              <label class="check"><input id="debugVerbose" type="checkbox"> Verbose debug trace</label>
              <label class="check"><input id="keepalive" type="checkbox"> Keep alive</label>
              <div class="row"><button id="save">Apply settings</button><button id="toggleKeepalive">Toggle keep-alive</button></div>
              <button id="restart" class="danger">Restart server</button>
            </section>
          </div>
          <section><h2>Request Log · refresh 5s</h2><pre id="logs">loading</pre></section>
        </main>
        <script>
          const $ = id => document.getElementById(id);
          $('token').value = localStorage.getItem('computeAdminToken') || '';
          const headers = () => { const h={'Content-Type':'application/json'}; if ($('token').value) h['X-Admin-Token']=$('token').value; return h; };
          async function api(path, options={}) { const response=await fetch(path,{...options,headers:{...headers(),...(options.headers||{})}}); const data=await response.json(); if(!response.ok) throw new Error(data.reason||data.message||response.statusText); return data; }
          function message(value) { $('message').textContent=value; }
          async function refresh() {
            try {
              const [health,settings,log] = await Promise.all([api('/health'),api('/admin/settings'),api('/admin/log')]);
              $('health').textContent=health.status.toUpperCase()+' · '+health.uptime_s+'s';
              $('healthData').textContent=JSON.stringify(health,null,2);
              $('level').value=settings.recognition_level; $('correction').checked=settings.language_correction; $('detect').checked=settings.automatically_detects_language; $('improve').checked=settings.improve; $('confidence').value=settings.confidence_threshold; $('multipass').checked=settings.multipass; $('roiUpscale').value=settings.roi_upscale; $('activePack').value=settings.active_pack; $('correctorGroups').value=settings.corrector_groups.join(','); $('debugVerbose').checked=settings.debug_verbose; $('keepalive').checked=settings.keep_alive;
              $('logs').textContent=log.logs.slice().reverse().map(x=>`${x.timestamp} ${x.method.padEnd(8)} ${String(x.status).padStart(3)} ${x.duration_ms.toFixed(1).padStart(8)}ms ${x.path}`).join('\\n');
              message('');
            } catch(error) { message(error.message); }
          }
          $('remember').onclick=()=>{ localStorage.setItem('computeAdminToken',$('token').value); message('Current token saved in localStorage.'); };
          $('applyToken').onclick=async()=>{ try { const value=$('newToken').value; await api('/admin/settings',{method:'POST',body:JSON.stringify({admin_token:value})}); $('token').value=value; $('newToken').value=''; localStorage.setItem('computeAdminToken',value); message('Server token updated.'); } catch(error) { message(error.message); } };
          $('save').onclick=async()=>{ try { await api('/admin/settings',{method:'POST',body:JSON.stringify({recognition_level:$('level').value,language_correction:$('correction').checked,automatically_detects_language:$('detect').checked,improve:$('improve').checked,confidence_threshold:Number($('confidence').value),multipass:$('multipass').checked,roi_upscale:Number($('roiUpscale').value),active_pack:$('activePack').value,corrector_groups:$('correctorGroups').value.split(',').map(x=>x.trim()).filter(Boolean),debug_verbose:$('debugVerbose').checked,keep_alive:$('keepalive').checked})}); message('Settings applied. Restart may follow.'); } catch(error) { message(error.message); } };
          $('toggleKeepalive').onclick=async()=>{ try { await api('/admin/keepalive',{method:'POST',body:JSON.stringify({on:!$('keepalive').checked})}); await refresh(); } catch(error) { message(error.message); } };
          $('restart').onclick=async()=>{ try { await api('/admin/restart',{method:'POST',body:'{}'}); message('Restart requested.'); } catch(error) { message(error.message); } };
          refresh(); setInterval(refresh,5000);
        </script></body></html>
        """
    }

    private static func byteBufferToData(_ buffer: ByteBuffer) -> Data {
        var tmp = buffer
        if let bytes = tmp.readBytes(length: tmp.readableBytes) {
            return Data(bytes)
        }
        return Data()
    }

    private static func requestOptions(from request: Request) throws -> OCRRequestOptions {
        let options = try request.query.decode(OCRRequestOptions.self)
        if let dpi = options.dpi, !(72...300).contains(dpi) {
            throw ImageProcessingError.invalidPDFOptions("'dpi' must be between 72 and 300")
        }
        if let maximumPages = options.max_pages, !(1...200).contains(maximumPages) {
            throw ImageProcessingError.invalidPDFOptions(
                "'max_pages' must be between 1 and 200"
            )
        }
        for (name, value) in [
            ("rectify", options.rectify),
            ("improve", options.improve),
            ("raw", options.raw),
            ("multipass", options.multipass),
        ] where value != nil && booleanValue(value) == nil {
            throw ImageProcessingError.invalidPDFOptions("'\(name)' must be 0/1 or true/false")
        }
        if let level = options.level, !["accurate", "fast"].contains(level.lowercased()) {
            throw ImageProcessingError.invalidPDFOptions("'level' must be accurate or fast")
        }
        if let conf = options.conf, !conf.isFinite || !(0...1).contains(conf) {
            throw ImageProcessingError.invalidPDFOptions("'conf' must be between 0 and 1")
        }
        if let upscale = options.upscale, !upscale.isFinite || !(1...4).contains(upscale) {
            throw ImageProcessingError.invalidPDFOptions("'upscale' must be between 1 and 4")
        }
        if let groups = options.groups {
            let values = groups.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard values.allSatisfy({ CorrectorGroup(rawValue: $0) != nil }) else {
                throw ImageProcessingError.invalidPDFOptions("'groups' contains an unknown corrector group")
            }
        }
        if let pack = options.pack {
            let normalized = pack.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard normalized.range(
                of: "^[a-z0-9][a-z0-9._-]{0,63}$",
                options: .regularExpression
            ) != nil else {
                throw ImageProcessingError.invalidPDFOptions("'pack' must be a safe 1-64 character ID")
            }
        }
        return options
    }

    private static func effectivePDFDPI(
        requested: Int?,
        runtime: OCRRuntimeSettingsSnapshot
    ) -> Int {
        let selected = requested ?? runtime.pdfDPI
        guard ProcessInfo.processInfo.thermalState == .critical else {
            return selected
        }
        return min(selected, runtime.hotDPI)
    }

    private static func runtimeSettings(
        options: OCRRequestOptions,
        base: OCRRuntimeSettingsSnapshot
    ) throws -> OCRRuntimeSettingsSnapshot {
        let languages = options.langs.map {
            $0.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        if let languages,
           languages.isEmpty || languages.count > 8
            || !languages.allSatisfy(Self.isValidLanguageIdentifier) {
            throw ImageProcessingError.invalidPDFOptions(
                "'langs' must contain 1-8 BCP-47-style identifiers"
            )
        }
        let groups = options.groups.map {
            Set($0.split(separator: ",", omittingEmptySubsequences: false).compactMap {
                CorrectorGroup(
                    rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            })
        }
        return base.applying(
            recognitionLevel: options.level?.lowercased(),
            recognitionLanguages: languages,
            multipassEnabled: booleanValue(options.multipass),
            confidenceThreshold: options.conf,
            roiUpscale: options.upscale,
            correctorGroups: groups,
            activePack: options.pack?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        )
    }

    private static func isValidLanguageIdentifier(_ value: String) -> Bool {
        value.count <= 35
            && value.range(
                of: "^[A-Za-z]{2,8}(?:[-_][A-Za-z0-9]{1,8})*$",
                options: .regularExpression
            ) != nil
    }

    private static func booleanValue(_ value: String?) -> Bool? {
        guard let value else { return nil }
        switch value.lowercased() {
        case "1", "true", "yes", "on": return true
        case "0", "false", "no", "off": return false
        default: return nil
        }
    }

    private static func improveRequested(
        options: OCRRequestOptions,
        runtime: OCRRuntimeSettingsSnapshot
    ) -> Bool {
        if booleanValue(options.raw) == true { return false }
        if let improve = booleanValue(options.improve) { return improve }
        return runtime.improveEnabled
    }

    private static func domainMetadata(
        options: OCRRequestOptions,
        upload: OCRUploadPayload,
        activePack: String
    ) -> OCRDomainMetadata {
        OCRDomainMetadata(
            documentType: options.loai_van_ban ?? upload.loai_van_ban,
            agency: options.co_quan ?? upload.co_quan,
            year: options.nam ?? upload.nam,
            requestedPack: options.pack ?? upload.pack ?? activePack
        )
    }

    private static func recordDebugTraceIfNeeded(
        endpoint: String,
        result: OCRImprovementResult,
        runtime: OCRRuntimeSettingsSnapshot,
        improve: Bool,
        recognitionLevel: String,
        usesLanguageCorrection: Bool,
        automaticallyDetectsLanguage: Bool
    ) async {
        guard runtime.debugVerbose else { return }
        let trace = await OCRDebugTraceFactory.make(
            endpoint: endpoint,
            result: result,
            runtime: runtime,
            improve: improve,
            recognitionLevel: recognitionLevel,
            usesLanguageCorrection: usesLanguageCorrection,
            automaticallyDetectsLanguage: automaticallyDetectsLanguage
        )
        await OCRDebugStore.shared.append(trace)
    }

    private static func ocrErrorStatus(_ error: Error) -> HTTPResponseStatus {
        if error is VNLegalCorrectorError || error is DecodingError {
            return .internalServerError
        }
        return .badRequest
    }

    private static func isPDF(_ data: Data) -> Bool {
        data.starts(with: Data("%PDF".utf8))
    }

    private static func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func audioFileExtension(for contentType: String) -> String {
        if contentType.contains("wav") { return "wav" }
        if contentType.contains("mpeg") || contentType.contains("mp3") { return "mp3" }
        if contentType.contains("caf") { return "caf" }
        return "m4a"
    }

    private static func coreMLStatus(for error: CoreMLServiceError) -> HTTPResponseStatus {
        switch error {
        case .modelNotFound:
            return .notFound
        case .internalFailure:
            return .internalServerError
        case .invalidUpload,
             .invalidModelID,
             .missingInput,
             .invalidInput,
             .unsupportedFeatureType:
            return .badRequest
        }
    }

    private static func htmlResponse(_ html: String, status: HTTPResponseStatus = .ok) -> Response {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/html; charset=utf-8")
        return Response(status: status, headers: headers, body: .init(string: html))
    }

    private static func jsonResponse<T: Content>(_ status: HTTPResponseStatus, _ payload: T) throws -> Response {
        let res = Response(status: status)
        try res.content.encode(payload, as: .json)
        return res
    }
}

extension Notification.Name {
    static let vaporServerShouldRestart = Notification.Name("vaporServerShouldRestart")
}
