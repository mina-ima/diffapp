import { describe, expect, it } from 'vitest';
import { extractRegions, nms } from '../regions';

describe('extractRegions', () => {
  it('detects two separated components', () => {
    const w = 20;
    const h = 20;
    const mask = new Uint8Array(w * h);
    const score = new Float32Array(w * h);
    const paint = (x0: number, y0: number, x1: number, y1: number, s: number) => {
      for (let y = y0; y <= y1; y++) {
        for (let x = x0; x <= x1; x++) {
          mask[y * w + x] = 1;
          score[y * w + x] = s;
        }
      }
    };
    paint(2, 2, 6, 6, 0.9);
    paint(12, 12, 16, 16, 0.7);
    const regions = extractRegions(mask, score, w, h, { minAreaPercent: 0.1 });
    expect(regions.length).toBe(2);
    expect(regions[0].score).toBeGreaterThan(regions[1].score);
    expect(regions[0].w).toBe(5);
    expect(regions[0].h).toBe(5);
  });

  it('keeps thin elongated regions that would be below the area floor', () => {
    const w = 40;
    const h = 40;
    const mask = new Uint8Array(w * h);
    const score = new Float32Array(w * h);
    // 縦 30, 横 2 の細長領域（面積 60 / 総画素 1600 = 3.75%）
    for (let y = 2; y < 32; y++) {
      for (let x = 5; x < 7; x++) {
        mask[y * w + x] = 1;
        score[y * w + x] = 0.8;
      }
    }
    const regions = extractRegions(mask, score, w, h, { minAreaPercent: 5 });
    expect(regions.length).toBe(1);
    expect(regions[0].h).toBe(30);
  });
});

describe('nms', () => {
  it('suppresses heavily overlapping lower-score boxes', () => {
    const boxes = [
      { x: 0, y: 0, w: 10, h: 10, score: 0.9, area: 100, channelScores: {} },
      { x: 1, y: 1, w: 10, h: 10, score: 0.8, area: 100, channelScores: {} },
      { x: 30, y: 30, w: 10, h: 10, score: 0.7, area: 100, channelScores: {} },
    ];
    const kept = nms(boxes, 0.3, 10);
    expect(kept.length).toBe(2);
    expect(kept.map((b) => b.score)).toEqual([0.9, 0.7]);
  });
});
