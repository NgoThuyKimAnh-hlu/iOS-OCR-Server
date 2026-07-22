# BUILD_COREML report

Date: 2026-07-22

## Implemented APIs

- `POST /coreml/upload` accepts multipart field `file`. A direct `.mlmodel` is
  compiled on the iPhone. Directory-based `.mlpackage` and `.mlmodelc` models
  are accepted as ZIP data; the client can preserve the original multipart
  filename or upload a ZIP containing exactly one supported model directory.
- `GET /coreml/info?model_id=...` returns sorted input/output feature metadata,
  including type, optionality, tensor shape/data type, image dimensions/pixel
  format, and dictionary key type where applicable.
- `POST /coreml/predict` accepts `model_id` plus a dynamic `inputs` JSON object,
  runs synchronous Core ML prediction, and returns JSON outputs with measured
  `inference_ms` and the requested `compute: "neuralEngine/all"` marker.
- `POST /coreml/delete?model_id=...` unloads the cached model and removes its
  persistent Application Support directory.

Uploaded content gets a stable model ID based on a sanitized filename and the
first 16 hexadecimal characters of SHA-256. Compiled models are stored below
Application Support under `OcrServer/CoreMLModels/<model_id>/model.mlmodelc`.
They are loaded lazily again after an app/server restart.

## Dynamic feature mapping

Inputs are mapped from JSON according to
`model.modelDescription.inputDescriptionsByName`:

- Core ML `double` accepts a JSON number; `int64` requires a JSON integer.
- `string` accepts a JSON string.
- `multiArray` accepts flat or rectangular nested numeric arrays. Flat arrays
  are reshaped to the model's declared shape; nested arrays are checked for a
  matching shape and total element count. `MLMultiArray` uses the model's
  declared element data type.
- `image` accepts a raw base64 string or a `data:` URL. The decoded image is
  resized into a `CVPixelBuffer` using the model's image dimensions and pixel
  format.

Outputs map `double`, `int64`, and `string` directly; `MLMultiArray` becomes a
flat JSON array; Core ML dictionaries become JSON objects; image buffers become
base64 PNG strings. Missing, unknown, malformed, ragged, constraint-violating,
or unsupported feature values return a JSON error instead of crashing the
other compute routes. Sequence, state, and dictionary inputs are not currently
constructed by the JSON mapper and return HTTP 400 when required.

Example:

```bash
curl -F "file=@VietnameseLegal.mlmodel" \
  http://IPHONE:8000/coreml/upload

curl -H "Content-Type: application/json" \
  -X POST http://IPHONE:8000/coreml/predict \
  -d '{"model_id":"vietnameselegal-HASH","inputs":{"input_ids":[[1,2,3,4]]}}'
```

For a package directory:

```bash
zip -qr VietnameseLegal.mlpackage.zip VietnameseLegal.mlpackage
curl -F "file=@VietnameseLegal.mlpackage.zip;filename=VietnameseLegal.mlpackage" \
  http://IPHONE:8000/coreml/upload
```

## Compatibility and runtime caveats

- Every load creates `MLModelConfiguration` with `computeUnits = .all`. This
  makes the Neural Engine eligible, but Core ML chooses the actual per-operation
  backend and can fall back to CPU/GPU. The public API does not prove that every
  layer ran on ANE.
- ZIP extraction is capped at 2 GB and ZIPFoundation rejects uncontained paths
  and symlinks. The HTTP upload body is capped at 500 MB.
- Models still need to be compatible with the device OS, Core ML runtime,
  available memory, and ANE-supported operators. Model compilation/loading can
  therefore fail cleanly at upload time even though the app itself compiles.
- No physical iPhone/model runtime test was available in this environment, so
  real model upload, ANE scheduling, prediction correctness, latency, memory
  pressure, and persistence across app restarts remain device checks.
- The original eight compute routes remain registered, and no vi-VN OCR pin or
  automatic-language-detection setting was changed.

## Verification

- Implementation commits: `8ada3b2`, `ad580ad`.
- GitHub Actions successful run: `29904273720`.
- Runner toolchain: Xcode 26.5, iPhoneOS 26.5 SDK, deployment target iOS 18.4.
- Result: dependency resolution, app build, unsigned IPA packaging, and artifact
  upload all succeeded.
- Artifact: `OcrServer-unsigned-ipa`, artifact ID `8523339122`, uploaded size
  13,575,529 bytes.
- CI iteration: run `29903736703` exposed one insufficient-indentation error in
  the root HTML multiline string. Commit `ad580ad` corrected that line; the next
  run compiled successfully with the full Core ML implementation.

