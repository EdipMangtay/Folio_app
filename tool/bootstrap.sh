#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter bulunamadı. Flutter 3.47+ kurup PATH'e ekleyin."
  exit 1
fi

printf '\n→ Flutter sürümü\n'
flutter --version | head -n 3

if [[ ! -d android || ! -d ios ]]; then
  printf '\n→ iOS ve Android platform kabukları oluşturuluyor\n'
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  flutter create \
    --platforms=android,ios \
    --org com.folio \
    --project-name folio_wallet \
    "$TMP_DIR/generated"
  cp -R "$TMP_DIR/generated/android" "$ROOT/android"
  cp -R "$TMP_DIR/generated/ios" "$ROOT/ios"
else
  printf '\n→ Platform klasörleri zaten mevcut; yeniden oluşturulmadı\n'
fi

printf '\n→ Platform ayarları Folio için uygulanıyor\n'
python3 tool/patch_platforms.py

printf '\n→ Paketler kuruluyor\n'
flutter pub get

printf '\n→ App icon oluşturuluyor\n'
dart run flutter_launcher_icons

printf '\n→ Native splash oluşturuluyor\n'
dart run flutter_native_splash:create

printf '\n→ Statik analiz\n'
flutter analyze

printf '\n→ Testler\n'
flutter test

printf '\n✓ Folio hazır.\n'
echo "  iOS:     flutter run -d ios"
echo "  Android: flutter run -d android"
