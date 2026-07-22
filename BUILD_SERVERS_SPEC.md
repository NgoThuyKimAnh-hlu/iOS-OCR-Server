# TASK (Codex): mở rộng fork thành "Apple Compute Server" — thêm Translation + STT + TTS theo pattern tác giả

## Bối cảnh
Fork iOS-OCR-Server (Vapor + Vision, đã pin vi-VN) tại thư mục này. Pattern tác giả riddleling: Vapor server + framework
Apple → HTTP API on-device. Giờ THÊM 3 capability vào CHÍNH app này (1 app đa-năng, 1 ESign, deploy 1 lần lên farm).
Build qua CI sẵn (.github/workflows/build-ipa.yml → unsigned IPA). Target iOS 26.

## THÊM 3 service + route (match style route /upload trong VaporServer.swift: decode Content → gọi service → Self.jsonResponse)

### 1. Translation — POST /translate  (Translation framework, iOS 18+)
- Body JSON: `{ "text": "...", "target": "en", "source": "vi"(optional) }` → trả `{ "success":true, "translated":"...", "source":"vi", "target":"en" }`.
- Translation framework `TranslationSession` lấy qua SwiftUI `.translationTask` → headless cần cầu nối: tạo 1 hidden SwiftUI view host `.translationTask(configuration)` + 1 actor/AsyncStream để route Vapor gửi yêu cầu và nhận kết quả (continuation). Nếu API headless quá khó → fallback: tài liệu rõ hạn chế + để endpoint trả 501 "cần UI-session", KHÔNG chặn STT/TTS.
- Auto-detect source nếu không truyền (Translation hỗ trợ).

### 2. STT — POST /transcribe  (Speech framework)
- Body: multipart file audio (m4a/wav/mp3) HOẶC raw audio. → trả `{ "success":true, "text":"...", "locale":"vi-VN" }`.
- `SFSpeechRecognizer(locale: vi-VN)` + `SFSpeechURLRecognitionRequest(url:)` (ghi tạm file), `requiresOnDeviceRecognition = true`. Xin quyền `SFSpeechRecognizer.requestAuthorization`.
- Cho tham số `?locale=vi-VN` (default vi-VN).

### 3. TTS — POST /synthesize  (AVSpeechSynthesizer)
- Body JSON: `{ "text":"...", "lang":"vi-VN"(optional), "rate":0.5(optional) }` → trả **file audio** (Content-Type audio/x-caf hoặc audio/wav), KHÔNG phải JSON.
- `AVSpeechSynthesizer().write(utterance) { buffer in ... }` gom `AVAudioPCMBuffer` → ghi file WAV (AVAudioFile) → trả data. Voice theo lang (AVSpeechSynthesisVoice(language:)).

## Ràng buộc
- Info.plist: thêm `NSSpeechRecognitionUsageDescription`, `NSMicrophoneUsageDescription` (mô tả tiếng Việt).
- Mỗi service 1 file .swift riêng (TranslationService/SpeechService/SynthService) — nếu 1 cái lỗi compile không kéo sập 2 cái kia (giữ được build).
- KHÔNG phá route /upload /docOCR hiện có. Giữ vi-VN pin ở DocRecognizer.
- Cập nhật trang HTML `/` liệt kê 3 endpoint mới + curl example.
- **Build qua CI, ITERATE tới khi compile success**: sau mỗi push, poll `gh`/curl GitHub Actions run của NgoThuyKimAnh-hlu/iOS-OCR-Server (token trong git remote), đọc log lỗi Swift, sửa, push lại. Tối đa ~6 vòng.
- **PUSH được authorized CHỈ cho repo fork này** (NgoThuyKimAnh-hlu/iOS-OCR-Server) — user đã cho phép per-instance cho mục tiêu này. KHÔNG push repo khác.
- Ghi tiến trình vào `BUILD_SERVERS_codex.md` (API dùng, lỗi CI đã sửa, kết quả build). Marker BUILD_SERVERS_DONE khi CI success (hoặc dừng với STT+TTS xong nếu Translation-headless bất khả).
