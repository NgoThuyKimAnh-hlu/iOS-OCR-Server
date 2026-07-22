# TASK (Codex): thêm TẦNG HIỂU on-device vào Apple Compute Server — Foundation Models + NER + Embedding

## Bối cảnh
Fork đã là Apple Compute Server (OCR/bảng + /translate + /transcribe + /synthesize, CI-proven, commit b557c95).
Giờ THÊM tầng "hiểu" để farm iPhone tự tóm-tắt/trích/hiểu văn bản luật on-device — bước mở khóa lớn nhất.
Pattern y hệt lần trước: mỗi service 1 file .swift riêng + route Vapor (match style /translate) + Self.jsonResponse.
Build qua CI GitHub Actions (NgoThuyKimAnh-hlu/iOS-OCR-Server, token trong git remote), ITERATE tới compile OK.

## THÊM 3 service + route

### 1. LLM on-device — POST /llm  (Foundation Models framework, iOS 26)
- `import FoundationModels`. Kiểm khả dụng: `SystemLanguageModel.default.availability` (nếu unavailable → trả 503 + lý do).
- Body JSON: `{ "prompt":"...", "system":"..."(optional instructions), "max"(optional) }` → trả `{ "success":true, "text":"..." }`.
- Dùng `LanguageModelSession(instructions: system)` rồi `try await session.respond(to: prompt)` → lấy `.content`.
- Dùng cho: tóm tắt điều luật, trích cặp ý-kiến↔giải-trình, Q&A. (Structured @Generable là bonus, không bắt buộc.)

### 2. NER trích thực thể — POST /ner  (NaturalLanguage)
- Body JSON: `{ "text":"..." }` → trả `{ "success":true, "entities":[{"text":"...","type":"organization|place|person"}], "so_hieu":["255/2024/NĐ-CP",...], "dieu_khoan":["Điều 5 khoản 2",...] }`.
- `NLTagger(tagSchemes:[.nameType])` enumerate → org/place/person. CỘNG regex cho **số hiệu VN** (`\d{1,4}/\d{4}/(NĐ-CP|QĐ-TTg|TT-[A-ZĐ]+|QH\d+)`) + Điều/Khoản/Điểm (đây là giá trị luật thật, NLTagger không bắt được).

### 3. Embedding semantic — POST /embed  (NaturalLanguage NLEmbedding)
- Body JSON: `{ "text":"..." }` → trả `{ "success":true, "vector":[...], "dim":N }`.
- Thử `NLEmbedding.sentenceEmbedding(for: .vietnamese)`; nếu nil → `.wordEmbedding(for:.vietnamese)` trung bình các từ; nếu vẫn nil → trả 501 + ghi rõ "NLEmbedding chưa hỗ trợ vi, cần Core ML embedding model sau".
- Dùng cho: semantic search điều luật tương tự.

## Ràng buộc
- KHÔNG phá route cũ (/upload /docOCR /translate /transcribe /synthesize) + giữ vi-VN pin.
- Mỗi service file riêng (LLMService/NERService/EmbeddingService) — 1 cái lỗi không sập cái khác.
- Cập nhật HTML `/` liệt kê 3 endpoint mới + curl example.
- Info.plist nếu cần (Foundation Models không cần quyền đặc biệt thường).
- **CI-iterate tới compile success** (poll run + đọc log Swift + sửa + push, ~6 vòng). PUSH CHỈ repo fork này (authorized per-instance).
- Ghi `BUILD_INTELLIGENCE_codex.md` (API dùng, availability caveat, lỗi CI đã sửa) + marker BUILD_INTELLIGENCE_DONE khi CI success.
