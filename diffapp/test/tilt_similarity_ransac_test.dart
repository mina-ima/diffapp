import 'dart:math' as math;

import 'package:diffapp/image_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

Point2 _apply(Point2 p, double s, double rad, double tx, double ty) {
  final c = math.cos(rad);
  final sn = math.sin(rad);
  final x = s * (c * p.x - sn * p.y) + tx;
  final y = s * (sn * p.x + c * p.y) + ty;
  return Point2(x, y);
}

void main() {
  test('RANSAC recovers transform with outliers', () {
    // Inlier points: grid around origin
    final src = <Point2>[];
    for (var y = -2; y <= 2; y++) {
      for (var x = -2; x <= 2; x++) {
        src.add(Point2(10.0 * x, 8.0 * y));
      }
    }
    const sTrue = 1.8;
    const radTrue = 20 * math.pi / 180;
    const txTrue = -12.0;
    const tyTrue = 7.0;
    final dst =
        src.map((p) => _apply(p, sTrue, radTrue, txTrue, tyTrue)).toList();

    // Add some outliers
    final outlierSrc = <Point2>[
      const Point2(300, 300),
      const Point2(-250, 150)
    ];
    final outlierDst = <Point2>[
      const Point2(-100, -200),
      const Point2(400, -50)
    ];

    final allSrc = <Point2>[...src, ...outlierSrc];
    final allDst = <Point2>[...dst, ...outlierDst];

    final result = estimateSimilarityTransformRansac(
      allSrc,
      allDst,
      iterations: 300,
      inlierThreshold: 1.5,
      minInliers: src.length - 2, // allow a couple to be borderline
    );

    expect(result.inliersCount, greaterThanOrEqualTo(src.length - 2));
    expect(result.transform.scale, closeTo(sTrue, 1e-2));
    expect(result.transform.rotationRad, closeTo(radTrue, 1e-2));
    expect(result.transform.tx, closeTo(txTrue, 0.5));
    expect(result.transform.ty, closeTo(tyTrue, 0.5));
  });

  test('RANSAC throws when insufficient points', () {
    final p = [const Point2(0, 0)];
    expect(
      () => estimateSimilarityTransformRansac(p, p),
      throwsA(isA<ArgumentError>()),
    );
  });
}
