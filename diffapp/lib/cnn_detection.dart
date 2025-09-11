import 'dart:typed_data';

import 'image_pipeline.dart';
import 'settings.dart';

enum DetectionCategory { color, shape, position, size, text }

class Detection {
  final IntRect box;
  final double score;
  final DetectionCategory category;
  const Detection(
      {required this.box, required this.score, required this.category});
}

abstract class CnnDetector {
  bool get isLoaded;
  Future<void> load(Uint8List modelData);

  /// Detect from a normalized difference map (0..1 where higher means more different).
  List<Detection> detectFromDiffMap(
    List<double> diffMap,
    int width,
    int height, {
    required Settings settings,
    int maxOutputs = 20,
    double iouThreshold = 0.5,
  });
}

class MockCnnDetector implements CnnDetector {
  bool _loaded = false;
  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load(Uint8List modelData) async {
    // pretend to parse model
    _loaded = true;
  }

  double _thresholdForPrecision(int p) {
    // precision:1..5 => threshold 0.9 .. 0.8 (higher precision = more sensitive)
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
    final boxes = connectedComponentsBoundingBoxes(
      bin,
      width,
      height,
      eightConnected: true,
      minArea: 2,
    );

    // scores = mean diff value within each box
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

    // NMS (keeping indices)
    final indices = List<int>.generate(boxes.length, (i) => i);
    indices.sort((a, b) => scores[b].compareTo(scores[a]));
    final selected = <int>[];
    final suppressed = List<bool>.filled(boxes.length, false);
    for (final idx in indices) {
      if (suppressed[idx]) continue;
      selected.add(idx);
      if (selected.length >= maxOutputs) break;
      for (final j in indices) {
        if (j == idx || suppressed[j]) continue;
        if (iou(boxes[idx], boxes[j]) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    final cats = _enabledCategories(settings);
    final out = <Detection>[];
    for (var i = 0; i < selected.length; i++) {
      final idx = selected[i];
      final cat = cats[i % cats.length];
      out.add(Detection(box: boxes[idx], score: scores[idx], category: cat));
    }
    return out;
  }
}

/// FFI Detector 土台。現状は Mock にフォールバック。
class FfiCnnDetector implements CnnDetector {
  final MockCnnDetector _fallback = MockCnnDetector();

  @override
  bool get isLoaded => _fallback.isLoaded;

  @override
  Future<void> load(Uint8List modelData) => _fallback.load(modelData);

  @override
  List<Detection> detectFromDiffMap(List<double> diffMap, int width, int height,
          {required Settings settings,
          int maxOutputs = 20,
          double iouThreshold = 0.5}) =>
      _fallback.detectFromDiffMap(diffMap, width, height,
          settings: settings,
          maxOutputs: maxOutputs,
          iouThreshold: iouThreshold);
}
