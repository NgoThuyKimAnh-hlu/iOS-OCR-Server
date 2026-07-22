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
