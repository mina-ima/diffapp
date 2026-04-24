import { rgbaToGray, normalizeFloat, gaussianBlur } from '../../lib/image';

/**
 * 純TS 版の簡易エッジ差分:
 *   1. Sobel で勾配強度マップを左右それぞれ計算
 *   2. 軽いガウシアンブラーでサブピクセル揺らぎを吸収
 *   3. 近傍最小差（±SHIFT_R 画素）で残留ミスアラインを許容
 *
 * カメラ写真では整列後も ±1〜2px の微小ズレが必ず残るので、
 * 素朴な |eL - eR| は「二重線」として全域で強く反応してしまう。
 * 近傍 3x3 (SHIFT_R=1) の最小差を取ることで 1px 以内のズレを差分から除外し、
 * 本当に形状が変わった場所だけが残る。
 */
const SHIFT_R = 1;

export function edgeDiffMap(
  leftRgba: Uint8ClampedArray,
  rightRgba: Uint8ClampedArray,
  w: number,
  h: number,
): Float32Array {
  const gl = rgbaToGray(leftRgba, w, h);
  const gr = rgbaToGray(rightRgba, w, h);
  const eL0 = sobelMagnitude(gl, w, h);
  const eR0 = sobelMagnitude(gr, w, h);
  // 軽いブラーでサブピクセル揺らぎを吸収（radius 1 ≒ σ 0.5）
  const eL = gaussianBlur(eL0, w, h, 1);
  const eR = gaussianBlur(eR0, w, h, 1);

  const out = new Float32Array(w * h);
  const r = SHIFT_R;
  for (let y = 0; y < h; y++) {
    const y0 = Math.max(0, y - r);
    const y1 = Math.min(h - 1, y + r);
    for (let x = 0; x < w; x++) {
      const x0 = Math.max(0, x - r);
      const x1 = Math.min(w - 1, x + r);
      const vL = eL[y * w + x];
      // eL の値に最も近い eR の近傍値を探す
      let best = Infinity;
      for (let yy = y0; yy <= y1; yy++) {
        for (let xx = x0; xx <= x1; xx++) {
          const d = Math.abs(vL - eR[yy * w + xx]);
          if (d < best) best = d;
        }
      }
      // 同様に eR 側からも最小を取り、双方向で一致する差分のみ残す
      const vR = eR[y * w + x];
      let best2 = Infinity;
      for (let yy = y0; yy <= y1; yy++) {
        for (let xx = x0; xx <= x1; xx++) {
          const d = Math.abs(vR - eL[yy * w + xx]);
          if (d < best2) best2 = d;
        }
      }
      out[y * w + x] = Math.min(best, best2);
    }
  }
  return normalizeFloat(out);
}

function sobelMagnitude(gray: Float32Array, w: number, h: number): Float32Array {
  const out = new Float32Array(w * h);
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      const idx = y * w + x;
      const gx =
        -gray[idx - w - 1] - 2 * gray[idx - 1] - gray[idx + w - 1] +
         gray[idx - w + 1] + 2 * gray[idx + 1] + gray[idx + w + 1];
      const gy =
        -gray[idx - w - 1] - 2 * gray[idx - w] - gray[idx - w + 1] +
         gray[idx + w - 1] + 2 * gray[idx + w] + gray[idx + w + 1];
      out[idx] = Math.hypot(gx, gy);
    }
  }
  return out;
}
