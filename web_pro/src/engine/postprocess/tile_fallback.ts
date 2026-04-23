import type { Channel, DetectedBox } from '../../lib/types';

/**
 * タイル分割フォールバック検出。
 * 既存 diffapp から踏襲した「タイルごとの上位分位平均で二値化→連結成分」方式。
 *
 * アルゴリズム:
 *   1. ヒートマップを tileCount × tileCount タイル（例: 20×20=400）に分割
 *   2. 各タイル内で上位 tileTopQuantile（既定10%）の値の平均を取る
 *   3. タイル平均が全体上位 tileSelectTopPercent%（既定15%）以上のタイルを「強タイル」とする
 *   4. 強タイルを 4近傍ラベリングで連結成分化
 *   5. 上位 maxClusters 件をボックスとして返す
 *
 * 主な用途: Otsu や百分位で拾えない、連続した広い差分領域の救済。
 */
export interface TileFallbackOptions {
  tileCount: number;
  tileTopQuantile: number;
  tileSelectTopPercent: number;
  maxClusters: number;
}

export const DEFAULT_TILE_OPTIONS: TileFallbackOptions = {
  tileCount: 20,
  tileTopQuantile: 0.1,
  tileSelectTopPercent: 15,
  maxClusters: 10,
};

export function detectByTileClusters(
  heatmap: Float32Array,
  w: number,
  h: number,
  perChannel: Partial<Record<Channel, Float32Array>>,
  options: TileFallbackOptions = DEFAULT_TILE_OPTIONS,
): DetectedBox[] {
  const T = options.tileCount;
  const tileW = Math.max(1, Math.floor(w / T));
  const tileH = Math.max(1, Math.floor(h / T));
  const tileScores = new Float32Array(T * T);

  for (let ty = 0; ty < T; ty++) {
    for (let tx = 0; tx < T; tx++) {
      const x0 = tx * tileW;
      const y0 = ty * tileH;
      const x1 = tx === T - 1 ? w : x0 + tileW;
      const y1 = ty === T - 1 ? h : y0 + tileH;
      const buf: number[] = [];
      for (let y = y0; y < y1; y++) {
        for (let x = x0; x < x1; x++) buf.push(heatmap[y * w + x]);
      }
      buf.sort((a, b) => b - a);
      const top = Math.max(1, Math.floor(buf.length * options.tileTopQuantile));
      let sum = 0;
      for (let i = 0; i < top; i++) sum += buf[i];
      tileScores[ty * T + tx] = sum / top;
    }
  }

  // 全タイルを降順ソートして、上位 selectTopPercent% を閾値とする
  const sorted = Float32Array.from(tileScores);
  sorted.sort();
  const cutIdx = Math.max(
    0,
    Math.floor(sorted.length * (1 - options.tileSelectTopPercent / 100)),
  );
  const threshold = sorted[cutIdx];

  // 強タイルのマスク
  const mask = new Uint8Array(T * T);
  for (let i = 0; i < mask.length; i++) mask[i] = tileScores[i] >= threshold ? 1 : 0;

  // 4 近傍連結成分
  const labels = new Int32Array(mask.length);
  let next = 1;
  const parent: number[] = [0];
  const find = (x: number): number => {
    while (parent[x] !== x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  };
  const union = (a: number, b: number) => {
    const ra = find(a);
    const rb = find(b);
    if (ra !== rb) parent[Math.max(ra, rb)] = Math.min(ra, rb);
  };
  for (let ty = 0; ty < T; ty++) {
    for (let tx = 0; tx < T; tx++) {
      const idx = ty * T + tx;
      if (!mask[idx]) continue;
      const up = ty > 0 ? labels[idx - T] : 0;
      const lf = tx > 0 ? labels[idx - 1] : 0;
      if (up && lf) {
        const m = Math.min(up, lf);
        labels[idx] = m;
        union(up, lf);
      } else if (up) labels[idx] = up;
      else if (lf) labels[idx] = lf;
      else {
        labels[idx] = next;
        parent[next] = next;
        next++;
      }
    }
  }
  for (let i = 0; i < labels.length; i++) if (labels[i]) labels[i] = find(labels[i]);

  interface Acc {
    minTx: number;
    minTy: number;
    maxTx: number;
    maxTy: number;
    score: number;
    channels: Map<Channel, number>;
  }
  const clusters = new Map<number, Acc>();
  for (let ty = 0; ty < T; ty++) {
    for (let tx = 0; tx < T; tx++) {
      const lab = labels[ty * T + tx];
      if (!lab) continue;
      let c = clusters.get(lab);
      if (!c) {
        c = {
          minTx: tx,
          minTy: ty,
          maxTx: tx,
          maxTy: ty,
          score: 0,
          channels: new Map(),
        };
        clusters.set(lab, c);
      }
      c.minTx = Math.min(c.minTx, tx);
      c.maxTx = Math.max(c.maxTx, tx);
      c.minTy = Math.min(c.minTy, ty);
      c.maxTy = Math.max(c.maxTy, ty);
      const s = tileScores[ty * T + tx];
      if (s > c.score) c.score = s;
    }
  }

  const boxes: DetectedBox[] = [];
  for (const c of clusters.values()) {
    const x0 = c.minTx * tileW;
    const y0 = c.minTy * tileH;
    const x1 = (c.maxTx === T - 1) ? w : (c.maxTx + 1) * tileW;
    const y1 = (c.maxTy === T - 1) ? h : (c.maxTy + 1) * tileH;
    const bx = x0;
    const by = y0;
    const bw = x1 - x0;
    const bh = y1 - y0;
    // クラスタ領域内のチャネル別最大値を拾う
    const channelScores: Partial<Record<Channel, number>> = {};
    for (const [k, m] of Object.entries(perChannel) as Array<[Channel, Float32Array | undefined]>) {
      if (!m) continue;
      let mx = 0;
      for (let y = by; y < by + bh; y++) {
        for (let x = bx; x < bx + bw; x++) {
          const v = m[y * w + x];
          if (v > mx) mx = v;
        }
      }
      channelScores[k] = mx;
    }
    boxes.push({ x: bx, y: by, w: bw, h: bh, score: c.score, channelScores });
  }
  return boxes.sort((a, b) => b.score - a.score).slice(0, options.maxClusters);
}
