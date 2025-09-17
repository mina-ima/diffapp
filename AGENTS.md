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
