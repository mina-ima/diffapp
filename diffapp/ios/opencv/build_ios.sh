#!/usr/bin/env bash
set -euo pipefail

# 雛形: iOS 用 OpenCV ライブラリを CMake でビルドするスクリプト
# 必要に応じて OpenCV_DIR, CMAKE_OSX_ARCHITECTURES, CMAKE_SYSTEM_NAME などを設定してください。

BUILD_DIR=${BUILD_DIR:-build-ios}
INSTALL_DIR=${INSTALL_DIR:-install-ios}

mkdir -p "$BUILD_DIR"
cmake -S . -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  ${OpenCV_DIR:+-DOpenCV_DIR=$OpenCV_DIR}

cmake --build "$BUILD_DIR" --config Release --parallel

echo "iOS build (stub) finished."

