import { describe, expect, it } from 'vitest';
import { cropRgba, normalizeFloat, resizeRgbaBilinear, rgbaToGray, clamp } from '../image';

function flat(w: number, h: number, rgb: [number, number, number]) {
  const out = new Uint8ClampedArray(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    out[i * 4] = rgb[0];
    out[i * 4 + 1] = rgb[1];
    out[i * 4 + 2] = rgb[2];
    out[i * 4 + 3] = 255;
  }
  return out;
}

describe('image utilities', () => {
  it('rgbaToGray computes luma', () => {
    const px = new Uint8ClampedArray([255, 0, 0, 255, 0, 255, 0, 255]);
    const g = rgbaToGray(px, 2, 1);
    expect(g[0]).toBeCloseTo(76.245, 1);
    expect(g[1]).toBeCloseTo(149.685, 1);
  });

  it('resizeRgbaBilinear preserves flat color', () => {
    const src = flat(4, 4, [128, 200, 50]);
    const dst = resizeRgbaBilinear(src, 4, 4, 8, 8);
    expect(dst.length).toBe(8 * 8 * 4);
    expect(dst[0]).toBe(128);
    expect(dst[1]).toBe(200);
    expect(dst[2]).toBe(50);
    expect(dst[3]).toBe(255);
  });

  it('cropRgba extracts subregion', () => {
    const src = new Uint8ClampedArray(16);
    for (let i = 0; i < 4; i++) src[i * 4] = i;
    const cropped = cropRgba(src, 4, 1, 1, 0, 2, 1);
    expect(cropped[0]).toBe(1);
    expect(cropped[4]).toBe(2);
  });

  it('normalizeFloat maps range to [0,1]', () => {
    const n = normalizeFloat(new Float32Array([2, 4, 6]));
    expect(n[0]).toBeCloseTo(0);
    expect(n[1]).toBeCloseTo(0.5);
    expect(n[2]).toBeCloseTo(1);
  });

  it('clamp clamps values', () => {
    expect(clamp(-1, 0, 5)).toBe(0);
    expect(clamp(7, 0, 5)).toBe(5);
    expect(clamp(3, 0, 5)).toBe(3);
  });
});
