import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('iOS: Xcode pbxproj のネイティブ連携下地', () => {
  const path = 'diffapp/ios/Runner.xcodeproj/project.pbxproj';
  const t = () => readFileSync(path, 'utf-8');

  it('Bridging Header が設定されている', () => {
    expect(t()).toMatch(/Runner-Bridging-Header\.h/);
    expect(t()).toMatch(/SWIFT_OBJC_BRIDGING_HEADER\s*=\s*"Runner\/Runner-Bridging-Header\.h"/);
  });

  it('libc++ が指定されている', () => {
    expect(t()).toMatch(/CLANG_CXX_LIBRARY\s*=\s*"libc\+\+"/);
  });

  it('Frameworks ビルドフェーズが存在する', () => {
    expect(t()).toMatch(/\/\* Frameworks \*\//);
    expect(t()).toMatch(/Embed Frameworks/);
  });

  it('iOS 13+ をターゲットとしている', () => {
    expect(t()).toMatch(/IPHONEOS_DEPLOYMENT_TARGET\s*=\s*13\.0/);
  });
});
