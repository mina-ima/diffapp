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
