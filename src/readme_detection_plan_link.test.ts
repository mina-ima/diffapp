import { readFileSync } from 'node:fs';
import { describe, it, expect } from 'vitest';

describe('README リンク検証', () => {
  it('検査パイプライン計画ドキュメントへのリンクがある', () => {
    const text = readFileSync('README.md', 'utf-8');
    expect(text).toMatch(/diffapp\/docs\/detection_pipeline_plan\.md/);
  });
});
