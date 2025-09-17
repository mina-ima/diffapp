import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

describe('ストア提出準備: スクリーンショット準備', () => {
  const dir = join('diffapp', 'assets', 'screenshots');
  const readme = join(dir, 'README.md');

  it('screenshots ディレクトリが存在する', () => {
    expect(existsSync(dir)).toBe(true);
  });

  it('README.md に撮影対象のシーンが定義されている', () => {
    expect(existsSync(readme)).toBe(true);
    const text = readFileSync(readme, 'utf-8');
    // 最低限、主要6画面の記載をチェック
    const required = [
      'トップ画面',
      '画像選択',
      '範囲指定',
      '比較結果',
      '設定画面',
      'スプラッシュ画面',
    ];
    for (const keyword of required) {
      expect(text).toContain(keyword);
    }
  });
});
