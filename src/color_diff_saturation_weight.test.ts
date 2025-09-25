import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

const targetFile = 'diffapp/lib/image_pipeline.dart';

/**
 * 画像の色差検出が彩度に応じて強調されるよう、Dart 実装に彩度ベースの重み付けが入っていることを検証する。
 */
describe('colorDiffMapRgbaRobust の彩度重み付け', () => {
  it('彩度差を算出して色差に反映している', () => {
    const source = readFileSync(targetFile, 'utf-8');
    expect(source).toMatch(/final\s+sat1\s*=\s*_saturation\(r1,\s*g1,\s*b1\);/);
    expect(source).toMatch(/final\s+sat2\s*=\s*_saturation\(r2,\s*g2,\s*b2\);/);
    expect(source).toMatch(
      /final\s+satAvgNorm\s*=\s*\(\(sat1\s*\+\s*sat2\)\s*\*\s*0\.5\)\s*\/\s*255\.0?;/,
    );
    expect(source).toMatch(/final\s+satAvg\s*=\s*satAvgNorm\.clamp\(0\.0,\s*1\.0\);/);
    expect(source).toMatch(/final\s+chromaEnergy\s*=\s*math\.sqrt\(satAvg\.toDouble\(\)\);/);
    expect(source).toMatch(/final\s+wChroma\s*=\s*0\.18\s*\+\s*0\.82\s*\*\s*chromaEnergy;/);
    expect(source).toMatch(/final\s+wSat\s*=\s*0\.18\s*\+\s*0\.62\s*\*\s*chromaEnergy;/);
    expect(source).toMatch(/final\s+satDelta\s*=\s*\(sat1\s*-\s*sat2\)\.abs\(\)\s*\/\s*255\.0?;/);
    expect(source).toMatch(
      /dChroma\s*\*\s*wChroma\s*\+\s*dRgb\s*\*\s*0\.22\s*\+\s*satDelta\s*\*\s*wSat/,
    );
  });

  it('_saturation ヘルパーが定義されている', () => {
    const source = readFileSync(targetFile, 'utf-8');
    expect(source).toMatch(/double\s+_saturation\(double\s+r,\s*double\s+g,\s*double\s+b\)/);
  });
});
