export function rgbaToGray(
  rgba: Uint8ClampedArray,
  width: number,
  height: number,
): Float32Array {
  const out = new Float32Array(width * height);
  for (let i = 0, j = 0; i < rgba.length; i += 4, j++) {
    out[j] = 0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
  }
  return out;
}

export function resizeRgbaBilinear(
  src: Uint8ClampedArray,
  sw: number,
  sh: number,
  dw: number,
  dh: number,
): Uint8ClampedArray {
  const out = new Uint8ClampedArray(dw * dh * 4);
  const sx = sw / dw;
  const sy = sh / dh;
  for (let y = 0; y < dh; y++) {
    const fy = (y + 0.5) * sy - 0.5;
    const y0 = Math.max(0, Math.floor(fy));
    const y1 = Math.min(sh - 1, y0 + 1);
    const wy = fy - y0;
    for (let x = 0; x < dw; x++) {
      const fx = (x + 0.5) * sx - 0.5;
      const x0 = Math.max(0, Math.floor(fx));
      const x1 = Math.min(sw - 1, x0 + 1);
      const wx = fx - x0;
      const i00 = (y0 * sw + x0) * 4;
      const i10 = (y0 * sw + x1) * 4;
      const i01 = (y1 * sw + x0) * 4;
      const i11 = (y1 * sw + x1) * 4;
      const di = (y * dw + x) * 4;
      for (let c = 0; c < 4; c++) {
        const v =
          src[i00 + c] * (1 - wx) * (1 - wy) +
          src[i10 + c] * wx * (1 - wy) +
          src[i01 + c] * (1 - wx) * wy +
          src[i11 + c] * wx * wy;
        out[di + c] = v;
      }
    }
  }
  return out;
}

export function cropRgba(
  src: Uint8ClampedArray,
  sw: number,
  _sh: number,
  x: number,
  y: number,
  w: number,
  h: number,
): Uint8ClampedArray {
  const out = new Uint8ClampedArray(w * h * 4);
  for (let j = 0; j < h; j++) {
    const srcStart = ((y + j) * sw + x) * 4;
    const dstStart = j * w * 4;
    out.set(src.subarray(srcStart, srcStart + w * 4), dstStart);
  }
  return out;
}

export function clamp(v: number, lo: number, hi: number): number {
  return v < lo ? lo : v > hi ? hi : v;
}

/**
 * 射影変換（ホモグラフィ）を RGBA 画像に適用する。
 * H_inv は「出力座標 → 入力座標」の逆変換行列（9要素、row-major）。
 * バイリニア補間で出力画像を生成。
 */
export function warpPerspectiveRgba(
  src: Uint8ClampedArray,
  sw: number,
  sh: number,
  dw: number,
  dh: number,
  H_inv: number[],
): Uint8ClampedArray {
  const out = new Uint8ClampedArray(dw * dh * 4);
  for (let y = 0; y < dh; y++) {
    for (let x = 0; x < dw; x++) {
      const w = H_inv[6] * x + H_inv[7] * y + H_inv[8];
      if (Math.abs(w) < 1e-8) continue;
      const sx = (H_inv[0] * x + H_inv[1] * y + H_inv[2]) / w;
      const sy = (H_inv[3] * x + H_inv[4] * y + H_inv[5]) / w;
      const di = (y * dw + x) * 4;
      if (sx < 0 || sx >= sw - 1 || sy < 0 || sy >= sh - 1) {
        // 範囲外 = 比較不能領域。alpha = 0 にして後段の差分計算から除外できるようにする
        out[di + 3] = 0;
        continue;
      }
      const x0 = Math.floor(sx);
      const y0 = Math.floor(sy);
      const wx = sx - x0;
      const wy = sy - y0;
      const i00 = (y0 * sw + x0) * 4;
      const i10 = (y0 * sw + x0 + 1) * 4;
      const i01 = ((y0 + 1) * sw + x0) * 4;
      const i11 = ((y0 + 1) * sw + x0 + 1) * 4;
      for (let c = 0; c < 3; c++) {
        out[di + c] =
          src[i00 + c] * (1 - wx) * (1 - wy) +
          src[i10 + c] * wx * (1 - wy) +
          src[i01 + c] * (1 - wx) * wy +
          src[i11 + c] * wx * wy;
      }
      out[di + 3] = 255;
    }
  }
  return out;
}

/**
 * ImageData の alpha チャネルから有効マスク（1=比較可能、0=無効）を抽出する。
 * ワープで範囲外になったピクセルは alpha が 0 になっている。
 */
export function extractValidMask(rgba: Uint8ClampedArray, w: number, h: number): Uint8Array {
  const mask = new Uint8Array(w * h);
  for (let i = 0; i < mask.length; i++) {
    mask[i] = rgba[i * 4 + 3] > 200 ? 1 : 0;
  }
  return mask;
}

/**
 * バイナリマスクに対し 3x3 erosion を iterations 回適用する。
 * ワープ境界で 1 画素分の interp 混入を除外するために使う。
 */
export function erodeMask(mask: Uint8Array, w: number, h: number, iterations = 1): Uint8Array {
  let cur = mask;
  for (let it = 0; it < iterations; it++) {
    const out = new Uint8Array(cur.length);
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
            if (!cur[yy * w + xx]) {
              v = 0;
              break;
            }
          }
        }
        out[y * w + x] = v;
      }
    }
    cur = out;
  }
  return cur;
}

/**
 * 新しい ArrayBuffer を確保した Uint8ClampedArray でラップして ImageData を作る。
 * TS 5 の厳しい型推論（ArrayBufferLike vs ArrayBuffer）による互換問題を回避するため、
 * すべての ImageData 生成箇所はこのヘルパーを経由する。
 */
export function makeImageData(
  data: Uint8ClampedArray | Uint8Array | number[],
  width: number,
  height: number,
): ImageData {
  const buf = new Uint8ClampedArray(width * height * 4);
  if (data instanceof Uint8ClampedArray || data instanceof Uint8Array) {
    buf.set(data);
  } else {
    for (let i = 0; i < data.length && i < buf.length; i++) buf[i] = data[i];
  }
  return new ImageData(buf, width, height);
}

/**
 * 可分ガウシアンブラー。差分マップの位置ズレ吸収とノイズ平滑化に使う。
 * radius 2 ≒ σ≈1, radius 3 ≒ σ≈1.5 相当。
 */
export function gaussianBlur(
  src: Float32Array,
  w: number,
  h: number,
  radius = 2,
): Float32Array {
  if (radius <= 0) return src;
  const sigma = radius / 2;
  const len = radius * 2 + 1;
  const kernel = new Float32Array(len);
  let ksum = 0;
  for (let i = 0; i < len; i++) {
    const x = i - radius;
    kernel[i] = Math.exp(-(x * x) / (2 * sigma * sigma));
    ksum += kernel[i];
  }
  for (let i = 0; i < len; i++) kernel[i] /= ksum;

  const tmp = new Float32Array(src.length);
  const out = new Float32Array(src.length);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let acc = 0;
      for (let k = -radius; k <= radius; k++) {
        const xx = Math.min(w - 1, Math.max(0, x + k));
        acc += src[y * w + xx] * kernel[k + radius];
      }
      tmp[y * w + x] = acc;
    }
  }
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let acc = 0;
      for (let k = -radius; k <= radius; k++) {
        const yy = Math.min(h - 1, Math.max(0, y + k));
        acc += tmp[yy * w + x] * kernel[k + radius];
      }
      out[y * w + x] = acc;
    }
  }
  return out;
}

export function normalizeFloat(src: Float32Array): Float32Array {
  let lo = Infinity;
  let hi = -Infinity;
  for (let i = 0; i < src.length; i++) {
    const v = src[i];
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  const span = hi - lo || 1;
  const out = new Float32Array(src.length);
  for (let i = 0; i < src.length; i++) out[i] = (src[i] - lo) / span;
  return out;
}
