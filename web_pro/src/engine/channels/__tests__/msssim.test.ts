import { describe, expect, it } from 'vitest';
import { ssimDiffMap, msssimDiffMap } from '../msssim';

function buildFlat(w: number, h: number, v: number): Uint8ClampedArray {
  const out = new Uint8ClampedArray(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    out[i * 4] = out[i * 4 + 1] = out[i * 4 + 2] = v;
    out[i * 4 + 3] = 255;
  }
  return out;
}

describe('SSIM diff maps', () => {
  it('returns near-zero for identical images', () => {
    const a = buildFlat(16, 16, 128);
    const b = buildFlat(16, 16, 128);
    const map = ssimDiffMap(a, b, 16, 16);
    let max = 0;
    for (let i = 0; i < map.length; i++) if (map[i] > max) max = map[i];
    expect(max).toBeLessThan(0.05);
  });

  it('raises values where images differ', () => {
    const a = buildFlat(32, 32, 30);
    const b = buildFlat(32, 32, 30);
    // 中央 4x4 を差し替え
    for (let y = 14; y < 18; y++) {
      for (let x = 14; x < 18; x++) {
        const idx = (y * 32 + x) * 4;
        b[idx] = b[idx + 1] = b[idx + 2] = 230;
      }
    }
    const map = ssimDiffMap(a, b, 32, 32);
    const centerIdx = 16 * 32 + 16;
    const cornerIdx = 0;
    expect(map[centerIdx]).toBeGreaterThan(map[cornerIdx] + 0.1);
  });

  it('msssimDiffMap outputs normalized values', () => {
    const a = buildFlat(32, 32, 30);
    const b = buildFlat(32, 32, 30);
    for (let y = 10; y < 22; y++) {
      for (let x = 10; x < 22; x++) {
        const idx = (y * 32 + x) * 4;
        b[idx] = 200;
        b[idx + 1] = 200;
        b[idx + 2] = 200;
      }
    }
    const map = msssimDiffMap(a, b, 32, 32);
    let lo = 1;
    let hi = 0;
    for (let i = 0; i < map.length; i++) {
      if (map[i] < lo) lo = map[i];
      if (map[i] > hi) hi = map[i];
    }
    expect(lo).toBeGreaterThanOrEqual(0);
    expect(hi).toBeLessThanOrEqual(1 + 1e-6);
    expect(hi - lo).toBeGreaterThan(0.3);
  });
});
