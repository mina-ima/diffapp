import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('検出精度レベルの拡張', () => {
  it('Settings.maxPrecision が 7 段階に拡張されている', () => {
    const source = readFileSync('diffapp/lib/settings.dart', 'utf-8');
    expect(source).toMatch(/static const int maxPrecision = 7;/);
  });

  it('CNN 検出器が精度ごとのしきい値を段階的に下げている', () => {
    const source = readFileSync('diffapp/lib/cnn_detection.dart', 'utf-8');
    expect(source).toMatch(/0\.9\s*-\s*\(p\s*-\s*1\)\s*\*\s*0\.05/);
    expect(source).toMatch(/return\s+t\.clamp\(0\.6,\s*0\.9\);/);
  });
});
