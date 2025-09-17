cmake_minimum_required(VERSION 3.22)
project(opencv_ios)

# 雛形: iOS 用 OpenCV ラッパーを静的ライブラリ or Framework としてビルドする方針
# 実際のOpenCVパスは環境に応じて設定します（OpenCV_DIR など）。

add_library(opencv_ios STATIC
  src/dummy.cpp
)

target_include_directories(opencv_ios PUBLIC include)

