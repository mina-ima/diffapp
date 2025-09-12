import 'dart:math' as math;

import 'package:diffapp/image_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SSIMとパイプラインが1280幅で5秒以内に完了する', () {
    const w = 1280;
    const h = 960;

    // 疑似グレースケール画像を生成（横方向グラデーション）。
    final imgA = List<int>.filled(w * h, 0);
    final imgB = List<int>.filled(w * h, 0);

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final base = (x * 255 / (w - 1)).round();
        imgA[y * w + x] = base;
        var v = base;
        // いくつかの矩形領域に微小差分を付与
        if ((x >= 200 && x < 360 && y >= 300 && y < 420) ||
            (x >= 800 && x < 920 && y >= 500 && y < 640)) {
          v = math.min(255, base + 30);
        }
        imgB[y * w + x] = v;
      }
    }

    final sw = Stopwatch()..start();

    // SSIM（windowRadius=0 で最小計算）
    final ssim = computeSsimMapUint8(imgA, imgB, w, h, windowRadius: 0);

    // 差分マップ（1-SSIM）を正規化し、二値化→連結成分→NMS までを通す
    final diff = ssim.map((v) => 1.0 - v).toList();
    final diffN = normalizeToUnit(diff);
    final bin = thresholdBinary(diffN, 0.8);
    final boxes = connectedComponentsBoundingBoxes(bin, w, h,
        eightConnected: true, minArea: 64);

    // ダミースコア（矩形面積）で NMS を実行
    final scores = [for (final b in boxes) (b.width * b.height).toDouble()];
    final kept = nonMaxSuppression(boxes, scores, iouThreshold: 0.3);

    sw.stop();

    // 矩形はいくつか検出される想定（ゼロでないこと）
    expect(kept.isNotEmpty, isTrue);

    // 処理時間が 5 秒未満であること
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
  });
}
