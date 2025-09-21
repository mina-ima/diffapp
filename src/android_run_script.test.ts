import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';
import pkg from '../package.json' assert { type: 'json' };

describe('Android 実行スクリプト run_android.sh', () => {
  it('package.json で `pnpm android` が scripts/run_android.sh を呼ぶ', () => {
    const script = pkg.scripts?.['android'] as string | undefined;
    expect(script, 'package.json に android スクリプトが必要').toBeTruthy();
    expect(script!).toMatch(/bash\s+scripts\/run_android\.sh$/);
  });

  it('スクリプトが存在し、シバンとFVM優先の記述がある', () => {
    const p = 'scripts/run_android.sh';
    expect(existsSync(p), 'scripts/run_android.sh が必要').toBe(true);
    const t = readFileSync(p, 'utf-8');
    expect(t.startsWith('#!/usr/bin/env bash')).toBe(true);
    // FVM を優先し、未インストール時は flutter をフォールバック
    expect(t).toMatch(/command -v fvm/);
    expect(t).toMatch(/FLUTTER_CMD=\(fvm flutter\)/);
    expect(t).toMatch(/FLUTTER_CMD=\(flutter\)/);
  });

  it('依存取得、エミュレータ/デバイス検出、main.dart 実行を含む', () => {
    const t = readFileSync('scripts/run_android.sh', 'utf-8');
    expect(t).toMatch(/pub get/);
    expect(t).toMatch(/flutter\s+emulators|\$\{FLUTTER_CMD\[@\]\}\" emulators/);
    expect(t).toMatch(/devices/);
    expect(t).toMatch(/--target\s+lib\/main\.dart/);
  });

  it('AVD 未作成時のエラーメッセージに「AVD」を正しく含む', () => {
    const t = readFileSync('scripts/run_android.sh', 'utf-8');
    // 「A VD」のような分割表記ではなく "AVD" と連続していることを要求
    expect(t).toMatch(/Androidエミュレーター\(AVD\)が見つかりません/);
  });

  it('任意の端末IDを引数で指定できる（第一引数を -d に渡す）', () => {
    const t = readFileSync('scripts/run_android.sh', 'utf-8');
    // 第一引数の受け取り
    expect(t).toMatch(/DEVICE_ID=\$\{1:-\}/);
    // -d "$CURRENT_DEVICE_ID" を RUN_ARGS に含める（存在確認後に使用）
    expect(t).toMatch(/RUN_ARGS\+\=\( -d \"\$CURRENT_DEVICE_ID\" \)/);
  });

  it('指定した端末IDが接続されていない場合は AVD を起動してから実行する', () => {
    const t = readFileSync('scripts/run_android.sh', 'utf-8');
    // 端末の存在確認（adb get-state）を行う
    expect(t).toMatch(/adb\s+-s\s+\"\$DEVICE_ID\"\s+get-state/);
    // 未接続なら CURRENT_DEVICE_ID を空にして起動フローにフォールバック
    expect(t).toMatch(/CURRENT_DEVICE_ID=\"\"/);
    // AVD 起動ロジック（flutter emulators --launch ...）が存在
    expect(t).toMatch(/emulators\s+--launch/);
  });
});
