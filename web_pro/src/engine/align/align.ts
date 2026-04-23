import { makeImageData, rgbaToGray } from '../../lib/image';

export interface AlignResult {
  alignedRight: ImageData;
  method: 'translation' | 'similarity' | 'none';
  inliers: number;
  shiftX: number;
  shiftY: number;
  rotationDeg: number;
  scale: number;
}

/**
 * 類似変換（回転 + スケール + 平行移動）で右画像を左に整列する。純 TS。
 *
 * アルゴリズム:
 *   1. 両画像を 256×256 にダウンサンプル + Hanning 窓
 *   2. 回転角 × スケールの候補を総当たりし、各組で右画像を変換
 *   3. 変換した右画像と左画像でフェーズ相関 → 相関ピーク高と平行移動を取得
 *   4. 最も相関が強い (θ, s, Δx, Δy) を採用
 *   5. 元解像度の右画像をその設定で逆変換 → 整列済み画像を作る
 *
 * スマホ手持ち撮影レベル（±5°、スケール 0.9–1.1）の歪みを吸収できる。
 * 台形歪み（透視）には対応しない。
 */

const N = 256;
const ROT_DEGREES = [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5];
const SCALES = [0.9, 0.925, 0.95, 0.975, 1.0, 1.025, 1.05, 1.075, 1.1];

export function alignRightToLeft(left: ImageData, right: ImageData): AlignResult {
  const lDown = downsampleGray(left, N);
  hanningWindowInPlace(lDown, N);

  // 基準となる左画像の FFT を事前計算（使い回すため）
  const lRe = lDown.slice();
  const lIm = new Float32Array(N * N);
  fft2d(lRe, lIm, N);

  let bestPeak = -Infinity;
  let bestAngle = 0;
  let bestScale = 1;
  let bestShiftPx = 0;
  let bestShiftPy = 0;

  for (const deg of ROT_DEGREES) {
    for (const scale of SCALES) {
      const rDown = downsampleGrayTransformed(
        right,
        N,
        (deg * Math.PI) / 180,
        scale,
      );
      hanningWindowInPlace(rDown, N);
      const { peak, px, py } = phaseCorrelateWithLeft(lRe, lIm, rDown);
      if (peak > bestPeak) {
        bestPeak = peak;
        bestAngle = deg;
        bestScale = scale;
        bestShiftPx = px;
        bestShiftPy = py;
      }
    }
  }

  const peakNorm = Math.max(0, Math.min(1, bestPeak));
  if (peakNorm < 0.01) {
    return {
      alignedRight: right,
      method: 'none',
      inliers: 0,
      shiftX: 0,
      shiftY: 0,
      rotationDeg: 0,
      scale: 1,
    };
  }

  const ratioX = left.width / N;
  const ratioY = left.height / N;
  const shiftX = Math.round(bestShiftPx * ratioX);
  const shiftY = Math.round(bestShiftPy * ratioY);

  // 元解像度の右画像を (回転 → スケール → 平行移動) で整列
  const aligned = applyInverseTransform(
    right,
    left.width,
    left.height,
    (bestAngle * Math.PI) / 180,
    bestScale,
    shiftX,
    shiftY,
  );

  return {
    alignedRight: aligned,
    method: bestAngle !== 0 || bestScale !== 1 ? 'similarity' : 'translation',
    inliers: Math.round(peakNorm * 100),
    shiftX,
    shiftY,
    rotationDeg: bestAngle,
    scale: bestScale,
  };
}

/** 左画像のFFTを使って、渡された右画像（空間領域）とのフェーズ相関を計算 */
function phaseCorrelateWithLeft(
  lRe: Float32Array,
  lIm: Float32Array,
  rightSpatial: Float32Array,
): { peak: number; px: number; py: number } {
  const rRe = rightSpatial.slice();
  const rIm = new Float32Array(N * N);
  fft2d(rRe, rIm, N);

  const cRe = new Float32Array(N * N);
  const cIm = new Float32Array(N * N);
  for (let i = 0; i < N * N; i++) {
    const re = lRe[i] * rRe[i] + lIm[i] * rIm[i];
    const im = lIm[i] * rRe[i] - lRe[i] * rIm[i];
    const mag = Math.hypot(re, im) + 1e-9;
    cRe[i] = re / mag;
    cIm[i] = im / mag;
  }
  ifft2d(cRe, cIm, N);

  let peakIdx = 0;
  let peakVal = -Infinity;
  for (let i = 0; i < N * N; i++) {
    if (cRe[i] > peakVal) {
      peakVal = cRe[i];
      peakIdx = i;
    }
  }
  let py = Math.floor(peakIdx / N);
  let px = peakIdx - py * N;
  if (px > N / 2) px -= N;
  if (py > N / 2) py -= N;
  return { peak: peakVal, px, py };
}

/** 右画像を (angleRad, scale) で回転・拡縮してから N×N グレー配列にサンプリング */
function downsampleGrayTransformed(
  img: ImageData,
  N: number,
  angleRad: number,
  scale: number,
): Float32Array {
  const w = img.width;
  const h = img.height;
  const gray = rgbaToGray(img.data, w, h);
  const out = new Float32Array(N * N);
  const cx = w / 2;
  const cy = h / 2;
  const cos = Math.cos(-angleRad);
  const sin = Math.sin(-angleRad);
  const srcStep = w / N; // 解像度からのサンプリング間隔
  let sum = 0;
  let count = 0;

  for (let y = 0; y < N; y++) {
    for (let x = 0; x < N; x++) {
      // N×N 空間のターゲット座標を元画像座標へ逆変換
      // まず中心に揃える
      const tx = (x - N / 2) * srcStep;
      const ty = (y - N / 2) * srcStep;
      // スケール除算 + 回転
      const rx = (cos * tx - sin * ty) / scale + cx;
      const ry = (sin * tx + cos * ty) / scale + cy;
      let v = 0;
      if (rx >= 0 && rx < w - 1 && ry >= 0 && ry < h - 1) {
        const x0 = Math.floor(rx);
        const y0 = Math.floor(ry);
        const wx = rx - x0;
        const wy = ry - y0;
        v =
          gray[y0 * w + x0] * (1 - wx) * (1 - wy) +
          gray[y0 * w + x0 + 1] * wx * (1 - wy) +
          gray[(y0 + 1) * w + x0] * (1 - wx) * wy +
          gray[(y0 + 1) * w + x0 + 1] * wx * wy;
      }
      out[y * N + x] = v;
      sum += v;
      count++;
    }
  }
  const mean = sum / Math.max(1, count);
  for (let i = 0; i < out.length; i++) out[i] -= mean;
  return out;
}

/** 整列のために元解像度の右画像を (回転, スケール, 平行移動) で逆変換 */
function applyInverseTransform(
  src: ImageData,
  outW: number,
  outH: number,
  angleRad: number,
  scale: number,
  shiftX: number,
  shiftY: number,
): ImageData {
  const { data, width: sw, height: sh } = src;
  const out = new Uint8ClampedArray(outW * outH * 4);
  const cx = outW / 2;
  const cy = outH / 2;
  const cos = Math.cos(-angleRad);
  const sin = Math.sin(-angleRad);
  for (let y = 0; y < outH; y++) {
    for (let x = 0; x < outW; x++) {
      const tx = x - shiftX - cx;
      const ty = y - shiftY - cy;
      const rx = (cos * tx - sin * ty) / scale + sw / 2;
      const ry = (sin * tx + cos * ty) / scale + sh / 2;
      const dst4 = (y * outW + x) * 4;
      if (rx < 0 || rx >= sw - 1 || ry < 0 || ry >= sh - 1) {
        out[dst4] = 0;
        out[dst4 + 1] = 0;
        out[dst4 + 2] = 0;
        out[dst4 + 3] = 255;
        continue;
      }
      const x0 = Math.floor(rx);
      const y0 = Math.floor(ry);
      const wx = rx - x0;
      const wy = ry - y0;
      for (let c = 0; c < 3; c++) {
        const v =
          data[(y0 * sw + x0) * 4 + c] * (1 - wx) * (1 - wy) +
          data[(y0 * sw + x0 + 1) * 4 + c] * wx * (1 - wy) +
          data[((y0 + 1) * sw + x0) * 4 + c] * (1 - wx) * wy +
          data[((y0 + 1) * sw + x0 + 1) * 4 + c] * wx * wy;
        out[dst4 + c] = v;
      }
      out[dst4 + 3] = 255;
    }
  }
  return makeImageData(out, outW, outH);
}

function downsampleGray(img: ImageData, N: number): Float32Array {
  const gray = rgbaToGray(img.data, img.width, img.height);
  const out = new Float32Array(N * N);
  const sx = img.width / N;
  const sy = img.height / N;
  let mean = 0;
  for (let y = 0; y < N; y++) {
    for (let x = 0; x < N; x++) {
      const ix = Math.min(img.width - 1, Math.floor(x * sx));
      const iy = Math.min(img.height - 1, Math.floor(y * sy));
      const v = gray[iy * img.width + ix];
      out[y * N + x] = v;
      mean += v;
    }
  }
  mean /= N * N;
  for (let i = 0; i < out.length; i++) out[i] -= mean;
  return out;
}

function hanningWindowInPlace(buf: Float32Array, N: number): void {
  const w = new Float32Array(N);
  for (let i = 0; i < N; i++) w[i] = 0.5 * (1 - Math.cos((2 * Math.PI * i) / (N - 1)));
  for (let y = 0; y < N; y++) {
    for (let x = 0; x < N; x++) {
      buf[y * N + x] *= w[x] * w[y];
    }
  }
}

function fft2d(re: Float32Array, im: Float32Array, N: number): void {
  const tmpRe = new Float32Array(N);
  const tmpIm = new Float32Array(N);
  for (let y = 0; y < N; y++) {
    for (let x = 0; x < N; x++) {
      tmpRe[x] = re[y * N + x];
      tmpIm[x] = im[y * N + x];
    }
    fft1d(tmpRe, tmpIm, N, false);
    for (let x = 0; x < N; x++) {
      re[y * N + x] = tmpRe[x];
      im[y * N + x] = tmpIm[x];
    }
  }
  for (let x = 0; x < N; x++) {
    for (let y = 0; y < N; y++) {
      tmpRe[y] = re[y * N + x];
      tmpIm[y] = im[y * N + x];
    }
    fft1d(tmpRe, tmpIm, N, false);
    for (let y = 0; y < N; y++) {
      re[y * N + x] = tmpRe[y];
      im[y * N + x] = tmpIm[y];
    }
  }
}

function ifft2d(re: Float32Array, im: Float32Array, N: number): void {
  const tmpRe = new Float32Array(N);
  const tmpIm = new Float32Array(N);
  for (let y = 0; y < N; y++) {
    for (let x = 0; x < N; x++) {
      tmpRe[x] = re[y * N + x];
      tmpIm[x] = im[y * N + x];
    }
    fft1d(tmpRe, tmpIm, N, true);
    for (let x = 0; x < N; x++) {
      re[y * N + x] = tmpRe[x];
      im[y * N + x] = tmpIm[x];
    }
  }
  for (let x = 0; x < N; x++) {
    for (let y = 0; y < N; y++) {
      tmpRe[y] = re[y * N + x];
      tmpIm[y] = im[y * N + x];
    }
    fft1d(tmpRe, tmpIm, N, true);
    for (let y = 0; y < N; y++) {
      re[y * N + x] = tmpRe[y];
      im[y * N + x] = tmpIm[y];
    }
  }
  const scale = 1 / (N * N);
  for (let i = 0; i < N * N; i++) {
    re[i] *= scale;
    im[i] *= scale;
  }
}

function fft1d(re: Float32Array, im: Float32Array, N: number, inverse: boolean): void {
  let j = 0;
  for (let i = 0; i < N; i++) {
    if (i < j) {
      [re[i], re[j]] = [re[j], re[i]];
      [im[i], im[j]] = [im[j], im[i]];
    }
    let m = N >> 1;
    while (m >= 1 && j >= m) {
      j -= m;
      m >>= 1;
    }
    j += m;
  }
  for (let size = 2; size <= N; size *= 2) {
    const half = size / 2;
    const angle = (inverse ? 2 : -2) * Math.PI / size;
    const wRe = Math.cos(angle);
    const wIm = Math.sin(angle);
    for (let i = 0; i < N; i += size) {
      let twRe = 1;
      let twIm = 0;
      for (let k = 0; k < half; k++) {
        const aRe = re[i + k];
        const aIm = im[i + k];
        const bRe = re[i + k + half] * twRe - im[i + k + half] * twIm;
        const bIm = re[i + k + half] * twIm + im[i + k + half] * twRe;
        re[i + k] = aRe + bRe;
        im[i + k] = aIm + bIm;
        re[i + k + half] = aRe - bRe;
        im[i + k + half] = aIm - bIm;
        const newTwRe = twRe * wRe - twIm * wIm;
        twIm = twRe * wIm + twIm * wRe;
        twRe = newTwRe;
      }
    }
  }
}
