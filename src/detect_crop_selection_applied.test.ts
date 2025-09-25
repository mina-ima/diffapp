import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('検査は範囲指定部分のみを対象にする（Dartコードの存在検証）', () => {
  it('compare_page.dart で整列後の矩形抽出と再サンプリングを行っている', () => {
    const t = readFileSync('diffapp/lib/screens/compare_page.dart', 'utf-8');
    expect(t).toMatch(/final\s+alignmentRect\s*=\s*_leftRect/);
    expect(t).toMatch(/_extractRgbaRegion\(/);
    expect(t).toMatch(/_resizeRgbaBilinear\(/);
  });

  it('選択範囲がある場合、解析座標へ再投影して検出ボックスを返している', () => {
    const t = readFileSync('diffapp/lib/screens/compare_page.dart', 'utf-8');
    expect(t).toMatch(/final\s+double\s+analysisScaleX/);
    expect(t).toMatch(/regionAnalysisWidth/);
    expect(t).toMatch(/regionFactorX/);
    expect(t).toMatch(/IntRect\(/);
  });

  it('ResultPage のオーバーレイは解析サイズと同期している', () => {
    const t = readFileSync('diffapp/lib/screens/result_page.dart', 'utf-8');
    expect(t).toMatch(/const\s+srcW\s*=\s*256/);
    expect(t).toMatch(/const\s+srcH\s*=\s*256/);
  });
});
