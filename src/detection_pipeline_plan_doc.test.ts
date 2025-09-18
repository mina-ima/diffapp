import { readFileSync } from 'node:fs';
import { describe, it, expect } from 'vitest';

describe('検査パイプライン計画ドキュメント', () => {
  it('diffapp/docs/detection_pipeline_plan.md が存在し、主要項目を含む', () => {
    const path = 'diffapp/docs/detection_pipeline_plan.md';
    const text = readFileSync(path, 'utf-8');

    // タイトル
    expect(text).toMatch(/検査パイプライン計画/); // 見出し

    // 主要技術要素
    expect(text).toMatch(/SSIM/); // 差分抽出
    expect(text).toMatch(/TensorFlow\s*Lite|TFLite/i); // AI モデル
    expect(text).toMatch(/1280/); // 正規化幅
    expect(text).toMatch(/5秒以内|5 秒以内/); // パフォーマンス目標

    // 処理手順のキーワード
    expect(text).toMatch(/正規化|リサイズ/);
    expect(text).toMatch(/スコアマップ|差分|二値化/);
    expect(text).toMatch(/連結成分|ラベリング/);
    expect(text).toMatch(/NMS|重複除去/);
    expect(text).toMatch(/閾値|しきい値/);

    // 実装段階（マイルストーン）
    expect(text).toMatch(/マイルストーン|Milestones/i);
    expect(text).toMatch(/段階|フェーズ|Phase/i);
  });
});
