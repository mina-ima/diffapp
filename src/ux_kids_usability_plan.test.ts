import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';

describe('UI/UX: 子供による操作テスト計画ドキュメント', () => {
  const path = 'diffapp/docs/ux_kids_test_plan.md';

  it('計画ドキュメントが存在する', () => {
    expect(existsSync(path)).toBe(true);
  });

  it('年齢層/参加人数/タスク/指標/倫理面などの項目を含む', () => {
    const t = readFileSync(path, 'utf-8');
    expect(t).toContain('年齢層');
    expect(t).toContain('参加人数');
    expect(t).toContain('タスク');
    expect(t).toContain('指標');
    expect(t).toContain('倫理');
  });

  it('主要な操作タスク（画像選択/けんさをはじめる/結果確認/再比較/設定/誤タップ対策）を含む', () => {
    const t = readFileSync(path, 'utf-8');
    for (const kw of ['画像選択', 'けんさをはじめる', '結果確認', '再比較', '設定', '誤タップ']) {
      expect(t).toContain(kw);
    }
  });

  it('最小タップ領域48x48/セマンティクス/音量に関する項目がある', () => {
    const t = readFileSync(path, 'utf-8');
    expect(t).toMatch(/48\s*x\s*48/);
    expect(t).toContain('セマンティクス');
    expect(t).toContain('音量');
  });
});
