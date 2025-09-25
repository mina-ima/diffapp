import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('MockCnnDetector の重複抑制とスコア再評価', () => {
  it('refine 後にテール平均ベースの再スコアリングと追加NMSを行っている', () => {
    const source = readFileSync('diffapp/lib/cnn_detection.dart', 'utf-8');
    expect(source).toMatch(/_refineScoreTailMean\(/);
    expect(source).toMatch(/_runNms\(/);
    expect(source).toMatch(/secondPassIndices/);
    expect(source).toMatch(/remainingSlots/);
    expect(source).toMatch(/localMaxima2d\(/);
  });
});
