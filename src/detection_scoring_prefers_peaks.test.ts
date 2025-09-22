import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('検出スコアは「ピーク（最大値）」を優先して局所化する', () => {
  it('image_pipeline.dart に boxMaxScore が実装されている', () => {
    const t = readFileSync('diffapp/lib/image_pipeline.dart', 'utf-8');
    expect(t).toMatch(/double\s+boxMaxScore\(/);
    // 最大値を走査する実装の断片も確認（空白や改行は寛容に）
    expect(t).toMatch(/if\s*\(v\s*>\s*best\)\s*\{\s*best\s*=\s*v;\s*\}/s);
  });

  it('cnn_detection.dart でコンポーネントのスコアに boxMaxScore を使っている', () => {
    const t = readFileSync('diffapp/lib/cnn_detection.dart', 'utf-8');
    // 初回のスコア算出
    expect(t).toMatch(/scores\.add\(boxMaxScore\(diffMap,\s*width,\s*b\)\)/);
    // 二段目（補助検出のスコア再計算）
    expect(t).toMatch(/scores2\.add\(boxMaxScore\(diffMap,\s*width,\s*b\)\)/);
  });
});
