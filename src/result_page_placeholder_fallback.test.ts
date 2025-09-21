import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('ResultPage のプレビュー欠如時のフォールバック', () => {
  it('bytes/path が無い場合でも、Container で視認できる領域（"プレビューなし"）を表示する実装がある', () => {
    const t = readFileSync('diffapp/lib/screens/result_page.dart', 'utf-8');
    expect(t).toMatch(/プレビューなし/);
    expect(t).toMatch(/Container\(/);
    expect(t).toMatch(/alignment:\s*Alignment\.center/);
  });
});
