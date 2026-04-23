import { makeImageData } from '../../lib/image';

/**
 * 全画像ヒストグラム平坦化（グローバル）。L* チャンネル相当（輝度）だけ補正する簡易版。
 * CLAHE の純TS実装は重いため、まずはグローバル平坦化で照明ムラを緩和する。
 */
export function applyHistEqualizeRgba(src: ImageData): ImageData {
  const { width: w, height: h, data } = src;
  const n = w * h;
  const hist = new Float64Array(256);
  const lum = new Uint8Array(n);
  for (let i = 0, j = 0; i < data.length; i += 4, j++) {
    const Y = Math.round(0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2]);
    lum[j] = Y;
    hist[Y]++;
  }
  const cdf = new Float64Array(256);
  let acc = 0;
  for (let i = 0; i < 256; i++) {
    acc += hist[i];
    cdf[i] = acc / n;
  }
  const lut = new Uint8Array(256);
  for (let i = 0; i < 256; i++) lut[i] = Math.round(cdf[i] * 255);

  const out = new Uint8ClampedArray(data.length);
  for (let i = 0, j = 0; i < data.length; i += 4, j++) {
    const y = lum[j];
    const yNew = lut[y];
    const scale = y === 0 ? 1 : yNew / y;
    out[i] = Math.min(255, data[i] * scale);
    out[i + 1] = Math.min(255, data[i + 1] * scale);
    out[i + 2] = Math.min(255, data[i + 2] * scale);
    out[i + 3] = 255;
  }
  return makeImageData(out, w, h);
}

/**
 * 参照画像の輝度分布に対象画像を揃えるヒストグラムマッチング（輝度のみ）。
 * 色チャネルには同じ輝度比を適用して色相を保持する。
 */
export function matchLumaHistogramRgba(
  reference: ImageData,
  target: ImageData,
): ImageData {
  const refCdf = lumaCdf(reference);
  const tgtCdf = lumaCdf(target);
  const lut = new Uint8Array(256);
  let j = 0;
  for (let i = 0; i < 256; i++) {
    while (j < 255 && refCdf[j] < tgtCdf[i]) j++;
    lut[i] = j;
  }
  const { width: w, height: h, data } = target;
  const out = new Uint8ClampedArray(data.length);
  for (let i = 0; i < data.length; i += 4) {
    const Y = Math.round(0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2]);
    const Ynew = lut[Y];
    const s = Y === 0 ? 1 : Ynew / Y;
    out[i] = Math.min(255, data[i] * s);
    out[i + 1] = Math.min(255, data[i + 1] * s);
    out[i + 2] = Math.min(255, data[i + 2] * s);
    out[i + 3] = 255;
  }
  return makeImageData(out, w, h);
}

function lumaCdf(img: ImageData): Float64Array {
  const { data } = img;
  const n = data.length / 4;
  const hist = new Float64Array(256);
  for (let i = 0; i < data.length; i += 4) {
    const Y = Math.round(0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2]);
    hist[Y]++;
  }
  for (let i = 0; i < 256; i++) hist[i] /= n;
  const cdf = new Float64Array(256);
  let acc = 0;
  for (let i = 0; i < 256; i++) {
    acc += hist[i];
    cdf[i] = acc;
  }
  return cdf;
}
