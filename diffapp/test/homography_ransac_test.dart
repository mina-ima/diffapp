import 'dart:math' as math;

import 'package:diffapp/image_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Point2 applyH(Point2 p, Homography h) => applyHomography(p, h);

  test('estimateHomographyRansac recovers projective transform with outliers',
      () {
    // True homography (mild perspective warp)
    const hTrue = Homography(
      h11: 1.10,
      h12: 0.05,
      h13: 20.0,
      h21: 0.02,
      h22: 1.05,
      h23: -15.0,
      h31: 0.0005,
      h32: -0.0003,
      h33: 1.0,
    );

    // Inlier grid near origin
    final src = <Point2>[];
    for (var y = -3; y <= 3; y++) {
      for (var x = -3; x <= 3; x++) {
        src.add(Point2(25.0 * x, 20.0 * y));
      }
    }
    final dst = src.map((p) => applyH(p, hTrue)).toList();

    // Add some outliers
    final outSrc = <Point2>[
      const Point2(300, 300),
      const Point2(-280, 160),
      const Point2(150, -220),
    ];
    final outDst = <Point2>[
      const Point2(-200, -120),
      const Point2(400, -50),
      const Point2(-150, 260),
    ];
    final allSrc = <Point2>[...src, ...outSrc];
    final allDst = <Point2>[...dst, ...outDst];

    final res = estimateHomographyRansac(
      allSrc,
      allDst,
      iterations: 500,
      inlierThreshold: 2.0,
      minInliers: src.length - 3,
    );

    expect(res.inliersCount, greaterThanOrEqualTo(src.length - 3));

    // Evaluate RMS reprojection error on inlier-only set
    double sq(double v) => v * v;
    double err(Point2 a, Point2 b) => math.sqrt(sq(a.x - b.x) + sq(a.y - b.y));
    var sumSq = 0.0;
    for (var i = 0; i < src.length; i++) {
      final p = applyH(src[i], res.homography);
      sumSq += sq(err(p, dst[i]));
    }
    final rms = math.sqrt(sumSq / src.length);
    expect(rms, lessThan(1.0));
  });

  test('estimateHomographyRansac throws on insufficient points', () {
    final p = [const Point2(0, 0), const Point2(1, 1), const Point2(2, 2)];
    expect(() => estimateHomographyRansac(p, p), throwsArgumentError);
  });
}
