📄 Diffapp Ver1.2 開発仕様書

対象：スマホアプリ（iOS / Android）
開発環境：Flutter
利用者層：小学生〜中学生
運用形態：完全無料・広告なし・オフライン動作

⸻

1. 基本情報

項目 内容
アプリ名 Diffapp（ディフアップ）
カテゴリ 教育 / ゲーム / 知育
目的 2枚の画像からAIが自動で間違いを検出し、子供にわかりやすく表示
実行環境 Android 9以降 / iOS 14以降
開発基盤 Flutter（Dart）＋プラットフォーム依存部分はネイティブ呼び出し
SDK管理 fvm（Flutter 3.22.0 をプロジェクトで固定）
ライセンス制約 オープンソースライブラリのみ使用可

⸻

2. 機能仕様

2.1 トップ画面
• ロゴ＋キャッチコピー - キャッチコピー文言（暫定）: AIがちがいをみつけるよ
• 画像選択／撮影ボタン（左・右）
• 「けんさをはじめる」ボタン
• 設定アイコン（検出設定へ）

2.2 画像入力
• カメラ撮影（前後切替）
• ギャラリー選択（jpg/png）
• 最大解像度：4000×3000px（内部で自動リサイズ）- 対応拡張子: jpg/jpeg/png（大文字小文字不問）- 補足: 入力ファイル名の前後空白は無視して拡張子判定（例: " photo.JPG " も許容）- 超過時は縦横比を保持して 4000×3000 以内に縮小
• 権限: Androidは CAMERA / READ_MEDIA_IMAGES（9〜12は READ_EXTERNAL_STORAGE）、iOSはカメラ/フォトライブラリアクセス文言を設定
• 権限拒否時はSnackBarで「設定をひらく」導線を表示

2.3 比較範囲指定
• 左画像を拡大表示
• 指ドラッグで矩形選択（リサイズ可）
• 選択範囲は右画像にも同座標で適用

2.4 画像前処理

処理 技術 詳細
傾き補正 OpenCV ORB/SIFT 特徴点マッチング＋ホモグラフィ変換（Dart側で相似変換推定の雛形を実装・テスト済み）
サイズ統一 OpenCV 幅1280px基準に縮小
トリミング OpenCV 指定矩形領域で切り出し
色調整（任意） OpenCV/Dart 自動コントラスト補正（Dartで簡易線形ストレッチを実装済み）

2.5 検出設定
• チェックボックス：色 / 形 / 場所 / 大きさ / 文字
• 精度スライダー：3〜5段階
• 初期設定：全ON、普通精度

2.6 検出処理

処理 技術 詳細
差分抽出 SSIM ピクセルベースでスコアマップ生成
AIモデル TensorFlow Lite（CNN） 形・文字認識補強
最大検出数 20件 上位スコア順に制限
補足 前処理 SSIMスコアマップを正規化→二値化→連結成分解析で矩形候補抽出（純Dart実装）

2.7 結果表示
• 左右画像を並列表示
• 赤枠ハイライト＋アニメーション（中央にポヨン演出）
• 効果音（ON/OFF可）- 現状: 設定でON/OFF切替可。検出開始/再比較で効果音を再生
• 「スクショをとろう！」案内
• 再比較ボタン（選択範囲リセット＋案内SnackBar）

⸻

3. 非機能要件
   • オフライン実行：通信不要
   • パフォーマンス：処理5秒以内（1280px画像想定）
   • ストレージ：一時ファイルはセッション終了時に削除
   • セキュリティ：画像は外部送信禁止
   • 拡張性：Flutterで共通UIロジック、AI処理はプラットフォームごとに最適化可
   • 低メモリ端末での安定性：計画（`diffapp/docs/perf_low_memory_plan.md`）に基づき確認（ulimit/adb/Xcodeのメモリ警告を活用）。

⸻

4. アーキテクチャ設計
   • フロント層：Flutter UI
   • 処理層：Dart → FFI経由でC++（OpenCV / TFLite）呼び出し - 現状: FFI土台を用意し、Dart実装にフォールバック（`ffi/image_ops.dart`, `FfiCnnDetector`）- C++サンプル関数: グレースケール変換 `to_grayscale_u8` を追加（Android NDK/CMake 設定済み。iOSは今後対応）- Dart からの FFI 配線（Android）を実装し、`DefaultNativeOps` 経由で呼び出し可能にした（未接続環境は従来どおり Dart 実装にフォールバック）- FFI呼び出し方針: `FfiImageOps` はネイティブ実装を優先し、未接続環境では Dart 実装へフォールバックできる注入構造を導入（単体テストで検証済み）- 既定ネイティブ実装スタブ: `DefaultNativeOps` を追加。現段階では環境未接続時のフォールバック挙動のみ担保（今後 `to_grayscale_u8` へ接続）- ネイティブ未接続環境で `DefaultNativeOps.rgbToGrayscaleU8` を直呼びした場合は `UnsupportedError` を投げる（`FfiImageOps` 経由では Dart 実装へ自動フォールバック）- 傾き補正: Dart側で相似変換のRANSAC推定を実装（外れ値混入時も安定したs/R/t推定が可能）- 傾き補正（拡張）: Dart雛形としてホモグラフィ（射影変換）のRANSAC推定を実装し、インライアでの再投影誤差を低減
   • データ層：端末内キャッシュ（メモリor一時ディレクトリ）
   • 依存関係管理：Flutter pub + CMake連携

アプリ構造イメージ：

Flutter (UI)
└─ Application Layer (Dart)
├─ Image IO Service
├─ Preprocess Service (OpenCV FFI)
├─ Detection Service (TFLite)
└─ Result Presenter

⸻

5. データハンドリング
   • 入力画像：一時ディレクトリに保存、処理後即削除
   • 中間結果：メモリ保持のみ（キャッシュ書き込み禁止）
   • ログ：クラッシュログのみ（端末内、外部送信なし）
   • 永続保存：ユーザー操作でスクショ保存のみ

⸻

6. エラーハンドリング

ケース 表示／対応
入力画像なし アラート「がぞうを えらんでね」
備考 ホーム画面の開始ボタン押下時にSnackBarで表示
解像度超過 自動リサイズ、警告なし
AIモデル読み込み失敗 「けんさに しっぱいしました。もういちどためしてね」
検出ゼロ件 「ちがいは みつかりませんでした」表示
タイムアウト（5秒超） 中断して再試行案内
内部例外 エラーログ記録、ユーザーには一般的メッセージ

⸻

7. テスト計画

単体テスト
• 画像入力（カメラ/ギャラリー）
• 矩形選択UI
• OpenCV補正処理
• TFLiteモデル推論（モックデータ使用）

結合テスト
• 前処理〜差分抽出〜UI表示のパイプライン
• 各設定（色/形/文字ON/OFF）の挙動確認

UI/UXテスト
• 子供ユーザビリティテスト（直感操作確認）
• 誤タップ対応（主要ボタンの最小タップ領域 48×48 をウィジェットテストで検証：`test/tap_target_min_size_test.dart`）

パフォーマンステスト
• 1280px画像2枚で5秒以内に完了（ユニットテストで担保: `test/performance_ssim_1280_test.dart`）
• メモリリーク監視

回帰テスト
• 既存バージョンとの比較（機能退行なし）

補足（実装済みの自動テスト例）
• 矩形スケーリング／NMS／入出力バリデーション（Dart単体）
• 比較画面UIの同座標適用ボタン挙動（ウィジェットテスト）
• 解像度超過時の自動リサイズ表示（ウィジェットテスト）
• モデル読込失敗時のエラーメッセージ表示（ウィジェットテスト）
• タイムアウト時の再試行案内メッセージ表示（ウィジェットテスト）
• 内部例外の一般メッセージ表示＋ローカルログ記録（ウィジェットテスト）
• 検出ゼロ件メッセージ表示（ウィジェットテスト）
• Dart/Flutter バージョン互換チェック（`test/sdk_compat_test.dart`）
• pubspec の SDK 制約抽出は二重引用・単一引用・無引用に対応（`test/sdk_compat_extract_test.dart`）
• ホーム→左右選択→比較画面までの一連のフロー（ウィジェットテスト）
• 画像入力（拡張子判定・最大解像度クランプ）の単体テスト
• 拡張子判定でファイル名の前後空白を許容するテスト（`test/input_format_whitespace_test.dart`）
• 範囲指定（左）→保存→比較画面に選択が反映されるフロー（`test/rect_select_apply_flow_test.dart`）
• CI ワークフロー内の署名付きリリースジョブ存在確認（`test/ci_release_job_test.dart`）
• CI ワークフロー内の解析/テスト/ビルドジョブ存在確認（`test/ci_analyze_build_jobs_test.dart`）
• Android CMake に OpenCV 検出/リンクの雛形が含まれることを検証（`test/opencv_android_cmake_test.dart`）
• Android の jniLibs に OpenCV のプリビルド .so を配置していることを検証（Web 側で存在検証: `src/opencv_android_jnilibs_test.ts`）
• iOS の Xcode プロジェクト（pbxproj）にネイティブ連携の下地（ブリッジングヘッダ、libc++、Frameworks フェーズ、iOS 13+）が整っていることを検証（Web 側で存在検証: `src/opencv_ios_pbxproj_test.ts`）
• Web プロトタイプ（React）でトップ画面の文言/ボタン存在テスト（Vitest + RTL, `src/TopScreen.test.tsx`）
• TFLite ランタイム導入を Web テストでも存在検証（`src/tflite_runtime_presence.test.ts` で Podfile/Gradle/models を確認）
• C++ ネイティブテスト雛形の存在を Web テストで検証（`src/native_cpp_tests_presence.test.ts`）
• C++ アルゴリズム骨子（ORB/SSIM/NMS）をファイル内容で検証（`src/native_algorithms_content.test.ts`）
• Android NDK 用 CMake にテストターゲット（add_executable）を定義し、Web テストで存在検証（`src/native_gtest_build_config.test.ts`）
• gtest 導入（CMake FetchContent・gtest_mainリンク・gtest用CPP雛形）をWeb テストで検証（`src/native_gtest_presence.test.ts`）
• gtest 数値検証（合成データ）を C++ に記述し、Web 側では内容検証（`src/native_gtest_numeric_content.test.ts`）
• OpenCV 実データ（PGM）資産を追加し、gtest 内で `cv::imread` を用いた検証を記述（Web 側では資産と記述の存在検証: `src/native_gtest_opencv_assets_content.test.ts`）

⸻

8. 除外機能（Ver1.2）
   • 結果保存（共有／ダウンロード）
   • SNS連携
   • Web版提供

⸻

9. 今後の拡張余地
   • オンデバイス強化学習（ユーザー補正フィードバック）
   • 結果保存（保護者ロック付き）
   • マルチデバイス連携（将来のWeb版統合）

補足（UI）
• 設定画面に「OSS ライセンス」リンクを追加（Materialの showLicensePage を使用して一覧表示）
• 設定画面に「プライバシーポリシー」リンクを追加（簡易ページ `PrivacyPolicyPage` を実装）
• 矩形選択画面に編集/拡大モード切替を実装（ウィジェットテストを追加し挙動を検証）
• 比較画面のハイライトにセマンティクスラベルを付与（VoiceOver/TalkBack で認識可能）
• 子供による操作テストの計画ドキュメントを整備（`diffapp/docs/ux_kids_test_plan.md`）。主要タスク・指標・倫理面・誤タップ/セマンティクス/音量を明記し、Web テストで存在検証（`src/ux_kids_usability_plan.test.ts`）。
• ストア提出準備の一環として、スクリーンショット撮影計画ドキュメントを作成（`diffapp/assets/screenshots/README.md`）。Vitest で存在・記述を検証（`src/screenshot_prep.test.ts`）。
• 主要ボタンに最小タップ領域 48x48 を適用し、Web テストで検証（`src/TopScreen.test.tsx`）。
• パフォーマンス予算（1280px・5秒以内）ドキュメントを追加（`diffapp/docs/perf_budget.md`）し、Web テストで存在検証（`src/perf_budget_doc.test.ts`）。

進捗注記（Ver1.2 現状）
• 画像処理パイプラインの Dart 実装（1280幅正規化、矩形スケーリング、SSIM、二値化、連結成分、NMS、上位20件、設定反映、モックCNN）は実装・テスト済み
• 傾き補正の相似変換/RANSAC とホモグラフィRANSAC（Dart雛形）は実装・テスト済み
• ネイティブ導入（OpenCV/TFLite の FFI 配線）は未着手のため、現状は Dart 実装へ自動フォールバック
• TFLite モデルアセットの配置準備（assets/models/）を追加し、存在検証の自動テストを作成（`test/model_asset_presence_test.dart`）
• スプラッシュ画面設定（Android/iOS）を整備し、Web/Dart テストで検証済み
• スプラッシュ画面（Android/iOS）設定を整備：Androidは `launch_background.xml` でアイコンを中央表示（`test/android_splash_config_test.dart`）、iOSは LaunchScreen.storyboard で `LaunchImage` を中央表示（`test/ios_splash_config_test.dart`）
• TFLite ランタイム導入の下準備を追加：Android Gradle へ `org.tensorflow:tensorflow-lite` を追加（`test/tflite_runtime_android_gradle_test.dart`）、iOS Podfile に `pod 'TensorFlowLiteSwift'` を追加（`test/tflite_runtime_ios_podfile_test.dart`）
• Dart からの TFLite 呼び出しスタブ `TfliteCnnNative` を追加し、`FfiCnnDetector` に注入してユニットテストを作成（`test/tflite_invoke_dart_test.dart`）
• 特徴点抽出の Dart 雛形（Harris + BRIEF）を追加し、検出・記述・単純マッチのユニットテストを作成（`lib/features.dart`, `test/features_harris_brief_test.dart`）
• CNN 検出の FFI スタブ注入構造を追加：`FfiCnnDetector` に `CnnNative` を注入可能にし、未接続時は `MockCnnDetector` にフォールバック（`test/ffi_cnn_detector_native_test.dart`）
• OSS ライセンス専用ページ `OssLicensesPage` を追加し、設定から遷移（`test/licenses_custom_page_test.dart`）
• Android NDK の CMake に OpenCV 連携（find_package/include/link）の雛形を追加し、Web 側でも存在検証（`src/opencv_ndk_config.test.ts`）
• iOS 向けの OpenCV CMake 雛形/README/ビルドスクリプトを追加し、Web 側でも存在検証（`src/opencv_ios_build_config.test.ts`）
• iOS 側 CMake に OpenCV の find_package/include/link を具体化し、Web 側でも内容検証（`src/opencv_ios_cmake_link_config.test.ts`）
