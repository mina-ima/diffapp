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
    final bin = thresholdBinary(diffMap, thr);
    final minAreaPx = (width * height * (settings.minAreaPercent / 100)).ceil();
    final boxes = connectedComponentsBoundingBoxes(
      bin,
      width,
      height,
      eightConnected: true,
      minArea: minAreaPx < 2 ? 2 : minAreaPx,
    );

    // 平均スコアを算出
    final scores = <double>[];
    for (final b in boxes) {
      double sum = 0;
      int cnt = 0;
      for (var y = b.top; y < b.top + b.height; y++) {
        for (var x = b.left; x < b.left + b.width; x++) {
          sum += diffMap[y * width + x];
          cnt++;
        }
      }
      scores.add(cnt == 0 ? 0.0 : sum / cnt);
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

    final cats = _enabledCategories(settings);
    final out = <Detection>[];
    for (var i = 0; i < kept.length; i++) {
      final k = kept[i];
      final cat = cats[i % cats.length];
      out.add(Detection(box: boxes[k], score: scores[k], category: cat));
    }
    return out;
  }
}
