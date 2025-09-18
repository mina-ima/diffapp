#!/usr/bin/env bash
set -euo pipefail

# Capture Android logs for Diffapp and Flutter, optionally filtered by device.
# Usage: bash scripts/logcat_diffapp.sh [<emulator-id-or-device-id>]

DEVICE_ID=${1:-}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT=logs/android_${TIMESTAMP}.log
mkdir -p logs

if ! command -v adb >/dev/null 2>&1; then
  echo "[ERROR] adb が見つかりません。Android SDK / platform-tools を PATH に追加してください。" >&2
  exit 1
fi

echo "[INFO] Writing log to $OUT"
if [[ -n "$DEVICE_ID" ]]; then
  echo "[INFO] Target device: $DEVICE_ID"
  adb -s "$DEVICE_ID" logcat -v time | grep -E "flutter|Diffapp" | tee "$OUT"
else
  adb logcat -v time | grep -E "flutter|Diffapp" | tee "$OUT"
fi

