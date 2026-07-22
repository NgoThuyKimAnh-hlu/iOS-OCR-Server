#!/usr/bin/env python3
"""Build compact, reproducible OCR resources for the iOS app bundle."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import re
import struct
import unicodedata
import zlib
from pathlib import Path
from typing import Any


DEFAULT_ENGINE = Path("/mnt/d/AI Projects/Iphone OCR/engine")
DEFAULT_LEGACY_CORRECTOR = Path("/mnt/d/AI Projects/Iphone OCR/vn_corrector.py")
DEFAULT_OUTPUT = Path(__file__).resolve().parents[1] / "OCRResources"
PACK_VERSION = "2026.07.22.1"


def json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def pack_zlib(source: Path, destination: Path) -> dict[str, Any]:
    raw = source.read_bytes()
    compressor = zlib.compressobj(level=9, method=zlib.DEFLATED, wbits=-15)
    compressed = compressor.compress(raw) + compressor.flush()
    destination.write_bytes(b"CZL1" + struct.pack("<Q", len(raw)) + compressed)
    parsed = json.loads(raw)
    return {
        "source": str(source),
        "source_sha256": sha256(raw),
        "entries": len(parsed),
        "raw_bytes": len(raw),
        "bundle_bytes": destination.stat().st_size,
        "bundle_sha256": sha256(destination.read_bytes()),
    }


def assigned_dicts(path: Path, names: set[str]) -> dict[str, dict[str, str]]:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    result: dict[str, dict[str, str]] = {}
    for node in ast.walk(tree):
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if not isinstance(target, ast.Name) or target.id not in names:
            continue
        value = ast.literal_eval(node.value)
        if isinstance(value, dict):
            result[target.id] = {str(k): str(v) for k, v in value.items()}
    missing = names - result.keys()
    if missing:
        raise RuntimeError(f"Could not extract dictionaries: {sorted(missing)}")
    return result


AMBIGUOUS_ADMIN_SYLLABLES = {
    "ban", "bao", "bo", "can", "cao", "chanh", "chi", "chinh", "chu",
    "chuc", "cong", "cuc", "dan", "dia", "dieu", "dinh", "doc", "don",
    "dung", "giam", "giay", "han", "hien", "hoi", "huong", "kiem", "lap",
    "nghi", "nhan", "nhiem", "noi", "phan", "pho", "quan", "quy", "quyen",
    "so", "tham", "thanh", "thi", "thong", "thu", "thuc", "tich", "tra",
    "trung", "truong", "tuc", "uong", "uy", "van", "vien", "viet", "vu",
}


def normalized_phrase(value: str) -> str:
    return re.sub(r"\s+", " ", unicodedata.normalize("NFC", value).strip())


def strip_diacritics(value: str) -> str:
    value = unicodedata.normalize("NFD", value.replace("đ", "d").replace("Đ", "D"))
    return "".join(char for char in value if unicodedata.category(char) != "Mn")


def build_safe_corrections(engine: Path, legacy_corrector: Path) -> list[dict[str, Any]]:
    dictionaries = assigned_dicts(
        legacy_corrector,
        {"tax_phrases", "legal_phrases", "tax_words"},
    )
    phrase_map = dict(dictionaries["tax_phrases"])
    phrase_map.update(
        {source.lower(): target.lower() for source, target in dictionaries["legal_phrases"].items()}
    )
    phrase_map.update(dictionaries["legal_phrases"])

    exact: dict[str, str] = {}
    for source, target in phrase_map.items():
        source = normalized_phrase(source)
        target = normalized_phrase(target)
        exact[source] = target
        accentless_upper = strip_diacritics(source).upper()
        if source != accentless_upper:
            exact[accentless_upper] = target

    for source, target in dictionaries["tax_words"].items():
        source = normalized_phrase(source)
        target = normalized_phrase(target)
        key = strip_diacritics(source).lower()
        if " " in source or key not in AMBIGUOUS_ADMIN_SYLLABLES:
            exact[source] = target

    records = [
        {
            "source": source,
            "target": target,
            "case_insensitive": False,
            "rule_id": "legacy_phrase",
        }
        for source, target in exact.items()
        if source and target and source != target
    ]

    for overlay_name in ("htpl_safe_overrides.json", "pass2_safe_overrides.json"):
        overlay_path = engine / "lexicon" / overlay_name
        if not overlay_path.is_file():
            continue
        for source, target in json.loads(overlay_path.read_text(encoding="utf-8")).items():
            records.append(
                {
                    "source": normalized_phrase(source),
                    "target": normalized_phrase(target),
                    "case_insensitive": True,
                    "rule_id": overlay_name.removesuffix(".json"),
                }
            )
    return sorted(records, key=lambda item: (-len(item["source"]), item["source"]))


def has_vietnamese_mark(value: str) -> bool:
    decomposed = unicodedata.normalize("NFD", value)
    return "đ" in value.lower() or any(unicodedata.category(char) == "Mn" for char in decomposed)


def pack_record(pack_id: str, words: set[str], metadata: dict[str, list[str]]) -> dict[str, Any]:
    cleaned = sorted(
        {
            unicodedata.normalize("NFC", re.sub(r"\s+", " ", word.strip()))
            for word in words
            if word.strip()
        },
        key=lambda value: (value.lower(), value),
    )
    digest = sha256(json_bytes(cleaned))
    return {
        "id": pack_id,
        "version": PACK_VERSION,
        "sha256": digest,
        "metadata": metadata,
        "words": cleaned,
    }


def build_domain_packs(unigrams: dict[str, int], safe: list[dict[str, Any]]) -> dict[str, Any]:
    ranked = [
        word
        for word, _ in sorted(unigrams.items(), key=lambda item: (-int(item[1]), item[0]))
        if 3 <= len(word) <= 30
        and re.fullmatch(r"[A-Za-zÀ-ỹĐđ]+", word)
        and has_vietnamese_mark(word)
    ]

    legal_terms = {
        "Cộng hòa xã hội chủ nghĩa Việt Nam", "Độc lập - Tự do - Hạnh phúc",
        "nghị định", "nghị quyết", "thông tư", "quyết định", "chỉ thị",
        "căn cứ", "điều", "khoản", "điểm", "phụ lục", "quy định",
        "Chính phủ", "Quốc hội", "Ủy ban nhân dân", "Hội đồng nhân dân",
        "Bộ Tài chính", "Bộ Tư pháp", "Văn phòng Chính phủ", "Công báo",
        "cơ quan", "đơn vị", "trách nhiệm", "thi hành", "hiệu lực",
        "thủ tục hành chính", "hướng dẫn", "tổ chức thực hiện",
    }
    tax_terms = {
        record["target"] for record in safe
        for target in [record["target"]]
        if any(token in target for token in ("thuế", "hóa đơn", "tài chính", "doanh nghiệp", "kê khai"))
    }
    tax_terms.update({
        "Tổng cục Thuế", "Cục Thuế", "Chi cục Thuế", "mã số thuế",
        "thuế giá trị gia tăng", "thuế thu nhập doanh nghiệp",
        "thuế thu nhập cá nhân", "hóa đơn điện tử", "người nộp thuế",
        "kê khai thuế", "quản lý thuế", "miễn giảm thuế", "ưu đãi thuế",
    })
    customs_terms = {
        "Tổng cục Hải quan", "Cục Hải quan", "Chi cục Hải quan",
        "tờ khai hải quan", "thuế xuất khẩu", "thuế nhập khẩu", "trị giá hải quan",
        "xuất xứ hàng hóa", "kiểm tra sau thông quan", "giám sát hải quan",
        "hàng hóa xuất khẩu", "hàng hóa nhập khẩu", "mã số hàng hóa",
    }

    minimal = legal_terms | set(ranked[:120])
    legal = legal_terms | set(ranked[:600]) | {record["target"] for record in safe}
    tax = minimal | tax_terms | set(ranked[:350])
    customs = minimal | customs_terms | set(ranked[:350])

    return {
        "schema_version": 1,
        "default_pack": "minimal",
        "packs": [
            pack_record("minimal", minimal, {}),
            pack_record(
                "legal",
                legal,
                {"document_type": ["luật", "nghị định", "thông tư", "quyết định"]},
            ),
            pack_record(
                "tax",
                tax,
                {"agency": ["thuế", "tài chính"], "document_type": ["thuế", "hóa đơn"]},
            ),
            pack_record(
                "customs",
                customs,
                {"agency": ["hải quan"], "document_type": ["hải quan", "xuất nhập khẩu"]},
            ),
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, default=DEFAULT_ENGINE)
    parser.add_argument("--legacy-corrector", type=Path, default=DEFAULT_LEGACY_CORRECTOR)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    lexicon = args.engine / "lexicon"
    args.output.mkdir(parents=True, exist_ok=True)
    correction_meta = pack_zlib(
        lexicon / "correction_map.json",
        args.output / "correction_map.json.zlib",
    )
    unigram_meta = pack_zlib(
        lexicon / "unigram.json",
        args.output / "unigram.json.zlib",
    )

    safe = build_safe_corrections(args.engine, args.legacy_corrector)
    safe_bytes = json_bytes(safe)
    (args.output / "safe_corrections.json").write_bytes(safe_bytes)

    unigrams = json.loads((lexicon / "unigram.json").read_text(encoding="utf-8"))
    packs = build_domain_packs(unigrams, safe)
    packs_bytes = json_bytes(packs)
    (args.output / "domain_packs.json").write_bytes(packs_bytes)

    manifest = {
        "schema_version": 1,
        "generated_by": "tools/build_ios_ocr_resources.py",
        "excluded": ["phrases.json"],
        "correction_map": correction_meta,
        "unigram": unigram_meta,
        "safe_corrections": {
            "entries": len(safe),
            "bundle_bytes": len(safe_bytes),
            "bundle_sha256": sha256(safe_bytes),
        },
        "domain_packs": {
            "count": len(packs["packs"]),
            "bundle_bytes": len(packs_bytes),
            "bundle_sha256": sha256(packs_bytes),
            "packs": [
                {
                    "id": pack["id"],
                    "version": pack["version"],
                    "sha256": pack["sha256"],
                    "word_count": len(pack["words"]),
                }
                for pack in packs["packs"]
            ],
        },
    }
    manifest_bytes = json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True).encode("utf-8") + b"\n"
    (args.output / "resource_manifest.json").write_bytes(manifest_bytes)

    total = sum(path.stat().st_size for path in args.output.iterdir() if path.is_file())
    print(json.dumps({"output": str(args.output), "bundle_bytes": total, **manifest}, ensure_ascii=False, indent=2))
    if total > 40 * 1024 * 1024:
        raise SystemExit("Resource bundle exceeds 40 MiB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
