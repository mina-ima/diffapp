import 'dart:typed_data';

import 'package:diffapp/cnn_detection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diffapp/settings.dart';

void main() {
  test('FfiCnnDetector falls back to mock and detects similarly', () async {
    final det = FfiCnnDetector();
    await det.load(Uint8List(0));
    const w = 12, h = 8;
    final diffMap = List<double>.filled(w*h, 0.1);
    for (var y=2; y<=3; y++) {
      for (var x=5; x<=6; x++) {
        diffMap[y*w+x] = 0.95;
      }
    }
    final r = det.detectFromDiffMap(diffMap, w, h, settings: Settings.initial());
    expect(r, isNotEmpty);
  });
}
