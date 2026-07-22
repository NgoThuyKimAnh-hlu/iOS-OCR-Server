# TASK (Codex): thêm Core ML RUNNER — chạy MODEL TỰ TẠO trên Neural Engine iPhone

## Bối cảnh
Apple Compute Server đã có 8 endpoint (OCR/bảng/dịch/STT/TTS/LLM/NER/embed, commit d648ee7). Giờ thêm **Core ML runner**:
tải model Core ML tùy ý lên iPhone → chạy inference trên **Neural Engine** (computeUnits=.all). Đây là mảnh mở khóa
chạy MODEL VN-luật (fine-tune ở 5060Ti rồi convert coremltools → chạy on-device, không cần Qwen-GPU).
Pattern y hệt: service file riêng (CoreMLService.swift) + route Vapor, `import CoreML`. CI-iterate tới compile OK.

## THÊM service + routes (Core ML, computeUnits = .all để dùng ANE)

### POST /coreml/upload  — nạp model (multipart)
- Nhận file model: `.mlmodelc` (đã compile) HOẶC `.mlpackage`/`.mlmodel` (chưa compile → `MLModel.compileModel(at:)`).
- Lưu vào Application Support, gán `model_id` (hash/tên), trả `{ "success":true, "model_id":"...", "input":[...], "output":[...] }`
  (mô tả feature từ `model.modelDescription.inputDescriptionsByName`).

### GET /coreml/info?model_id=...  — mô tả model
- Trả input/output features: tên, type (multiArray[shape]/string/image/dictionary), constraints.

### POST /coreml/predict  — chạy inference (JSON)
- Body: `{ "model_id":"...", "inputs": { "<featureName>": <value> } }`.
- Build `MLFeatureProvider` động theo type feature:
  - Double/Int → MLFeatureValue(double/int)
  - [Double]/[[Double]] → MLMultiArray (theo shape input)
  - String → MLFeatureValue(string:)
  - base64 image → CVPixelBuffer (nếu input là image)
- `MLModelConfiguration(); config.computeUnits = .all` → `MLModel(contentsOf: compiledURL, configuration: config)`.
- Chạy `model.prediction(from: provider)`, chuyển output → JSON: MLMultiArray→[Double], String→string, Dictionary→map.
- Trả `{ "success":true, "outputs": {...}, "compute":"neuralEngine/all" }`. Đo thời gian inference.

### POST /coreml/delete?model_id  — xóa model đã nạp (dọn dung lượng).

## Ràng buộc
- KHÔNG phá 8 route cũ + vi-VN pin. File riêng (CoreMLService.swift) — lỗi không sập cái khác.
- Xử lý gọn các type feature phổ biến (multiArray, string, double, image). Type lạ → trả 400 "unsupported feature type: X" (đừng crash).
- Cập nhật HTML `/` liệt kê endpoint Core ML + curl example (upload model + predict).
- **CI-iterate tới compile success** (poll GitHub Actions NgoThuyKimAnh-hlu/iOS-OCR-Server + sửa Swift + push, ~6 vòng). PUSH chỉ repo fork này (authorized per-instance).
- Ghi `BUILD_COREML_codex.md` (API dùng, cách map feature động, caveat runtime) + marker BUILD_COREML_DONE.
