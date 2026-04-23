import { rgbaToGray, normalizeFloat } from '../../lib/image';

/**
 * 線画比較チャネル:
 *   1. 両画像をグレースケール化
 *   2. Otsu 二値化で黒（線）/ 白（地）に分ける
 *   3. 両方の線マスクに膨張（3x3）をかけて位置ズレを吸収
 *   4. XOR → 片方にしかない線のみが残る
 *   5. 距離変換で「線からの距離」に変換し、正確にゼロになる領域を除外
 *
 * モノクロ線画の間違い探しで、撮影時の色味差に惑わされず線の形状差を検出できる。
 */
export function lineartDiffMap(
  leftRgba: Uint8ClampedArray,
  rightRgba: Uint8ClampedArray,
  w: number,
  h: number,
): Float32Array {
  const gl = rgbaToGray(leftRgba, w, h);
  const gr = rgbaToGray(rightRgba, w, h);
  const maskL = otsuMaskInverted(gl);
  const maskR = otsuMaskInverted(gr);
  const dilL = dilate3x3(maskL, w, h, 2);
  const dilR = dilate3x3(maskR, w, h, 2);

  // XOR: 片方にしかない線ピクセルを前景とする
  const out = new Float32Array(w * h);
  for (let i = 0; i < out.length; i++) {
    out[i] = dilL[i] === dilR[i] ? 0 : 1;
  }

  // 膨張して大きな輝点を形成（検出しやすいように）
  return normalizeFloat(dilate3x3Float(out, w, h, 2));
}

function otsuMaskInverted(gray: Float32Array): Uint8Array {
  const hist = new Float64Array(256);
  for (let i = 0; i < gray.length; i++) {
    const b = Math.min(255, Math.max(0, Math.round(gray[i])));
    hist[b]++;
  }
  const total = gray.length;
  let sum = 0;
  for (let i = 0; i < 256; i++) sum += i * hist[i];
  let wB = 0;
  let sumB = 0;
  let maxVar = -1;
  let threshold = 128;
  for (let t = 0; t < 256; t++) {
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
  const mask = new Uint8Array(gray.length);
  for (let i = 0; i < gray.length; i++) mask[i] = gray[i] < threshold ? 1 : 0;
  return mask;
}

function dilate3x3(mask: Uint8Array, w: number, h: number, iterations = 1): Uint8Array {
  let cur = mask;
  for (let it = 0; it < iterations; it++) {
    const out = new Uint8Array(cur.length);
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        let v = 0;
        for (let dy = -1; dy <= 1 && !v; dy++) {
          const yy = y + dy;
          if (yy < 0 || yy >= h) continue;
          for (let dx = -1; dx <= 1; dx++) {
            const xx = x + dx;
            if (xx < 0 || xx >= w) continue;
            if (cur[yy * w + xx]) {
              v = 1;
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

function dilate3x3Float(src: Float32Array, w: number, h: number, iterations = 1): Float32Array {
  let cur = src;
  for (let it = 0; it < iterations; it++) {
    const out = new Float32Array(cur.length);
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        let mx = 0;
        for (let dy = -1; dy <= 1; dy++) {
          const yy = y + dy;
          if (yy < 0 || yy >= h) continue;
          for (let dx = -1; dx <= 1; dx++) {
            const xx = x + dx;
            if (xx < 0 || xx >= w) continue;
            const v = cur[yy * w + xx];
            if (v > mx) mx = v;
          }
        }
        out[y * w + x] = mx;
      }
    }
    cur = out;
  }
  return cur;
}
