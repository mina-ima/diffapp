import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('TODO: ネイティブテスト（C++）の親項目完了チェック', () => {
  it('todo.md の「ネイティブテスト（C++）」が完了([x])になっている', () => {
    const t = readFileSync('todo.md', 'utf-8');
    const checked = /\- \[x\] ネイティブテスト（C\+\+）/.test(t);
    expect(checked).toBe(true);
  });
});
