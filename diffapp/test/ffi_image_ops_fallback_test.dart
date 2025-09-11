import 'package:diffapp/ffi/image_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'FfiImageOps falls back to Dart and matches results (SSIM, threshold, CC)',
      () {
    const w = 8, h = 8;
    final a = List<int>.filled(w * h, 128);
    final b = List<int>.from(a);
    // Introduce small difference
    for (var y = 3; y <= 4; y++) {
      for (var x = 3; x <= 4; x++) {
        b[y * w + x] = 200;
      }
    }

    final dartOps = DartImageOps();
    final ffiOps = FfiImageOps(); // Currently should fall back

    final ssimD = dartOps.computeSsimMapUint8(a, b, w, h, windowRadius: 1);
    final ssimF = ffiOps.computeSsimMapUint8(a, b, w, h, windowRadius: 1);
    expect(ssimF, hasLength(ssimD.length));
    for (var i = 0; i < ssimD.length; i++) {
      expect(ssimF[i], closeTo(ssimD[i], 1e-9));
    }

    final normD = dartOps.normalizeToUnit(ssimD);
    final normF = ffiOps.normalizeToUnit(ssimD);
    for (var i = 0; i < normD.length; i++) {
      expect(normF[i], closeTo(normD[i], 1e-12));
    }

    final binD = dartOps.thresholdBinary(normD, 0.5);
    final binF = ffiOps.thresholdBinary(normD, 0.5);
    expect(binF, equals(binD));

    final boxesD = dartOps.connectedComponentsBoundingBoxes(binD, w, h,
        eightConnected: true, minArea: 2);
    final boxesF = ffiOps.connectedComponentsBoundingBoxes(binD, w, h,
        eightConnected: true, minArea: 2);
    expect(boxesF, equals(boxesD));
  });
}
