import 'dart:math' as math;

import 'package:diffapp/image_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

Point2 _rotScaleTrans(Point2 p, double s, double rad, double tx, double ty) {
  final c = math.cos(rad);
  final sN = math.sin(rad);
  final x = s * (c * p.x - sN * p.y) + tx;
  final y = s * (sN * p.x + c * p.y) + ty;
  return Point2(x, y);
}

void main() {
  test('estimateSimilarityTransform recovers known transform', () {
    // 元データ: 正方形の一部
    final src = <Point2>[
      const Point2(0, 0),
      const Point2(10, 0),
      const Point2(0, 10),
      const Point2(5, 7),
    ];
    const sTrue = 2.0;
    const radTrue = 30 * math.pi / 180;
    const txTrue = 5.0;
    const tyTrue = -3.0;

    final dst = src
        .map((p) => _rotScaleTrans(p, sTrue, radTrue, txTrue, tyTrue))
        .toList();

    final est = estimateSimilarityTransform(src, dst);
    expect(est.scale, closeTo(sTrue, 1e-9));
    expect(est.rotationRad, closeTo(radTrue, 1e-9));
    expect(est.tx, closeTo(txTrue, 1e-9));
    expect(est.ty, closeTo(tyTrue, 1e-9));

    // 推定変換を適用して再現性を確認
    for (var i = 0; i < src.length; i++) {
      final p = applySimilarityTransform(src[i], est);
      expect(p.x, closeTo(dst[i].x, 1e-6));
      expect(p.y, closeTo(dst[i].y, 1e-6));
    }
  });

  test('throws on insufficient or degenerate inputs', () {
    final p = [const Point2(0, 0)];
    expect(() => estimateSimilarityTransform(p, p), throwsArgumentError);

    // 2点だが両点が同じ → 分散 0 で例外
    final a = [const Point2(1, 1), const Point2(1, 1)];
    final b = [const Point2(2, 2), const Point2(2, 2)];
    expect(() => estimateSimilarityTransform(a, b), throwsArgumentError);
  });
}
