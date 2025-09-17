import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('NDKビルド: C++テストターゲットのCMake定義', () => {
  const cmakePath = 'diffapp/android/app/src/main/cpp/CMakeLists.txt';
  const read = () => readFileSync(cmakePath, 'utf-8');

  it('CMake にテスト用 add_executable が定義されている', () => {
    const t = read();
    expect(t.includes('add_executable(orb_sift_matching_test')).toBe(true);
    expect(t.includes('tests/orb_sift_matching_test.cpp')).toBe(true);
    expect(t.includes('add_executable(ssim_numeric_test')).toBe(true);
    expect(t.includes('tests/ssim_numeric_test.cpp')).toBe(true);
    expect(t.includes('add_executable(nms_dedup_test')).toBe(true);
    expect(t.includes('tests/nms_dedup_test.cpp')).toBe(true);
  });
});
