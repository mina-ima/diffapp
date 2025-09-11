import 'package:flutter_test/flutter_test.dart';
import 'package:diffapp/image_pipeline.dart';

void main() {
  group('calculateResizeDimensions', () {
    test('keeps size when width <= target', () {
      final dims = calculateResizeDimensions(800, 600, targetMaxWidth: 1280);
      expect(dims, const Dimensions(800, 600));
    });

    test('scales down to 1280 width preserving aspect ratio', () {
      final dims = calculateResizeDimensions(4000, 3000, targetMaxWidth: 1280);
      // 4000x3000 -> scale = 1280/4000 = 0.32 => 1280x960
      expect(dims, const Dimensions(1280, 960));
    });

    test('handles portrait images correctly', () {
      final dims = calculateResizeDimensions(3000, 4000, targetMaxWidth: 1280);
      // 3000x4000 -> scale = 1280/3000 ≈ 0.4267 => height ≈ 1707
      expect(dims, const Dimensions(1280, 1707));
    });

    test('throws on non-positive inputs', () {
      expect(() => calculateResizeDimensions(0, 100), throwsArgumentError);
      expect(() => calculateResizeDimensions(100, 0), throwsArgumentError);
      expect(
        () => calculateResizeDimensions(100, 100, targetMaxWidth: 0),
        throwsArgumentError,
      );
    });
  });

  group('scaleRectForResizedImage', () {
    test('returns same rect when no resize needed', () {
      const rect = IntRect(left: 10, top: 20, width: 30, height: 40);
      final scaled = scaleRectForResizedImage(
        rect,
        800,
        600,
        targetMaxWidth: 1280,
      );
      expect(scaled, rect);
    });

    test('scales rect proportionally on downscale', () {
      // Original: 4000x3000, target width 1280 -> scale 0.32
      const rect = IntRect(left: 200, top: 150, width: 400, height: 300);
      final scaled = scaleRectForResizedImage(
        rect,
        4000,
        3000,
        targetMaxWidth: 1280,
      );
      expect(scaled, const IntRect(left: 64, top: 48, width: 128, height: 96));
    });

    test('throws when rect is out of bounds', () {
      const rect = IntRect(
        left: 3900,
        top: 2900,
        width: 200,
        height: 200,
      );
      expect(
        () => scaleRectForResizedImage(rect, 4000, 3000, targetMaxWidth: 1280),
        throwsArgumentError,
      );
    });
  });

  group('nonMaxSuppression + iou', () {
    test('computes IoU correctly for overlapping boxes', () {
      const a = IntRect(left: 0, top: 0, width: 100, height: 100);
      const b = IntRect(left: 50, top: 50, width: 100, height: 100);
      // Intersection: 50x50=2500; Union: 10000+10000-2500=17500; IoU=2500/17500≈0.1429
      expect(iou(a, b), closeTo(2500 / 17500, 1e-6));
    });

    test('suppresses lower score box when IoU > threshold', () {
      final boxes = [
        const IntRect(left: 0, top: 0, width: 100, height: 100),
        const IntRect(left: 10, top: 10, width: 100, height: 100),
        const IntRect(left: 200, top: 200, width: 50, height: 50),
      ];
      final scores = [0.9, 0.8, 0.7];
      final kept = nonMaxSuppression(boxes, scores, iouThreshold: 0.5);
      // First two have high overlap, keep the first; third is far, keep too
      expect(kept.length, 2);
      expect(kept[0], boxes[0]);
      expect(kept[1], boxes[2]);
    });

    test('respects maxOutputs (top-K)', () {
      final boxes = List.generate(
        30,
        (i) => IntRect(left: i * 10, top: i * 10, width: 10, height: 10),
      );
      final scores = List<double>.generate(30, (i) => 1.0 - i / 30);
      final kept = nonMaxSuppression(
        boxes,
        scores,
        iouThreshold: 0.0,
        maxOutputs: 20,
      );
      expect(kept.length, 20);
    });
  });

  group('scaleRectBetweenSpaces', () {
    test('scales with independent x/y ratios', () {
      const r = IntRect(left: 50, top: 100, width: 200, height: 300);
      final scaled = scaleRectBetweenSpaces(r, 1000, 2000, 2000, 1000);
      // x2 on width, 0.5 on height
      expect(
        scaled,
        const IntRect(left: 100, top: 50, width: 400, height: 150),
      );
    });

    test('throws if rect exceeds source bounds', () {
      const r = IntRect(left: 900, top: 900, width: 200, height: 200);
      expect(
        () => scaleRectBetweenSpaces(r, 1000, 1000, 2000, 2000),
        throwsArgumentError,
      );
    });
  });
}
