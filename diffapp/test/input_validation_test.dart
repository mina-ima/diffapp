import 'package:diffapp/image_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSupportedImageFormat', () {
    test('accepts jpg/jpeg/png case-insensitively', () {
      expect(isSupportedImageFormat('photo.jpg'), isTrue);
      expect(isSupportedImageFormat('photo.JPEG'), isTrue);
      expect(isSupportedImageFormat('image.PNG'), isTrue);
    });

    test('rejects unsupported extensions or missing ext', () {
      expect(isSupportedImageFormat('anim.gif'), isFalse);
      expect(isSupportedImageFormat('doc.bmp'), isFalse);
      expect(isSupportedImageFormat('noext'), isFalse);
      expect(isSupportedImageFormat(''), isFalse);
    });
  });

  group('clampToMaxResolution', () {
    test('keeps size when within 4000x3000', () {
      expect(clampToMaxResolution(4000, 3000), const Dimensions(4000, 3000));
      expect(clampToMaxResolution(2000, 1500), const Dimensions(2000, 1500));
    });

    test('scales down width when width exceeds limit', () {
      // 5000x3000 -> scale = 4000/5000 = 0.8 => 4000x2400
      expect(clampToMaxResolution(5000, 3000), const Dimensions(4000, 2400));
    });

    test('scales down height when height exceeds limit', () {
      // 3000x5000 -> scale = 3000/5000 = 0.6 => 1800x3000
      expect(clampToMaxResolution(3000, 5000), const Dimensions(1800, 3000));
    });

    test('scales to fit both when both exceed', () {
      // 8000x6000 -> scale = min(4000/8000=0.5, 3000/6000=0.5) => 4000x3000
      expect(clampToMaxResolution(8000, 6000), const Dimensions(4000, 3000));
    });

    test('throws on non-positive inputs', () {
      expect(() => clampToMaxResolution(0, 100), throwsArgumentError);
      expect(() => clampToMaxResolution(100, 0), throwsArgumentError);
      expect(() => clampToMaxResolution(-1, 100), throwsArgumentError);
    });
  });
}
