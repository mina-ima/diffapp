import 'package:flutter_test/flutter_test.dart';
import 'package:diffapp/image_pipeline.dart';

void main() {
  test('明度のみの変化にはロバスト、色相差は高スコア', () {
    const w = 8, h = 8;
    final a = List<int>.filled(w * h * 4, 0);
    final bBright = List<int>.filled(w * h * 4, 0);
    final bHue = List<int>.filled(w * h * 4, 0);

    // 画像A: 中庸灰+わずかに赤み (R=120,G=110,B=110)
    for (var i = 0; i < w * h; i++) {
      a[i * 4 + 0] = 120; // R
      a[i * 4 + 1] = 110; // G
      a[i * 4 + 2] = 110; // B
      a[i * 4 + 3] = 255;
    }
    // 明度を上げるだけ（クロマ同等の想定）: +50
    for (var i = 0; i < w * h; i++) {
      bBright[i * 4 + 0] = 170;
      bBright[i * 4 + 1] = 160;
      bBright[i * 4 + 2] = 160;
      bBright[i * 4 + 3] = 255;
    }
    // 色相を変える: 緑寄りにシフト（R=100,G=140,B=110）
    for (var i = 0; i < w * h; i++) {
      bHue[i * 4 + 0] = 100;
      bHue[i * 4 + 1] = 140;
      bHue[i * 4 + 2] = 110;
      bHue[i * 4 + 3] = 255;
    }

    final dBright = colorDiffMapRgbaRobust(a, bBright, w, h);
    final dHue = colorDiffMapRgbaRobust(a, bHue, w, h);

    // 明度差のみ → 平均スコアは小さい（< 0.1）
    final meanBright = dBright.reduce((x, y) => x + y) / dBright.length;
    expect(meanBright, lessThan(0.1), reason: '明度差にロバストであるべき');

    // 色相差 → 平均スコアはそこそこ大きい（> 0.15）
    final meanHue = dHue.reduce((x, y) => x + y) / dHue.length;
    expect(meanHue, greaterThan(0.15), reason: '色相差には敏感であるべき');
  });
}

