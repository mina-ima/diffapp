import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('ComparePage の多段アラインメント', () => {
  it('複数パスの整列とホモグラフィ合成を行っている', () => {
    const source = readFileSync('diffapp/lib/screens/compare_page.dart', 'utf-8');
    expect(source).toMatch(/const\s+(?:int\s+)?_alignmentPasses\s*=\s*2/);
    expect(source).toMatch(/composeHomography\(/);
  });
});

describe('image_pipeline のホモグラフィ合成API', () => {
  it('相似変換をホモグラフィへ変換する関数を公開している', () => {
    const source = readFileSync('diffapp/lib/image_pipeline.dart', 'utf-8');
    expect(source).toMatch(/Homography\s+homographyFromSimilarity\(/);
    expect(source).toMatch(/Homography\s+composeHomography\(/);
  });
});
