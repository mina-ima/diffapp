import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('CI: native gtest job (Android NDK)', () => {
  const path = '.github/workflows/flutter-ci.yml';
  const t = readFileSync(path, 'utf-8');

  it('native_gtest ジョブが定義されている', () => {
    expect(t).toContain('native_gtest:');
    expect(t).toContain('Build native gtest (Android NDK)');
  });

  it('setup-ndk アクションを使用している', () => {
    expect(t).toContain('nttld/setup-ndk@v1');
    expect(t).toContain('ndk-version: r26d');
  });

  it('CMake の Android ツールチェーン設定とビルドが含まれる', () => {
    expect(t).toMatch(/cmake -S diffapp\/android\/app\/src\/main\/cpp -B build-native/);
    expect(t).toContain(
      '-DCMAKE_TOOLCHAIN_FILE=${{ steps.setup-ndk.outputs.ndk-path }}/build/cmake/android.toolchain.cmake',
    );
    expect(t).toContain('cmake --build build-native');
  });
});
