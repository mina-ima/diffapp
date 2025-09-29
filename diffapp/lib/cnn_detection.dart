import 'dart:typed_data';
import 'dart:math' as math;

import 'image_pipeline.dart';
import 'settings.dart';

const _baselineArea = 64 * 64;

int _minAreaPixels(int width, int height, int minAreaPercent) {
  if (width <= 0 || height <= 0) return 1;
  if (minAreaPercent <= 0) return 1;
  final total = width * height;
  final effective = math.min(total, _baselineArea);
  final raw = (effective * (minAreaPercent / 100)).ceil();
  return math.max(1, raw);
}

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
    final steps = (p - Settings.minPrecision).toDouble();
    final t = 0.92 - steps * 0.06;
    return t.clamp(0.45, 0.9);
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

    final highThr = _thresholdForPrecision(settings.precision);
    final lowThr = (highThr * 0.5).clamp(0.2, highThr * 0.85);
    final totalPixels = width * height;
    final largeMap = totalPixels > _baselineArea;
    final minAreaPercent = settings.minAreaPercent;
    final minAreaPx = _minAreaPixels(width, height, minAreaPercent);
    final minCoreSideRaw = math.sqrt(minAreaPx).ceil();
    final minCoreSideLimit = math.min(width, height);
    final minCoreSide = minCoreSideRaw > 0
        ? math.max(1, math.min(minCoreSideLimit, minCoreSideRaw))
        : 1;

    final binary = List<int>.generate(
      diffMap.length,
      (i) => diffMap[i] >= lowThr ? 1 : 0,
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
      final peak = boxMaxScore(diffMap, width, b);
      if (peak < highThr) {
        continue;
      }
      if (area > maxAreaPixels) {
        continue; // giant regions are noise
      }
      final elongated = isElongated(b, ratio: 4.0);
      final support = _countSupportAbove(
        diffMap,
        width,
        height,
        b,
        threshold: lowThr,
      );
      if (support == 0) {
        continue;
      }
      final requiredSupport = _dynamicMinSupport(
        minAreaPx,
        peak,
        area,
        elongated,
        largeMap,
      );
      final meetsArea = support >= requiredSupport;
      if (!meetsArea) {
        continue;
      }
      boxes.add(b);
      scores.add(peak);
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
    final minScore = highThr * 0.7;
    final candidates = <Detection>[];
    for (var i = 0; i < keptBoxes.length && i < maxOutputs; i++) {
      final candidate = keptBoxes[i];
      final score = keptScores[i];
      if (score < minScore) {
        continue;
      }
      candidates.add(
        Detection(
          box: candidate,
          score: score,
          category: categories[candidates.length % categories.length],
        ),
      );
    }

    final remainingSlots = math.max(0, maxOutputs - candidates.length);
    if (remainingSlots > 0) {
      final boxes2 = <IntRect>[];
      final scores2 = <double>[];
      final supports2 = <int>[];
      final side = math.max(1, minCoreSide);
      final peaks = localMaxima2d(
        diffMap,
        width,
        height,
        radius: 3,
        threshold: highThr,
        maxFeatures: remainingSlots * 4,
      );
      final props = boxesFromPeaks(peaks, width, height, side: side);
      for (final b in props) {
        final area = b.width * b.height;
        final elongated = isElongated(b, ratio: 4.0);
        final supportLow = _countSupportAbove(
          diffMap,
          width,
          height,
          b,
          threshold: lowThr,
        );
        final meetsArea = supportLow >= minAreaPx ||
            (elongated && supportLow >= relaxedMinArea);
        if (!meetsArea) {
          continue;
        }
        final expanded = expandClampBox(b, 3, minCoreSide, width, height);
        final support = _countSupportAbove(
          diffMap,
          width,
          height,
          expanded,
          threshold: lowThr,
        );
        boxes2.add(expanded);
        supports2.add(support);
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
      final support = supports2[idx];
      final requiredSupport = _dynamicMinSupport(
        minAreaPx,
          scores2[idx],
          candidate.width * candidate.height,
          isElongated(candidate, ratio: 4.0),
          largeMap,
        );
        if (support < requiredSupport) {
          continue;
        }
        final score = _refineScoreTailMean(
          diffMap,
          width,
          height,
          candidate,
          tailRatio: 0.1,
        );
        if (score < minScore) {
          continue;
        }
        candidates.add(
          Detection(
            box: candidate,
            score: score,
            category: categories[candidates.length % categories.length],
          ),
        );
        if (candidates.length >= maxOutputs) {
          break;
        }
      }
    }

    if (largeMap && candidates.length < 3 && maxOutputs > candidates.length) {
      final needed = (3 - candidates.length).clamp(1, 4);
      final fallbackMinScore = highThr * 0.6;
      final fallbackPixels = <(double, int)>[];
      for (var idx = 0; idx < diffMap.length; idx++) {
        final v = diffMap[idx];
        if (v < fallbackMinScore) continue;
        fallbackPixels.add((v, idx));
      }
      if (fallbackPixels.isNotEmpty) {
        fallbackPixels.sort((a, b) => b.$1.compareTo(a.$1));
        final limit = math.min(fallbackPixels.length, needed * 8);
        final sideFallback = math.max(1, minCoreSide ~/ 2);
        for (var i = 0; i < limit; i++) {
          final entry = fallbackPixels[i];
          final idx = entry.$2;
          final x = idx % width;
          final y = idx ~/ width;
          bool nearExisting = false;
          for (final c in candidates) {
            final cx = c.box.left + c.box.width / 2.0;
            final cy = c.box.top + c.box.height / 2.0;
            final dx = cx - x;
            final dy = cy - y;
            if ((dx * dx + dy * dy) < 30 * 30) {
              nearExisting = true;
              break;
            }
          }
          if (nearExisting) {
            continue;
          }
          final half = (sideFallback / 2).ceil();
          final rect = IntRect(
            left: (x - half).clamp(0, width - 1),
            top: (y - half).clamp(0, height - 1),
            width: math.max(1, math.min(sideFallback, width - (x - half).clamp(0, width - 1))),
            height: math.max(1, math.min(sideFallback, height - (y - half).clamp(0, height - 1))),
          );
          final support = _countSupportAbove(
            diffMap,
            width,
            height,
            rect,
            threshold: lowThr,
          );
          if (support < 24) {
            continue;
          }
          final score = boxMaxScore(diffMap, width, rect);
          candidates.add(
            Detection(
              box: expandClampBox(rect, 2, math.max(1, sideFallback), width, height),
              score: score,
              category: categories[candidates.length % categories.length],
            ),
          );
          if (candidates.length >= 3) {
            break;
          }
        }
      }
    }

    if (candidates.isEmpty) {
      return const <Detection>[];
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    final selected = <Detection>[];
    final minSpacing = largeMap
        ? math.max(40.0, minCoreSide * 1.5)
        : math.max(18.0, minCoreSide * 0.8);
    bool separatedFromSelection(IntRect box) {
      for (final d in selected) {
        final cx1 = d.box.left + d.box.width / 2.0;
        final cy1 = d.box.top + d.box.height / 2.0;
        final cx2 = box.left + box.width / 2.0;
        final cy2 = box.top + box.height / 2.0;
        final dx = cx1 - cx2;
        final dy = cy1 - cy2;
        if ((dx * dx + dy * dy) < minSpacing * minSpacing) {
          return false;
        }
      }
      return true;
    }

    for (final cand in candidates) {
      if (separatedFromSelection(cand.box)) {
        selected.add(cand);
        if (selected.length >= maxOutputs) {
          break;
        }
      }
    }

    if (largeMap && selected.length < 3 && maxOutputs > selected.length) {
      final fallbackThreshold = highThr * 0.5;
      double bestVal = fallbackThreshold;
      IntRect? bestRect;
      for (var idx = 0; idx < diffMap.length; idx++) {
        final v = diffMap[idx];
        if (v < bestVal) continue;
        final x = idx % width;
        final y = idx ~/ width;
        final box = IntRect(
          left: math.max(0, x - minCoreSide ~/ 2),
          top: math.max(0, y - minCoreSide ~/ 2),
          width: math.max(1, math.min(minCoreSide, width - math.max(0, x - minCoreSide ~/ 2))),
          height: math.max(1, math.min(minCoreSide, height - math.max(0, y - minCoreSide ~/ 2))),
        );
        if (!separatedFromSelection(box)) {
          continue;
        }
        bestVal = v;
        bestRect = box;
      }
      if (bestRect != null) {
        final score = boxMaxScore(diffMap, width, bestRect);
        final det = Detection(
          box: expandClampBox(bestRect, 2, minCoreSide, width, height),
          score: score,
          category: categories[selected.length % categories.length],
        );
        selected.add(det);
      }
    }

    if (selected.isEmpty) {
      selected.add(candidates.first);
    }

    return selected;
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

  int _countSupportAbove(
    List<double> diffMap,
    int width,
    int height,
    IntRect box, {
    required double threshold,
  }) {
    final clamped = IntRect(
      left: box.left.clamp(0, width - 1),
      top: box.top.clamp(0, height - 1),
      width: math.max(1, math.min(box.width, width - box.left)),
      height: math.max(1, math.min(box.height, height - box.top)),
    );
    var count = 0;
    for (var y = clamped.top; y < clamped.top + clamped.height; y++) {
      final row = y * width;
      for (var x = clamped.left; x < clamped.left + clamped.width; x++) {
        if (diffMap[row + x] >= threshold) {
          count++;
        }
      }
    }
    return count;
  }

  int _dynamicMinSupport(
    int base,
    double peak,
    int area,
    bool elongated,
    bool largeMap,
  ) {
    if (!largeMap || base <= 1) {
      return math.max(1, base);
    }
    final clampedPeak = peak.clamp(0.0, 1.0);
    double factor;
    if (clampedPeak >= 0.95) {
      factor = elongated ? 0.1 : 0.12;
    } else if (clampedPeak >= 0.88) {
      factor = elongated ? 0.12 : 0.16;
    } else if (clampedPeak >= 0.82) {
      factor = elongated ? 0.16 : 0.22;
    } else {
      factor = elongated ? 0.18 : 0.26;
    }
    var relaxed = (base * factor).round();
    if (area <= 60) {
      relaxed = math.min(relaxed, 28);
    } else if (area <= 120) {
      relaxed = math.min(relaxed, 48);
    }
    return relaxed.clamp(30, base);
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
