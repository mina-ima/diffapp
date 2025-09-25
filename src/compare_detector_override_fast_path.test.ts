import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

// ComparePageの検出プロセスはテスト用に差し替えた検出器でも重たい前処理を避け、
// 設定オブジェクトを速やかに渡す必要がある。
describe('ComparePageのカスタム検出器ショートカット', () => {
  it('detector差し替え時は早期にdetectFromDiffMapへsettingsを渡して終了する', () => {
    const source = readFileSync('diffapp/lib/screens/compare_page.dart', 'utf-8');

    expect(source).toMatch(/final\s+overrideDetector\s*=\s*widget\.detector;/);
    expect(source).toMatch(/if\s*\(overrideDetector\s*!?=\s*null\)/);
    expect(source).toMatch(/overrideDetector\.detectFromDiffMap\([^)]*settings:\s*_settings/s);
    expect(source).toMatch(/return\s+const\s+<IntRect>\[\]\s*;/);

    const fastPathIndex = source.indexOf('overrideDetector.detectFromDiffMap');
    const preparationIndex = source.indexOf('_leftPreparation ??=');
    expect(fastPathIndex).toBeGreaterThanOrEqual(0);
    expect(preparationIndex).toBeGreaterThanOrEqual(0);
    expect(fastPathIndex).toBeLessThan(preparationIndex);
  });
});
