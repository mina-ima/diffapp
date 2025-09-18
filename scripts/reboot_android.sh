#!/usr/bin/env bash
set -euo pipefail

# Reboot a running Android emulator by id and wait for boot completion.
# Usage: bash scripts/reboot_android.sh <emulator-id>

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <emulator-id>" >&2
  exit 2
fi

DEVICE_ID="$1"

if ! command -v adb >/dev/null 2>&1; then
  echo "[ERROR] adb が見つかりません。Android SDK の platform-tools を PATH に追加してください。" >&2
  exit 1
fi

echo "[INFO] Rebooting $DEVICE_ID ..."
adb -s ${DEVICE_ID} reboot

echo -n "[INFO] Waiting for device to reconnect"
adb -s ${DEVICE_ID} wait-for-device || true

echo -n "[INFO] Waiting for Android boot completion"
for i in {1..120}; do
  BOOTED=$(adb -s ${DEVICE_ID} shell getprop sys.boot_completed 2>/dev/null | tr -d '\r') || true
  if [[ "$BOOTED" == "1" ]]; then
    echo " ...done"
    break
  fi
  echo -n "."
  sleep 1
done

echo "[INFO] Reboot completed for $DEVICE_ID"
