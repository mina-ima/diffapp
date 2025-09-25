import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('最小面積割合の統一', () => {
  it('設定・仕様・TODOが5%で揃っている', () => {
    const settings = readFileSync('diffapp/lib/settings.dart', 'utf-8');
    expect(settings).toMatch(/defaultMinAreaPercent\s*=\s*5/);

    const spec = readFileSync('prompt_spec.md', 'utf-8');
    expect(spec).not.toMatch(/minAreaPercent=2%/);
    expect(spec).toMatch(/最小面積（割合）[\s\S]*?既定:\s*5%/);

    const todo = readFileSync('todo.md', 'utf-8');
    expect(todo).not.toMatch(/\[ \] 検出の最小面積を割合基準に変更/);
  });
});
