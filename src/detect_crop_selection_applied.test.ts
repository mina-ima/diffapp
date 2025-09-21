import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

describe('検査は範囲指定部分のみを対象にする（Dartコードの存在検証）', () => {
  it('compare_page.dart の _toGrayscale が srcRect（切り出し矩形）に対応している', () => {
    const t = readFileSync('diffapp/lib/screens/compare_page.dart', 'utf-8');
    // 署名に Rect? srcRect のオプション引数が存在
    expect(t).toMatch(/_toGrayscale\([^)]*\{\s*Rect\?\s*srcRect\s*\}\)/s);
    // src = srcRect ?? (Offset.zero & srcSize) の分岐があり、drawImageRect に src が渡される
    expect(t).toMatch(/src\s*=\s*srcRect\s*\?\?\s*\(Offset\.zero\s*&\s*srcSize\)/);
    expect(t).toMatch(/drawImageRect\(image,\s*src,\s*dstRect,\s*paint\)/);
  });

  it('選択範囲がある場合、_runDetection で左/右それぞれのクロップ矩形を算出している', () => {
    const t = readFileSync('diffapp/lib/screens/compare_page.dart', 'utf-8');
    // 左の正規化矩形 _leftRect から元画像ピクセル空間の Rect.fromLTWH を計算
    expect(t).toMatch(/_leftRect\s*!=\s*null/);
    expect(t).toMatch(/Rect\.fromLTWH\([\s\S]*_leftRect/);
    // 右は scaleRectBetweenSpaces でマッピング（または _rightRect を使用）
    expect(t).toMatch(/scaleRectBetweenSpaces\(/);
    // _toGrayscale 呼び出し時に srcRect を渡す
    expect(t).toMatch(/_toGrayscale\(.*src(Rect)?:/s);
  });

  it('検出ボックスはフル画像の64x64座標へオフセット加算して返却している', () => {
    const t = readFileSync('diffapp/lib/screens/compare_page.dart', 'utf-8');
    // オフセット: leftOffsetX/leftOffsetY を足して IntRect を再構築
    expect(t).toMatch(/leftOffsetX/);
    expect(t).toMatch(/leftOffsetY/);
    expect(t).toMatch(/IntRect\(\s*left:\s*\(d\.left\s*\+\s*leftOffsetX\)/);
  });
});
