import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('ComparePage の位置合わせ強化', () => {
  it('BRIEFマッチングのレシオ検査とRANSACしきい値を厳格化している', () => {
    const source = readFileSync('diffapp/lib/screens/compare_page.dart', 'utf-8');
    expect(source).toMatch(/matchDescriptorsHammingRatioCross\([\s\S]*?ratio:\s*0\.76/);
    expect(source).toMatch(/estimateHomographyRansac\([\s\S]*?inlierThreshold:\s*1\.1/);
    expect(source).toMatch(/estimateHomographyRansac\([\s\S]*?minInliers:\s*20/);
  });

  it('解析解像度256とアラインメント用サイズの定数を持つ', () => {
    const source = readFileSync('diffapp/lib/screens/compare_page.dart', 'utf-8');
    expect(source).toMatch(/const\s+int\s+_analysisSize\s*=\s*256/);
    expect(source).toMatch(/const\s+int\s+_alignmentSize\s*=\s*384/);
  });
});

describe('差分検出の微小領域抑制', () => {
  it('最小ボックス寸法をminArea%に基づきsqrtスケールで底上げしている', () => {
    const source = readFileSync('diffapp/lib/cnn_detection.dart', 'utf-8');
    expect(source).toMatch(/final\s+minCoreSideRaw\s*=\s*math\.sqrt\(minAreaPx\)\.ceil\(\);/);
    expect(source).toMatch(
      /final\s+minCoreSide\s*=\s*minCoreSideRaw\s*>\s*0[\s\S]*math\.max\(1,\s*math\.min\(minCoreSideLimit,\s*minCoreSideRaw\)\)/,
    );
    expect(source).toMatch(/expandClampBox\(b,\s*3,\s*minCoreSide,\s*width,\s*height\)/);
  });
});
