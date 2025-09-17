import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('CI: 署名付きリリースジョブの存在検証', () => {
  const path = '.github/workflows/flutter-ci.yml';
  const t = readFileSync(path, 'utf-8');

  it('Android リリース（署名付き）ジョブが存在し、署名アクションを使う', () => {
    expect(t).toContain('release_android_signed:');
    expect(t).toContain('Release Android (Signed AAB)');
    expect(t).toMatch(/flutter build appbundle --release/);
    expect(t).toMatch(/r0adkll\/sign-android-release@v1/);
    expect(t).toMatch(/app-release-signed-aab/);
    expect(t).toContain('diffapp/build/app/outputs/bundle/release/*.aab');
  });

  it('iOS リリース（署名付き）ジョブが存在し、IPA をビルドしてアーティファクト化', () => {
    expect(t).toContain('release_ios_signed:');
    expect(t).toContain('Release iOS (Signed IPA)');
    expect(t).toMatch(/flutter build ipa --release/);
    expect(t).toContain('diffapp/build/ios/ipa/*.ipa');
  });
});
