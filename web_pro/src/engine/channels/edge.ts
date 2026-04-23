import { rgbaToGray, normalizeFloat } from '../../lib/image';

/**
 * 純TS 版の簡易エッジ差分:
 *   1. Sobel で勾配強度マップを左右それぞれ計算
 *   2. 勾配強度の差の絶対値
 *
 * OpenCV の Canny + 距離変換ほど洗練されていないが、形状ズレの検出には十分。
 */
export function edgeDiffMap(
  leftRgba: Uint8ClampedArray,
  rightRgba: Uint8ClampedArray,
  w: number,
  h: number,
): Float32Array {
  const gl = rgbaToGray(leftRgba, w, h);
  const gr = rgbaToGray(rightRgba, w, h);
  const eL = sobelMagnitude(gl, w, h);
  const eR = sobelMagnitude(gr, w, h);
  const out = new Float32Array(w * h);
  for (let i = 0; i < out.length; i++) out[i] = Math.abs(eL[i] - eR[i]);
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
