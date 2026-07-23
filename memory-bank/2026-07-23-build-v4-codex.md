---
status: active
date: 2026-07-23
owner: codex
---

# Compute v4 handoff

Implemented `BUILD_V4_SPEC.md` locally; no GitHub push occurred.

- A `46a46b2` + `f11fee9`: effective custom words are assigned to Vision and the
  applied request count is exposed in debug/health.
- B `6be2159`: four large admin JSON routes collect up to 8 MB.
- C `eaa33aa`: schema v1 OCR fields are stable across image/PDF JSON responses,
  vi-VT is the default pinned language, auto-detect defaults off, version is
  `1.5.0 (32)`.
- D `449f132` + `3add223`: offline `/console`, serial OCR/Markdown/DOCX-source
  batch routes, browser-side ZIP/DOCX, four default-on toggles, hotspot docs, and
  verified mobile layout.

Verified: 37 Swift files parse, four inline scripts parse, OCR resources and
Python sources validate, browser ZIP/DOCX smoke passes, Chrome CDP proves serial
two-file batching/ZIP download/503 handling, and 390 px mobile fit has no
horizontal overflow. Synchronized Xcode source grouping remains intact.

Open: no Apple SDK/Xcode local build and no device run. CI must prove type-check,
link, and IPA packaging. A phone must verify actual customWords influence,
iOS 26 document OCR, hotspot behavior, and thermal characteristics. The real
`vn_legal_v1.json` was unavailable; a 233 KB synthetic payload with the same
1,995-word/3,759-override counts fit the 8 MB route and validators.

Full report: `BUILD_V4_codex.md`.
