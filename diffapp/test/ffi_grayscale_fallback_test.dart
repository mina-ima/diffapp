import 'dart:math';

import 'package:diffapp/ffi/image_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FfiImageOps.rgbToGrayscaleU8 falls back and matches Dart', () {
    const w = 5, h = 4;
    final rnd = Random(1);
    final rgb = List<int>.generate(w * h * 3, (_) => rnd.nextInt(256));
    final dartOps = DartImageOps();
    final ffiOps = FfiImageOps();

    final g1 = dartOps.rgbToGrayscaleU8(rgb, w, h);
    final g2 = ffiOps.rgbToGrayscaleU8(rgb, w, h);
    expect(g2, equals(g1));
  });
}
