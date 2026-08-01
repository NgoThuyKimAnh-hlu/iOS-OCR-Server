#!/usr/bin/env python3
"""Fail unless the packaged app declares the required background plist arrays."""

from __future__ import annotations

import plistlib
import sys
import zipfile
from pathlib import Path


REQUIRED_ARRAY_VALUES = {
    "UIBackgroundModes": "audio",
    "NSBonjourServices": "_http._tcp",
}


def fail(message: str) -> None:
    raise SystemExit(f"Info.plist verification failed: {message}")


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify_ipa_plist.py <app.ipa>")

    ipa_path = Path(sys.argv[1])
    if not ipa_path.is_file():
        fail(f"IPA not found: {ipa_path}")

    try:
        with zipfile.ZipFile(ipa_path) as archive:
            app_plists = [
                name
                for name in archive.namelist()
                if name.startswith("Payload/")
                and name.count("/") == 2
                and name.endswith(".app/Info.plist")
            ]
            if len(app_plists) != 1:
                fail(f"expected one top-level app Info.plist, found {app_plists}")
            plist = plistlib.loads(archive.read(app_plists[0]))
    except (OSError, plistlib.InvalidFileException, zipfile.BadZipFile) as error:
        fail(str(error))

    if not isinstance(plist, dict):
        fail(f"top-level plist object must be a dictionary, got {type(plist).__name__}")

    for key, required_value in REQUIRED_ARRAY_VALUES.items():
        values = plist.get(key)
        if not isinstance(values, list):
            fail(f"{key} must be an array, got {values!r}")
        if required_value not in values:
            fail(f"{key} is missing {required_value!r}: {values!r}")

    print(
        "Verified packaged Info.plist: "
        "UIBackgroundModes contains 'audio'; "
        "NSBonjourServices contains '_http._tcp'."
    )


if __name__ == "__main__":
    main()
