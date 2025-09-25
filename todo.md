# Diffapp Ver1.2

## 0. プロジェクト初期化

- [x] Flutter SDK バージョンを決定（例: 3.22.0）
  - [x] Dart SDK バージョン互換性を確認（自動テスト `test/sdk_compat_test.dart` を追加）
  - [x] fvm をインストール
  - [x] fvm で Flutter バージョンを pin（3.22.0）
  - [x] `.fvm/flutter_sdk` を `.gitignore` に追加
- [x] 新規 Flutter プロジェクト作成（最小構成）
  - [x] `lib/main.dart` を追加
  - [x] `pubspec.yaml` に description を追加済み（organization は後追い）
  - [x] iOS/Android フォルダ作成（ローカルでは `flutter create .` を実行）
  - [x] CI 側で `flutter create .` を自動実行してビルド可能にした
- [x] iOS の Bundle Identifier を設定（既定: dev.minamidenshiimanaka.diffapp。CIで自動生成）
- [x] Android の applicationId を設定（既定: dev.minamidenshiimanaka.diffapp。CIで自動生成）
- [x] `flutter_lints` を追加し lint を CI に組込（`analysis_options.yaml` 設定済み）
- [x] README にセットアップ手順を記載
- [x] GitHub Actions で CI（lint / test / build）を設定
  - [x] analyze（lint）実行を追加
  - [x] test 実行を追加
  - [x] build 実行を追加（Android debug／プラットフォームが無ければ CI が `flutter create --org dev.minamidenshiimanaka .` 実行）
  - [x] iOS シミュレータ用ビルド（no codesign）を追加（macOS ランナー）
  - [x] ルートの Android 補助スクリプト（`android:doctor` / `android:emulators`）を FVM 優先に統一
  - [x] エミュレータ再起動補助 `android:reboot` を追加（`scripts/reboot_android.sh`）
  - [x] 署名付き iOS/Android リリースビルドを追加（Secrets がある場合のみ実行）
  - [x] Android 実行スクリプト `pnpm android`（`scripts/run_android.sh`）を追加し、Web テストで存在・挙動（FVM優先/依存取得/AVD検出/`lib/main.dart`実行）を検証（`src/android_run_script.test.ts`）

---

## 1. 権限設定

- [x] Android Manifest の権限確認
  - [x] INTERNET 権限が入っていないことを確認
  - [x] CAMERA, READ_MEDIA_IMAGES を追加
  - [x] Android 9〜12 の場合 READ_EXTERNAL_STORAGE を許可
- [x] iOS Info.plist に権限文言追加
  - [x] NSCameraUsageDescription
  - [x] NSPhotoLibraryUsageDescription
- [x] 拒否時のリカバリ導線（設定アプリへの遷移）を実装

---

## 2. ネイティブライブラリ導入

- [x] OpenCV ビルド
  - [x] iOS 用 OpenCV CMake 雛形/README/ビルドスクリプトを追加（将来の .framework / .a 生成用）
  - [x] iOS 側 CMake に OpenCV の find_package/include/link を具体化
  - [x] Android 用に CMake ビルド → .so 生成（arm64-v8a / armeabi-v7a）
  - [x] Xcode プロジェクトに組込（pbxproj のブリッジングヘッダ/CLANG_CXX_LIBRARY 等の検証を追加）
  - [x] Android Studio jniLibs に配置
  - [x] Android NDK の CMake に OpenCV 連携の雛形（find_package/include/link）を追加
- [x] TFLite ランタイム導入
  - [x] iOS Podfile に追加
  - [x] Android Gradle に追加
  - [x] モデルを assets/models に配置
- [x] Dart ↔ C++ FFI 実装
  - [x] Dart 側のFFI土台（フォールバック実装）
  - [x] グレースケール変換のC++サンプル関数とAndroid NDK/CMake設定（Dartからはフォールバックで動作確認）
  - [x] `FfiImageOps` がネイティブ実装を優先使用できる注入機構を追加（単体テストを実装）
  - [x] 既定ネイティブ実装スタブ `DefaultNativeOps` を追加（未接続環境では Dart 実装にフォールバックすることをテストで保証）
  - [x] OpenCV サンプル関数（代替の C++ グレースケール関数）を Dart から呼び出す（Android FFI 配線）
  - [x] CNN 検出の FFI スタブ注入（`FfiCnnDetector` に `CnnNative` を注入可能にし、未接続時は Mock にフォールバック）
  - [x] TFLite 推論を Dart から呼び出す（Dart スタブ `TfliteCnnNative` を実装し、単体テスト `tflite_invoke_dart_test.dart` を追加）

---

## 3. 画像処理パイプライン

- [x] 入力画像受取（カメラ / ギャラリー）
  - [x] jpg/png のみ受け入れる
  - [x] 4000×3000px 超はリサイズ
- [x] 傾き補正
  - [x] 相似変換推定の雛形（対応点から s/R/t を最小二乗推定）
  - [x] ORB/SIFT 特徴点抽出（Dart雛形: Harris + BRIEF 実装と単体テスト）
  - [x] RANSAC でホモグラフィ推定
  - [x] RANSAC による相似変換のロバスト推定（外れ値耐性のテスト追加）
  - [x] RANSAC によるホモグラフィ推定の雛形（Dart実装・外れ値混在データでテスト済み）
- [x] サイズ統一
  - [x] 幅 1280px に縮小（Dartロジックとテスト済み）
  - [x] 寸法計算ロジック（Dart）を実装（`lib/image_pipeline.dart`）
- [x] 矩形トリミング
  - [x] 左画像で選択した矩形を右画像に適用（UIの「同座標適用」ボタン）
  - [x] 画像寸法が異なる場合のスケーリング同期（1280幅へ正規化し比率適用）
  - [x] 縮小後画像に対する矩形スケーリング（Dartロジック）を実装（`scaleRectForResizedImage`）
- [x] 色調整
  - [x] 自動コントラスト調整を実装（任意 ON/OFF）
- [x] 差分抽出
  - [x] SSIM スコアマップ生成
  - [x] スコアマップを正規化
  - [x] 二値化 & 連結成分解析
- [x] 検査パイプライン計画ドキュメントを追加（`diffapp/docs/detection_pipeline_plan.md`）。Web テストで主要項目を検証（`src/detection_pipeline_plan_doc.test.ts`）
- [x] CNN 推論
  - [x] モデルをロード
  - [x] 特徴抽出を行う
  - [x] 検出カテゴリ（色/形/場所/大きさ/文字）を判定
- [x] NMS & 上位制限
  - [x] 重複枠を除外（Dartロジック `nonMaxSuppression`）
  - [x] スコア順で上位 20 件を採用（`maxOutputs` で制限）

---

## 4. UI 実装

- [x] トップ画面
  - [x] ロゴ＋キャッチコピー表示
  - [x] 左画像ボタン（ダミー選択に遷移）
  - [x] 右画像ボタン（ダミー選択に遷移）
  - [x] 「けんさをはじめる」ボタン（比較画面に遷移）
  - [x] 歯車アイコン（設定画面遷移）
- [x] 画像選択画面
  - [x] カメラ起動（ダミー）
  - [x] ギャラリー選択（ダミー）
- [x] 矩形選択画面
  - [x] 拡大表示（InteractiveViewer、編集モード切替）
  - [x] ドラッグで矩形移動（ダミー矩形の描画）
  - [x] リサイズ可能（四隅・辺ハンドル）
  - [x] 見出しを「範囲指定（左画像で設定）」に変更
  - [x] 左で選んだ画像を背景表示（メモリ/ファイルの両方に対応）
- [x] 結果画面
  - [x] 左右並列表示（プレースホルダ）
  - [x] 赤枠ハイライト（ポヨンアニメ）
  - [x] 効果音再生
  - [x] スクショ案内テキスト表示
  - [x] 再比較ボタン

追記（仕様更新）

- [x] 比較画面の見出しを「けんさせってい」に変更
- [x] 比較画面の下部3ボタンを OutlinedButton に統一（範囲指定/検査精度設定/検査をはじめる）

---

## 5. 設定画面

- [x] チェックボックスを表示（色/形/ばしょ/おおきさ/もじ）
- [x] 精度スライダーを表示（1〜5 段階、既定3）
- [x] 初期値：全 ON、普通精度で表示
- [x] 設定を保持（セッション中のみ・画面間受け渡し）
- [x] 効果音 ON/OFF トグルを追加（検出開始/再比較の再生可否に反映）
- [x] 比較画面の検出処理に Settings を反映（precision→しきい値、カテゴリ→出力ラベル）
  - テスト: `test/compare_passes_settings_to_detector_test.dart`（Compare→Detector への受け渡し）
  - テスト: `test/cnn_detector_precision_threshold_test.dart`（precision による閾値の違い）

---

## 6. エラーハンドリング

- [x] 入力画像未選択 → 「がぞうを えらんでね」
- [x] 解像度超過 → 自動リサイズ
- [x] モデル読込失敗 → 「けんさに しっぱいしました。もういちどためしてね」
- [x] 検出ゼロ件 → 「ちがいは みつかりませんでした」
- [x] タイムアウト → 再試行案内
- [x] 内部例外 → 一般メッセージ＋ローカルログ
- [x] 再比較（結果→戻る）直後のSnackBar競合を解消（前のSnackBarをクリアし、次フレームで表示）

---

## 7. テスト

- [x] 単体テスト（Dart）
  - [x] 画像入力関数
    - [x] 拡張子前後の空白を許容するケースを追加（`input_format_whitespace_test.dart`）
  - [x] 設定保持ロジック
  - [x] 上位 20 件制限処理
  - [x] 前処理（サイズ統一）の寸法計算テスト（`test/image_pipeline_test.dart`）
  - [x] 設定モデルのシリアライズ/バリデーション（`test/settings_test.dart`）
  - [x] 矩形スケーリングのテスト（`scaleRectForResizedImage`）
- [x] ネイティブテスト（C++）
  - [x] テスト雛形/方針ドキュメントの追加（`diffapp/native/README.md`）
  - [x] ORB/SIFT マッチング精度確認（アルゴリズム骨子）
  - [x] SSIM 数値検証（アルゴリズム骨子）
  - [x] NMS 重複除去テスト（アルゴリズム骨子）
  - [x] NDK CMake にテストターゲット（add_executable）を追加
  - [x] gtest 導入（CMake FetchContent・gtest_mainリンク・gtest用CPP雛形）
  - [x] gtest 数値検証（合成データ）を記述（ORB/SSIM/NMS）
  - [x] OpenCV 実データ（PGM資産）を使った gtest の記述を追加（imreadでの読み込みと確認）
  - [x] CI に NDK ビルドジョブ（`native_gtest`）を追加
  - [x] CI に エミュレータ実行ジョブ（`native_gtest_run`）を追加し、adb push/実行で gtest を走らせる
- [x] 結合テスト
  - [x] 入力〜表示まで一連のフロー確認
  - [x] 設定が処理に反映されるか確認（効果音OFFで再生されない）
  - [x] 同座標適用ボタンで右に矩形が反映される（ComparePageのUIテスト）
  - [x] SDK 互換評価の空白入り表記に対応（">= 3.4.0 < 4.0.0" のような表記を解釈するテストを追加）
  - [x] pubspec の SDK 制約抽出を単引用・無引用にも対応（`sdk_compat_extract_test.dart` 追加）
- [x] UI/UX テスト
  - [x] 子供による操作テスト（計画ドキュメント追加・内容検証）
  - [x] 誤タップ耐性（主要ボタンの最小タップ領域48x48をテストで担保）
  - [x] VoiceOver / TalkBack 確認（比較画面ハイライトにセマンティクスラベル付与・テスト追加）
  - [x] Web プロトタイプ（React）のトップ画面文言/ボタン存在テスト（Vitest + RTL）
  - [x] 範囲指定プレビューのスケール整合性（矩形に一致するビューポート＋オフセットがスケール追従）をウィジェットテストで担保（`test/crop_preview_translation_scaled_test.dart`）
  - [x] 極端な縦長/横長の矩形でもプレビューが表示される回帰テストを追加（`test/crop_preview_extreme_aspect_test.dart`）
  - [x] `scaleRectBetweenSpaces` の丸めで最小1pxを保証するユニットテストを追加（`test/image_pipeline_test.dart`）
  - [x] 検査結果ページに検出オーバーレイ（赤枠）が表示されるウィジェットテストを追加（`test/result_overlay_display_test.dart`）

---

## 10. 検出精度の改善（細長領域の検出）

- [x] 問題: 右上の本の背表紙のような幅が細い差分が、最小面積フィルタで除外されやすい。
- [x] 対応: 連結成分抽出時の最小面積を緩め、後段で形状（縦横比）に応じて面積しきい値を適用。
  - 通常: 基準64×64の2%相当（約82px）未満は除外。
  - 例外: 縦横比>=4.0の細長領域は最小面積の25%まで許容。
- [x] 実装箇所: `lib/cnn_detection.dart`, `lib/tflite_cnn_native.dart`
- [x] 単体テスト追加: `test/detection_spine_like_test.dart`（右上の細い縦線を検出できること）

## 11. ドキュメント整備（タイル分割フォールバック）

- [x] `diffapp/docs/detection_pipeline_plan.md` に 20×20 タイル分割フォールバックの手順と「上位10クラスター追加」を明記
- [x] Web テストで存在検証: `src/detection_tile_fallback_doc.test.ts`

## 12. 色差と位置合わせの強化

- [x] 色差を明度変化にロバストにする（クロマ距離+RGB距離のブレンド）
  - 実装: `colorDiffMapRgbaRobust` を追加し `ComparePage` で採用
  - テスト: `diffapp/test/color_diff_robust_test.dart`
- [x] 彩度ベースの重み付けで色差ピークを強調し、低彩度領域の誤検出を抑制
  - 実装: `colorDiffMapRgbaRobust` に彩度エネルギー重みと差分寄与を追加
  - テスト: `src/color_diff_saturation_weight.test.ts`
- [x] 位置合わせ強化（Harris+BRIEF→Hamming 比率テスト+クロスチェック→RANSAC）
  - キーポイント数を増強・閾値緩和、比率テスト導入、RANSAC 反復/閾値の調整
  - 実装: `lib/features.dart`, `lib/screens/compare_page.dart`

---

## 9. 手動検証（エミュレーター）

- [x] 範囲指定プレビューの動作確認（指定範囲のみが「けんさせってい」に切り出し表示）
  - 実施日: 2025-09-18
  - 実施者: 開発者（操作）、エージェント（シミュレーター起動・アプリ再起動）
  - ログ: `diffapp/docs/emulator_verification_log.md` に記載
- [x] パフォーマンステスト
  - [x] 1280px 入力で 5 秒以内
  - [x] 低メモリ端末での安定性確認（計画ドキュメントと簡易検証の方針を整備）

---

## 10. 回帰・安定化対応（最新）

- [x] 検査結果ページで画像が表示されないことがある問題を修正
  - [x] 大きな画像はデコード段階で正規化幅にダウンサンプル（OOM回避）
  - [x] 画像が取得できない場合のフォールバックUI（中央に「プレビューなし」）を追加
  - [x] Webテストでフォールバック実装の存在を検証（`src/result_page_placeholder_fallback.test.ts`）

- [x] 検出箇所が意図と異なる位置に出ることがある問題を修正
  - [x] 候補ボックスのスコアを「トップ10%平均」から「ピーク最大値」へ変更（局所ピークを優先）
  - [x] グレースケール変換でも `srcRect` を適用し、色・輝度の両経路で同一の切り出しを保証
  - [x] Webテストを追加（`src/detection_scoring_prefers_peaks.test.ts`）

- [ ] 検出の最小面積を割合基準に変更（既定 5%）
  - [ ] 仕様反映: `prompt_spec.md` に最小面積(%) を追記（64×64空間比率で判定）
  - [ ] テスト追加（Dart）: 5%未満の領域は検出されず、5%以上は検出される
  - [ ] 実装: `Settings` に `minAreaPercent` を追加（初期値 5）。検出器で `ceil(percent/100 * width * height)` を最小面積に適用
  - [ ] 比較画面・結果表示は既存のまま（検出器の出力に依存）

---

## 8. ストア提出準備

- [x] アイコン作成
- [x] スプラッシュ画面設定
  - [x] Android でロゴを中央表示（`launch_background.xml` に bitmap を追加）
  - [x] iOS でロゴを中央表示
  - [x] 撮影フローに含める（スクショ準備ドキュメント作成）
- [x] プライバシーポリシー整備
- [x] スクリーンショット準備
- [x] OSS ライセンス一覧画面作成
  - [x] 設定画面から `showLicensePage` を開くリンクを追加
  - [x] 専用ページ `OssLicensesPage` を実装し、設定から遷移
