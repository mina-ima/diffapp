import 'dart:typed_data';

import 'package:diffapp/cnn_detection.dart';
import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/settings.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNativeDetector implements CnnNative {
  bool available;
  bool _loaded = false;
  int loadCalls = 0;
  int detectCalls = 0;
  List<Detection> nextResult;

  _FakeNativeDetector({this.available = true, List<Detection>? next})
      : nextResult = next ??
            [
              Detection(
                box: const IntRect(left: 1, top: 2, width: 3, height: 4),
                score: 0.99,
                category: DetectionCategory.text,
              )
            ];

  @override
  bool get isAvailable => available;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load(Uint8List modelData) async {
    loadCalls++;
    _loaded = true;
  }

  @override
  List<Detection> detectFromDiffMap(
    List<double> diffMap,
    int width,
    int height, {
    required Settings settings,
    int maxOutputs = 20,
    double iouThreshold = 0.5,
  }) {
    detectCalls++;
    return nextResult;
  }
}

List<double> _makeDiffMap(
    int w, int h, List<(int, int, int, int, double)> blocks, double bg) {
  final m = List<double>.filled(w * h, bg);
  for (final (x0, y0, x1, y1, v) in blocks) {
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        m[y * w + x] = v;
      }
    }
  }
  return m;
}

void main() {
  test('FfiCnnDetector はネイティブが利用可能ならそれを優先する', () async {
    final fake = _FakeNativeDetector(available: true);
    final det = FfiCnnDetector(native: fake);

    expect(det.isLoaded, isFalse);
    await det.load(Uint8List.fromList([0, 1, 2]));
    expect(det.isLoaded, isTrue);
    expect(fake.loadCalls, 1);

    final out = det.detectFromDiffMap(
      _makeDiffMap(8, 6, [(2, 2, 3, 3, 0.95)], 0.1),
      8,
      6,
      settings: Settings.initial(),
    );
    expect(out, isNotEmpty);
    expect(fake.detectCalls, 1, reason: 'ネイティブ経路が呼ばれたはず');
  });

  test('FfiCnnDetector はネイティブが未利用なら Mock にフォールバック', () async {
    final fake = _FakeNativeDetector(available: false);
    final det = FfiCnnDetector(native: fake);

    // 同じ入力を Mock に直接渡した結果と一致することを確認
    final w = 10, h = 8;
    final diff = _makeDiffMap(w, h, [(1, 1, 2, 2, 0.95)], 0.1);
    final settings = Settings.initial().copyWith(
      detectColor: false,
      detectShape: false,
      detectPosition: false,
      detectSize: false,
      detectText: true,
      precision: 3,
    );

    await det.load(Uint8List(0));
    final outFfi = det.detectFromDiffMap(diff, w, h, settings: settings);

    final mock = MockCnnDetector();
    await mock.load(Uint8List(0));
    final outMock = mock.detectFromDiffMap(diff, w, h, settings: settings);

    expect(outFfi.length, outMock.length);
    expect(outFfi.first.box, outMock.first.box);
    expect(outFfi.first.category, outMock.first.category);
    expect(fake.detectCalls, 0, reason: '未利用ならネイティブ経路は呼ばれない');
  });
}
