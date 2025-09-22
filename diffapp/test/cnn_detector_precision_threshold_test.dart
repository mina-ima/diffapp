import 'dart:typed_data';

import 'package:diffapp/cnn_detection.dart';
import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('precision の違いで検出有無が変わる（閾値反映）', () {
    const w = 32, h = 32;
    // 差分マップを作る: 画面中央 10x10 を 0.82、それ以外は 0.0
    final diff = List<double>.filled(w * h, 0.0);
    for (var y = 11; y < 21; y++) {
      for (var x = 11; x < 21; x++) {
        diff[y * w + x] = 0.82;
      }
    }

    final det = FfiCnnDetector(); // フォールバックで MockCnnDetector を使用
    // モデルは空データでロード済み扱い
    expectLater(det.load(Uint8List(0)), completes);

    // 低精度（threshold=0.9）→ 検出されない
    final low = const Settings(
      detectColor: true,
      detectShape: true,
      detectPosition: true,
      detectSize: true,
      detectText: true,
      enableSound: true,
      precision: 1,
      minAreaPercent: Settings.defaultMinAreaPercent,
    );
    final resLow = det.detectFromDiffMap(diff, w, h, settings: low);
    expect(resLow.isEmpty, isTrue);

    // 高精度（threshold=0.8）→ 検出される
    final high = low.copyWith(precision: 5);
    final resHigh = det.detectFromDiffMap(diff, w, h, settings: high);
    expect(resHigh.isNotEmpty, isTrue);
  });
}
