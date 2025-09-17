import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('CI: native gtest emulator run job', () => {
  const t = readFileSync('.github/workflows/flutter-ci.yml', 'utf-8');

  it('native_gtest_run ジョブが定義されている', () => {
    expect(t).toContain('native_gtest_run:');
    expect(t).toContain('Run native gtest on Android Emulator');
  });

  it('android-emulator-runner を使用している', () => {
    expect(t).toContain('reactivecircus/android-emulator-runner@v2');
    expect(t).toMatch(/api-level:\s*30/);
    expect(t).toMatch(/arch:\s*x86_64/);
  });

  it('adb で push/実行するスクリプトが含まれる', () => {
    expect(t).toContain('adb push');
    expect(t).toContain('adb shell chmod +x');
    expect(t).toContain('adb shell /data/local/tmp');
  });
});
