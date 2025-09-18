import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:diffapp/image_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _makeTestImageBytes() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // 左上は赤、その他は青で塗り分け
  final red = ui.Paint()..color = const ui.Color(0xFFFF0000);
  final blue = ui.Paint()..color = const ui.Color(0xFF0000FF);
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 50, 50), red);
  canvas.drawRect(const ui.Rect.fromLTWH(50, 0, 50, 50), blue);
  canvas.drawRect(const ui.Rect.fromLTWH(0, 50, 100, 50), blue);
  final picture = recorder.endRecording();
  final image = await picture.toImage(100, 100);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

Future<ui.Color> _sampleCenterColor(ui.Image image) async {
  final bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final byteData = bd!.buffer.asUint8List();
  final w = image.width;
  final h = image.height;
  final cx = (w / 2).floor();
  final cy = (h / 2).floor();
  final idx = (cy * w + cx) * 4;
  final r = byteData[idx];
  final g = byteData[idx + 1];
  final b = byteData[idx + 2];
  final a = byteData[idx + 3];
  return ui.Color.fromARGB(a, r, g, b);
}

void main() {
  test('範囲指定の矩形どおりに切り出される（左上=赤を取得）', () async {
    // 元画像（100x100, 左上=赤 それ以外=青）
    final bytes = await _makeTestImageBytes();
    const originalW = 100;
    const originalH = 100;

    // ComparePage の正規化では 100x100 はそのまま（1280 未満）
    const normalizedW = 100;
    const normalizedH = 100;

    // 切り出し矩形（正規化空間）
    const rect = IntRect(left: 0, top: 0, width: 50, height: 50);

    // CroppedImage と同じロジック: 実画像ピクセル空間にスケールして drawImageRect
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final srcScaleX = originalW / normalizedW;
    final srcScaleY = originalH / normalizedH;
    final src = ui.Rect.fromLTWH(
      rect.left * srcScaleX.toDouble(),
      rect.top * srcScaleY.toDouble(),
      rect.width * srcScaleX.toDouble(),
      rect.height * srcScaleY.toDouble(),
    );

    // 出力先（適当な 50x50）
    const outW = 50.0;
    const outH = 50.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      frame.image,
      src,
      ui.Rect.fromLTWH(0, 0, outW, outH),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    final outImage = await picture.toImage(outW.toInt(), outH.toInt());

    // 中央画素の色をサンプルし、赤系であることを確認
    final center = await _sampleCenterColor(outImage);
    expect(center.red, greaterThan(200));
    expect(center.green, lessThan(60));
    expect(center.blue, lessThan(60));
  });
}
