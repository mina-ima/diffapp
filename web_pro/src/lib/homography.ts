export interface Point {
  x: number;
  y: number;
}

/**
 * 4組の対応点から射影変換行列（3x3 homography）を計算する（DLT法）。
 * src[i] → dst[i] の対応を最小二乗で当てはめる（ただし 4 点なら厳密解）。
 * 戻り値は 9 要素の配列で、h33 = 1 に正規化済み。
 */
export function computeHomography(src: Point[], dst: Point[]): number[] {
  if (src.length !== 4 || dst.length !== 4) {
    throw new Error('computeHomography requires exactly 4 point pairs');
  }
  const A: number[][] = [];
  const b: number[] = [];
  for (let i = 0; i < 4; i++) {
    const { x, y } = src[i];
    const { x: u, y: v } = dst[i];
    A.push([x, y, 1, 0, 0, 0, -u * x, -u * y]);
    b.push(u);
    A.push([0, 0, 0, x, y, 1, -v * x, -v * y]);
    b.push(v);
  }
  const h = solveLinearSystem(A, b);
  return [h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], 1];
}

/**
 * n (>=4) 個の対応点から最小二乗ホモグラフィを求める。
 * 4 点 RANSAC で得た H をインライア全体で refine するのに使う。
 *
 * 正規方程式 (AᵀA) h = Aᵀb を解く。n が大きいほど条件がよくなり、
 * サブピクセル精度の整列が実現できる。
 */
export function computeHomographyLSQ(src: Point[], dst: Point[]): number[] {
  const n = src.length;
  if (n !== dst.length || n < 4) {
    throw new Error('computeHomographyLSQ: need >=4 matched pairs');
  }
  const AtA: number[][] = Array.from({ length: 8 }, () => new Array(8).fill(0));
  const Atb: number[] = new Array(8).fill(0);
  const row = new Array(8);
  for (let i = 0; i < n; i++) {
    const { x, y } = src[i];
    const { x: u, y: v } = dst[i];
    // u 方程式
    row[0] = x; row[1] = y; row[2] = 1;
    row[3] = 0; row[4] = 0; row[5] = 0;
    row[6] = -u * x; row[7] = -u * y;
    for (let a = 0; a < 8; a++) {
      Atb[a] += row[a] * u;
      for (let b = 0; b < 8; b++) AtA[a][b] += row[a] * row[b];
    }
    // v 方程式
    row[0] = 0; row[1] = 0; row[2] = 0;
    row[3] = x; row[4] = y; row[5] = 1;
    row[6] = -v * x; row[7] = -v * y;
    for (let a = 0; a < 8; a++) {
      Atb[a] += row[a] * v;
      for (let b = 0; b < 8; b++) AtA[a][b] += row[a] * row[b];
    }
  }
  const h = solveLinearSystem(AtA, Atb);
  return [h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], 1];
}

/**
 * 3x3 行列の逆行列。warpPerspective 用の逆変換行列を得るのに使う。
 */
export function invert3x3(m: number[]): number[] {
  const a = m[0], bb = m[1], c = m[2];
  const d = m[3], e = m[4], f = m[5];
  const g = m[6], h = m[7], i = m[8];
  const det =
    a * (e * i - f * h) - bb * (d * i - f * g) + c * (d * h - e * g);
  if (Math.abs(det) < 1e-10) {
    throw new Error('Matrix is singular, cannot invert');
  }
  const invDet = 1 / det;
  return [
    (e * i - f * h) * invDet,
    (c * h - bb * i) * invDet,
    (bb * f - c * e) * invDet,
    (f * g - d * i) * invDet,
    (a * i - c * g) * invDet,
    (c * d - a * f) * invDet,
    (d * h - e * g) * invDet,
    (bb * g - a * h) * invDet,
    (a * e - bb * d) * invDet,
  ];
}

/** 行列 H を点 p に適用し、射影された点を返す */
export function applyHomography(H: number[], p: Point): Point {
  const w = H[6] * p.x + H[7] * p.y + H[8];
  return {
    x: (H[0] * p.x + H[1] * p.y + H[2]) / w,
    y: (H[3] * p.x + H[4] * p.y + H[5]) / w,
  };
}

/** 部分ピボット選択付きガウス消去で Ax=b を解く */
function solveLinearSystem(A: number[][], b: number[]): number[] {
  const n = A.length;
  const M: number[][] = A.map((row, i) => [...row, b[i]]);
  for (let i = 0; i < n; i++) {
    let maxRow = i;
    let maxVal = Math.abs(M[i][i]);
    for (let k = i + 1; k < n; k++) {
      if (Math.abs(M[k][i]) > maxVal) {
        maxVal = Math.abs(M[k][i]);
        maxRow = k;
      }
    }
    if (maxVal < 1e-12) throw new Error('Singular matrix');
    [M[i], M[maxRow]] = [M[maxRow], M[i]];
    for (let k = i + 1; k < n; k++) {
      const factor = M[k][i] / M[i][i];
      for (let j = i; j <= n; j++) {
        M[k][j] -= factor * M[i][j];
      }
    }
  }
  const x = new Array(n).fill(0);
  for (let i = n - 1; i >= 0; i--) {
    let s = M[i][n];
    for (let j = i + 1; j < n; j++) s -= M[i][j] * x[j];
    x[i] = s / M[i][i];
  }
  return x;
}
