import { describe, expect, it } from 'vitest';
import { ciede2000Map } from '../ciede2000';

function fill(w: number, h: number, rgb: [number, number, number]): Uint8ClampedArray {
  const out = new Uint8ClampedArray(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    out[i * 4] = rgb[0];
    out[i * 4 + 1] = rgb[1];
    out[i * 4 + 2] = rgb[2];
    out[i * 4 + 3] = 255;
  }
  return out;
}

function meanOf(
  map: Float32Array,
  w: number,
  x0: number,
  y0: number,
  w2: number,
  h2: number,
): number {
  let s = 0;
  let n = 0;
  for (let y = y0; y < y0 + h2; y++) {
    for (let x = x0; x < x0 + w2; x++) {
      s += map[y * w + x];
      n++;
    }
  }
  return s / Math.max(1, n);
}

describe('CIEDE2000 map', () => {
  it('is zero for identical images', () => {
    const a = fill(4, 4, [50, 80, 90]);
    const b = fill(4, 4, [50, 80, 90]);
    const map = ciede2000Map(a, b, 4, 4);
    for (const v of map) expect(v).toBeLessThanOrEqual(1e-6);
  });

  it('is higher where colors differ than where they match', () => {
    // 一様な差だと normalizeFloat で 0 に畳まれるため、半分だけ色を変えた画像を用意。
    const a = fill(16, 8, [100, 100, 100]);
    const b = fill(16, 8, [100, 100, 100]);
    for (let y = 0; y < 8; y++) {
      for (let x = 8; x < 16; x++) {
        const idx = (y * 16 + x) * 4;
        b[idx] = 200;
        b[idx + 1] = 30;
        b[idx + 2] = 30;
      }
    }
    const map = ciede2000Map(a, b, 16, 8);
    const leftMean = meanOf(map, 16, 0, 0, 8, 8);
    const rightMean = meanOf(map, 16, 8, 0, 8, 8);
    expect(rightMean).toBeGreaterThan(leftMean + 0.3);
  });
});
