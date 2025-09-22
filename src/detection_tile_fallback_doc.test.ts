import { readFileSync } from 'node:fs';
import { describe, it, expect } from 'vitest';

describe('検査パイプライン計画: タイル分割フォールバックの記載', () => {
  it('detection_pipeline_plan.md に 20×20 タイルや上位10件の記述がある', () => {
    const text = readFileSync('diffapp/docs/detection_pipeline_plan.md', 'utf8');
    expect(text).toMatch(/タイル/);
    expect(text).toMatch(/20×20|20x20/); // 記法いずれか
    expect(text).toMatch(/上位\s*10/); // 上位10件
  });
});
