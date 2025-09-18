import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:diffapp/cnn_detection.dart';
import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:diffapp/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpyDetector implements CnnDetector {
  bool _loaded = false;
  Settings? lastSettings;

  @override
  Future<void> load(Uint8List modelData) async {
    _loaded = true;
  }

  @override
  bool get isLoaded => _loaded;

  @override
  List<Detection> detectFromDiffMap(List<double> diffMap, int width, int height,
      {required Settings settings, int maxOutputs = 20, double iouThreshold = 0.5}) {
    lastSettings = settings;
    return const <Detection>[];
  }
}

void main() {
  Future<Uint8List> makePng({int w = 16, int h = 16}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    final p = Paint()..color = const Color(0xFF808080);
    canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), p);
    final pic = recorder.endRecording();
    final img = await pic.toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  testWidgets('ComparePage は渡された Settings を検出器に引き渡す', (tester) async {
    final bytes = await makePng();
    final left = SelectedImage(label: 'L', width: 16, height: 16, bytes: bytes);
    final right = SelectedImage(label: 'R', width: 16, height: 16, bytes: bytes);

    final spy = _SpyDetector();
    final custom = const Settings(
      detectColor: true,
      detectShape: false,
      detectPosition: true,
      detectSize: false,
      detectText: true,
      enableSound: false,
      precision: 5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ComparePage(
          left: left,
          right: right,
          enableSound: false,
          settings: custom,
          detector: spy,
        ),
      ),
    );

    await tester.tap(find.text('検査をはじめる'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(spy.lastSettings, isNotNull);
    expect(spy.lastSettings!.precision, 5);
    expect(spy.lastSettings!.detectShape, isFalse);
    expect(spy.lastSettings!.enableSound, isFalse);
  });
}
