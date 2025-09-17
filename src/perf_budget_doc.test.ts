import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';

describe('パフォーマンス予算ドキュメントの存在検証', () => {
  const path = 'diffapp/docs/perf_budget.md';

  it('perf_budget.md が存在する', () => {
    expect(existsSync(path)).toBe(true);
  });

  it('1280px と 5 秒以内に言及がある', () => {
    const t = readFileSync(path, 'utf-8');
    expect(t).toMatch(/1280\s*px?/i);
    expect(t).toMatch(/5\s*秒/);
  });
});
