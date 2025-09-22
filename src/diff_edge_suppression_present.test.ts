import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('エッジ共通部位の抑制で誤検出を下げる', () => {
  it('compare_page.dart に edgeSuppression の計算と適用がある', () => {
    const t = readFileSync('diffapp/lib/screens/compare_page.dart', 'utf-8');
    expect(t).toMatch(/edgeSuppression/);
    expect(t).toMatch(/final\s+edgeCommon\s*=/);
    expect(t).toMatch(/final\s+diffFinal\s*=\s*List<double>\.generate\(/);
    // diffFinal -> normalizeToUnit(diffFinal) -> detector.detectFromDiffMap(diffN,
    expect(t).toMatch(/final\s+diffN\s*=\s*normalizeToUnit\(diffFinal\)/);
    expect(t).toMatch(/detector\.detectFromDiffMap\(\s*diffN,/s);
  });
});
