import { makeImageData, rgbaToGray } from '../../lib/image';

export interface AlignResult {
  alignedRight: ImageData;
  method: 'translation' | 'none';
  inliers: number; // 相関ピーク強度（0–1 に正規化）× 100
  shiftX: number;
  shiftY: number;
}

/**
 * フェーズ相関で左右画像の平行移動量を検出し、右画像を整列する（純TS、外部依存なし）。
 *
 * アルゴリズム:
 *   1. 2 のべき乗サイズ（例: 256×256）にダウンサンプル
 *   2. 両画像をグレースケール + Hanning 窓で周辺を減衰
 *   3. 2D FFT → クロスパワースペクトル → 逆FFT
 *   4. 相関マップのピーク位置 = 平行移動量
 *   5. 元解像度に戻して shift 補正し、右画像を warp
 *
 * 回転・スケール差には対応しない（平行移動のみ）。
 * ただし撮影時の三脚固定や、画面キャプチャ比較では十分精度が高い。
 */
export function alignRightToLeft(left: ImageData, right: ImageData): AlignResult {
  const N = 256;
  const lDown = downsampleGray(left, N);
  const rDown = downsampleGray(right, N);
  hanningWindowInPlace(lDown, N);
  hanningWindowInPlace(rDown, N);

  const lRe = lDown.slice();
  const lIm = new Float32Array(N * N);
  const rRe = rDown.slice();
  const rIm = new Float32Array(N * N);
  fft2d(lRe, lIm, N);
  fft2d(rRe, rIm, N);

  // Cross-power spectrum: L * conj(R) / |L * conj(R)|
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

  // Peak location in correlation map → sub-pixel shift
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

  const ratioX = left.width / N;
  const ratioY = left.height / N;
  const shiftX = Math.round(px * ratioX);
  const shiftY = Math.round(py * ratioY);

  const peakNorm = Math.max(0, Math.min(1, peakVal));
  if (peakNorm < 0.01) {
    return { alignedRight: right, method: 'none', inliers: 0, shiftX: 0, shiftY: 0 };
  }

  const aligned = shiftImage(right, shiftX, shiftY);
  return {
    alignedRight: aligned,
    method: 'translation',
    inliers: Math.round(peakNorm * 100),
    shiftX,
    shiftY,
  };
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

/**
 * 2D FFT（行方向 + 列方向に 1D FFT を適用）。N は 2 のべき乗。
 * In-place で re/im を書き換える。
 */
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

/** Iterative Cooley–Tukey radix-2 FFT (N は 2 のべき乗). */
function fft1d(re: Float32Array, im: Float32Array, N: number, inverse: boolean): void {
  // Bit-reversal
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

function shiftImage(src: ImageData, dx: number, dy: number): ImageData {
  const { width: w, height: h, data } = src;
  const out = new Uint8ClampedArray(data.length);
  for (let y = 0; y < h; y++) {
    const sy = clampInt(y - dy, 0, h - 1);
    for (let x = 0; x < w; x++) {
      const sx = clampInt(x - dx, 0, w - 1);
      const src4 = (sy * w + sx) * 4;
      const dst4 = (y * w + x) * 4;
      out[dst4] = data[src4];
      out[dst4 + 1] = data[src4 + 1];
      out[dst4 + 2] = data[src4 + 2];
      out[dst4 + 3] = 255;
    }
  }
  return makeImageData(out, w, h);
}

function clampInt(v: number, lo: number, hi: number): number {
  return v < lo ? lo : v > hi ? hi : v;
}
