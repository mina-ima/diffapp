# Diffapp Ver1.2 
## 0. プロジェクト初期化

- [x] Flutter SDK バージョンを決定（例: 3.22.0）
  - [x] Dart SDK バージョン互換性を確認（自動テスト `test/sdk_compat_test.dart` を追加）
  - [ ] fvm をインストール
  - [x] fvm で Flutter バージョンを pin（3.22.0）
  - [x] `.fvm/flutter_sdk` を `.gitignore` に追加
- [x] 新規 Flutter プロジェクト作成（最小構成）
  - [x] `lib/main.dart` を追加
  - [x] `pubspec.yaml` に description を追加済み（organization は後追い）
  - [ ] iOS/Android フォルダ作成（ローカルでは `flutter create .` を実行）
  - [x] CI 側で `flutter create .` を自動実行してビルド可能にした
- [x] iOS の Bundle Identifier を設定（既定: dev.minamidenshiimanaka.diffapp。CIで自動生成）
- [x] Android の applicationId を設定（既定: dev.minamidenshiimanaka.diffapp。CIで自動生成）
- [x] `flutter_lints` を追加し lint を CI に組込（`analysis_options.yaml` 設定済み）
- [x] README にセットアップ手順を記載
- [ ] GitHub Actions で CI（lint / test / build）を設定
  - [x] analyze（lint）実行を追加
  - [x] test 実行を追加
  - [x] build 実行を追加（Android debug／プラットフォームが無ければ CI が `flutter create --org dev.minamidenshiimanaka .` 実行）
  - [x] iOS シミュレータ用ビルド（no codesign）を追加（macOS ランナー）
  - [ ] 署名付き iOS/Android リリースビルドを追加

---

## 1. 権限設定

- [ ] Android Manifest の権限確認
  - [ ] INTERNET 権限が入っていないことを確認
  - [ ] CAMERA, READ_MEDIA_IMAGES を追加
  - [ ] Android 9〜12 の場合 READ_EXTERNAL_STORAGE を許可
- [ ] iOS Info.plist に権限文言追加
  - [ ] NSCameraUsageDescription
  - [ ] NSPhotoLibraryUsageDescription
- [ ] 拒否時のリカバリ導線（設定アプリへの遷移）を実装

---

## 2. ネイティブライブラリ導入

- [ ] OpenCV ビルド
  - [ ] iOS 用に CMake ビルド → .framework / .a 生成
  - [ ] Android 用に CMake ビルド → .so 生成（arm64-v8a / armeabi-v7a）
  - [ ] Xcode プロジェクトに組込
  - [ ] Android Studio jniLibs に配置
- [ ] TFLite ランタイム導入
  - [ ] iOS Podfile に追加
  - [ ] Android Gradle に追加
  - [ ] モデルを assets/models に配置
- [ ] Dart ↔ C++ FFI 実装
  - [ ] OpenCV サンプル関数を Dart から呼び出す
  - [ ] TFLite 推論を Dart から呼び出す

---

## 3. 画像処理パイプライン

- [ ] 入力画像受取（カメラ / ギャラリー）
  - [x] jpg/png のみ受け入れる
  - [x] 4000×3000px 超はリサイズ
- [ ] 傾き補正
  - [ ] ORB/SIFT 特徴点抽出
  - [ ] RANSAC でホモグラフィ推定
- [ ] サイズ統一
  - [x] 幅 1280px に縮小（Dartロジックとテスト済み）
  - [x] 寸法計算ロジック（Dart）を実装（`lib/image_pipeline.dart`）
- [ ] 矩形トリミング
  - [x] 左画像で選択した矩形を右画像に適用（UIの「同座標適用」ボタン）
  - [x] 画像寸法が異なる場合のスケーリング同期（1280幅へ正規化し比率適用）
  - [x] 縮小後画像に対する矩形スケーリング（Dartロジック）を実装（`scaleRectForResizedImage`）
- [ ] 色調整
  - [x] 自動コントラスト調整を実装（任意 ON/OFF）
- [ ] 差分抽出
  - [ ] SSIM スコアマップ生成
  - [ ] スコアマップを正規化
  - [ ] 二値化 & 連結成分解析
- [ ] CNN 推論
  - [ ] モデルをロード
  - [ ] 特徴抽出を行う
  - [ ] 検出カテゴリ（色/形/場所/大きさ/文字）を判定
- [ ] NMS & 上位制限
  - [x] 重複枠を除外（Dartロジック `nonMaxSuppression`）
  - [x] スコア順で上位 20 件を採用（`maxOutputs` で制限）

---

## 4. UI 実装

- [ ] トップ画面
  - [x] ロゴ＋キャッチコピー表示
  - [x] 左画像ボタン（ダミー選択に遷移）
  - [x] 右画像ボタン（ダミー選択に遷移）
  - [x] 「けんさをはじめる」ボタン（比較画面に遷移）
  - [x] 歯車アイコン（設定画面遷移）
- [ ] 画像選択画面
  - [x] カメラ起動（ダミー）
  - [x] ギャラリー選択（ダミー）
- [ ] 矩形選択画面
  - [x] 拡大表示（InteractiveViewer、編集モード切替）
  - [x] ドラッグで矩形移動（ダミー矩形の描画）
  - [x] リサイズ可能（四隅・辺ハンドル）
- [ ] 結果画面
  - [x] 左右並列表示（プレースホルダ）
  - [x] 赤枠ハイライト（ポヨンアニメ）
  - [x] 効果音再生
  - [x] スクショ案内テキスト表示
  - [x] 再比較ボタン

---

## 5. 設定画面

- [x] チェックボックスを表示（色/形/ばしょ/おおきさ/もじ）
- [x] 精度スライダーを表示（1〜5 段階、既定3）
- [x] 初期値：全 ON、普通精度で表示
- [x] 設定を保持（セッション中のみ・画面間受け渡し）
- [x] 効果音 ON/OFF トグルを追加（検出開始/再比較の再生可否に反映）

---

## 6. エラーハンドリング

- [x] 入力画像未選択 → 「がぞうを えらんでね」
- [x] 解像度超過 → 自動リサイズ
- [x] モデル読込失敗 → 「けんさに しっぱいしました。もういちどためしてね」
- [x] 検出ゼロ件 → 「ちがいは みつかりませんでした」
- [x] タイムアウト → 再試行案内
- [x] 内部例外 → 一般メッセージ＋ローカルログ

---

## 7. テスト

- [ ] 単体テスト（Dart）
  - [ ] 画像入力関数
  - [x] 設定保持ロジック
  - [x] 上位 20 件制限処理
  - [x] 前処理（サイズ統一）の寸法計算テスト（`test/image_pipeline_test.dart`）
  - [x] 設定モデルのシリアライズ/バリデーション（`test/settings_test.dart`）
  - [x] 矩形スケーリングのテスト（`scaleRectForResizedImage`）
- [ ] ネイティブテスト（C++）
  - [ ] ORB/SIFT マッチング精度確認
  - [ ] SSIM 数値検証
  - [ ] NMS 重複除去テスト
- [ ] 結合テスト
  - [ ] 入力〜表示まで一連のフロー確認
  - [x] 設定が処理に反映されるか確認（効果音OFFで再生されない）
  - [x] 同座標適用ボタンで右に矩形が反映される（ComparePageのUIテスト）
- [ ] UI/UX テスト
  - [ ] 子供による操作テスト
  - [ ] 誤タップ耐性
  - [ ] VoiceOver / TalkBack 確認
- [ ] パフォーマンステスト
  - [ ] 1280px 入力で 5 秒以内
  - [ ] 低メモリ端末での安定性確認

---

## 8. ストア提出準備

- [ ] アイコン作成
- [ ] スプラッシュ画面設定
- [ ] プライバシーポリシー整備
- [ ] スクリーンショット準備
- [ ] OSS ライセンス一覧画面作成
