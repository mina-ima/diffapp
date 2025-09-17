## OpenCV iOS ビルド雛形

このディレクトリは、iOS 用の OpenCV 連携を CMake で .framework / .a を生成するための雛形です。

- 目的
  - アプリに同梱する iOS ネイティブライブラリとして OpenCV をリンク
  - 将来的に .framework もしくは静的ライブラリ（.a）のいずれかを生成

- 方針（例）
  1. OpenCV SDK の配置と `OpenCV_DIR` の設定
  2. `CMakeLists.txt` にて `find_package(OpenCV REQUIRED)` を追加
  3. `add_library(opencv_ios STATIC ...)` もしくは `FRAMEWORK` 指定
  4. `target_link_libraries(opencv_ios ${OpenCV_LIBS})`
  5. Xcode への組込み（pbxproj または SPM/手動追加）

- ビルド
  - `./build_ios.sh` を参考に CMake で iOS 用アーキテクチャをターゲットにビルド

注意: 現時点では雛形のみ。実際のパスや署名設定は環境に合わせて調整してください。
