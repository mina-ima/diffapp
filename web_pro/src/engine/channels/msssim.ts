import { rgbaToGray, resizeRgbaBilinear, normalizeFloat } from '../../lib/image';

const WIN = 5;
const K1 = 0.01;
const K2 = 0.03;
const L = 255;

/**
 * 単一スケールの SSIM マップ。1 - SSIM を返し、差分強度として扱う。
 * 局所統計は積分画像（summed-area table）で O(N) に計算。
 */
export function ssimDiffMap(
  leftRgba: Uint8ClampedArray,
  rightRgba: Uint8ClampedArray,
  w: number,
  h: number,
): Float32Array {
  const gx = rgbaToGray(leftRgba, w, h);
  const gy = rgbaToGray(rightRgba, w, h);
  const gxx = new Float32Array(w * h);
  const gyy = new Float32Array(w * h);
  const gxy = new Float32Array(w * h);
  for (let i = 0; i < w * h; i++) {
    gxx[i] = gx[i] * gx[i];
    gyy[i] = gy[i] * gy[i];
    gxy[i] = gx[i] * gy[i];
  }
  const ix = integralImage(gx, w, h);
  const iy = integralImage(gy, w, h);
  const ixx = integralImage(gxx, w, h);
  const iyy = integralImage(gyy, w, h);
  const ixy = integralImage(gxy, w, h);

  const c1 = (K1 * L) * (K1 * L);
  const c2 = (K2 * L) * (K2 * L);
  const r = Math.floor(WIN / 2);
  const out = new Float32Array(w * h);

  for (let y = 0; y < h; y++) {
    const y0 = Math.max(0, y - r);
    const y1 = Math.min(h - 1, y + r);
    for (let x = 0; x < w; x++) {
      const x0 = Math.max(0, x - r);
      const x1 = Math.min(w - 1, x + r);
      const n = (y1 - y0 + 1) * (x1 - x0 + 1);
      const mx = box(ix, w, x0, y0, x1, y1) / n;
      const my = box(iy, w, x0, y0, x1, y1) / n;
      const mxx = box(ixx, w, x0, y0, x1, y1) / n;
      const myy = box(iyy, w, x0, y0, x1, y1) / n;
      const mxy = box(ixy, w, x0, y0, x1, y1) / n;
      const vx = mxx - mx * mx;
      const vy = myy - my * my;
      const cov = mxy - mx * my;
      const num = (2 * mx * my + c1) * (2 * cov + c2);
      const den = (mx * mx + my * my + c1) * (vx + vy + c2);
      const s = den > 0 ? num / den : 1;
      out[y * w + x] = Math.max(0, Math.min(1, 1 - s));
    }
  }
  return out;
}

/**
 * Multi-scale SSIM。3 スケール（1x, 1/2, 1/4）の差分マップを解析空間にリサイズして合成。
 */
export function msssimDiffMap(
  leftRgba: Uint8ClampedArray,
  rightRgba: Uint8ClampedArray,
  w: number,
  h: number,
): Float32Array {
  const scales = [1, 0.5, 0.25];
  const weights = [0.5, 0.3, 0.2];
  const acc = new Float32Array(w * h);
  for (let s = 0; s < scales.length; s++) {
    const sc = scales[s];
    const sw = Math.max(8, Math.round(w * sc));
    const sh = Math.max(8, Math.round(h * sc));
    const l = sc === 1 ? leftRgba : resizeRgbaBilinear(leftRgba, w, h, sw, sh);
    const r = sc === 1 ? rightRgba : resizeRgbaBilinear(rightRgba, w, h, sw, sh);
    const map = ssimDiffMap(l, r, sw, sh);
    const up = sc === 1 ? map : upscaleFloat(map, sw, sh, w, h);
    for (let i = 0; i < acc.length; i++) acc[i] += weights[s] * up[i];
  }
  return normalizeFloat(acc);
}

function integralImage(
  src: Float32Array,
  w: number,
  h: number,
): Float64Array {
  const out = new Float64Array((w + 1) * (h + 1));
  for (let y = 0; y < h; y++) {
    let rowSum = 0;
    for (let x = 0; x < w; x++) {
      rowSum += src[y * w + x];
      out[(y + 1) * (w + 1) + (x + 1)] = out[y * (w + 1) + (x + 1)] + rowSum;
    }
  }
  return out;
}

function box(
  ii: Float64Array,
  w: number,
  x0: number,
  y0: number,
  x1: number,
  y1: number,
): number {
  const W = w + 1;
  return (
    ii[(y1 + 1) * W + (x1 + 1)] -
    ii[y0 * W + (x1 + 1)] -
    ii[(y1 + 1) * W + x0] +
    ii[y0 * W + x0]
  );
}

function upscaleFloat(
  src: Float32Array,
  sw: number,
  sh: number,
  dw: number,
  dh: number,
): Float32Array {
  const out = new Float32Array(dw * dh);
  const sx = sw / dw;
  const sy = sh / dh;
  for (let y = 0; y < dh; y++) {
    const fy = y * sy;
    const y0 = Math.min(sh - 1, Math.floor(fy));
    const y1 = Math.min(sh - 1, y0 + 1);
    const wy = fy - y0;
    for (let x = 0; x < dw; x++) {
      const fx = x * sx;
      const x0 = Math.min(sw - 1, Math.floor(fx));
      const x1 = Math.min(sw - 1, x0 + 1);
      const wx = fx - x0;
      const v =
        src[y0 * sw + x0] * (1 - wx) * (1 - wy) +
        src[y0 * sw + x1] * wx * (1 - wy) +
        src[y1 * sw + x0] * (1 - wx) * wy +
        src[y1 * sw + x1] * wx * wy;
      out[y * dw + x] = v;
    }
  }
  return out;
}
