# Repository Guidelines

私がgoと指示したら
@prompt_spec.md と @todo.md を開く。
この指示に従って未完了なステップを１つずつ完了させる

やること:

1. まず失敗するテストを書く（Vitest + RTL）。
2. テストに合格するコードを実装する。
3. 実行: pnpm format && pnpm lint && pnpm typecheck && pnpm test
4. すべて合格したら: git commit -m "<分かりやすい日本語のメッセージ>"
5. prompt_spec.md と todo.md を更新する。
6. いったん停止して、続行可否を確認する。

日本語で分かりやすく答えること

---

Android/Flutter の動作確認フロー

- 目的: Android エミュレータ上で機能を手早く検証する。
- 実行コマンド（リポジトリ直下）
  - `pnpm android`
    - `scripts/run_android.sh` を呼び出し、FVM の `flutter` を優先して実行
    - 依存取得→エミュレータ起動→`lib/main.dart` 実行まで自動
- 事前準備
  - Android Studio の AVD（仮想デバイス）を1つ以上用意
  - FVM or Flutter 3.22.0 が動作していること（`fvm flutter doctor -v`）
- アプリ内での確認例（画像選択の回帰チェック）
  - ホームの「左 の画像を選ぶ」→「ギャラリーから選ぶ」→画像を1枚選択
  - 左カードにプレビュー画像と「ファイル名(横x縦)」が表示されること
  - 右も同様に選択し、プレビュー表示されること
  - キャンセル時は「キャンセルしました」のスナックバーが出ること
  - 未選択で「けんさをはじめる」を押すと警告スナックバーが出ること
- トラブルシュート
  - 権限系: Manifest に `READ_MEDIA_IMAGES`（API33+）/ `READ_EXTERNAL_STORAGE`（API32以下）あり。権限ダイアログは許可する。
  - FVM ロックファイル権限: `.../fvm/versions/3.22.0/bin/cache/lockfile` に権限問題が出たら、所有者を自分に変更する。
    - 例: `sudo chown -R $(whoami) ~/fvm/versions/3.22.0/bin/cache/lockfile`
  - 端末が見つからない: Android Studio > Device Manager で AVD を作成。`flutter emulators` で一覧確認。

補足（Dart 側テスト）

- Flutter/Dart の単体テスト: `cd diffapp && fvm flutter test -r compact`
- 静的解析: `cd diffapp && fvm flutter analyze`

---

開発の進め方（TDD → シミュレータ再起動＆動作確認 → コミット → ドキュメント更新）

- 前提:
  - 「シミュレータの再起動」はエージェント（私）が実施します。
  - 「動作確認（画面操作・結果確認）」は開発者（あなた）が Android シミュレータ上で手動で行います。
- 手順:
  1. 失敗するテストを書く
     - Web/CI/ドキュメント検証: Vitest（`pnpm test`）
     - Flutter機能/UI: Flutter テスト（`cd diffapp && fvm flutter test`）
  2. テストに合格する最小実装を行う
  3. 品質チェック一式を実行
     - ルート: `pnpm format && pnpm lint && pnpm typecheck && pnpm test`
     - Flutter: `cd diffapp && fvm flutter analyze && fvm flutter test -r compact`
  4. シミュレータ再起動（エージェントが実施） → 手動動作確認（あなたが実施）
     - 再起動（エージェント）: `adb -s <emulator-id> reboot` 実行 → `sys.boot_completed=1` まで待機
       - 端末ID確認: `cd diffapp && fvm flutter devices`（例: `emulator-5554`）
     - アプリ起動（あなた）: `pnpm android` で自動起動
       - 失敗時は `cd diffapp && fvm flutter run -d <emulator-id> --target lib/main.dart`
     - 画面で期待動作を目視確認（例: ギャラリー選択→ホームでプレビュー反映）
  5. コミット
     - メッセージは日本語で分かりやすく要点を含める
  6. ドキュメント更新
     - `prompt_spec.md` と `todo.md` を最新状態に反映
  7. いったん停止して、次工程へ進むか確認

備考:

- FVMやAVDの準備・起動方法は「Android/Flutter の動作確認フロー」を参照
- 実装→テスト→手動確認の順序は崩さない（回帰を防止）
