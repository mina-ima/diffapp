import 'package:flutter_test/flutter_test.dart';
import 'package:diffapp/features.dart';

List<int> makeImage(int w, int h, int bg) => List<int>.filled(w * h, bg);

void drawRect(
    List<int> img, int w, int h, int x0, int y0, int x1, int y1, int val) {
  for (var y = y0; y <= y1; y++) {
    if (y < 0 || y >= h) continue;
    for (var x = x0; x <= x1; x++) {
      if (x < 0 || x >= w) continue;
      img[y * w + x] = val;
    }
  }
}

void main() {
  test('Harris で四角の角に特徴点が出る', () {
    const w = 32, h = 32;
    final img = makeImage(w, h, 0);
    // 10x10 白四角
    drawRect(img, w, h, 8, 8, 18, 18, 255);

    final kps = detectHarrisKeypointsU8(
      img,
      w,
      h,
      responseThreshold: 0,
      maxFeatures: 50,
    );
    // 何らかの特徴点が検出されること（簡易検証）
    expect(kps.isNotEmpty, isTrue);
  });

  test('BRIEF ディスクリプタで同一画像は自己一致する', () {
    const w = 32, h = 32;
    final img = makeImage(w, h, 10);
    drawRect(img, w, h, 6, 6, 20, 20, 200);

    final kps = detectHarrisKeypointsU8(img, w, h,
        responseThreshold: 0, maxFeatures: 30);
    final desc =
        computeBriefDescriptors(img, w, h, kps, bytes: 16, patch: 31, seed: 7);
    final matches = matchDescriptorsHamming(desc, desc);
    // 少なくとも半分程度は距離0で自己一致する
    final zeroMatches = matches.where((m) => m.$2 == m.$1 && m.$3 == 0).length;
    expect(zeroMatches >= (kps.length / 2).floor(), isTrue);
  });
}
