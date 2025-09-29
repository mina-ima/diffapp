import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:diffapp/cnn_detection.dart';
import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/settings.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decodePng(String relativePath) async {
  final file = File(relativePath);
  if (!file.existsSync()) {
    throw Exception('Sample image not found: $relativePath');
  }
  final bytes = await file.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

Future<Uint8List> _resizeToRgba(ui.Image image, int outW, int outH) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final src = ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  final dst = ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());
  canvas.drawImageRect(image, src, dst, ui.Paint()..filterQuality = ui.FilterQuality.high);
  final picture = recorder.endRecording();
  final scaled = await picture.toImage(outW, outH);
  final byteData = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);
  return byteData!.buffer.asUint8List();
}

List<int> _rgbaToGray(Uint8List rgba) {
  final out = List<int>.filled(rgba.length ~/ 4, 0);
  for (var i = 0, p = 0; i < out.length; i++, p += 4) {
    final r = rgba[p];
    final g = rgba[p + 1];
    final b = rgba[p + 2];
    out[i] = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('実写サンプル(左画像/右画像)で3件の差分を検出できる', () async {
    const analysisSize = 256;
    final leftImage = await _decodePng('../左画像.png');
    final rightImage = await _decodePng('../右画像.png');

    final leftRgba = await _resizeToRgba(leftImage, analysisSize, analysisSize);
    final rightRgba = await _resizeToRgba(rightImage, analysisSize, analysisSize);
    final leftGray = _rgbaToGray(leftRgba);
    final rightGray = _rgbaToGray(rightRgba);

    final blurL = boxBlurU8(leftGray, analysisSize, analysisSize, radius: 1);
    final blurR = boxBlurU8(rightGray, analysisSize, analysisSize, radius: 1);
    final ssim = computeSsimMapUint8(blurL, blurR, analysisSize, analysisSize, windowRadius: 0);
    final diffSsim = List<double>.generate(ssim.length, (i) => 1.0 - ssim[i]);
    final diffColor = colorDiffMapRgbaRobust(leftRgba, rightRgba, analysisSize, analysisSize);
    final gradL = sobelGradMagU8(leftGray, analysisSize, analysisSize);
    final gradR = sobelGradMagU8(rightGray, analysisSize, analysisSize);
    final diffGrad = List<double>.generate(diffSsim.length, (i) => (gradL[i] - gradR[i]).abs());
    final diffGradN = normalizeToUnit(diffGrad);
    final geom = List<double>.generate(diffSsim.length, (i) =>
        math.sqrt(diffSsim[i] * diffColor[i]));
    final diffCombined = List<double>.generate(diffSsim.length, (i) {
      final s = diffSsim[i] * 0.6 + diffGradN[i] * 0.4;
      final c = diffColor[i] * 1.35;
      final g = geom[i] * 1.1;
      final m1 = s > c ? s : c;
      return m1 > g ? m1 : g;
    });
    final edgeCommon = List<double>.generate(diffCombined.length, (i) {
      final a = gradL[i];
      final b = gradR[i];
      return a < b ? a : b;
    });
    final edgeSuppression = List<double>.generate(edgeCommon.length, (i) => 1.0 - edgeCommon[i]);
    final diffFinal = List<double>.generate(diffCombined.length, (i) {
      final mask = 0.75 + 0.25 * edgeSuppression[i];
      return diffCombined[i] * mask;
    });
    final diffN = normalizeToUnit(diffFinal);

    final detector = FfiCnnDetector();
    await detector.load(Uint8List(0));
    final detections = detector.detectFromDiffMap(
      diffN,
      analysisSize,
      analysisSize,
      settings: Settings.initial(),
      maxOutputs: 20,
      iouThreshold: 0.3,
    );

    expect(detections.length, 3);

    final centers = detections
        .map((d) => (
              d.box.left + d.box.width / 2,
              d.box.top + d.box.height / 2,
            ))
        .toList();
    // 各中心が十分離れており、3箇所の差分を拾えていることを確認
    final distances = <double>[];
    for (var i = 0; i < centers.length; i++) {
      for (var j = i + 1; j < centers.length; j++) {
        final dx = centers[i].$1 - centers[j].$1;
        final dy = centers[i].$2 - centers[j].$2;
        distances.add(math.sqrt(dx * dx + dy * dy));
      }
    }
    expect(distances.every((d) => d > 40), isTrue,
        reason: '検出結果が1箇所に集中しすぎている');
  });
}
