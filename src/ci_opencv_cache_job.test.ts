import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('CI: OpenCV Android SDK cache + configure', () => {
  const t = readFileSync('.github/workflows/flutter-ci.yml', 'utf-8');

  it('actions/cache を使って OpenCV SDK をキャッシュする', () => {
    expect(t).toContain('actions/cache@v4');
    expect(t).toContain('opencv-android-sdk');
    expect(t).toContain('opencv-android-4.8.0');
  });

  it('cache miss 時に OpenCV SDK をダウンロードして展開する', () => {
    expect(t).toContain('Download OpenCV Android SDK (if cache miss)');
    expect(t).toMatch(/curl -L -o opencv-android-sdk\.zip/);
    expect(t).toMatch(/unzip -q opencv-android-sdk\.zip/);
  });

  it('CMake に OpenCV_DIR を渡して必須化する', () => {
    expect(t).toMatch(
      /-DOpenCV_DIR=\$\{\{ github\.workspace \}\}\/opencv-android-sdk\/sdk\/native\/jni/,
    );
    expect(t).toContain('-DOPENCV_OPTIONAL=OFF');
  });
});
