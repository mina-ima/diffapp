import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';

describe('パフォーマンス: 低メモリ端末での安定性確認 計画/簡易検証', () => {
  const path = 'diffapp/docs/perf_low_memory_plan.md';

  it('計画ドキュメントが存在する', () => {
    expect(existsSync(path)).toBe(true);
  });

  it('目的/対象端末/制約条件/手順/計測項目/回復/CI簡易検証 の章が含まれる', () => {
    const t = readFileSync(path, 'utf-8');
    for (const kw of ['目的', '対象端末', '制約条件', '手順', '計測項目', '回復', 'CI簡易検証']) {
      expect(t).toContain(kw);
    }
  });

  it('メモリ/OOM/キャッシュ/一時ファイル/1280px/タイムアウト/GC に言及がある', () => {
    const t = readFileSync(path, 'utf-8');
    for (const kw of [
      'メモリ',
      'OOM',
      'キャッシュ',
      '一時ファイル',
      '1280px',
      'タイムアウト',
      'GC',
    ]) {
      expect(t).toContain(kw);
    }
  });

  it('実施のヒント（ulimit/adb/Xcodeのメモリ警告）に言及がある', () => {
    const t = readFileSync(path, 'utf-8');
    expect(t).toMatch(/ulimit/i);
    expect(t).toMatch(/adb\s+shell/i);
    expect(t).toMatch(/Xcode/i);
  });
});
