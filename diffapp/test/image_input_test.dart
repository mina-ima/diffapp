import 'package:diffapp/image_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSupportedImageFormat', () {
    test('accepts jpg/jpeg/png (case-insensitive)', () {
      expect(isSupportedImageFormat('photo.jpg'), isTrue);
      expect(isSupportedImageFormat('photo.jpeg'), isTrue);
      expect(isSupportedImageFormat('photo.png'), isTrue);
      expect(isSupportedImageFormat('PHOTO.JPG'), isTrue);
      expect(isSupportedImageFormat('IMG.JPeg'), isTrue);
      expect(isSupportedImageFormat('dir.name/pic.PNG'), isTrue);
    });

    test('rejects unsupported or malformed names', () {
      expect(isSupportedImageFormat('animation.gif'), isFalse);
      expect(isSupportedImageFormat('noext'), isFalse);
      expect(isSupportedImageFormat('.hidden'), isFalse);
      expect(isSupportedImageFormat('trailingdot.'), isFalse);
      // path-like with extra dot before the extension is fine; last dot is decisive
      expect(isSupportedImageFormat('a.b.c.png'), isTrue);
    });
  });

  group('clampToMaxResolution', () {
    test('returns original when within bounds', () {
      final d = clampToMaxResolution(1200, 900);
      expect(d, const Dimensions(1200, 900));
    });

    test('downscales preserving aspect ratio when exceeding either bound', () {
      // Exceeds both → scale by the tighter (height) constraint
      final d1 = clampToMaxResolution(5000, 4000, maxWidth: 4000, maxHeight: 3000);
      expect(d1, const Dimensions(3750, 3000));

      // Exceeds width only
      final d2 = clampToMaxResolution(8000, 1000, maxWidth: 4000, maxHeight: 3000);
      // scale = 4000/8000 = 0.5 → 4000x500
      expect(d2, const Dimensions(4000, 500));

      // Exceeds height only
      final d3 = clampToMaxResolution(1000, 7000, maxWidth: 4000, maxHeight: 3000);
      // scale = 3000/7000 ≈ 0.4286 → 429x3000 (rounded)
      expect(d3, const Dimensions(429, 3000));
    });

    test('throws on invalid inputs', () {
      expect(() => clampToMaxResolution(0, 10), throwsArgumentError);
      expect(() => clampToMaxResolution(10, 0), throwsArgumentError);
      expect(() => clampToMaxResolution(10, 10, maxWidth: 0), throwsArgumentError);
      expect(() => clampToMaxResolution(10, 10, maxHeight: 0), throwsArgumentError);
    });
  });
}

