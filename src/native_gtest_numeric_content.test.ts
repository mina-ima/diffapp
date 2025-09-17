import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

const read = (p: string) => readFileSync(p, 'utf-8');

describe('gtest 数値検証（合成データ）内容チェック', () => {
  it('SSIM: 同一入力で ~1.0 を検証するテストがある', () => {
    const t = read('diffapp/android/app/src/main/cpp/tests/ssim_numeric_gtest.cpp');
    expect(t).toMatch(/TEST\(SsimNumeric,\s*IdenticalIsOne\)/);
    expect(t).toMatch(/EXPECT_NEAR\(/);
    expect(t).toMatch(/ssimGrayU8\s*\(/);
  });

  it('NMS: IoU で抑制されることを検証するテストがある', () => {
    const t = read('diffapp/android/app/src/main/cpp/tests/nms_dedup_gtest.cpp');
    expect(t).toMatch(/TEST\(NmsDedup,\s*SuppressByIoU\)/);
    expect(t).toMatch(/nonMaxSuppressionRect\s*\(/);
    expect(t).toMatch(/EXPECT_EQ\(/);
  });

  it('ORB: 対応点が一定数以上見つかることを検証するテストがある', () => {
    const t = read('diffapp/android/app/src/main/cpp/tests/orb_sift_matching_gtest.cpp');
    expect(t).toMatch(/TEST\(OrbSiftMatching,\s*FindsCorrespondences\)/);
    expect(t).toMatch(/matchFeaturesORB\s*\(/);
    expect(t).toMatch(/EXPECT_GE\(/);
  });
});
