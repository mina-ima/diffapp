import { rgbaToGray } from '../../lib/image';

/**
 * ローカルブロックマッチングで残留ミスアラインを吸収する。
 *
 * ホモグラフィ整列のあと、カメラ撮影画像にはどうしても非剛体的な歪み
 * （レンズ歪み、手ブレでの微小回転、被写体が平面でない）が残り、
 * 場所によって 1〜3px ずれが残る。素朴にピクセル差分を取ると
 * エッジが全域で「二重化」して差分マップが無意味になる。
 *
 * 対策: 画像をグリッド分割し、各グリッド点で右画像を ±SEARCH_R 画素
 * スライドさせて左画像との SAD（Sum of Absolute Difference）が最小に
 * なる位置を探す → 得られた局所ずれベクトル場をバイリニア補間して
 * 右画像全体を dense warp する。
 *
 * これにより「少しずつずらして最も重複する状態」で各領域が揃い、
 * 本当に違う箇所だけが差分として残る。
 */

const BLOCK_R = 10; // 21x21 ブロック
const BLOCK_STEP = 2; // ブロック内サブサンプリング（速度優先）
const GRID_STRIDE = 8; // フローグリッドの間隔
const SEARCH_R = 5; // ±5px 探索

export function locallyRefineRight(left: ImageData, right: ImageData): ImageData {
  const w = left.width;
  const h = left.height;
  if (right.width !== w || right.height !== h) return right;

  const lGray = rgbaToGray(left.data, w, h);
  const rGray = rgbaToGray(right.data, w, h);

  const gW = Math.max(2, Math.ceil(w / GRID_STRIDE));
  const gH = Math.max(2, Math.ceil(h / GRID_STRIDE));
  const flowX = new Float32Array(gW * gH);
  const flowY = new Float32Array(gW * gH);

  // 1) 各グリッド点で局所平行シフトを推定（SAD 最小化）
  for (let gy = 0; gy < gH; gy++) {
    const cy = Math.min(h - 1, gy * GRID_STRIDE + (GRID_STRIDE >> 1));
    for (let gx = 0; gx < gW; gx++) {
      const cx = Math.min(w - 1, gx * GRID_STRIDE + (GRID_STRIDE >> 1));
      let bestSad = Infinity;
      let bestDx = 0;
      let bestDy = 0;
      for (let dy = -SEARCH_R; dy <= SEARCH_R; dy++) {
        for (let dx = -SEARCH_R; dx <= SEARCH_R; dx++) {
          let sad = 0;
          let cnt = 0;
          for (let py = -BLOCK_R; py <= BLOCK_R; py += BLOCK_STEP) {
            const ly = cy + py;
            const ry = cy + py + dy;
            if (ly < 0 || ly >= h || ry < 0 || ry >= h) continue;
            const lrow = ly * w;
            const rrow = ry * w;
            for (let px = -BLOCK_R; px <= BLOCK_R; px += BLOCK_STEP) {
              const lx = cx + px;
              const rx = cx + px + dx;
              if (lx < 0 || lx >= w || rx < 0 || rx >= w) continue;
              const d = lGray[lrow + lx] - rGray[rrow + rx];
              sad += d >= 0 ? d : -d;
              cnt++;
            }
          }
          if (cnt < 20) continue; // ブロックがほぼ範囲外 → 無効
          const norm = sad / cnt;
          if (norm < bestSad) {
            bestSad = norm;
            bestDx = dx;
            bestDy = dy;
          }
        }
      }
      flowX[gy * gW + gx] = bestDx;
      flowY[gy * gW + gx] = bestDy;
    }
  }

  // 2) 3x3 メディアンでフローを平滑化（外れ値のブロックを抑える）
  const fx = median3x3(flowX, gW, gH);
  const fy = median3x3(flowY, gW, gH);

  // 3) フローのバイリニア補間で右画像を dense warp
  const src = right.data;
  const out = new Uint8ClampedArray(w * h * 4);
  for (let y = 0; y < h; y++) {
    const gyf = (y - (GRID_STRIDE >> 1)) / GRID_STRIDE;
    const gy0 = Math.max(0, Math.min(gH - 1, Math.floor(gyf)));
    const gy1 = Math.max(0, Math.min(gH - 1, gy0 + 1));
    const wy = Math.max(0, Math.min(1, gyf - gy0));
    for (let x = 0; x < w; x++) {
      const gxf = (x - (GRID_STRIDE >> 1)) / GRID_STRIDE;
      const gx0 = Math.max(0, Math.min(gW - 1, Math.floor(gxf)));
      const gx1 = Math.max(0, Math.min(gW - 1, gx0 + 1));
      const wx = Math.max(0, Math.min(1, gxf - gx0));
      const dx =
        (fx[gy0 * gW + gx0] * (1 - wx) + fx[gy0 * gW + gx1] * wx) * (1 - wy) +
        (fx[gy1 * gW + gx0] * (1 - wx) + fx[gy1 * gW + gx1] * wx) * wy;
      const dy =
        (fy[gy0 * gW + gx0] * (1 - wx) + fy[gy0 * gW + gx1] * wx) * (1 - wy) +
        (fy[gy1 * gW + gx0] * (1 - wx) + fy[gy1 * gW + gx1] * wx) * wy;
      const sx = x + dx;
      const sy = y + dy;
      const di = (y * w + x) * 4;
      if (sx < 0 || sx > w - 1 || sy < 0 || sy > h - 1) {
        out[di + 3] = 0; // 範囲外 → 無効
        continue;
      }
      const x0 = Math.floor(sx);
      const x1 = Math.min(w - 1, x0 + 1);
      const y0 = Math.floor(sy);
      const y1 = Math.min(h - 1, y0 + 1);
      const bwx = sx - x0;
      const bwy = sy - y0;
      const i00 = (y0 * w + x0) * 4;
      const i10 = (y0 * w + x1) * 4;
      const i01 = (y1 * w + x0) * 4;
      const i11 = (y1 * w + x1) * 4;
      for (let c = 0; c < 4; c++) {
        out[di + c] =
          src[i00 + c] * (1 - bwx) * (1 - bwy) +
          src[i10 + c] * bwx * (1 - bwy) +
          src[i01 + c] * (1 - bwx) * bwy +
          src[i11 + c] * bwx * bwy;
      }
    }
  }
  return new ImageData(out, w, h);
}

function median3x3(src: Float32Array, w: number, h: number): Float32Array {
  const out = new Float32Array(src.length);
  const vals = new Float32Array(9);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let k = 0;
      for (let dy = -1; dy <= 1; dy++) {
        const yy = Math.max(0, Math.min(h - 1, y + dy));
        for (let dx = -1; dx <= 1; dx++) {
          const xx = Math.max(0, Math.min(w - 1, x + dx));
          vals[k++] = src[yy * w + xx];
        }
      }
      // 9 要素なら insertion sort で十分
      for (let i = 1; i < 9; i++) {
        const v = vals[i];
        let j = i - 1;
        while (j >= 0 && vals[j] > v) {
          vals[j + 1] = vals[j];
          j--;
        }
        vals[j + 1] = v;
      }
      out[y * w + x] = vals[4];
    }
  }
  return out;
}
