import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

describe('ネイティブライブラリ導入: TFLite ランタイム導入', () => {
  it('iOS Podfile に TensorFlowLiteSwift が含まれる', () => {
    const podfile = join('diffapp', 'ios', 'Podfile');
    expect(existsSync(podfile)).toBe(true);
    const text = readFileSync(podfile, 'utf-8');
    expect(text).toMatch(/pod\s+'TensorFlowLiteSwift'/);
  });

  it('Android Gradle に tensorflow-lite 依存が含まれる', () => {
    const gradlekts = join('diffapp', 'android', 'app', 'build.gradle.kts');
    expect(existsSync(gradlekts)).toBe(true);
    const text = readFileSync(gradlekts, 'utf-8');
    expect(text).toMatch(/org\.tensorflow:tensorflow-lite/);
  });

  it('モデルが assets/models に配置されている（.tflite）', () => {
    const modelsDir = join('diffapp', 'assets', 'models');
    expect(existsSync(modelsDir)).toBe(true);
    const files = readdirSync(modelsDir).filter((f) => f.endsWith('.tflite'));
    expect(files.length).toBeGreaterThan(0);
  });
});
