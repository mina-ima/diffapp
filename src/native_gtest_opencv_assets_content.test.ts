import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';

describe('gtest: OpenCV 実データ（PGM）を使った検証の内容', () => {
  const base = 'diffapp/android/app/src/main/cpp/tests';
  const left = `${base}/assets/left.pgm`;
  const right = `${base}/assets/right.pgm`;

  it('PGM資産が存在する（left/right）', () => {
    expect(existsSync(left)).toBe(true);
    expect(existsSync(right)).toBe(true);
  });

  it('ORB gtest に imread で資産を読み込むテストがある', () => {
    const t = readFileSync(`${base}/orb_sift_matching_gtest.cpp`, 'utf-8');
    expect(t).toMatch(/cv::imread\(/);
    expect(t).toContain('assets/left.pgm');
    expect(t).toContain('assets/right.pgm');
    expect(t).toMatch(/TEST\(OrbSiftMatching,\s*AssetsFindsCorrespondences\)/);
  });

  it('SSIM gtest に imread で資産を読み込むテストがある', () => {
    const t = readFileSync(`${base}/ssim_numeric_gtest.cpp`, 'utf-8');
    expect(t).toMatch(/cv::imread\(/);
    expect(t).toContain('assets/left.pgm');
    expect(t).toContain('assets/right.pgm');
    expect(t).toMatch(/TEST\(SsimNumeric,\s*AssetsSsimAboveThreshold\)/);
  });
});
