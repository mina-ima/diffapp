import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('iOS OpenCV CMake: find_package/link 設定', () => {
  const cmake = 'diffapp/ios/opencv/CMakeLists.txt';
  const t = () => readFileSync(cmake, 'utf-8');

  it('find_package(OpenCV REQUIRED ...) が記載されている', () => {
    expect(t()).toMatch(/find_package\(OpenCV REQUIRED/);
  });

  it('include_directories(${OpenCV_INCLUDE_DIRS}) が記載されている', () => {
    expect(t()).toContain('include_directories(${OpenCV_INCLUDE_DIRS})');
  });

  it('target_link_libraries(opencv_ios ${OpenCV_LIBS}) が記載されている', () => {
    expect(t()).toContain('target_link_libraries(opencv_ios ${OpenCV_LIBS})');
  });
});
