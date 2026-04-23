import { rgbaToGray, resizeRgbaBilinear, warpPerspectiveRgba } from '../../lib/image';
import { computeHomography, invert3x3, type Point } from '../../lib/homography';

/**
 * 自動整列（純 TS）。Harris コーナー検出 → 正規化相互相関マッチ → RANSAC ホモグラフィ推定。
 *
 *   1. 両画像を解析解像度（512px 長辺）にリサイズ → グレースケール
 *   2. Harris + 非最大抑制で上位 N コーナー抽出
 *   3. 各コーナー周辺の正規化パッチ（11×11）を抽出
 *   4. 全対全の NCC で最良マッチを見つける（相互チェック）
 *   5. RANSAC で 4 点ホモグラフィを推定、インライアが最多の解を選ぶ
 *   6. 元解像度の右画像を、推定した H で左画像の座標系にワープ
 */

const CORNER_COUNT = 300;
const PATCH_RADIUS = 5; // 11x11 パッチ
const RANSAC_ITER = 600;
const RANSAC_THRESH = 4; // 解析解像度基準のピクセル
const NCC_THRESH = 0.6;

export interface AutoAlignResult {
  alignedRight: ImageData;
  inliers: number;
  matches: number;
  homography: number[];
  ok: boolean;
}

export function autoAlign(left: ImageData, right: ImageData): AutoAlignResult {
  const SIDE = 512;
  const scaleL = Math.min(1, SIDE / Math.max(left.width, left.height));
  const scaleR = Math.min(1, SIDE / Math.max(right.width, right.height));
  const lw = Math.max(64, Math.round(left.width * scaleL));
  const lh = Math.max(64, Math.round(left.height * scaleL));
  const rw = Math.max(64, Math.round(right.width * scaleR));
  const rh = Math.max(64, Math.round(right.height * scaleR));

  const lRgba = scaleL === 1 ? left.data : resizeRgbaBilinear(left.data, left.width, left.height, lw, lh);
  const rRgba = scaleR === 1 ? right.data : resizeRgbaBilinear(right.data, right.width, right.height, rw, rh);
  const lGray = rgbaToGray(lRgba, lw, lh);
  const rGray = rgbaToGray(rRgba, rw, rh);

  const lCorners = harrisCorners(lGray, lw, lh, CORNER_COUNT);
  const rCorners = harrisCorners(rGray, rw, rh, CORNER_COUNT);
  const matches = mutualNccMatches(lGray, lw, lh, lCorners, rGray, rw, rh, rCorners);

  if (matches.length < 8) {
    return {
      alignedRight: right,
      inliers: 0,
      matches: matches.length,
      homography: [1, 0, 0, 0, 1, 0, 0, 0, 1],
      ok: false,
    };
  }

  // RANSAC で整列解析空間でのホモグラフィを推定
  const { H, inliers } = ransacHomography(matches);
  if (inliers.length < 6 || !H) {
    return {
      alignedRight: right,
      inliers: 0,
      matches: matches.length,
      homography: [1, 0, 0, 0, 1, 0, 0, 0, 1],
      ok: false,
    };
  }

  // 解析空間 → 原寸スケールへ H を変換
  // H は「右（解析空間）→左（解析空間）」座標の対応。
  // 元解像度の右画像を左画像サイズへワープするには:
  //   原寸右 → 解析右 → (H) → 解析左 → 原寸左
  // H は「解析右 → 解析左」。これを「原寸右 → 原寸左」へ変換する:
  //   原寸左 = S_L^{-1} × H × S_R × 原寸右
  //   S_L = diag(scaleL, scaleL, 1),  S_R = diag(scaleR, scaleR, 1)
  //
  // 行列合成を展開すると:
  //   Hfull[0..1] = H[0..1] * (scaleR / scaleL)
  //   Hfull[2]    = H[2] / scaleL
  //   Hfull[3..4] = H[3..4] * (scaleR / scaleL)
  //   Hfull[5]    = H[5] / scaleL
  //   Hfull[6..7] = H[6..7] * scaleR   ← ここが bug の元。scaleR を掛けるのが正解
  //   Hfull[8]    = H[8]
  const k = scaleR / scaleL;
  const Hfull = [
    H[0] * k, H[1] * k, H[2] / scaleL,
    H[3] * k, H[4] * k, H[5] / scaleL,
    H[6] * scaleR, H[7] * scaleR, H[8],
  ];

  const Hinv = invert3x3(Hfull);
  const warped = warpPerspectiveRgba(
    right.data,
    right.width,
    right.height,
    left.width,
    left.height,
    Hinv,
  );

  const alignedRight: ImageData = new ImageData(
    new Uint8ClampedArray(warped),
    left.width,
    left.height,
  );

  return {
    alignedRight,
    inliers: inliers.length,
    matches: matches.length,
    homography: Hfull,
    ok: true,
  };
}

// -------- Harris コーナー検出 --------
function harrisCorners(gray: Float32Array, w: number, h: number, count: number): Point[] {
  const ix = new Float32Array(w * h);
  const iy = new Float32Array(w * h);
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      const i = y * w + x;
      // Sobel
      const gx =
        -gray[i - w - 1] - 2 * gray[i - 1] - gray[i + w - 1] +
         gray[i - w + 1] + 2 * gray[i + 1] + gray[i + w + 1];
      const gy =
        -gray[i - w - 1] - 2 * gray[i - w] - gray[i - w + 1] +
         gray[i + w - 1] + 2 * gray[i + w] + gray[i + w + 1];
      ix[i] = gx;
      iy[i] = gy;
    }
  }
  const ixx = new Float32Array(w * h);
  const iyy = new Float32Array(w * h);
  const ixy = new Float32Array(w * h);
  for (let i = 0; i < w * h; i++) {
    ixx[i] = ix[i] * ix[i];
    iyy[i] = iy[i] * iy[i];
    ixy[i] = ix[i] * iy[i];
  }
  // 3x3 ボックス窓で累積
  const sxx = boxBlur(ixx, w, h, 2);
  const syy = boxBlur(iyy, w, h, 2);
  const sxy = boxBlur(ixy, w, h, 2);

  const k = 0.04;
  const R = new Float32Array(w * h);
  for (let i = 0; i < w * h; i++) {
    const det = sxx[i] * syy[i] - sxy[i] * sxy[i];
    const tr = sxx[i] + syy[i];
    R[i] = det - k * tr * tr;
  }

  // 3x3 NMS + 閾値で上位を取る
  const radius = 3;
  const candidates: Array<[number, number, number]> = [];
  for (let y = radius; y < h - radius; y++) {
    for (let x = radius; x < w - radius; x++) {
      const v = R[y * w + x];
      if (v <= 0) continue;
      let isMax = true;
      for (let dy = -1; dy <= 1 && isMax; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (dx === 0 && dy === 0) continue;
          if (R[(y + dy) * w + (x + dx)] > v) {
            isMax = false;
            break;
          }
        }
      }
      if (isMax) candidates.push([x, y, v]);
    }
  }
  candidates.sort((a, b) => b[2] - a[2]);
  const picked: Point[] = [];
  const minDist = 12;
  const minDist2 = minDist * minDist;
  for (const [x, y] of candidates) {
    if (picked.length >= count) break;
    let ok = true;
    for (const p of picked) {
      const dx = p.x - x;
      const dy = p.y - y;
      if (dx * dx + dy * dy < minDist2) {
        ok = false;
        break;
      }
    }
    if (ok) picked.push({ x, y });
  }
  return picked;
}

function boxBlur(src: Float32Array, w: number, h: number, r: number): Float32Array {
  const out = new Float32Array(src.length);
  const tmp = new Float32Array(src.length);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let s = 0;
      let n = 0;
      for (let k = -r; k <= r; k++) {
        const xx = x + k;
        if (xx < 0 || xx >= w) continue;
        s += src[y * w + xx];
        n++;
      }
      tmp[y * w + x] = s / Math.max(1, n);
    }
  }
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let s = 0;
      let n = 0;
      for (let k = -r; k <= r; k++) {
        const yy = y + k;
        if (yy < 0 || yy >= h) continue;
        s += tmp[yy * w + x];
        n++;
      }
      out[y * w + x] = s / Math.max(1, n);
    }
  }
  return out;
}

// -------- 相互 NCC マッチ --------
function extractPatch(
  gray: Float32Array,
  w: number,
  h: number,
  cx: number,
  cy: number,
): Float32Array | null {
  const r = PATCH_RADIUS;
  if (cx - r < 0 || cx + r >= w || cy - r < 0 || cy + r >= h) return null;
  const size = (2 * r + 1) * (2 * r + 1);
  const patch = new Float32Array(size);
  let mean = 0;
  let idx = 0;
  for (let j = -r; j <= r; j++) {
    for (let i = -r; i <= r; i++) {
      const v = gray[(cy + j) * w + (cx + i)];
      patch[idx++] = v;
      mean += v;
    }
  }
  mean /= size;
  let sqSum = 0;
  for (let i = 0; i < size; i++) {
    patch[i] -= mean;
    sqSum += patch[i] * patch[i];
  }
  const norm = Math.sqrt(sqSum) + 1e-6;
  for (let i = 0; i < size; i++) patch[i] /= norm;
  return patch;
}

function ncc(a: Float32Array, b: Float32Array): number {
  let s = 0;
  for (let i = 0; i < a.length; i++) s += a[i] * b[i];
  return s;
}

function mutualNccMatches(
  lGray: Float32Array,
  lw: number,
  lh: number,
  lCorners: Point[],
  rGray: Float32Array,
  rw: number,
  rh: number,
  rCorners: Point[],
): Array<[Point, Point]> {
  const lPatches = lCorners.map((p) => extractPatch(lGray, lw, lh, p.x, p.y));
  const rPatches = rCorners.map((p) => extractPatch(rGray, rw, rh, p.x, p.y));

  const lToR: number[] = new Array(lCorners.length).fill(-1);
  const lToRScore: number[] = new Array(lCorners.length).fill(-1);
  for (let i = 0; i < lCorners.length; i++) {
    const lp = lPatches[i];
    if (!lp) continue;
    let bestJ = -1;
    let bestScore = NCC_THRESH;
    for (let j = 0; j < rCorners.length; j++) {
      const rp = rPatches[j];
      if (!rp) continue;
      const s = ncc(lp, rp);
      if (s > bestScore) {
        bestScore = s;
        bestJ = j;
      }
    }
    lToR[i] = bestJ;
    lToRScore[i] = bestScore;
  }

  const rToL: number[] = new Array(rCorners.length).fill(-1);
  const rToLScore: number[] = new Array(rCorners.length).fill(-1);
  for (let j = 0; j < rCorners.length; j++) {
    const rp = rPatches[j];
    if (!rp) continue;
    let bestI = -1;
    let bestScore = NCC_THRESH;
    for (let i = 0; i < lCorners.length; i++) {
      const lp = lPatches[i];
      if (!lp) continue;
      const s = ncc(lp, rp);
      if (s > bestScore) {
        bestScore = s;
        bestI = i;
      }
    }
    rToL[j] = bestI;
    rToLScore[j] = bestScore;
  }

  // 相互チェック: i の最良が j, かつ j の最良が i ならペア採用
  const pairs: Array<[Point, Point]> = [];
  for (let i = 0; i < lCorners.length; i++) {
    const j = lToR[i];
    if (j < 0) continue;
    if (rToL[j] !== i) continue;
    pairs.push([lCorners[i], rCorners[j]]);
  }
  return pairs;
}

// -------- RANSAC ホモグラフィ --------
function ransacHomography(
  matches: Array<[Point, Point]>,
): { H: number[] | null; inliers: number[] } {
  if (matches.length < 4) return { H: null, inliers: [] };
  let bestH: number[] | null = null;
  let bestIn: number[] = [];
  const thresh2 = RANSAC_THRESH * RANSAC_THRESH;
  const n = matches.length;
  for (let iter = 0; iter < RANSAC_ITER; iter++) {
    const idxs = pick4Unique(n);
    const srcPts = idxs.map((k) => matches[k][1]); // right → left
    const dstPts = idxs.map((k) => matches[k][0]);
    // 退化回避（同一直線など）
    if (isDegenerate(srcPts) || isDegenerate(dstPts)) continue;
    let H: number[];
    try {
      H = computeHomography(srcPts, dstPts);
    } catch {
      continue;
    }
    const inliers: number[] = [];
    for (let i = 0; i < n; i++) {
      const [l, r] = matches[i];
      const w = H[6] * r.x + H[7] * r.y + H[8];
      if (Math.abs(w) < 1e-8) continue;
      const px = (H[0] * r.x + H[1] * r.y + H[2]) / w;
      const py = (H[3] * r.x + H[4] * r.y + H[5]) / w;
      const dx = px - l.x;
      const dy = py - l.y;
      if (dx * dx + dy * dy < thresh2) inliers.push(i);
    }
    if (inliers.length > bestIn.length) {
      bestIn = inliers;
      bestH = H;
    }
  }
  return { H: bestH, inliers: bestIn };
}

function pick4Unique(n: number): [number, number, number, number] {
  const a = Math.floor(Math.random() * n);
  let b;
  do {
    b = Math.floor(Math.random() * n);
  } while (b === a);
  let c;
  do {
    c = Math.floor(Math.random() * n);
  } while (c === a || c === b);
  let d;
  do {
    d = Math.floor(Math.random() * n);
  } while (d === a || d === b || d === c);
  return [a, b, c, d];
}

function isDegenerate(pts: Point[]): boolean {
  // 3点が同一直線付近なら退化（4x3 すべての3点組を軽くチェック）
  for (let i = 0; i < 4; i++) {
    for (let j = i + 1; j < 4; j++) {
      for (let k = j + 1; k < 4; k++) {
        const cross =
          (pts[j].x - pts[i].x) * (pts[k].y - pts[i].y) -
          (pts[j].y - pts[i].y) * (pts[k].x - pts[i].x);
        if (Math.abs(cross) < 1) return true;
      }
    }
  }
  return false;
}
