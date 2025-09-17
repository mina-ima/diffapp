import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('CI: analyze/test/build ジョブの存在検証', () => {
  const path = '.github/workflows/flutter-ci.yml';
  const t = readFileSync(path, 'utf-8');

  it('analyze_test ジョブが存在し、analyze/test を実行する', () => {
    expect(t).toContain('analyze_test:');
    expect(t).toMatch(/flutter analyze/);
    expect(t).toMatch(/flutter test --no-pub/);
  });

  it('build_android ジョブが存在し、必要なら flutter create を行い、APK をビルドする', () => {
    expect(t).toContain('build_android:');
    expect(t).toMatch(/flutter create --org dev\.minamidenshiimanaka \./);
    expect(t).toMatch(/flutter build apk --debug/);
    expect(t).toMatch(/actions\/upload-artifact@v4/);
  });

  it('build_ios ジョブが存在し、シミュレータ向けビルドを行う', () => {
    expect(t).toContain('build_ios:');
    expect(t).toMatch(/flutter build ios --simulator --no-codesign/);
    expect(t).toMatch(/actions\/upload-artifact@v4/);
  });
});
