import type { Channel, DetectedBox } from '../../lib/types';

export interface RegionCandidate extends DetectedBox {
  area: number;
}

/**
 * 4 近傍ラベリングで連結成分を抽出し、スコアマップから領域ごとのピーク値を集める。
 * 既存 Dart 実装の知見を踏襲して、縦横比が大きい細長領域は面積下限を緩和。
 */
export function extractRegions(
  mask: Uint8Array,
  score: Float32Array,
  w: number,
  h: number,
  opts: { minAreaPercent: number } = { minAreaPercent: 0.4 },
  perChannel: Partial<Record<Channel, Float32Array>> = {},
): RegionCandidate[] {
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

  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const idx = y * w + x;
      if (!mask[idx]) continue;
      const up = y > 0 ? labels[idx - w] : 0;
      const lf = x > 0 ? labels[idx - 1] : 0;
      if (up && lf) {
        const m = Math.min(up, lf);
        labels[idx] = m;
        union(up, lf);
      } else if (up) {
        labels[idx] = up;
      } else if (lf) {
        labels[idx] = lf;
      } else {
        labels[idx] = next;
        parent[next] = next;
        next++;
      }
    }
  }

  const roots = new Map<number, number>();
  for (let i = 0; i < labels.length; i++) {
    if (!labels[i]) continue;
    const r = find(labels[i]);
    roots.set(labels[i], r);
    labels[i] = r;
  }

  interface Acc {
    minX: number;
    minY: number;
    maxX: number;
    maxY: number;
    area: number;
    peak: number;
    sum: number;
    channels: Map<Channel, number>;
  }
  const regions = new Map<number, Acc>();
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const idx = y * w + x;
      const lab = labels[idx];
      if (!lab) continue;
      let r = regions.get(lab);
      if (!r) {
        r = {
          minX: x,
          minY: y,
          maxX: x,
          maxY: y,
          area: 0,
          peak: 0,
          sum: 0,
          channels: new Map(),
        };
        regions.set(lab, r);
      }
      if (x < r.minX) r.minX = x;
      if (x > r.maxX) r.maxX = x;
      if (y < r.minY) r.minY = y;
      if (y > r.maxY) r.maxY = y;
      r.area++;
      const s = score[idx];
      if (s > r.peak) r.peak = s;
      r.sum += s;
      for (const key of Object.keys(perChannel) as Channel[]) {
        const m = perChannel[key];
        if (!m) continue;
        const cur = r.channels.get(key) ?? 0;
        if (m[idx] > cur) r.channels.set(key, m[idx]);
      }
    }
  }

  const total = w * h;
  const minAreaAbs = Math.max(4, Math.floor((opts.minAreaPercent / 100) * total));

  const out: RegionCandidate[] = [];
  for (const r of regions.values()) {
    const bw = r.maxX - r.minX + 1;
    const bh = r.maxY - r.minY + 1;
    const aspect = Math.max(bw, bh) / Math.max(1, Math.min(bw, bh));
    const areaThresh = aspect >= 4 ? minAreaAbs * 0.25 : minAreaAbs;
    if (r.area < areaThresh) continue;
    const channelScores: Partial<Record<Channel, number>> = {};
    for (const [k, v] of r.channels) channelScores[k] = v;
    out.push({
      x: r.minX,
      y: r.minY,
      w: bw,
      h: bh,
      area: r.area,
      score: r.peak * 0.7 + (r.sum / r.area) * 0.3,
      channelScores,
    });
  }
  return out.sort((a, b) => b.score - a.score);
}

/**
 * Non-Maximum Suppression。スコア降順で残し、以下のいずれかを満たす候補は抑制する:
 *   - IoU > iouThreshold  … 半分以上重なる
 *   - IoM > iomThreshold  … 小さい方がほぼ大きい方に含まれる（完全包含対策）
 *
 * IoM = 交差面積 / min(面積A, 面積B)。大きな枠の中に小さな枠が入ったケースを抑制。
 */
export function nms(
  boxes: RegionCandidate[],
  iouThreshold = 0.3,
  max = 20,
  iomThreshold = 0.6,
): RegionCandidate[] {
  const sorted = boxes.slice().sort((a, b) => b.score - a.score);
  const kept: RegionCandidate[] = [];
  for (const b of sorted) {
    if (kept.length >= max) break;
    let drop = false;
    for (const k of kept) {
      if (iou(b, k) > iouThreshold || iom(b, k) > iomThreshold) {
        drop = true;
        break;
      }
    }
    if (!drop) kept.push(b);
  }
  return kept;
}

function inter(a: RegionCandidate, b: RegionCandidate): number {
  const x1 = Math.max(a.x, b.x);
  const y1 = Math.max(a.y, b.y);
  const x2 = Math.min(a.x + a.w, b.x + b.w);
  const y2 = Math.min(a.y + a.h, b.y + b.h);
  if (x2 <= x1 || y2 <= y1) return 0;
  return (x2 - x1) * (y2 - y1);
}

function iou(a: RegionCandidate, b: RegionCandidate): number {
  const i = inter(a, b);
  if (!i) return 0;
  return i / (a.w * a.h + b.w * b.h - i);
}

function iom(a: RegionCandidate, b: RegionCandidate): number {
  const i = inter(a, b);
  if (!i) return 0;
  const minArea = Math.min(a.w * a.h, b.w * b.h);
  return minArea > 0 ? i / minArea : 0;
}
