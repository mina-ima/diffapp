import { rgbaToGray, resizeRgbaBilinear, warpPerspectiveRgba } from '../../lib/image';
import { computeHomography, computeHomographyLSQ, invert3x3, type Point } from '../../lib/homography';

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
const RANSAC_ITER = 800;
const RANSAC_THRESH = 3; // 解析解像度基準のピクセル（refine 前）
const RANSAC_REFINE_THRESH = 2; // refine 後の再インライア判定
const NCC_THRESH = 0.6;
// Lowe's ratio test: best NCC が 2nd best の ratio 倍以上なら採用（曖昧マッチを除外）
const LOWE_RATIO = 0.85;
// CLAHE: タイル数（8 なら 8x8 タイルに分割）+ クリップ上限（コントラストの暴走を防ぐ）
const CLAHE_TILES = 8;
const CLAHE_CLIP = 4.0;

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
  // 照明ムラを CLAHE で平準化してから特徴抽出（スマホ撮影で効く）
  const lGray = claheGray(rgbaToGray(lRgba, lw, lh), lw, lh);
  const rGray = claheGray(rgbaToGray(rRgba, rw, rh), rw, rh);

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

  // RANSAC で粗い H を推定 → 全インライアで最小二乗 refine → 再判定でさらに絞る
  const { H: Hcoarse, inliers: coarseInliers } = ransacHomography(matches);
  if (coarseInliers.length < 6 || !Hcoarse) {
    return {
      alignedRight: right,
      inliers: 0,
      matches: matches.length,
      homography: [1, 0, 0, 0, 1, 0, 0, 0, 1],
      ok: false,
    };
  }

  // 粗インライアで LSQ refine
  let H = Hcoarse;
  let inliers = coarseInliers;
  try {
    const refined = computeHomographyLSQ(
      coarseInliers.map((k) => matches[k][1]),
      coarseInliers.map((k) => matches[k][0]),
    );
    // refine 後にもう一度 inlier を取り直す（厳しめ）
    const refinedInliers: number[] = [];
    const t2 = RANSAC_REFINE_THRESH * RANSAC_REFINE_THRESH;
    for (let i = 0; i < matches.length; i++) {
      const [l, r] = matches[i];
      const w = refined[6] * r.x + refined[7] * r.y + refined[8];
      if (Math.abs(w) < 1e-8) continue;
      const px = (refined[0] * r.x + refined[1] * r.y + refined[2]) / w;
      const py = (refined[3] * r.x + refined[4] * r.y + refined[5]) / w;
      const dx = px - l.x;
      const dy = py - l.y;
      if (dx * dx + dy * dy < t2) refinedInliers.push(i);
    }
    // 最終 refine: 再インライアで LSQ を再度
    if (refinedInliers.length >= 6) {
      const final = computeHomographyLSQ(
        refinedInliers.map((k) => matches[k][1]),
        refinedInliers.map((k) => matches[k][0]),
      );
      H = final;
      inliers = refinedInliers;
    } else {
      H = refined;
    }
  } catch {
    // LSQ が数値的に失敗した場合は RANSAC の H をそのまま使う
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
  // 左→右: 各左コーナーで best / secondBest をトラックし、Lowe's ratio を満たすものだけ残す
  for (let i = 0; i < lCorners.length; i++) {
    const lp = lPatches[i];
    if (!lp) continue;
    let bestJ = -1;
    let bestScore = -Infinity;
    let secondScore = -Infinity;
    for (let j = 0; j < rCorners.length; j++) {
      const rp = rPatches[j];
      if (!rp) continue;
      const s = ncc(lp, rp);
      if (s > bestScore) {
        secondScore = bestScore;
        bestScore = s;
        bestJ = j;
      } else if (s > secondScore) {
        secondScore = s;
      }
    }
    if (bestScore < NCC_THRESH) continue;
    // NCC は [-1,1] 類似度なので "距離" は (1-s)。Lowe: dist_best / dist_second < ratio
    // ⇔ (1-best) / (1-second) < ratio。second==best 相当なら除外される
    const dBest = 1 - bestScore;
    const dSecond = 1 - Math.max(-1, secondScore);
    if (dBest < dSecond * LOWE_RATIO) {
      lToR[i] = bestJ;
    }
  }

  const rToL: number[] = new Array(rCorners.length).fill(-1);
  for (let j = 0; j < rCorners.length; j++) {
    const rp = rPatches[j];
    if (!rp) continue;
    let bestI = -1;
    let bestScore = -Infinity;
    let secondScore = -Infinity;
    for (let i = 0; i < lCorners.length; i++) {
      const lp = lPatches[i];
      if (!lp) continue;
      const s = ncc(lp, rp);
      if (s > bestScore) {
        secondScore = bestScore;
        bestScore = s;
        bestI = i;
      } else if (s > secondScore) {
        secondScore = s;
      }
    }
    if (bestScore < NCC_THRESH) continue;
    const dBest = 1 - bestScore;
    const dSecond = 1 - Math.max(-1, secondScore);
    if (dBest < dSecond * LOWE_RATIO) {
      rToL[j] = bestI;
    }
  }

  // 相互チェック: i の最良が j, かつ j の最良が i ならペア採用（ratio test 通過者のみ）
  const pairs: Array<[Point, Point]> = [];
  for (let i = 0; i < lCorners.length; i++) {
    const j = lToR[i];
    if (j < 0) continue;
    if (rToL[j] !== i) continue;
    pairs.push([lCorners[i], rCorners[j]]);
  }
  return pairs;
}

// -------- CLAHE (Contrast Limited Adaptive Histogram Equalization) --------
// タイル分割して各タイルのヒストグラムを正規化 → 双一次補間で段差を消す。
// 照明ムラのある撮影画像でも Harris コーナーが平等に検出できるようになる。
function claheGray(src: Float32Array, w: number, h: number): Float32Array {
  const TILES = CLAHE_TILES;
  const BINS = 64; // 256 階調を 64 段に圧縮（ヒストグラムが密になって速い）
  const tileW = Math.max(1, Math.floor(w / TILES));
  const tileH = Math.max(1, Math.floor(h / TILES));
  // 各タイルのマッピング（元 bin → 出力 bin）を構築
  const maps: Float32Array[] = new Array(TILES * TILES);
  const pixelsPerTile = tileW * tileH;
  const clipLimit = Math.max(1, Math.round((CLAHE_CLIP * pixelsPerTile) / BINS));
  for (let ty = 0; ty < TILES; ty++) {
    const y0 = ty * tileH;
    const y1 = ty === TILES - 1 ? h : y0 + tileH;
    for (let tx = 0; tx < TILES; tx++) {
      const x0 = tx * tileW;
      const x1 = tx === TILES - 1 ? w : x0 + tileW;
      const hist = new Int32Array(BINS);
      for (let yy = y0; yy < y1; yy++) {
        const row = yy * w;
        for (let xx = x0; xx < x1; xx++) {
          const v = src[row + xx];
          let b = Math.floor((v * BINS) / 256);
          if (b < 0) b = 0;
          if (b >= BINS) b = BINS - 1;
          hist[b]++;
        }
      }
      // ヒストグラムをクリップしてエクセスを均等再配分
      let excess = 0;
      for (let b = 0; b < BINS; b++) {
        if (hist[b] > clipLimit) {
          excess += hist[b] - clipLimit;
          hist[b] = clipLimit;
        }
      }
      const per = Math.floor(excess / BINS);
      for (let b = 0; b < BINS; b++) hist[b] += per;
      let remain = excess - per * BINS;
      for (let b = 0; b < BINS && remain > 0; b++, remain--) hist[b]++;
      // CDF → 0..255 マッピング
      const total = (y1 - y0) * (x1 - x0);
      const map = new Float32Array(BINS);
      let acc = 0;
      for (let b = 0; b < BINS; b++) {
        acc += hist[b];
        map[b] = (acc * 255) / total;
      }
      maps[ty * TILES + tx] = map;
    }
  }
  // タイル 4 近傍のマッピングを双一次補間して各ピクセルに適用
  const out = new Float32Array(src.length);
  for (let y = 0; y < h; y++) {
    const fy = y / tileH - 0.5;
    let ty0 = Math.floor(fy);
    let ty1 = ty0 + 1;
    const wy = fy - ty0;
    if (ty0 < 0) ty0 = 0;
    if (ty1 > TILES - 1) ty1 = TILES - 1;
    for (let x = 0; x < w; x++) {
      const fx = x / tileW - 0.5;
      let tx0 = Math.floor(fx);
      let tx1 = tx0 + 1;
      const wx = fx - tx0;
      if (tx0 < 0) tx0 = 0;
      if (tx1 > TILES - 1) tx1 = TILES - 1;
      const v = src[y * w + x];
      let b = Math.floor((v * BINS) / 256);
      if (b < 0) b = 0;
      if (b >= BINS) b = BINS - 1;
      const m00 = maps[ty0 * TILES + tx0][b];
      const m10 = maps[ty0 * TILES + tx1][b];
      const m01 = maps[ty1 * TILES + tx0][b];
      const m11 = maps[ty1 * TILES + tx1][b];
      const mx0 = m00 * (1 - wx) + m10 * wx;
      const mx1 = m01 * (1 - wx) + m11 * wx;
      out[y * w + x] = mx0 * (1 - wy) + mx1 * wy;
    }
  }
  return out;
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
