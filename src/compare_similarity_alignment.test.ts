import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

const target = 'diffapp/lib/screens/compare_page.dart';

describe('ComparePage の位置合わせ強化', () => {
  it('相似変換ベースのフォールバックを実装している', () => {
    const source = readFileSync(target, 'utf-8');
    expect(source).toMatch(/estimateSimilarityTransformRansac\(/);
    expect(source).toMatch(/_estimateSimilarityHomography\(/);
    expect(source).toMatch(/composeHomography\(/);
    expect(source).toMatch(/homographyFromSimilarity\(/);
  });
});
