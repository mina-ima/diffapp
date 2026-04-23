import type { Channel } from '../../lib/types';

export interface DetectedPeak {
  x: number;
  y: number;
  score: number;
  channelScores: Partial<Record<Channel, number>>;
}

/**
 * 差分ヒートマップから「間違い探し」らしいピーク点を抽出する。
 *
 * アルゴリズム:
 *   1. ヒートマップの全ピクセルを降順ソート
 *   2. スコア上位から順に走査し、既に採用したピーク点と minDistance 以上離れていれば採用
 *   3. 上位 maxCount 件を返す
 *
 * 結果は「差分の中心」を指す点の集合になり、伝統的な間違い探しのように
 * 円で囲む表示に適する。矩形より重なりが起きず、誤検出が視覚的に目立ちにくい。
 */
export function detectPeaks(
  heatmap: Float32Array,
  w: number,
  _h: number,
  options: {
    minDistance: number;
    maxCount: number;
    minScore: number;
  },
  perChannel: Partial<Record<Channel, Float32Array>> = {},
): DetectedPeak[] {
  const n = heatmap.length;
  // Index + score のペアを作り降順ソート（十分に速い: 数十万px）
  const indexed = new Array<[number, number]>(n);
  for (let i = 0; i < n; i++) indexed[i] = [i, heatmap[i]];
  indexed.sort((a, b) => b[1] - a[1]);

  const peaks: DetectedPeak[] = [];
  const d2 = options.minDistance * options.minDistance;

  for (let k = 0; k < n; k++) {
    const [idx, score] = indexed[k];
    if (score < options.minScore) break;
    if (peaks.length >= options.maxCount) break;
    const y = Math.floor(idx / w);
    const x = idx - y * w;

    let tooClose = false;
    for (const p of peaks) {
      const dx = p.x - x;
      const dy = p.y - y;
      if (dx * dx + dy * dy < d2) {
        tooClose = true;
        break;
      }
    }
    if (tooClose) continue;

    const channelScores: Partial<Record<Channel, number>> = {};
    for (const key of Object.keys(perChannel) as Channel[]) {
      const m = perChannel[key];
      if (m) channelScores[key] = m[idx];
    }
    peaks.push({ x, y, score, channelScores });
  }
  return peaks;
}
