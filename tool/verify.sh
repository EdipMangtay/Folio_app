#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

flutter pub get
flutter analyze
flutter test
flutter build apk --release
if [[ "$(uname -s)" == "Darwin" ]]; then
  flutter build ios --release --no-codesign
fi

echo "✓ Analyze, test ve release build kontrolleri tamamlandı."
