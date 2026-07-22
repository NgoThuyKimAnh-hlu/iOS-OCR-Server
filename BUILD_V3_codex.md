# BUILD_V3 report

Date: 2026-07-23

## Outcome

Implemented `BUILD_V3_SPEC.md` in four local implementation commits. No GitHub
push or publish action was performed.

- A: `3af1428` - `Guard valid OCR words from correction`
- B: `42e021a` - `Remove legacy about and donation UI`
- C: `d422733` - `Wire request logs into admin diagnostics`
- D: `1908633` - `Open remote OCR customization controls`

The app version is now `1.4.0 (31)` in both Debug and Release.

## A - corrector guard

- Added the default-on `respect_valid` corrector group.
- NFC-normalizes and lowercases source and target tokens for unigram lookup.
- Diacritic restoration now requires the source to be absent from the bundled
  unigram and the target to be present. The guard covers safe corrections,
  corpus corrections, all-caps restoration, and remote custom overrides.
- Existing installations migrate back to all default corrector groups, including
  `allcaps_diacritic`, `undiacritic_map`, `legalid_normalize`, and
  `respect_valid`.
- `tests/verify_improve.py` now obtains `/debug/ocr` traces and prints per-page
  and aggregate correction OK/BAD counts.

### p0001 evidence

- Verified historical device baseline from build `1.3.9`: `OK=10`, `BAD=28`
  on `htpl_04_2022_QH15_47edcbed_p0001`.
- Verified offline against the exact bundled 97,197-entry unigram that all six
  named destructive substitutions are blocked: `NAM->NAM-with-wrong-tone`,
  `CO-with-tone->CO-with-wrong-tone`, `DONG-with-tone->DONG-with-wrong-tone`,
  `Canh->Canh-with-wrong-tone`, `CHUNG->CHUNG-with-wrong-tone`, and
  `Can->Can-with-wrong-tone`.
- The archived trace exposes 34 individual changes. Every exposed source token,
  including the nine exposed historically-correct changes, is present in the
  supplied unigram, so the strict spec guard would skip all 34. This proves the
  destructive examples are removed, but it does not prove a new correction
  count of `OK >> BAD`.
- A new IPA/device run was not possible: the prior phone at
  `192.168.31.65:8000` timed out and this machine has no Xcode. Therefore the
  post-fix p0001 device count is explicitly unverified, not assumed.

## B - legacy UI removal

- Deleted `DonationView.swift` and `ReadmeView.swift`.
- Removed StoreKit linkage, donation/readme localization entries, navigation,
  coffee links, and related UI state.
- The overflow menu now contains only Settings and Monitor.

## C - request logging

- Added an actor-backed 200-entry request log store.
- Request middleware writes method, path, status, duration, and response size
  for success and error responses.
- `/admin/log` reads the actor store and returns `logs`, compatibility alias
  `entries`, and `count`.
- `/debug/last` returns the same recent request log data with OCR traces.

## D1 - persistent remote settings

`GET /admin/settings` returns a dynamic schema with type/range/options metadata.
`POST /admin/settings` accepts any subset and returns
`{applied:[...], rejected:[...], restarted:bool}`.

- Vision/OCR: `recognition_level`, `recognition_languages`,
  `uses_language_correction`, `automatically_detects_language`,
  `minimum_text_height`, `vision_revision`, `confidence_threshold`,
  `multipass`, `roi_upscale`, `max_roi_count`.
- Corrector: `improve`, `corrector_groups`, `active_pack`, `ambiguous_skip`.
- Quality envelope: `page_score_pass2_threshold`, `legal_id_regex`,
  `possible_legal_id_regex`, `candidate_gap_threshold`,
  `candidate_gap_confidence_threshold`, `candidate_gap_normalizer`,
  `line_confidence_weight`, `missing_page_number_min_pages`,
  `broken_table_min_lines`, `low_confidence_penalty`,
  `invalid_legal_id_penalty`, `missing_page_number_penalty`,
  `broken_table_penalty`, `multipass_min_confidence_gain`,
  `multipass_legal_id_tolerance`, `multipass_min_length_ratio`,
  `multipass_max_length_ratio`.
- PDF: `pdf_dpi`, `pdf_max_pages`, `rectify_default`.
- Server: `http_port`, `keep_alive`, `watchdog_interval_s`, `debug_verbose`,
  `admin_token`.

All 39 settings persist in UserDefaults. OCR settings are snapshotted for each
request. Port changes request a managed restart; the other settings apply hot.

## D2 - per-request overrides

`/upload`, `/docOCR`, and `/debug/ocr` accept the requested query overrides:
`improve`, `groups`, `level`, `langs`, `rectify`, `multipass`, `conf`, `upscale`,
`dpi`, and `pack`. They do not modify persistent defaults. Existing `raw`,
`max_pages`, and domain metadata query inputs remain supported.

## D3 - hot resources

- `GET/POST /admin/customwords` with replace/append mode.
- `GET/POST /admin/corrections` for high-precedence post-corrector overrides.
- `POST /admin/pack` and `GET /admin/packs` for custom domain packs.
- `POST /admin/lexicon/reset` removes custom resources and selects `auto`.
- Resources persist atomically in Application Support and expose version/hash
  metadata in their responses and `/health.ocr_improve`.
- Global custom corrections apply after pack corrections and remain protected
  by `respect_valid` when that group is enabled.

## D4 - service switches

`GET/POST /admin/services` controls `ocr`, `dococr`, `translate`, `transcribe`,
`synthesize`, `llm`, `ner`, `embed`, `coreml`, and `barcode`. Disabled routes
throw HTTP 503 with a `disabled` reason. The in-app service monitor also marks
them OFF and avoids availability probes for disabled heavyweight services.

## D5 - web console

The dark self-contained `/admin` page renders all settings from the server
schema, manages custom words/corrections/packs, toggles services, resets the
custom lexicon, shows health, and tails request logs. It does not use a fixed
post-save delay to assume restart readiness.

## Verification performed

- `git diff --check` and staged diff checks passed for every implementation
  commit.
- Tree-sitter parsed all 36 Swift source files with zero syntax errors.
- The `/admin` JavaScript passed `node --check`.
- JSON catalogs/resources parsed successfully; both compressed resource maps
  decompressed and parsed, with 923,186 correction entries and 97,197 unigram
  entries.
- `tests/verify_improve.py` and `tools/build_ios_ocr_resources.py` passed Python
  bytecode compilation.
- Static coverage confirmed all 39 settings, all D2 query keys, all D3 routes,
  all 10 service switches, and dynamic D5 rendering.
- The project uses `PBXFileSystemSynchronizedRootGroup`, so
  `RemoteCustomization.swift` is included by the synchronized source group.
- All five OCR resource files remain explicitly present in Copy Bundle
  Resources for both builds.

## Not verified

- No Apple SDK, `swiftc`, or `xcodebuild` is installed here. Apple-framework and
  Vapor type-checking, linking, signing, and an actual iOS build are not proven.
- No new IPA was installed, so hot settings, service 503 responses, persistence,
  request-log population, custom resource behavior, and UI layout remain
  device-runtime checks.
- The required post-fix p0001 `OK >> BAD` device result remains open. What is
  verified offline is that every named destructive regression is blocked.

