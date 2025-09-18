import { describe, it, expect } from 'vitest';
import { readFileSync, existsSync } from 'node:fs';
import pkg from '../package.json' assert { type: 'json' };

describe('Android ログ採取スクリプト', () => {
  it('package.json に android:logs スクリプトがある', () => {
    const s = pkg.scripts?.['android:logs'] as string | undefined;
    expect(s, 'scripts.android:logs を定義してください').toBeTruthy();
    expect(s!).toMatch(/bash\s+scripts\/logcat_diffapp\.sh/);
  });

  it('scripts/logcat_diffapp.sh が存在し、flutter または Diffapp ログを grep している', () => {
    const p = 'scripts/logcat_diffapp.sh';
    expect(existsSync(p), 'scripts/logcat_diffapp.sh が必要').toBe(true);
    const t = readFileSync(p, 'utf-8');
    expect(t).toMatch(/adb\s+.*logcat/);
    expect(t).toMatch(/grep -E\s+\"flutter\|Diffapp\"/);
  });
});
