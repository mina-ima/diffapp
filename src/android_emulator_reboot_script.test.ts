import { describe, it, expect } from 'vitest';
import { readFileSync, existsSync } from 'node:fs';
import pkg from '../package.json' assert { type: 'json' };

describe('Android エミュレータ再起動スクリプト', () => {
  it('package.json に android:reboot スクリプトが定義されている', () => {
    const s = pkg.scripts?.['android:reboot'] as string | undefined;
    expect(s, 'package.json の scripts.android:reboot が必要').toBeTruthy();
    expect(s!).toMatch(/bash\s+scripts\/reboot_android\.sh/);
  });

  it('scripts/reboot_android.sh が存在し、adb で再起動＋boot完了待機を行う', () => {
    const path = 'scripts/reboot_android.sh';
    expect(existsSync(path), 'reboot_android.sh が存在すること').toBe(true);
    const t = readFileSync(path, 'utf-8');
    expect(t).toMatch(/adb\s+-s\s+\$\{?DEVICE_ID\}?\s+reboot/);
    expect(t).toMatch(/getprop\s+sys\.boot_completed/);
  });
});
