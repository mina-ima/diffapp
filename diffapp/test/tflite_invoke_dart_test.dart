import 'dart:typed_data';

import 'package:diffapp/cnn_detection.dart';
import 'package:diffapp/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diffapp/tflite_cnn_native.dart';

List<double> _makeDiffMap(
  int w,
  int h,
  List<(int, int, int, int, double)> blocks,
  double bg,
) {
  final m = List<double>.filled(w * h, bg);
  for (final (x0, y0, x1, y1, v) in blocks) {
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        m[y * w + x] = v;
      }
    }
  }
  return m;
}

void main() {
  test('TfliteCnnNative を使って Dart 経由で推論を呼び出せる', () async {
    final native = TfliteCnnNative();
    final det = FfiCnnDetector(native: native);

    expect(det.isLoaded, isFalse);
    await det.load(Uint8List.fromList([1, 2, 3]));
    expect(det.isLoaded, isTrue);

    const w = 10, h = 8;
    final diff = _makeDiffMap(w, h, [(1, 1, 2, 2, 0.95)], 0.1);

    final out = det.detectFromDiffMap(
      diff,
      w,
      h,
      settings: Settings.initial(),
    );

    expect(out, isNotEmpty);
    // (1,1)-(2,2) の 2x2 ブロックが1件は検出される想定
    final hasBlock = out.any((d) =>
        d.box.left == 1 &&
        d.box.top == 1 &&
        d.box.width == 2 &&
        d.box.height == 2);
    expect(hasBlock, isTrue);
  });
}
