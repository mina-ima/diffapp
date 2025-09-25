import 'dart:typed_data';
import 'dart:math' as math;

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

/// ネイティブ実装インタフェース（将来的にTFLiteへ接続）。
/// FfiCnnDetector へ注入可能で、利用可能な場合は優先的に使用される。
abstract class CnnNative {
  bool get isAvailable;
  bool get isLoaded;
  Future<void> load(Uint8List modelData);
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
    if (p < Settings.minPrecision) p = Settings.minPrecision;
    if (p > Settings.maxPrecision) p = Settings.maxPrecision;
    final t = 0.9 - (p - 1) * 0.05;
    return t.clamp(0.6, 0.9);
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

    final threshold = _thresholdForPrecision(settings.precision);
    final totalPixels = width * height;
    final minAreaPercent = settings.minAreaPercent;
    final minAreaPx = minAreaPercent <= 0
        ? 1
        : ((totalPixels * minAreaPercent) / 100).ceil();
    final minCoreSideRaw = math.sqrt(minAreaPx).ceil();
    final minCoreSideLimit = math.min(width, height);
    final minCoreSide = minCoreSideRaw > 0
        ? math.max(1, math.min(minCoreSideLimit, minCoreSideRaw))
        : 1;

    final binary = List<int>.generate(
      diffMap.length,
      (i) => diffMap[i] >= threshold ? 1 : 0,
      growable: false,
    );

    final rawBoxes = connectedComponentsBoundingBoxes(
      binary,
      width,
      height,
      eightConnected: true,
      minArea: 1,
    );
    if (rawBoxes.isEmpty) {
      return const <Detection>[];
    }

    final scores = <double>[];
    final boxes = <IntRect>[];
    final relaxedMinArea = math.max(1, (minAreaPx * 0.25).floor());
    final maxAreaPixels = (totalPixels * 0.3).ceil();
    for (final b in rawBoxes) {
      final area = b.width * b.height;
      if (area > maxAreaPixels) {
        continue; // giant regions are noise
      }
      final elongated = isElongated(b, ratio: 4.0);
      final meetsArea =
          area >= minAreaPx || (elongated && area >= relaxedMinArea);
      if (!meetsArea) {
        continue;
      }
      boxes.add(b);
      scores.add(boxMaxScore(diffMap, width, b));
    }
    if (boxes.isEmpty) {
      return const <Detection>[];
    }

    final indices = _runNms(
      boxes,
      scores,
      iouThreshold: iouThreshold,
      maxOutputs: maxOutputs,
    );
    if (indices.isEmpty) {
      return const <Detection>[];
    }

    final keptBoxes = <IntRect>[];
    final keptScores = <double>[];
    for (final idx in indices) {
      final base = boxes[idx];
      final expanded = expandClampBox(base, 3, minCoreSide, width, height);
      keptBoxes.add(expanded);
      keptScores.add(
        _refineScoreTailMean(diffMap, width, height, expanded, tailRatio: 0.12),
      );
    }

    final categories = _enabledCategories(settings);
    final detections = <Detection>[];
    for (var i = 0; i < keptBoxes.length && i < maxOutputs; i++) {
      detections.add(
        Detection(
          box: keptBoxes[i],
          score: keptScores[i],
          category: categories[i % categories.length],
        ),
      );
    }

    final remainingSlots = math.max(0, maxOutputs - detections.length);
    if (remainingSlots > 0) {
      final boxes2 = <IntRect>[];
      final scores2 = <double>[];
      final side = math.max(1, minCoreSide);
      final peaks = localMaxima2d(
        diffMap,
        width,
        height,
        radius: 3,
        threshold: threshold,
        maxFeatures: remainingSlots * 4,
      );
      final props = boxesFromPeaks(peaks, width, height, side: side);
      for (final b in props) {
        final area = b.width * b.height;
        final elongated = isElongated(b, ratio: 4.0);
        final meetsArea =
            area >= minAreaPx || (elongated && area >= relaxedMinArea);
        if (!meetsArea) {
          continue;
        }
        boxes2.add(expandClampBox(b, 3, minCoreSide, width, height));
      }
      for (final b in boxes2) {
        scores2.add(boxMaxScore(diffMap, width, b));
      }
      final secondPassIndices = _runNms(
        boxes2,
        scores2,
        iouThreshold: math.min(0.45, iouThreshold * 0.9),
        maxOutputs: remainingSlots,
      );
      for (final idx in secondPassIndices) {
        final candidate = boxes2[idx];
        bool overlaps = false;
        for (final existing in detections) {
          if (iou(existing.box, candidate) > 0.35) {
            overlaps = true;
            break;
          }
        }
        if (overlaps) {
          continue;
        }
        final score = _refineScoreTailMean(
          diffMap,
          width,
          height,
          candidate,
          tailRatio: 0.1,
        );
        detections.add(
          Detection(
            box: candidate,
            score: score,
            category: categories[detections.length % categories.length],
          ),
        );
        if (detections.length >= maxOutputs) {
          break;
        }
      }
    }

    return detections;
  }

  List<int> _runNms(
    List<IntRect> boxes,
    List<double> scores, {
    double iouThreshold = 0.5,
    int maxOutputs = 20,
  }) {
    if (boxes.isEmpty) return const <int>[];
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
    return selected;
  }

  double _refineScoreTailMean(
    List<double> diffMap,
    int width,
    int height,
    IntRect box, {
    double tailRatio = 0.1,
  }) {
    final area = box.width * box.height;
    if (area <= 0) {
      return 0;
    }
    final clamped = IntRect(
      left: box.left.clamp(0, width - 1),
      top: box.top.clamp(0, height - 1),
      width: math.max(1, math.min(box.width, width - box.left)),
      height: math.max(1, math.min(box.height, height - box.top)),
    );
    return boxTailMeanScore(
      diffMap,
      width,
      clamped,
      tailRatio: tailRatio.clamp(0.02, 0.3),
    );
  }

}

/// FFI Detector 土台。現状は Mock にフォールバック。
class FfiCnnDetector implements CnnDetector {
  final MockCnnDetector _fallback = MockCnnDetector();
  final CnnNative? _native;

  FfiCnnDetector({CnnNative? native}) : _native = native;

  @override
  bool get isLoaded {
    final n = _native;
    if (n != null && n.isAvailable) return n.isLoaded;
    return _fallback.isLoaded;
  }

  @override
  Future<void> load(Uint8List modelData) async {
    final n = _native;
    if (n != null && n.isAvailable) {
      await n.load(modelData);
      return;
    }
    await _fallback.load(modelData);
  }

  @override
  List<Detection> detectFromDiffMap(List<double> diffMap, int width, int height,
      {required Settings settings,
      int maxOutputs = 20,
      double iouThreshold = 0.5}) {
    final n = _native;
    if (n != null && n.isAvailable) {
      return n.detectFromDiffMap(
        diffMap,
        width,
        height,
        settings: settings,
        maxOutputs: maxOutputs,
        iouThreshold: iouThreshold,
      );
    }
    return _fallback.detectFromDiffMap(
      diffMap,
      width,
      height,
      settings: settings,
      maxOutputs: maxOutputs,
      iouThreshold: iouThreshold,
    );
  }
}
