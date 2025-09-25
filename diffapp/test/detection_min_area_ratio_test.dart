import 'dart:typed_data';

import 'package:diffapp/cnn_detection.dart';
import 'package:diffapp/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('最小面積5%未満は除外され、5%以上は検出される', () async {
    const w = 64, h = 64; // 解析空間は64x64（4096px）
    const total = w * h;
    final fivePercent = (total * 0.05).ceil(); // 205px

    // 差分マップを作る（全体0.0、ブロックだけ0.9）
    List<double> makeMapWithBlock(int bx, int by, int bw, int bh) {
      final m = List<double>.filled(total, 0.0);
      for (var y = by; y < by + bh; y++) {
        for (var x = bx; x < bx + bw; x++) {
          m[y * w + x] = 0.9; // しきい値越え
        }
      }
      return m;
    }

    // 小ブロック: 面積は fivePercent - 1 未満
    const smallSize = 8; // 8x8=64 (<205)
    expect(smallSize * smallSize, lessThan(fivePercent));
    final diffSmall = makeMapWithBlock(2, 2, smallSize, smallSize);

    // 大ブロック: 面積は fivePercent 以上
    const bigSize = 16; // 16x16=256 (>=205)
    expect(bigSize * bigSize, greaterThanOrEqualTo(fivePercent));
    final diffBig = makeMapWithBlock(20, 20, bigSize, bigSize);

    // 同時に存在させる
    final diffBoth = List<double>.from(diffSmall);
    for (var y = 20; y < 20 + bigSize; y++) {
      for (var x = 20; x < 20 + bigSize; x++) {
        diffBoth[y * w + x] = 0.9;
      }
    }

    final det = FfiCnnDetector();
    await det.load(Uint8List(0));
    final settings = Settings.initial().copyWith(
      precision: 5, // しきい値を敏感に
      minAreaPercent: 5,
    );

    final rSmall = det.detectFromDiffMap(diffSmall, w, h, settings: settings);
    final rBig = det.detectFromDiffMap(diffBig, w, h, settings: settings);
    final rBoth = det.detectFromDiffMap(diffBoth, w, h, settings: settings);

    expect(rSmall.isEmpty, isTrue, reason: '5%未満は除外される');
    expect(rBig.isNotEmpty, isTrue, reason: '5%以上は検出される');
    expect(rBoth.length, 1, reason: '小は除外・大のみ検出');
  });
}
