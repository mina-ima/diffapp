import { describe, expect, it } from 'vitest';
import { otsuBinarize, morphClose } from '../binarize';

describe('otsuBinarize', () => {
  it('splits a bimodal distribution', () => {
    const n = 100;
    const arr = new Float32Array(n);
    for (let i = 0; i < n; i++) arr[i] = i < n / 2 ? 0.05 : 0.9;
    const { mask } = otsuBinarize(arr, 0.5);
    let zeros = 0;
    let ones = 0;
    for (const v of mask) {
      if (v) ones++;
      else zeros++;
    }
    expect(zeros).toBeGreaterThan(40);
    expect(ones).toBeGreaterThan(40);
  });

  it('lowers threshold when sensitivity is high', () => {
    const arr = new Float32Array(64);
    for (let i = 0; i < 64; i++) arr[i] = i < 32 ? 0.2 : 0.6;
    const low = otsuBinarize(arr, 0.0).threshold;
    const high = otsuBinarize(arr, 1.0).threshold;
    expect(high).toBeLessThanOrEqual(low);
  });
});

describe('morphClose', () => {
  it('fills a single-pixel hole', () => {
    const w = 5;
    const h = 5;
    const mask = new Uint8Array(w * h);
    for (let y = 1; y <= 3; y++) {
      for (let x = 1; x <= 3; x++) {
        mask[y * w + x] = 1;
      }
    }
    mask[2 * w + 2] = 0;
    const closed = morphClose(mask, w, h, 1);
    expect(closed[2 * w + 2]).toBe(1);
  });
});
