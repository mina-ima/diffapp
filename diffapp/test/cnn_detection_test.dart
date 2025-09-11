import 'dart:typed_data';

import 'package:diffapp/cnn_detection.dart';
import 'package:diffapp/settings.dart';
import 'package:flutter_test/flutter_test.dart';

List<double> _makeDiffMap(int w, int h, List<(int,int,int,int,double)> blocks, double bg) {
  final m = List<double>.filled(w*h, bg);
  for (final (x0,y0,x1,y1,v) in blocks) {
    for (var y=y0; y<=y1; y++) {
      for (var x=x0; x<=x1; x++) {
        m[y*w+x] = v;
      }
    }
  }
  return m;
}

void main() {
  test('mock model loads and reports isLoaded', () async {
    final det = MockCnnDetector();
    expect(det.isLoaded, isFalse);
    await det.load(Uint8List.fromList([1,2,3]));
    expect(det.isLoaded, isTrue);
  });

  test('categories respect settings toggles', () async {
    final det = MockCnnDetector();
    await det.load(Uint8List(0));
    const w = 12, h = 8;
    final diffMap = _makeDiffMap(w, h, [ (2,2,3,3,0.92), (8,4,9,5,0.93) ], 0.1);

    // Only text on => all detections labeled text
    final s1 = Settings.initial().copyWith(
      detectColor: false, detectShape: false, detectPosition: false, detectSize: false, detectText: true,
      precision: 3,
    );
    final r1 = det.detectFromDiffMap(diffMap, w, h, settings: s1);
    expect(r1.length, 2);
    expect(r1.every((d) => d.category == DetectionCategory.text), isTrue);

    // Only color on => all detections labeled color
    final s2 = Settings.initial().copyWith(
      detectColor: true, detectShape: false, detectPosition: false, detectSize: false, detectText: false,
      precision: 3,
    );
    final r2 = det.detectFromDiffMap(diffMap, w, h, settings: s2);
    expect(r2.length, 2);
    expect(r2.every((d) => d.category == DetectionCategory.color), isTrue);
  });

  test('precision affects threshold (higher precision detects more)', () async {
    final det = MockCnnDetector();
    await det.load(Uint8List(0));
    const w = 10, h = 6;
    // One weak block at 0.82
    final diffMap = _makeDiffMap(w, h, [ (4,2,5,3,0.82) ], 0.1);

    final lowPrec = Settings.initial().copyWith(precision: 1);
    final highPrec = Settings.initial().copyWith(precision: 5);

    final rLow = det.detectFromDiffMap(diffMap, w, h, settings: lowPrec);
    final rHigh = det.detectFromDiffMap(diffMap, w, h, settings: highPrec);
    expect(rLow.isEmpty, isTrue); // strict threshold => not detected
    expect(rHigh.isNotEmpty, isTrue); // sensitive threshold => detected
  });
}
