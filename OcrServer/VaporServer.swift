//
//  VaporServer.swift
//  OcrServer
//
//  Created by Riddle Ling on 2025/8/21.
//

import Vapor
import Vision

struct OCRRectItem: Content {
    let topLeft_x: Double
    let topLeft_y: Double
    let topRight_x: Double
    let topRight_y: Double
    let bottomLeft_x: Double
    let bottomLeft_y: Double
    let bottomRight_x: Double
    let bottomRight_y: Double
}

struct OCRBoxItem: Content {
    let text: String
    let x: Double
    let y: Double
    let w: Double
    let h: Double
    let rect: OCRRectItem?
}

struct OCRResult: Content {
    let text: String
    let image_width: Int
    let image_height: Int
    let boxes: [OCRBoxItem]
}

struct DocOCRResult: Content {
    let success: Bool
    let message: String
    let ocr_text: String
}

struct UploadResponse: Content {
    let success: Bool
    let message: String
    let ocr_result: String
    let image_width: Int
    let image_height: Int
    let ocr_boxes: [OCRBoxItem]
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
        guard runTask == nil else { return } // 已在跑就不重複啟動

        let app = try await Application.make(environment)
        app.http.server.configuration.hostname = host
        app.http.server.configuration.port = port

        try routes(app)

        self.app = app
        isRunning = true

        // 用 Task 背景執行事件迴圈
        runTask = Task { [weak app, weak self] in
            guard let self = self else { return }
            var hadError = false
            do {
                try await app?.execute()
            } catch {
                hadError = true
            }
            
            // 通知外界「已停止」
            if let cb = await self.onStopped { cb() }
            
            // 依設定自動重啟
            if await self.shouldAutoRestart && hadError {
                await self.cleanupAfterStop()
                NotificationCenter.default.post(
                    name: .vaporServerShouldRestart,
                    object: nil,
                    userInfo: ["reason": "crash"]
                )
            }
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
        //runTask?.cancel()
        runTask = nil
        app = nil
        isRunning = false
    }

    // MARK: - Routes

    private func routes(_ app: Application) throws {
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
                <title>Apple Compute Server</title>
                <style>
                    code {
                        background: #dadada;
                        padding: 2px 6px;
                        font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
                        font-size: 0.85em;
                        font-weight: 600;
                        border-radius: 5px;
                    }
                    pre {
                        background: #dadada;
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
                <h1>Apple Compute Server</h1>
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
                <h3>OCR Test:</h3>
                <form id="ocrForm" action="/upload" method="post" enctype="multipart/form-data">
                    \(docOcrCheckBox)
                    <label>
                        Choose file:
                        <input type="file" name="file" required>
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

        // POST /upload（限制收集本文大小，可自行調整）
        app.on(.POST, "upload", body: .collect(maxSize: "100mb")) { [weak self] req async throws -> Response in
            guard let self else { throw Abort(.internalServerError) }

            struct Upload: Content { var file: File }

            let upload: Upload
            do {
                upload = try req.content.decode(Upload.self)
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

            // 取得 actor 內的參數（需 await）
            let recognitionLevel = await self.recognitionLevel
            let usesLanguageCorrection = await self.usesLanguageCorrection
            let automaticallyDetectsLanguage = await self.automaticallyDetectsLanguage

            // ByteBuffer -> Data
            let data = Self.byteBufferToData(upload.file.data)

            // OCR
            let textRecognizer = TextRecognizer(
                recognitionLevel: recognitionLevel,
                usesLanguageCorrection: usesLanguageCorrection,
                automaticallyDetectsLanguage: automaticallyDetectsLanguage
            )

            let accept = (req.headers.first(name: .accept) ?? "").lowercased()
            
            let result = await textRecognizer.getOcrResult(data: data)
            
            if result == nil && accept.contains("application/json") {
                return try Self.jsonResponse(.internalServerError, UploadResponse(success: false,
                                                                                  message: "OCR failed",
                                                                                  ocr_result: "",
                                                                                  image_width: 0,
                                                                                  image_height: 0,
                                                                                  ocr_boxes: []))
            }
            
            if accept.contains("application/json") {
                return try Self.jsonResponse(
                    .ok,
                    UploadResponse(
                        success: true,
                        message: "File uploaded successfully",
                        ocr_result: result?.text ?? "",
                        image_width: result?.image_width ?? 0,
                        image_height: result?.image_height ?? 0,
                        ocr_boxes: result?.boxes ?? []
                    )
                )
            } else {
                let escaped = Self.htmlEscape(result?.text ?? "")
                let html = """
                <!doctype html>
                <html>
                <head>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>OCR Server</title>
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

        // POST /docOCR（限制收集本文大小，可自行調整）
        app.on(.POST, "docOCR", body: .collect(maxSize: "100mb")) { [weak self] req async throws -> Response in
            if #unavailable(iOS 26) {
                // iOS 26 以下
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

            struct Upload: Content { var file: File }

            let upload: Upload
            do {
                upload = try req.content.decode(Upload.self)
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

            // 取得 actor 內的參數（需 await）
            let usesLanguageCorrection = await self.usesLanguageCorrection
            let automaticallyDetectsLanguage = await self.automaticallyDetectsLanguage

            // ByteBuffer -> Data
            let data = Self.byteBufferToData(upload.file.data)

            let accept = (req.headers.first(name: .accept) ?? "").lowercased()
            
            // OCR
            var resultText : String? = nil
            if #available(iOS 26, *) {
                let docRecognizer = DocRecognizer(
                    usesLanguageCorrection: usesLanguageCorrection,
                    automaticallyDetectsLanguage: automaticallyDetectsLanguage
                )
                resultText = await docRecognizer.recognizeParagraphText(from: data)
            }
            
            if resultText == nil && accept.contains("application/json") {
                return try Self.jsonResponse(.internalServerError, DocOCRResult(success: false,
                                                                                message: "OCR failed",
                                                                                ocr_text: ""))
            }
            
            if accept.contains("application/json") {
                return try Self.jsonResponse(
                    .ok,
                    DocOCRResult(
                        success: true,
                        message: "OCR completed successfully",
                        ocr_text: resultText ?? ""
                    )
                )
            } else {
                let escaped = Self.htmlEscape(resultText ?? "")
                let html = """
                <!doctype html>
                <html>
                <head>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>OCR Server</title>
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
        }
    }

    // MARK: - Helpers

    private static func byteBufferToData(_ buffer: ByteBuffer) -> Data {
        var tmp = buffer
        if let bytes = tmp.readBytes(length: tmp.readableBytes) {
            return Data(bytes)
        }
        return Data()
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
