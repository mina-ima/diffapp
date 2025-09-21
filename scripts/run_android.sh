#!/usr/bin/env bash
set -euo pipefail

# Run Flutter app on Android emulator.
# - Prefers `fvm flutter` if available, otherwise `flutter`.
# - Launches the first available Android emulator if none is running.
# - Waits for boot completion before running the app.

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_DIR="$ROOT_DIR/diffapp"

if command -v fvm >/dev/null 2>&1; then
  FLUTTER_CMD=(fvm flutter)
else
  FLUTTER_CMD=(flutter)
fi

cd "$APP_DIR"

"${FLUTTER_CMD[@]}" doctor -v || true

# Optional first argument: explicit device/emulator id (e.g., emulator-5554)
DEVICE_ID=${1:-}

# Ensure dependencies are installed
echo "[INFO] flutter pub get"
"${FLUTTER_CMD[@]}" pub get

# If a device is already attached, prefer the first Android emulator id (emulator-XXXX),
# unless an explicit DEVICE_ID was provided.
if [[ -n "$DEVICE_ID" ]]; then
  # If explicit device id was provided, make sure it's connected; otherwise, fallback to launch flow
  if command -v adb >/dev/null 2>&1; then
    STATE=$(adb -s "$DEVICE_ID" get-state 2>/dev/null || true)
  else
    STATE=""
  fi
  if [[ "$STATE" == "device" ]]; then
    CURRENT_DEVICE_ID="$DEVICE_ID"
  else
    CURRENT_DEVICE_ID=""
  fi
else
  CURRENT_DEVICE_ID=$("${FLUTTER_CMD[@]}" devices 2>/dev/null | sed -n 's/.*\(emulator-[0-9]\+\).*/\1/p' | head -n1) || true
fi

if [[ -z "${CURRENT_DEVICE_ID:-}" ]]; then
  # No device; try to launch the first Android emulator listed by Flutter.
  # Prefer the first Android emulator row from the table output of `flutter emulators`.
  # Be tolerant of non-zero exit from `flutter emulators` (no AVD installed, etc.).
  EMULATOR_LIST=$("${FLUTTER_CMD[@]}" emulators 2>/dev/null || true)
  EMULATOR_ID=$(awk -F "•" '/android/ {gsub(/^ +| +$/,"", $1); print $1; exit}' <<< "$EMULATOR_LIST")
  if [[ -z "${EMULATOR_ID:-}" ]]; then
    echo "[ERROR] Androidエミュレーター(AVD)が見つかりません。Android StudioでAVDを作成してください。" >&2
    echo "ヒント: Android Studio > Device Manager > Create Virtual Device" >&2
    exit 1
  fi
  echo "[INFO] Launching Android emulator: $EMULATOR_ID"
  "${FLUTTER_CMD[@]}" emulators --launch "$EMULATOR_ID" >/dev/null 2>&1 &

  # Wait for ADB and boot completion
  if command -v adb >/dev/null 2>&1; then
    echo "[INFO] Waiting for device to appear..."
    adb wait-for-device || true
    echo -n "[INFO] Waiting for Android boot completion"
    for i in {1..120}; do
      BOOTED=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r') || true
      if [[ "$BOOTED" == "1" ]]; then
        echo " ...done"
        break
      fi
      echo -n "."
      sleep 1
    done
  else
    echo "[WARN] adb が見つかりません。環境PATHにAndroid SDK platform-toolsを追加してください。" >&2
    sleep 5
  fi

  # Refresh devices list and pick the first emulator id
  CURRENT_DEVICE_ID=$("${FLUTTER_CMD[@]}" devices 2>/dev/null | sed -n 's/.*\(emulator-[0-9]\+\).*/\1/p' | head -n1) || true
fi

RUN_ARGS=(run)
if [[ -n "${CURRENT_DEVICE_ID:-}" ]]; then
  # Prefer explicit/current device id
  RUN_ARGS+=( -d "$CURRENT_DEVICE_ID" )
fi

# Ensure we target the app's main entry
RUN_ARGS+=( --target lib/main.dart )

echo "[INFO] Running: ${FLUTTER_CMD[*]} ${RUN_ARGS[*]} (in $APP_DIR)"
"${FLUTTER_CMD[@]}" "${RUN_ARGS[@]}"
