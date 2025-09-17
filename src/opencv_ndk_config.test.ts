import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('OpenCV（Android NDK）連携のCMake雛形', () => {
  const cmake = 'diffapp/android/app/src/main/cpp/CMakeLists.txt';
  const t = () => readFileSync(cmake, 'utf-8');

  it('find_package(OpenCV ...) と include_directories が定義されている', () => {
    const s = t();
    expect(s.includes('find_package(OpenCV')).toBe(true);
    expect(s.includes('include_directories(${OpenCV_INCLUDE_DIRS})')).toBe(true);
  });

  it('native-lib が ${OpenCV_LIBS} へリンクされている', () => {
    const s = t();
    expect(s.includes('target_link_libraries(native-lib ${OpenCV_LIBS}')).toBe(true);
  });

  it('アルゴリズムテスト実行可能ファイルも ${OpenCV_LIBS} へリンクされている', () => {
    const s = t();
    expect(
      s.includes('target_link_libraries(orb_sift_matching_test gtest_main ${OpenCV_LIBS}'),
    ).toBe(true);
    expect(s.includes('target_link_libraries(ssim_numeric_test gtest_main ${OpenCV_LIBS}')).toBe(
      true,
    );
    expect(s.includes('target_link_libraries(nms_dedup_test gtest_main ${OpenCV_LIBS}')).toBe(true);
  });
});
