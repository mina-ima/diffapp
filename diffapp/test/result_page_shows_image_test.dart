import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:diffapp/screens/result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _makePng({int w = 64, int h = 64}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
  final base = Paint()..color = const Color(0xFF808080);
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), base);
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

void main() {
  testWidgets('検査結果ページで元画像プレビューが表示される', (tester) async {
    // シンプルな64x64グレー画像を左右に用意
    final leftBytes = await _makePng();
    final rightBytes = await _makePng();

    final left = SelectedImage(label: 'L', width: 64, height: 64, bytes: leftBytes);
    final right = SelectedImage(label: 'R', width: 64, height: 64, bytes: rightBytes);

    // 正規化寸法（ComparePageと同じ想定で 1280x? に揃えるが、ここでは簡略化して64x64）
    final norm = const Dimensions(64, 64);

    await tester.pumpWidget(
      MaterialApp(
        home: ResultPage(
          noDifferences: false,
          detections: const <IntRect>[],
          leftNorm: norm,
          left: left,
          right: right,
          selectedLeftRect: null,
        ),
      ),
    );

    // 画像デコード完了まで待機
    await tester.pumpAndSettle();

    // 結果画像のビューポート（キー）とイメージ（キー）が存在すること
    expect(find.byKey(const Key('result-image-viewport')), findsOneWidget);
    expect(find.byKey(const Key('result-image')), findsOneWidget);
  });
}
