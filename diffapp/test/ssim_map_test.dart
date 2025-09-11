import 'package:diffapp/image_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SSIM map ~1.0 for identical images', () {
    const w = 8, h = 8;
    final img = List<int>.filled(w * h, 128);
    final map = computeSsimMapUint8(img, img, w, h);
    expect(map.length, w * h);
    for (final v in map) {
      expect(v, closeTo(1.0, 1e-6));
    }
  });

  test('SSIM map highlights changed center block', () {
    const w = 16, h = 16;
    final a = List<int>.filled(w * h, 128);
    final b = List<int>.from(a);
    // Change a 4x4 block in the center
    for (var y = 6; y < 10; y++) {
      for (var x = 6; x < 10; x++) {
        b[y * w + x] = 200;
      }
    }
    final map = computeSsimMapUint8(a, b, w, h, windowRadius: 2);
    // Corners should remain high
    expect(map[0], greaterThan(0.95));
    // Center should be lower than corners
    final center = map[8 * w + 8];
    expect(center, lessThan(0.9));
  });

  test('normalizeToUnit maps min->0 and max->1', () {
    final src = [2.0, 4.0, 6.0];
    final out = normalizeToUnit(src);
    expect(out[0], closeTo(0.0, 1e-9));
    expect(out[1], closeTo(0.5, 1e-9));
    expect(out[2], closeTo(1.0, 1e-9));
  });

  test('normalizeToUnit returns zeros when all equal', () {
    final src = [0.5, 0.5, 0.5];
    final out = normalizeToUnit(src);
    expect(out, everyElement(closeTo(0.0, 1e-9)));
  });
}
