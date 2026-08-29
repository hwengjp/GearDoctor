#!/usr/bin/env python3
"""Raise the app version by 0.0.1 and the Android build number by 1."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PUBSPEC = ROOT / "pubspec.yaml"
VERSION_DART = ROOT / "lib" / "app_version.dart"
VERSION_LINE = re.compile(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$", re.M)
APP_VERSION = re.compile(r"const appVersion = '[^']+';")


def bump(pubspec: str, version_dart: str) -> tuple[str, str, str]:
    match = VERSION_LINE.search(pubspec)
    if match is None:
        raise ValueError("pubspec.yaml の version が major.minor.patch+build ではありません。")
    major, minor, patch, build = (int(part) for part in match.groups())
    patch += 1
    build += 1
    name = f"{major}.{minor}.{patch}"
    full = f"{name}+{build}"
    pubspec = VERSION_LINE.sub(f"version: {full}", pubspec, count=1)
    if APP_VERSION.search(version_dart) is None:
        raise ValueError("lib/app_version.dart の appVersion が見つかりません。")
    version_dart = APP_VERSION.sub(f"const appVersion = '{name}';", version_dart, count=1)
    return pubspec, version_dart, name


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        pubspec, dart, name = bump(
            "version: 1.0.0+1\n",
            "const appVersion = '1.0.0';\n",
        )
        if name != "1.0.1" or "version: 1.0.1+2" not in pubspec:
            raise SystemExit("版の繰り上げが違います。")
        if "const appVersion = '1.0.1';" not in dart:
            raise SystemExit("app_version.dart の更新が違います。")
        return 0
    pubspec, version_dart, name = bump(PUBSPEC.read_text(), VERSION_DART.read_text())
    PUBSPEC.write_text(pubspec)
    VERSION_DART.write_text(version_dart)
    print(name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
