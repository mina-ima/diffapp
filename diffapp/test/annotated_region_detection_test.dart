import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:diffapp/cnn_detection.dart';
import 'package:diffapp/settings.dart';
import 'package:diffapp/image_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> _decodeToGray(String path, int outW, int outH) async {
  final data = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(data);
  final fi = await codec.getNextFrame();
  final image = fi.image;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final src = ui.Offset.zero & ui.Size(image.width.toDouble(), image.height.toDouble());
  final dst = ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());
  final paint = ui.Paint();
  canvas.drawImageRect(image, src, dst, paint);
  final picture = recorder.endRecording();
  final scaled = await picture.toImage(outW, outH);
  final byteData = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgba = byteData!.buffer.asUint8List();
  final gray = List<int>.filled(outW * outH, 0);
  for (var i = 0, p = 0; i < gray.length; i++, p += 4) {
    final r = rgba[p];
    final g = rgba[p + 1];
    final b = rgba[p + 2];
    final y = (0.299 * r + 0.587 * g + 0.114 * b).round();
    gray[i] = y.clamp(0, 255);
  }
  return gray;
}

Future<List<(double, double, int, int)>> _annotCenters(String path) async {
  final data = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(data);
  final fi = await codec.getNextFrame();
  final image = fi.image;
  final w = image.width;
  final h = image.height;
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgba = byteData!.buffer.asUint8List();
  bool isPurple(int r, int g, int b) => r > 150 && b > 150 && g < 140;
  final visited = List<bool>.filled(w * h, false);
  int idx(int x, int y) => y * w + x;
  final centers = <(double, double, int, int)>[];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = idx(x, y);
      if (visited[i]) continue;
      final p = i * 4;
      final r = rgba[p];
      final g = rgba[p + 1];
      final b = rgba[p + 2];
      if (!isPurple(r, g, b)) continue;
      // BFS component
      double sumX = 0, sumY = 0;
      int count = 0;
      int minX = x, maxX = x, minY = y, maxY = y;
      final q = <(int, int)>[(x, y)];
      visited[i] = true;
      while (q.isNotEmpty) {
        final (cx, cy) = q.removeLast();
        final j = idx(cx, cy);
        final pj = j * 4;
        final rj = rgba[pj];
        final gj = rgba[pj + 1];
        final bj = rgba[pj + 2];
        if (!isPurple(rj, gj, bj)) continue;
        sumX += cx;
        sumY += cy;
        count++;
        if (cx < minX) minX = cx;
        if (cx > maxX) maxX = cx;
        if (cy < minY) minY = cy;
        if (cy > maxY) maxY = cy;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = cx + dx;
            final ny = cy + dy;
            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
            final ni = idx(nx, ny);
            if (visited[ni]) continue;
            visited[ni] = true;
            q.add((nx, ny));
          }
        }
      }
      if (count > 200) { // ignore tiny artifacts
        centers.add((sumX / count, sumY / count, w, h));
      }
    }
  }
  if (centers.isEmpty) {
    centers.add((w / 2, h / 2, w, h));
  }
  return centers;
}

void main() {
  test('注釈画像の紫円の中心付近を検出できる', () async {
    const targetW = 64, targetH = 64;
    final grayL = await _decodeToGray('../左画像.png', targetW, targetH);
    final grayR = await _decodeToGray('../右画像.png', targetW, targetH);

    // Compute diff (SSIM -> 1-ssim) and normalize like app does
    final ssim = computeSsimMapUint8(grayL, grayR, targetW, targetH, windowRadius: 0);
    final diff = ssim.map((v) => 1.0 - v).toList();
    final diffN = normalizeToUnit(diff);

    final det = FfiCnnDetector();
    await det.load(Uint8List(0));
    final settings = Settings.initial().copyWith(
      precision: 5,
      // 小さな差分も拾えるように 0% に緩和
      minAreaPercent: 0,
    );
    final results = det.detectFromDiffMap(diffN, targetW, targetH, settings: settings);
    expect(results.isNotEmpty, isTrue, reason: '少なくとも1件は検出される');

    // Centers from purple circles
    final centers = await _annotCenters('../検出画像.png');
    bool near = false;
    double best = 1e9;
    for (final (cx, cy, aw, ah) in centers) {
      final expX = cx * (targetW / aw);
      final expY = cy * (targetH / ah);
      for (final r in results) {
        final bx = r.box.left + r.box.width / 2.0;
        final by = r.box.top + r.box.height / 2.0;
        final dx = bx - expX;
        final dy = by - expY;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < best) best = d;
        if (d <= 32.0) {
          near = true;
          break;
        }
      }
      if (near) break;
    }
    expect(near, isTrue, reason: '検出中心が注釈円のいずれかに近い (best=$best)');
  });
}
