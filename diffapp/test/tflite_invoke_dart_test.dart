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

    const w = 64, h = 64;
    final diff = _makeDiffMap(w, h, [(24, 24, 39, 39, 0.95)], 0.1);

    final out = det.detectFromDiffMap(
      diff,
      w,
      h,
      settings: Settings.initial(),
    );

    expect(out, isNotEmpty);
    // 中央ブロック付近の差分が検出されていることを確認
    final hasBlock = out.any((d) {
      final right = d.box.left + d.box.width;
      final bottom = d.box.top + d.box.height;
      return d.box.left <= 32 && right >= 32 && d.box.top <= 32 && bottom >= 32;
    });
    expect(hasBlock, isTrue);
  });
}
