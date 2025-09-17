import { describe, it, expect } from 'vitest';
import { existsSync } from 'node:fs';
import { join } from 'node:path';

describe('ネイティブテスト（C++）雛形の存在検証', () => {
  const base = join('diffapp', 'android', 'app', 'src', 'main', 'cpp', 'tests');

  it('方針ドキュメントがある', () => {
    const doc = join('diffapp', 'native', 'README.md');
    expect(existsSync(doc)).toBe(true);
  });

  it('ORB/SIFT マッチング精度確認の雛形がある', () => {
    expect(existsSync(join(base, 'orb_sift_matching_test.cpp'))).toBe(true);
  });

  it('SSIM 数値検証の雛形がある', () => {
    expect(existsSync(join(base, 'ssim_numeric_test.cpp'))).toBe(true);
  });

  it('NMS 重複除去テストの雛形がある', () => {
    expect(existsSync(join(base, 'nms_dedup_test.cpp'))).toBe(true);
  });
});
