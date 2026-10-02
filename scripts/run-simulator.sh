#!/usr/bin/env bash
# Собирает MASHSTROY AI Control, запускает симулятор iPhone и открывает в нём приложение.
#   ./scripts/run-simulator.sh            — первый доступный iPhone
#   ./scripts/run-simulator.sh "iPhone 17" — конкретная модель
# Без Config/Secrets.xcconfig приложение откроется в демо-режиме.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/App/MashstroyAIControl.xcodeproj"
SCHEME="MashstroyAIControl"
BUNDLE_ID="kz.mashstroy.aicontrol"
# Сборка вне папки проекта: Рабочий стол и Документы синхронизирует iCloud,
# он ставит файлам атрибуты, и подпись падает с «resource fork … not allowed».
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/MashstroyAI"
WANTED="${1:-}"

command -v xcrun >/dev/null || { echo "Нужен Xcode (xcode-select --install не хватит, поставьте Xcode из App Store)"; exit 1; }

# Симулятор: уже запущенный iPhone, иначе нужная или первая доступная модель.
UDID="$(xcrun simctl list devices booted | grep -E "iPhone" | head -1 | grep -oE '[0-9A-F-]{36}' || true)"
if [[ -z "$UDID" ]]; then
  if [[ -n "$WANTED" ]]; then
    UDID="$(xcrun simctl list devices available | grep -F "$WANTED (" | head -1 | grep -oE '[0-9A-F-]{36}' || true)"
  fi
  if [[ -z "$UDID" ]]; then
    UDID="$(xcrun simctl list devices available | grep -E "^\s+iPhone" | head -1 | grep -oE '[0-9A-F-]{36}' || true)"
  fi
  [[ -n "$UDID" ]] || { echo "Нет симулятора iPhone. Xcode → Settings → Components → установите iOS Simulator."; exit 1; }
  echo "Запускаю симулятор $UDID"
  xcrun simctl boot "$UDID" 2>/dev/null || true
fi
open -a Simulator --args -CurrentDeviceUDID "$UDID" || true

xattr -cr "$ROOT/App" "$ROOT/Sources" "$ROOT/Config" 2>/dev/null || true

echo "Собираю приложение (первый раз скачивается supabase-swift, это несколько минут)…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -quiet \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="$DERIVED/Build/Products/Debug-iphonesimulator/MashstroyAIControl.app"
[[ -d "$APP" ]] || { echo "Не найден $APP"; exit 1; }

xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE_ID"
echo "Готово: MASHSTROY AI запущено в симуляторе."
