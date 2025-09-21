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
});
