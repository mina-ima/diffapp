import 'dart:typed_data';
import 'package:diffapp/cnn_detection.dart';
import 'package:diffapp/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('タイル分割フォールバックで細長い縦差分を上位検出', () async {
    const w = 128, h = 128; // 解析空間
    final diff = List<double>.filled(w * h, 0.0);
    // 右上に細い縦帯（x=100..102, y=8..88）を強くする
    for (var x = 100; x <= 102; x++) {
      for (var y = 8; y <= 88; y++) {
        diff[y * w + x] = 1.0;
      }
    }
    final det = FfiCnnDetector();
    await det.load(Uint8List(0));
    final settings = Settings.initial();
    final out = det.detectFromDiffMap(diff, w, h,
        settings: settings, maxOutputs: 10, iouThreshold: 0.3);
    expect(out.isNotEmpty, isTrue,
        reason: 'タイル分割のフォールバックが検出を返すべき');
    // 右上領域に重なる検出があること
    final anyRightTop = out.any((d) => d.box.left + d.box.width > (w * 0.7) && d.box.top < (h * 0.5));
    expect(anyRightTop, isTrue);
  });
}

