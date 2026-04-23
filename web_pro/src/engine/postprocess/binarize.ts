/**
 * 大津（Otsu）の方法で最適しきい値を決定し、[0,1] 正規化済みマップを二値化する。
 * sensitivity ∈ [0,1] で手動オフセットを追加（高いほどしきい値を下げて拾いやすくする）。
 */
export function otsuBinarize(
  map: Float32Array,
  sensitivity = 0.5,
): { mask: Uint8Array; threshold: number } {
  const BINS = 256;
  const hist = new Float64Array(BINS);
  for (let i = 0; i < map.length; i++) {
    const b = Math.min(BINS - 1, Math.max(0, Math.floor(map[i] * (BINS - 1))));
    hist[b]++;
  }
  const total = map.length;
  let sum = 0;
  for (let i = 0; i < BINS; i++) sum += i * hist[i];

  let sumB = 0;
  let wB = 0;
  let maxVar = -1;
  let threshold = 128;
  for (let t = 0; t < BINS; t++) {
    wB += hist[t];
    if (wB === 0) continue;
    const wF = total - wB;
    if (wF === 0) break;
    sumB += t * hist[t];
    const mB = sumB / wB;
    const mF = (sum - sumB) / wF;
    const between = wB * wF * (mB - mF) * (mB - mF);
    if (between > maxVar) {
      maxVar = between;
      threshold = t;
    }
  }
  // bin t は「背景側クラスの上限」なので、境界は bin t+1 の先頭に置く。
  const normalized = (threshold + 1) / (BINS - 1);
  const adjusted = Math.max(
    0.02,
    Math.min(0.98, normalized * (1 - 0.5 * (sensitivity - 0.5))),
  );
  const mask = new Uint8Array(map.length);
  for (let i = 0; i < map.length; i++) {
    mask[i] = map[i] >= adjusted ? 1 : 0;
  }
  return { mask, threshold: adjusted };
}

/**
 * 値の上位 p% を 1 とする補助マスク。Otsu で拾えない小さな差分を救うために使う。
 * Otsu のマスクと OR 結合することで、どちらかの基準で差分と判定されたピクセルを採用する。
 */
export function percentileMask(map: Float32Array, topPercent: number): Uint8Array {
  const n = map.length;
  const sorted = Float32Array.from(map);
  sorted.sort();
  const cutIndex = Math.max(0, Math.floor(n * (1 - topPercent / 100)));
  const threshold = sorted[cutIndex];
  const mask = new Uint8Array(n);
  for (let i = 0; i < n; i++) mask[i] = map[i] >= threshold ? 1 : 0;
  return mask;
}

export function orMasks(a: Uint8Array, b: Uint8Array): Uint8Array {
  const out = new Uint8Array(a.length);
  for (let i = 0; i < a.length; i++) out[i] = a[i] | b[i];
  return out;
}

/**
 * 3x3 モルフォロジー closing（膨張→収縮）。ノイズを埋めつつ近接領域を結合する。
 */
export function morphClose(
  mask: Uint8Array,
  w: number,
  h: number,
  iterations = 1,
): Uint8Array {
  let cur = mask;
  for (let it = 0; it < iterations; it++) {
    cur = dilate3x3(cur, w, h);
  }
  for (let it = 0; it < iterations; it++) {
    cur = erode3x3(cur, w, h);
  }
  return cur;
}

function dilate3x3(mask: Uint8Array, w: number, h: number): Uint8Array {
  const out = new Uint8Array(mask.length);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let v = 0;
      for (let dy = -1; dy <= 1 && !v; dy++) {
        const yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (let dx = -1; dx <= 1; dx++) {
          const xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          if (mask[yy * w + xx]) {
            v = 1;
            break;
          }
        }
      }
      out[y * w + x] = v;
    }
  }
  return out;
}

function erode3x3(mask: Uint8Array, w: number, h: number): Uint8Array {
  const out = new Uint8Array(mask.length);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let v = 1;
      for (let dy = -1; dy <= 1 && v; dy++) {
        const yy = y + dy;
        if (yy < 0 || yy >= h) {
          v = 0;
          break;
        }
        for (let dx = -1; dx <= 1; dx++) {
          const xx = x + dx;
          if (xx < 0 || xx >= w) {
            v = 0;
            break;
          }
          if (!mask[yy * w + xx]) {
            v = 0;
            break;
          }
        }
      }
      out[y * w + x] = v;
    }
  }
  return out;
}
