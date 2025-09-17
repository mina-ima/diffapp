import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';

describe('OpenCV iOS CMake ビルド雛形', () => {
  const base = 'diffapp/ios/opencv';
  it('CMakeLists.txt が存在し、framework/.a 生成に言及がある', () => {
    const p = `${base}/CMakeLists.txt`;
    expect(existsSync(p)).toBe(true);
    const t = readFileSync(p, 'utf-8');
    expect(t).toMatch(/project\(opencv_ios\)/);
    expect(t).toMatch(/add_library\(/);
    expect(t).toMatch(/STATIC|FRAMEWORK/);
  });

  it('README.md が存在し、.framework と .a の生成手順を記載', () => {
    const p = `${base}/README.md`;
    expect(existsSync(p)).toBe(true);
    const t = readFileSync(p, 'utf-8');
    expect(t).toContain('.framework');
    expect(t).toContain('.a');
    expect(t).toContain('CMake');
  });

  it('ビルドスクリプトの雛形がある（build_ios.sh）', () => {
    expect(existsSync(`${base}/build_ios.sh`)).toBe(true);
  });
});
