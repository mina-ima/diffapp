import { describe, it, expect } from 'vitest';
import { existsSync } from 'node:fs';
import { join } from 'node:path';

describe('Android: jniLibs に OpenCV の .so が配置されている', () => {
  const base = 'diffapp/android/app/src/main/jniLibs';
  it('ディレクトリが存在する（arm64-v8a / armeabi-v7a）', () => {
    expect(existsSync(base)).toBe(true);
    expect(existsSync(join(base, 'arm64-v8a'))).toBe(true);
    expect(existsSync(join(base, 'armeabi-v7a'))).toBe(true);
  });

  it('libopencv_java4.so が両ABIに存在する', () => {
    expect(existsSync(join(base, 'arm64-v8a', 'libopencv_java4.so'))).toBe(true);
    expect(existsSync(join(base, 'armeabi-v7a', 'libopencv_java4.so'))).toBe(true);
  });
});
