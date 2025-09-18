import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _makePng({int w = 64, int h = 64, bool withDiff = false}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
  // base gray
  final base = Paint()..color = const Color(0xFF808080);
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), base);
  if (withDiff) {
    // draw a white rectangle in the center to ensure detection > 0
    final diffPaint = Paint()..color = const Color(0xFFFFFFFF);
    final rect = Rect.fromLTWH(w * 0.3, h * 0.3, w * 0.4, h * 0.4);
    canvas.drawRect(rect, diffPaint);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

void main() {
  testWidgets('検査結果ページで検出矩形オーバーレイが表示される', (tester) async {
    final leftBytes = await _makePng(w: 64, h: 64, withDiff: false);
    final rightBytes = await _makePng(w: 64, h: 64, withDiff: true);

    final left = SelectedImage(label: 'L', width: 64, height: 64, bytes: leftBytes);
    final right = SelectedImage(label: 'R', width: 64, height: 64, bytes: rightBytes);

    await tester.pumpWidget(
      MaterialApp(
        home: ComparePage(left: left, right: right, enableSound: false),
      ),
    );

    // 検査実行
    await tester.tap(find.text('検査をはじめる'));
    // ComparePage は常時アニメしているため、段階的に進める
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 結果ページに検出オーバーレイ（左のみ）が少なくとも1件表示されること
    expect(find.byKey(const Key('det-left-0')), findsOneWidget);
  });
}
