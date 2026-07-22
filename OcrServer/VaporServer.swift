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
    let boxes: [OCRBoxItem]
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

    init(
        success: Bool,
        message: String,
        ocr_text: String,
        rectified: Bool? = nil,
        improvement: OCRImprovementResult? = nil
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
    let corrections_applied: Int
    let improve_ms: Double
    let pack_id: String
    let pack_version: String
    let pack_hash: String

    init(
        success: Bool,
        message: String,
        ocr_result: String,
        image_width: Int,
        image_height: Int,
        ocr_boxes: [OCRBoxItem],
        rectified: Bool? = nil,
        improvement: OCRImprovementResult? = nil
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
        self.corrections_applied = improvement?.correctionsApplied ?? 0
        self.improve_ms = improvement?.improveMilliseconds ?? 0
        self.pack_id = improvement?.pack.id ?? "none"
        self.pack_version = improvement?.pack.version ?? ""
        self.pack_hash = improvement?.pack.hash ?? ""
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
    let corrections_applied: Int
    let improve_ms: Double
    let pack_id: String
    let pack_version: String
    let pack_hash: String

    init(
        page: Int,
        success: Bool,
        message: String,
        improvement: OCRImprovementResult?,
        rectified: Bool?
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
        self.corrections_applied = improvement?.correctionsApplied ?? 0
        self.improve_ms = improvement?.improveMilliseconds ?? 0
        self.pack_id = improvement?.pack.id ?? "none"
        self.pack_version = improvement?.pack.version ?? ""
        self.pack_hash = improvement?.pack.hash ?? ""
    }
}

struct PDFUploadResponse: Content {
    let success: Bool
    let message: String
    let pages: [PDFUploadPageResponse]
    let page_count: Int
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

    init(
        page: Int,
        success: Bool,
        message: String,
        improvement: OCRImprovementResult?,
        rectified: Bool?
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
    }
}

struct PDFDocOCRResponse: Content {
    let success: Bool
    let message: String
    let pages: [PDFDocOCRPageResponse]
    let page_count: Int
}

struct BatchUploadResponse: Content {
    let filename: String
    let success: Bool
    let message: String
    let ocr_result: String
    let image_width: Int
    let image_height: Int
    let ocr_boxes: [OCRBoxItem]
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

struct AdminSettingsResponse: Content, Sendable {
    let recognition_level: String
    let language_correction: Bool
    let automatically_detects_language: Bool
    let keep_alive: Bool
    let http_port: Int
    let admin_token_configured: Bool
    let improve: Bool
    let confidence_threshold: Double
    let multipass: Bool
    let roi_upscale: Double
    let corrector_groups: [String]
    let active_pack: String
    let debug_verbose: Bool
}

struct AdminSettingsPatch: Content, Sendable {
    let recognition_level: String?
    let language_correction: Bool?
    let automatically_detects_language: Bool?
    let keep_alive: Bool?
    let http_port: Int?
    let admin_token: String?
    let improve: Bool?
    let confidence_threshold: Double?
    let multipass: Bool?
    let roi_upscale: Double?
    let corrector_groups: [String]?
    let active_pack: String?
    let debug_verbose: Bool?
}

struct AdminApplyResponse: Content, Sendable {
    let applied: [String]
    let restarted: Bool
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

private enum AdminSettingsError: LocalizedError {
    case invalidRecognitionLevel
    case pinnedPort
    case emptyPatch
    case invalidConfidenceThreshold
    case invalidROIUpscale
    case invalidCorrectorGroups
    case invalidActivePack

    var errorDescription: String? {
        switch self {
        case .invalidRecognitionLevel:
            return "recognition_level must be Accurate or Fast"
        case .pinnedPort:
            return "http_port is pinned to 8000"
        case .emptyPatch:
            return "No supported setting was provided"
        case .invalidConfidenceThreshold:
            return "confidence_threshold must be between 0.05 and 0.99"
        case .invalidROIUpscale:
            return "roi_upscale must be between 1.0 and 4.0"
        case .invalidCorrectorGroups:
            return "corrector_groups contains an unknown rule group"
        case .invalidActivePack:
            return "active_pack must be auto, none, minimal, legal, tax, or customs"
        }
    }
}

private struct OCRRequestOptions: Decodable {
    let dpi: Int?
    let max_pages: Int?
    let rectify: Int?
    let improve: Int?
    let raw: Int?
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

actor VaporServer {
    private var app: Application?
    private var runTask: Task<Void, Never>?
    
    // 自動重啟設定
    private var shouldAutoRestart = true
    
    // 當伺服器停止時發通知
    private var onStopped: (@Sendable () -> Void)?

    let host: String = "0.0.0.0"
    let environment: Environment = .production
    
    // 可由外部設置
    var port: Int = 8000

    // OCR 參數
    var recognitionLevel: RecognizeTextRequest.RecognitionLevel = .accurate
    var usesLanguageCorrection: Bool = true
    var automaticallyDetectsLanguage: Bool = true

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
        app.http.server.configuration.hostname = host
        app.http.server.configuration.port = port
        app.http.server.configuration.reuseAddress = true
        app.middleware.use(RequestMetricsMiddleware(), at: .beginning)

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
            let health = await MainActor.run {
                ServerTelemetry.shared.healthResponse(
                    port: port,
                    keepAlive: KeepAliveService.shared.isActive
                )
            }
            return try Self.jsonResponse(.ok, health)
        }

        app.get("stats") { [weak self] req async throws -> Response in
            guard let self else { throw Abort(.internalServerError) }
            let port = await self.port
            let stats = await MainActor.run {
                ServerTelemetry.shared.statsResponse(
                    port: port,
                    keepAlive: KeepAliveService.shared.isActive
                )
            }
            return try Self.jsonResponse(.ok, stats)
        }

        app.get("admin") { [weak self] req async throws -> Response in
            guard let self else { throw Abort(.internalServerError) }
            return Self.htmlResponse(Self.adminHTML(port: await self.port))
        }

        app.get("admin", "settings") { req async throws -> Response in
            try await Self.requireAdminToken(request: req)
            let settings = await MainActor.run { Self.adminSettingsSnapshot() }
            return try Self.jsonResponse(.ok, settings)
        }

        app.post("admin", "settings") { req async throws -> Response in
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
                let outcome = try await MainActor.run {
                    try Self.applyAdminSettings(patch)
                }
                if outcome.restarted {
                    Self.scheduleServerRestart(reason: "/admin/settings")
                }
                return try Self.jsonResponse(.ok, outcome)
            } catch {
                return try Self.jsonResponse(
                    .badRequest,
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

        app.on(.POST, "debug", "ocr", body: .collect(maxSize: "100mb")) { [weak self] req async throws -> Response in
            try await Self.requireDebugEnabled()
            try await Self.requireAdminToken(request: req)
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
            let processed: RectifiedImage
            if options.rectify == 1 {
                processed = await ImageProcessingService.shared.rectify(data: data)
            } else {
                processed = RectifiedImage(data: data, rectified: false)
            }
            let recognitionLevel = await self.recognitionLevel
            let usesLanguageCorrection = await self.usesLanguageCorrection
            let automaticallyDetectsLanguage = await self.automaticallyDetectsLanguage
            let runtime = await MainActor.run { Settings.shared.ocrRuntimeSnapshot() }
            let improve = Self.improveRequested(options: options, runtime: runtime)
            let metadata = Self.domainMetadata(
                options: options,
                upload: upload,
                activePack: runtime.activePack
            )

            do {
                guard let result = try await OCRImprovementService.shared.processImage(
                    data: processed.data,
                    recognitionLevel: recognitionLevel,
                    usesLanguageCorrection: usesLanguageCorrection,
                    automaticallyDetectsLanguage: automaticallyDetectsLanguage,
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
                    recognitionLevel: recognitionLevel == .fast ? "Fast" : "Accurate",
                    usesLanguageCorrection: usesLanguageCorrection,
                    automaticallyDetectsLanguage: automaticallyDetectsLanguage
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
                <h3>OCR a PDF or rectify a photographed scan:</h3>
                <pre><code>curl -H "Accept: application/json" \\
              -X POST 'http://&lt;YOUR IP&gt;:\(port)/upload?dpi=200&amp;max_pages=50&amp;rectify=1' \\
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
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }

            let recognitionLevel = await self.recognitionLevel
            let usesLanguageCorrection = await self.usesLanguageCorrection
            let automaticallyDetectsLanguage = await self.automaticallyDetectsLanguage
            let data = Self.byteBufferToData(upload.file.data)
            let runtime = await MainActor.run { Settings.shared.ocrRuntimeSnapshot() }
            let improve = Self.improveRequested(options: options, runtime: runtime)
            let metadata = Self.domainMetadata(
                options: options,
                upload: upload,
                activePack: runtime.activePack
            )

            if Self.isPDF(data) {
                do {
                    let rendered = try await ImageProcessingService.shared.renderPDF(
                        data: data,
                        dpi: options.dpi ?? 200,
                        maximumPages: options.max_pages ?? 50
                    )
                    var pages: [PDFUploadPageResponse] = []
                    pages.reserveCapacity(rendered.pages.count)

                    for page in rendered.pages {
                        let processed: RectifiedImage
                        if options.rectify == 1 {
                            processed = await ImageProcessingService.shared.rectify(data: page.imageData)
                        } else {
                            processed = RectifiedImage(data: page.imageData, rectified: false)
                        }
                        let result = try await OCRImprovementService.shared.processImage(
                            data: processed.data,
                            recognitionLevel: recognitionLevel,
                            usesLanguageCorrection: usesLanguageCorrection,
                            automaticallyDetectsLanguage: automaticallyDetectsLanguage,
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
                                recognitionLevel: recognitionLevel,
                                usesLanguageCorrection: usesLanguageCorrection,
                                automaticallyDetectsLanguage: automaticallyDetectsLanguage
                            )
                        }
                        pages.append(
                            PDFUploadPageResponse(
                                page: page.pageNumber,
                                success: result != nil,
                                message: result == nil ? "OCR failed" : "OCR completed successfully",
                                improvement: result,
                                rectified: options.rectify == 1 ? processed.rectified : nil
                            )
                        )
                    }

                    let succeeded = pages.allSatisfy(\.success)
                    return try Self.jsonResponse(
                        .ok,
                        PDFUploadResponse(
                            success: succeeded,
                            message: "Processed \(pages.count) of \(rendered.totalPageCount) PDF pages",
                            pages: pages,
                            page_count: pages.count
                        )
                    )
                } catch {
                    return try Self.jsonResponse(
                        Self.ocrErrorStatus(error),
                        ComputeErrorResponse(success: false, message: error.localizedDescription)
                    )
                }
            }

            let processed: RectifiedImage
            if options.rectify == 1 {
                processed = await ImageProcessingService.shared.rectify(data: data)
            } else {
                processed = RectifiedImage(data: data, rectified: false)
            }
            let accept = (req.headers.first(name: .accept) ?? "").lowercased()
            let result: OCRImprovementResult?
            do {
                result = try await OCRImprovementService.shared.processImage(
                    data: processed.data,
                    recognitionLevel: recognitionLevel,
                    usesLanguageCorrection: usesLanguageCorrection,
                    automaticallyDetectsLanguage: automaticallyDetectsLanguage,
                    metadata: metadata,
                    improve: improve,
                    configuration: runtime.improvementConfiguration,
                    collectTrace: runtime.debugVerbose
                )
            } catch {
                return try Self.jsonResponse(
                    Self.ocrErrorStatus(error),
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }
            if let result {
                await Self.recordDebugTraceIfNeeded(
                    endpoint: "/upload",
                    result: result,
                    runtime: runtime,
                    improve: improve,
                    recognitionLevel: recognitionLevel,
                    usesLanguageCorrection: usesLanguageCorrection,
                    automaticallyDetectsLanguage: automaticallyDetectsLanguage
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
                        rectified: options.rectify == 1 ? processed.rectified : nil
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
                        rectified: options.rectify == 1 ? processed.rectified : nil,
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

            let recognitionLevel = await self.recognitionLevel
            let usesLanguageCorrection = await self.usesLanguageCorrection
            let automaticallyDetectsLanguage = await self.automaticallyDetectsLanguage
            let textRecognizer = TextRecognizer(
                recognitionLevel: recognitionLevel,
                usesLanguageCorrection: usesLanguageCorrection,
                automaticallyDetectsLanguage: automaticallyDetectsLanguage
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

                let result = await textRecognizer.getOcrResult(data: file.data)
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
                    ComputeErrorResponse(success: false, message: error.localizedDescription)
                )
            }

            let recognitionLevel = await self.recognitionLevel
            let usesLanguageCorrection = await self.usesLanguageCorrection
            let automaticallyDetectsLanguage = await self.automaticallyDetectsLanguage
            let data = Self.byteBufferToData(upload.file.data)
            let runtime = await MainActor.run { Settings.shared.ocrRuntimeSnapshot() }
            let improve = Self.improveRequested(options: options, runtime: runtime)
            let metadata = Self.domainMetadata(
                options: options,
                upload: upload,
                activePack: runtime.activePack
            )

            if #available(iOS 26, *) {
                let docRecognizer = DocRecognizer(
                    usesLanguageCorrection: usesLanguageCorrection,
                    automaticallyDetectsLanguage: automaticallyDetectsLanguage
                )

                if Self.isPDF(data) {
                    do {
                        let rendered = try await ImageProcessingService.shared.renderPDF(
                            data: data,
                            dpi: options.dpi ?? 200,
                            maximumPages: options.max_pages ?? 50
                        )
                        var pages: [PDFDocOCRPageResponse] = []
                        pages.reserveCapacity(rendered.pages.count)

                        for page in rendered.pages {
                            let processed: RectifiedImage
                            if options.rectify == 1 {
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
                                recognitionLevel: recognitionLevel,
                                usesLanguageCorrection: usesLanguageCorrection,
                                automaticallyDetectsLanguage: automaticallyDetectsLanguage,
                                metadata: metadata,
                                improve: improve,
                                pageNumber: page.pageNumber,
                                pageCount: rendered.totalPageCount,
                                configuration: runtime.improvementConfiguration,
                                collectTrace: runtime.debugVerbose
                            )
                            if let result {
                                await Self.recordDebugTraceIfNeeded(
                                    endpoint: "/docOCR?page=\(page.pageNumber)",
                                    result: result,
                                    runtime: runtime,
                                    improve: improve,
                                    recognitionLevel: recognitionLevel,
                                    usesLanguageCorrection: usesLanguageCorrection,
                                    automaticallyDetectsLanguage: automaticallyDetectsLanguage
                                )
                            }
                            pages.append(
                                PDFDocOCRPageResponse(
                                    page: page.pageNumber,
                                    success: result != nil,
                                    message: result == nil ? "OCR failed" : "OCR completed successfully",
                                    improvement: result,
                                    rectified: options.rectify == 1 ? processed.rectified : nil
                                )
                            )
                        }

                        let succeeded = pages.allSatisfy(\.success)
                        return try Self.jsonResponse(
                            .ok,
                            PDFDocOCRResponse(
                                success: succeeded,
                                message: "Processed \(pages.count) of \(rendered.totalPageCount) PDF pages",
                                pages: pages,
                                page_count: pages.count
                            )
                        )
                    } catch {
                        return try Self.jsonResponse(
                            Self.ocrErrorStatus(error),
                            ComputeErrorResponse(
                                success: false,
                                message: error.localizedDescription
                            )
                        )
                    }
                }

                let processed: RectifiedImage
                if options.rectify == 1 {
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
                        recognitionLevel: recognitionLevel,
                        usesLanguageCorrection: usesLanguageCorrection,
                        automaticallyDetectsLanguage: automaticallyDetectsLanguage,
                        metadata: metadata,
                        improve: improve,
                        configuration: runtime.improvementConfiguration,
                        collectTrace: runtime.debugVerbose
                    )
                } catch {
                    return try Self.jsonResponse(
                        Self.ocrErrorStatus(error),
                        ComputeErrorResponse(success: false, message: error.localizedDescription)
                    )
                }
                if let result {
                    await Self.recordDebugTraceIfNeeded(
                        endpoint: "/docOCR",
                        result: result,
                        runtime: runtime,
                        improve: improve,
                        recognitionLevel: recognitionLevel,
                        usesLanguageCorrection: usesLanguageCorrection,
                        automaticallyDetectsLanguage: automaticallyDetectsLanguage
                    )
                }

                if accept.contains("application/json") {
                    return try Self.jsonResponse(
                        .ok,
                        DocOCRResult(
                            success: result != nil,
                            message: result == nil ? "OCR quality analysis failed" : "OCR completed successfully",
                            ocr_text: result?.selectedText ?? resultText,
                            rectified: options.rectify == 1 ? processed.rectified : nil,
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

    @MainActor
    private static func adminSettingsSnapshot() -> AdminSettingsResponse {
        let settings = Settings.shared
        return AdminSettingsResponse(
            recognition_level: settings.recognitionLevel,
            language_correction: settings.languageCorrection,
            automatically_detects_language: settings.automaticallyDetectsLanguage,
            keep_alive: settings.keepAliveEnabled,
            http_port: 8000,
            admin_token_configured: !settings.adminToken
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
            improve: settings.improveEnabled,
            confidence_threshold: settings.confidenceThreshold,
            multipass: settings.multipassEnabled,
            roi_upscale: settings.roiUpscale,
            corrector_groups: settings.correctorGroupNames,
            active_pack: settings.activePack,
            debug_verbose: settings.debugVerbose
        )
    }

    @MainActor
    private static func applyAdminSettings(_ patch: AdminSettingsPatch) throws -> AdminApplyResponse {
        let settings = Settings.shared
        var applied: [String] = []
        var requiresRestart = false

        let normalizedRecognitionLevel: String?
        if let value = patch.recognition_level {
            switch value.lowercased() {
            case "accurate": normalizedRecognitionLevel = "Accurate"
            case "fast": normalizedRecognitionLevel = "Fast"
            default: throw AdminSettingsError.invalidRecognitionLevel
            }
        } else {
            normalizedRecognitionLevel = nil
        }
        if let value = patch.http_port, value != 8000 {
            throw AdminSettingsError.pinnedPort
        }
        if let value = patch.confidence_threshold, !(0.05...0.99).contains(value) {
            throw AdminSettingsError.invalidConfidenceThreshold
        }
        if let value = patch.roi_upscale, !(1.0...4.0).contains(value) {
            throw AdminSettingsError.invalidROIUpscale
        }
        let validatedGroups: [String]?
        if let value = patch.corrector_groups {
            let groups = value.compactMap { CorrectorGroup(rawValue: $0) }
            guard groups.count == value.count else {
                throw AdminSettingsError.invalidCorrectorGroups
            }
            validatedGroups = Array(Set(groups.map(\.rawValue))).sorted()
        } else {
            validatedGroups = nil
        }
        let normalizedActivePack: String?
        if let value = patch.active_pack {
            let normalized = value.lowercased()
            guard ["auto", "none", "minimal", "legal", "tax", "customs"].contains(normalized) else {
                throw AdminSettingsError.invalidActivePack
            }
            normalizedActivePack = normalized
        } else {
            normalizedActivePack = nil
        }

        if let normalized = normalizedRecognitionLevel {
            requiresRestart = requiresRestart || settings.recognitionLevel != normalized
            settings.recognitionLevel = normalized
            applied.append("recognition_level")
        }
        if let value = patch.language_correction {
            requiresRestart = requiresRestart || settings.languageCorrection != value
            settings.languageCorrection = value
            applied.append("language_correction")
        }
        if let value = patch.automatically_detects_language {
            requiresRestart = requiresRestart || settings.automaticallyDetectsLanguage != value
            settings.automaticallyDetectsLanguage = value
            applied.append("automatically_detects_language")
        }
        if let value = patch.keep_alive {
            KeepAliveService.shared.setEnabled(value)
            applied.append("keep_alive")
        }
        if patch.http_port != nil {
            settings.httpPort = 8000
            applied.append("http_port")
        }
        if let value = patch.admin_token {
            settings.adminToken = value.trimmingCharacters(in: .whitespacesAndNewlines)
            applied.append("admin_token")
        }
        if let value = patch.improve {
            settings.improveEnabled = value
            applied.append("improve")
        }
        if let value = patch.confidence_threshold {
            settings.confidenceThreshold = value
            applied.append("confidence_threshold")
        }
        if let value = patch.multipass {
            settings.multipassEnabled = value
            applied.append("multipass")
        }
        if let value = patch.roi_upscale {
            settings.roiUpscale = value
            applied.append("roi_upscale")
        }
        if let value = validatedGroups {
            settings.correctorGroupNames = value
            applied.append("corrector_groups")
        }
        if let value = normalizedActivePack {
            settings.activePack = value
            applied.append("active_pack")
        }
        if let value = patch.debug_verbose {
            settings.debugVerbose = value
            applied.append("debug_verbose")
        }

        guard !applied.isEmpty else { throw AdminSettingsError.emptyPatch }
        return AdminApplyResponse(applied: applied, restarted: requiresRestart)
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
        if let rectify = options.rectify, rectify != 0, rectify != 1 {
            throw ImageProcessingError.invalidPDFOptions("'rectify' must be 0 or 1")
        }
        if let improve = options.improve, improve != 0, improve != 1 {
            throw ImageProcessingError.invalidPDFOptions("'improve' must be 0 or 1")
        }
        if let raw = options.raw, raw != 0, raw != 1 {
            throw ImageProcessingError.invalidPDFOptions("'raw' must be 0 or 1")
        }
        return options
    }

    private static func improveRequested(
        options: OCRRequestOptions,
        runtime: OCRRuntimeSettingsSnapshot
    ) -> Bool {
        if options.raw == 1 { return false }
        if let improve = options.improve { return improve == 1 }
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
        recognitionLevel: RecognizeTextRequest.RecognitionLevel,
        usesLanguageCorrection: Bool,
        automaticallyDetectsLanguage: Bool
    ) async {
        guard runtime.debugVerbose else { return }
        let trace = await OCRDebugTraceFactory.make(
            endpoint: endpoint,
            result: result,
            runtime: runtime,
            improve: improve,
            recognitionLevel: recognitionLevel == .fast ? "Fast" : "Accurate",
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
