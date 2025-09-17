import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('TODO: スプラッシュ画面設定の完了チェック', () => {
  it('todo.md の「スプラッシュ画面設定」が完了済み([x])になっている', () => {
    const t = readFileSync('todo.md', 'utf-8');
    // チェック済みの表記を期待
    const checked = /\- \[x\] スプラッシュ画面設定/.test(t);
    expect(checked).toBe(true);
  });
});
