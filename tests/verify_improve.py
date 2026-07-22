#!/usr/bin/env python3
"""Measure raw versus improved CER against the held-out VLM manifest."""

from __future__ import annotations

import argparse
import json
import mimetypes
import sys
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
from typing import Any


DEFAULT_MANIFEST = Path(
    "/mnt/d/AI Projects/Iphone OCR/engine/finetune/gold_vlm/heldout_manifest.jsonl"
)


def normalize_text(value: str) -> str:
    value = unicodedata.normalize("NFC", value).replace("\r\n", "\n")
    return "\n".join(" ".join(line.split()) for line in value.splitlines() if line.strip())


def edit_distance(left: str, right: str) -> int:
    if len(left) < len(right):
        left, right = right, left
    previous = list(range(len(right) + 1))
    for row, char_left in enumerate(left, 1):
        current = [row]
        for column, char_right in enumerate(right, 1):
            current.append(
                min(
                    current[-1] + 1,
                    previous[column] + 1,
                    previous[column - 1] + (char_left != char_right),
                )
            )
        previous = current
    return previous[-1]


def multipart_body(path: Path) -> tuple[bytes, str]:
    boundary = f"----compute-{uuid.uuid4().hex}"
    content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    body = bytearray()
    body.extend(f"--{boundary}\r\n".encode())
    body.extend(
        f'Content-Disposition: form-data; name="file"; filename="{path.name}"\r\n'.encode()
    )
    body.extend(f"Content-Type: {content_type}\r\n\r\n".encode())
    body.extend(path.read_bytes())
    body.extend(f"\r\n--{boundary}--\r\n".encode())
    return bytes(body), boundary


def post_image(base_url: str, endpoint: str, path: Path, raw: bool, token: str) -> dict[str, Any]:
    body, boundary = multipart_body(path)
    suffix = "?raw=1" if raw else ""
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}/{endpoint.lstrip('/')}{suffix}",
        data=body,
        method="POST",
        headers={
            "Accept": "application/json",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            **({"X-Admin-Token": token} if token else {}),
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {error.code}: {detail}") from error


def resolve_manifest_path(project_root: Path, value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else project_root / path


def load_rows(manifest: Path, limit: int | None) -> list[dict[str, Any]]:
    rows = []
    for line in manifest.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        if row.get("authoritative_truth") is not True:
            continue
        rows.append(row)
        if limit is not None and len(rows) >= limit:
            break
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("server", help="iPhone address, for example 192.168.31.65:8000")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--endpoint", choices=("upload", "docOCR"), default="upload")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--token", default="")
    parser.add_argument("--pc-threshold", type=float, default=0.03)
    parser.add_argument("--pass-ratio", type=float, default=0.90)
    args = parser.parse_args()

    base_url = args.server if "://" in args.server else f"http://{args.server}"
    manifest = args.manifest.resolve()
    project_root = manifest.parents[3]
    rows = load_rows(manifest, args.limit)
    if not rows:
        raise SystemExit("No authoritative rows found in the manifest")

    total_raw_edits = total_improved_edits = total_chars = 0
    regressions = 0
    print("page                                      CER_raw  CER_improved    delta  PC_pass2 flags")
    print("-" * 104)
    for row in rows:
        image_path = resolve_manifest_path(project_root, row["image_path"])
        target_path = resolve_manifest_path(project_root, row["target_path"])
        gold = normalize_text(target_path.read_text(encoding="utf-8"))

        raw_response = post_image(base_url, args.endpoint, image_path, raw=True, token=args.token)
        improved_response = post_image(base_url, args.endpoint, image_path, raw=False, token=args.token)
        raw_text = normalize_text(raw_response.get("raw") or raw_response.get("ocr_result") or raw_response.get("ocr_text") or "")
        improved_text = normalize_text(improved_response.get("improved") or improved_response.get("ocr_result") or improved_response.get("ocr_text") or "")

        raw_edits = edit_distance(raw_text, gold)
        improved_edits = edit_distance(improved_text, gold)
        denominator = max(1, len(gold))
        raw_cer = raw_edits / denominator
        improved_cer = improved_edits / denominator
        delta = improved_cer - raw_cer
        flags = improved_response.get("flags") or []
        needs_pc = bool(improved_response.get("needs_pass2")) or improved_cer > args.pc_threshold
        if improved_edits > raw_edits:
            regressions += 1
        total_raw_edits += raw_edits
        total_improved_edits += improved_edits
        total_chars += denominator
        print(
            f"{row['id'][:40]:40} {raw_cer:8.3%} {improved_cer:13.3%} "
            f"{delta:+8.3%} {'YES' if needs_pc else 'no ':>8} {','.join(flags)}"
        )

    weighted_raw = total_raw_edits / max(1, total_chars)
    weighted_improved = total_improved_edits / max(1, total_chars)
    ratio = weighted_improved / max(weighted_raw, 1e-12)
    passed = weighted_improved < weighted_raw and ratio <= args.pass_ratio
    print("-" * 104)
    print(
        f"weighted CER raw={weighted_raw:.3%} improved={weighted_improved:.3%} "
        f"ratio={ratio:.3f} regressions={regressions}/{len(rows)} result={'PASS' if passed else 'NOT PASS'}"
    )
    return 0 if passed else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
