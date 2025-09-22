import 'package:diffapp/cnn_detection.dart';
import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('細い縦長の差分（本の背表紙想定）', () {
    // 解析空間は 64x64 とし、右上付近に幅1px・高さ20pxの強い差分を作る。
    // 既存実装では minAreaPercent=2% -> 約82px 相当のため除外されがち。
    // 修正後は『細長い領域』に限って最小面積の救済が働き、検出できることを期待する。
    test('右上の背表紙を検出できる', () {
      const w = 64, h = 64;
      final diff = List<double>.filled(w * h, 0.0);
      // x=56 の列に y=4..23 を強い差分として立てる（幅1px, 高さ20px → 面積20px）
      const x = 56;
      for (var y = 4; y < 24; y++) {
        diff[y * w + x] = 1.0;
      }

      final detector = FfiCnnDetector();
      detector.load(Uint8List(0));

      final settings = Settings.initial();
      final dets = detector.detectFromDiffMap(
        diff,
        w,
        h,
        settings: settings,
        maxOutputs: 5,
        iouThreshold: 0.3,
      );

      // 1件以上検出され、検出ボックスが右上(=xが48以上)の領域にかかっていること
      expect(dets.isNotEmpty, isTrue,
          reason: '細い背表紙様の差分が検出されていない');

      final anyRightTop = dets.any((d) {
        final b = d.box;
        return b.left + b.width > 48 && b.top < h ~/ 2;
      });
      expect(anyRightTop, isTrue, reason: '右上付近の領域が検出されていない');
    });
  });
}

