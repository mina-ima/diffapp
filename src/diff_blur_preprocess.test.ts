import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('SSIM の前にグレースケールへ軽いブラーを適用して微小ズレのノイズを抑制する', () => {
  it('image_pipeline.dart に boxBlurU8 実装がある', () => {
    const t = readFileSync('diffapp/lib/image_pipeline.dart', 'utf-8');
    expect(t).toMatch(/List<int>\s+boxBlurU8\(/);
  });

  it('compare_page.dart で SSIM 計算前に boxBlurU8 を適用している', () => {
    const t = readFileSync('diffapp/lib/screens/compare_page.dart', 'utf-8');
    expect(t).toMatch(/final\s+blurL\s*=\s*boxBlurU8\(/);
    expect(t).toMatch(/final\s+blurR\s*=\s*boxBlurU8\(/);
    expect(t).toMatch(/computeSsimMapUint8\(blurL,\s*blurR,/);
  });
});
