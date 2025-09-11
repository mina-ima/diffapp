import 'dart:math';

import 'package:diffapp/ffi/image_ops.dart';
import 'package:diffapp/ffi/bindings.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNativeOps implements ImageOpsNative {
  int calls = 0;

  @override
  bool get isAvailable => true;

  @override
  List<int> rgbToGrayscaleU8(List<int> rgb, int width, int height) {
    calls++;
    // Return a simple pattern so we can assert it's used.
    // Use average instead of BT.601 to differentiate from Dart fallback.
    final out = List<int>.filled(width * height, 0);
    for (var i = 0, j = 0; i < out.length; i++) {
      final r = rgb[j++];
      final g = rgb[j++];
      final b = rgb[j++];
      out[i] = ((r + g + b) / 3).round().clamp(0, 255);
    }
    return out;
  }
}

void main() {
  test('FfiImageOps prefers native when available (injected)', () {
    const w = 4, h = 3;
    final rnd = Random(42);
    final rgb = List<int>.generate(w * h * 3, (_) => rnd.nextInt(256));

    final fake = _FakeNativeOps();
    final ops = FfiImageOps(native: fake);

    final out = ops.rgbToGrayscaleU8(rgb, w, h);
    expect(out.length, w * h);
    // Ensure our fake native path was used
    expect(fake.calls, 1);

    // Calculate what fallback (Dart) would produce to ensure they differ for most inputs.
    final dartOut = DartImageOps().rgbToGrayscaleU8(rgb, w, h);
    // In general, BT.601 vs average will differ; allow rare equality but ensure not all equal.
    final equalCount = List.generate(out.length, (i) => out[i] == dartOut[i])
        .where((e) => e)
        .length;
    expect(equalCount < out.length, isTrue);
  });
}
