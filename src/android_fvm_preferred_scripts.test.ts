import { describe, it, expect } from 'vitest';
import pkg from '../package.json' assert { type: 'json' };

describe('Android 補助スクリプトは FVM を優先', () => {
  it('android:doctor は fvm flutter doctor -v を使う', () => {
    const s = pkg.scripts?.['android:doctor'] as string | undefined;
    expect(s, 'package.json に android:doctor が必要').toBeTruthy();
    // 例: "cd diffapp && fvm flutter doctor -v"
    expect(s!).toMatch(/fvm\s+flutter\s+doctor\s+-v/);
  });

  it('android:emulators は fvm flutter emulators/devices を使う', () => {
    const s = pkg.scripts?.['android:emulators'] as string | undefined;
    expect(s, 'package.json に android:emulators が必要').toBeTruthy();
    expect(s!).toMatch(/fvm\s+flutter\s+emulators/);
    expect(s!).toMatch(/fvm\s+flutter\s+devices/);
  });
});
