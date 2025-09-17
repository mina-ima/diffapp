## C++ ネイティブテスト方針（雛形）

このフォルダは、OpenCV/TFLite 連携の C++ ネイティブテストの方針と雛形を管理します。

- テスト対象
  - ORB/SIFT マッチング精度確認（特徴点対応の正確性）
  - SSIM 数値検証（Dart 実装と数値一致の検証）
  - NMS 重複除去テスト（IoU 閾値での抑制挙動）

- 進め方
  1. Android NDK 用に `app/src/main/cpp/tests` 配下へテストCPPを配置
  2. gtest などのテストランナー導入（将来のCIで実行）
  3. まずはリリースに影響しない独立ターゲットとしてビルド

- 現状
  - テストCPPのファイル雛形のみ用意（CI実行は未設定）
  - Web側（Vitest）で雛形ファイルの存在を検証

- 参考
  - OpenCV features2d / imgproc / core
  - GoogleTest (gtest)
