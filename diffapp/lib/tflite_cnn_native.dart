import 'dart:typed_data';

import 'package:diffapp/cnn_detection.dart';
import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/settings.dart';

/// TFLite 呼び出しの Dart スタブ実装。
/// 将来的に TensorFlow Lite の実ランタイムへ置き換える前提で、
/// ひとまず `CnnNative` インタフェースを満たし、検出ロジックは
/// 既存の Dart パイプラインを用いて動作する。
class TfliteCnnNative implements CnnNative {
  bool _loaded = false;

  @override
  bool get isAvailable => true; // Dart 実装のため常に利用可能

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load(Uint8List modelData) async {
    // 実際の TFLite では modelData を Interpreter にロードする。
    // 現段階では存在チェックのみでロード済み扱いにする。
    _loaded = true;
  }

  double _thresholdForPrecision(int p) {
    if (p < Settings.minPrecision) p = Settings.minPrecision;
    if (p > Settings.maxPrecision) p = Settings.maxPrecision;
    return 0.9 - (p - 1) * 0.025;
  }

  List<DetectionCategory> _enabledCategories(Settings s) {
    final list = <DetectionCategory>[];
    if (s.detectColor) list.add(DetectionCategory.color);
    if (s.detectShape) list.add(DetectionCategory.shape);
    if (s.detectPosition) list.add(DetectionCategory.position);
    if (s.detectSize) list.add(DetectionCategory.size);
    if (s.detectText) list.add(DetectionCategory.text);
    return list.isEmpty ? [DetectionCategory.color] : list;
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
    if (!_loaded) {
      throw StateError('Model not loaded');
    }
    if (diffMap.length != width * height) {
      throw ArgumentError('diffMap length must equal width*height');
    }

    final thr = _thresholdForPrecision(settings.precision);
    final lowThr = (thr * 0.8).clamp(0.0, 1.0);
    final bin = hysteresisBinary(diffMap, width, height, high: thr, low: lowThr);
    const refArea = 64 * 64; // 4096 基準
    final minAreaPx = (refArea * (settings.minAreaPercent / 100)).ceil();
    // 小領域も拾ってから後段で形状別にフィルタする
    var boxes = connectedComponentsBoundingBoxes(
      bin,
      width,
      height,
      eightConnected: true,
      minArea: 2,
    );

    // 平均スコアを算出
    var scores = <double>[];
    for (final b in boxes) {
      scores.add(boxTailMeanScore(diffMap, width, b, tailRatio: 0.1));
    }

    // 極端に大きい領域（ほぼ全画面）を除外する上限フィルタ
    final maxAreaPx = (width * height * 0.3).ceil();
    if (boxes.isNotEmpty) {
      final nextBoxes = <IntRect>[];
      final nextScores = <double>[];
      // 最小面積の適用と細長領域の救済
      final refArea = 64 * 64; // keep local consistent
      final minAreaPx = (refArea * (settings.minAreaPercent / 100)).ceil();
      for (var i = 0; i < boxes.length; i++) {
        final b = boxes[i];
        final area = b.width * b.height;
        if (area > maxAreaPx) continue;
        final elongated = isElongated(b, ratio: 4.0);
        final enoughArea = area >= minAreaPx || (elongated && area >= (minAreaPx * 0.25));
        if (!enoughArea) continue;
        nextBoxes.add(b);
        nextScores.add(scores[i]);
      }
      boxes = nextBoxes;
      scores = nextScores;
    }

    // NMS
    final indices = List<int>.generate(boxes.length, (i) => i);
    indices.sort((a, b) => scores[b].compareTo(scores[a]));
    final kept = <int>[];
    final suppressed = List<bool>.filled(boxes.length, false);
    for (final idx in indices) {
      if (suppressed[idx]) continue;
      kept.add(idx);
      if (kept.length >= maxOutputs) break;
      for (final j in indices) {
        if (j == idx || suppressed[j]) continue;
        if (iou(boxes[idx], boxes[j]) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    // Fallback: if none kept, try adaptive method (Otsu + dilation with smaller min area)
    if (kept.isEmpty) {
      bool anyAboveHigh = false;
      for (final v in diffMap) {
        if (v >= thr) {
          anyAboveHigh = true;
          break;
        }
      }
      if (!anyAboveHigh) {
        return const <Detection>[];
      }
      final thrOtsu = otsuThreshold01(diffMap);
      final thr2 = (thrOtsu + thr) * 0.5;
      final low2 = (thr2 * 0.8).clamp(0.0, 1.0);
      final bin2 = hysteresisBinary(diffMap, width, height, high: thr2, low: low2);
      final bin2Dil = dilateBinary(bin2, width, height, iterations: 1);
      final minAreaPx2 = (refArea * (settings.minAreaPercent / 100)).ceil();
      var boxes2 = connectedComponentsBoundingBoxes(
        bin2Dil,
        width,
        height,
        eightConnected: true,
        minArea: 2,
      );
      final maxAreaPx2 = (width * height * 0.4).ceil();
      final scores2 = <double>[];
      for (final b in boxes2) {
        scores2.add(boxTailMeanScore(diffMap, width, b, tailRatio: 0.1));
      }
      if (boxes2.isNotEmpty) {
        final nb = <IntRect>[];
        final ns = <double>[];
        final minAreaPx2b = (refArea * (settings.minAreaPercent / 100)).ceil();
        for (var i = 0; i < boxes2.length; i++) {
          final b = boxes2[i];
          final area = b.width * b.height;
          if (area > maxAreaPx2) continue;
          final elongated = isElongated(b, ratio: 4.0);
          final enoughArea = area >= minAreaPx2b || (elongated && area >= (minAreaPx2b * 0.25));
          if (!enoughArea) continue;
          nb.add(b);
          ns.add(scores2[i]);
        }
        boxes2 = nb;
        scores2
          ..clear()
          ..addAll(ns);
      }
      final idx2 = List<int>.generate(boxes2.length, (i) => i);
      idx2.sort((a, b) => scores2[b].compareTo(scores2[a]));
      for (final i in idx2) {
        bool sup = false;
        for (final k in kept) {
          if (iou(boxes[k], boxes2[i]) > iouThreshold) {
            sup = true;
            break;
          }
        }
        if (!sup) {
          boxes.add(boxes2[i]);
          scores.add(scores2[i]);
          kept.add(boxes.length - 1);
          if (kept.length >= maxOutputs) break;
        }
      }
    }

    final cats = _enabledCategories(settings);
    final out = <Detection>[];
    for (var i = 0; i < kept.length; i++) {
      final k = kept[i];
      var b = boxes[k];
      b = refineBoxByQuantile(diffMap, width, height, b, quantile: 0.82);
      final argmax = argmaxByQuantile(diffMap, width, height, b, quantile: 0.8);
      if (argmax != null) {
        final (mx, my) = argmax;
        final minSide = (width * 0.08).round();
        final half = minSide ~/ 2;
        final left = (mx - half).clamp(0, width - 1);
        final top = (my - half).clamp(0, height - 1);
        b = IntRect(
          left: left,
          top: top,
          width: (minSide).clamp(1, width - left),
          height: (minSide).clamp(1, height - top),
        );
      }
      b = expandClampBox(b, 3, (width * 0.08).round(), width, height);
      final area = b.width * b.height;
      final elongatedLarge = isElongated(b, ratio: 3.5) && area > (width * height * 0.12);
      if (area <= 2 || elongatedLarge) continue;
      final cat = cats[i % cats.length];
      out.add(Detection(box: b, score: scores[k], category: cat));
    }
    if (out.length < 3) {
      final side = (width * 0.12).round();
      final peaks = localMaxima2d(diffMap, width, height,
          radius: 3, threshold: thr, maxFeatures: 5);
      final props = boxesFromPeaks(peaks, width, height, side: side);
      for (final p in props) {
        bool overlaps = false;
        for (final d in out) {
          if (iou(d.box, p) > 0.3) { overlaps = true; break; }
        }
        if (!overlaps) {
          out.add(Detection(box: p, score: 1.0, category: cats[out.length % cats.length]));
          if (out.length >= 3) break;
        }
      }
    }
    return out;
  }
}
