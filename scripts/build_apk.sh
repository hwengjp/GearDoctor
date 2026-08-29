#!/usr/bin/env bash
# 版を 0.0.1 上げてから APK を作り、Windows のデスクトップへコピーする。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export JAVA_HOME="${JAVA_HOME:-$HOME/jdk-17}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$JAVA_HOME/bin:$HOME/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

if [[ "${1:-}" == "--no-bump" ]]; then
  VERSION="$(python3 - <<'PY'
import re
from pathlib import Path
text = Path("pubspec.yaml").read_text()
match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+", text, re.M)
if not match:
    raise SystemExit("pubspec.yaml の version が読めません。")
print(match.group(1))
PY
)"
else
  VERSION="$(python3 scripts/bump_version.py)"
fi

flutter config --android-sdk "$ANDROID_HOME"
flutter build apk

APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
DEST="/mnt/c/Users/kenjii/Desktop/GearDoctor-${VERSION}.apk"
cp "$APK" "$DEST"
echo "GearDoctor ${VERSION}"
echo "$DEST"
