import { describe, it, expect } from 'vitest';
import { readFileSync, existsSync } from 'node:fs';

describe('gtest 導入の存在検証', () => {
  const cmake = 'diffapp/android/app/src/main/cpp/CMakeLists.txt';

  it('CMake に googletest の FetchContent 設定が含まれる', () => {
    const t = readFileSync(cmake, 'utf-8');
    expect(t).toContain('FetchContent_Declare(');
    expect(t).toContain('googletest');
    expect(t).toContain('FetchContent_MakeAvailable(googletest');
  });

  it('テストターゲットが gtest_main にリンクされる', () => {
    const t = readFileSync(cmake, 'utf-8');
    expect(t).toContain('target_link_libraries(orb_sift_matching_test gtest_main');
    expect(t).toContain('target_link_libraries(ssim_numeric_test gtest_main');
    expect(t).toContain('target_link_libraries(nms_dedup_test gtest_main');
  });

  it('gtest のCPP雛形が存在する', () => {
    const base = 'diffapp/android/app/src/main/cpp/tests';
    for (const f of [
      'orb_sift_matching_gtest.cpp',
      'ssim_numeric_gtest.cpp',
      'nms_dedup_gtest.cpp',
    ]) {
      expect(existsSync(`${base}/${f}`)).toBe(true);
    }
  });
});
