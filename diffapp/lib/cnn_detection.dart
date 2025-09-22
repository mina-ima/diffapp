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
    // Hysteresis: strong/weak thresholds to avoid large faint regions and keep connected strong signals
    final lowThr = (thr * 0.8).clamp(0.0, 1.0);
    final bin = hysteresisBinary(diffMap, width, height, high: thr, low: lowThr);
    // 最小面積（%）は基準解像度64x64に対するピクセル数として扱い、
    // 解析解像度が上がっても絶対面積しきい値が過度に増えないようにする。
    const refArea = 64 * 64; // 4096
    final minAreaPx = (refArea * (settings.minAreaPercent / 100)).ceil();
    var boxes = connectedComponentsBoundingBoxes(
      bin,
      width,
      height,
      eightConnected: true,
      minArea: minAreaPx < 2 ? 2 : minAreaPx,
    );

    // scores = peak (max) diff value within each box（広域よりも局所の強さを優先）
    var scores = <double>[];
    for (final b in boxes) {
      scores.add(boxMaxScore(diffMap, width, b));
    }

    // Filter out overly-large regions (e.g., near full-screen) by max area ratio
    final maxAreaPx = (width * height * 0.3).ceil(); // 30% 上限（広域誤検出の抑制強化）
    if (boxes.isNotEmpty) {
      final nextBoxes = <IntRect>[];
      final nextScores = <double>[];
      for (var i = 0; i < boxes.length; i++) {
        final area = boxes[i].width * boxes[i].height;
        if (area <= maxAreaPx) {
          nextBoxes.add(boxes[i]);
          nextScores.add(scores[i]);
        }
      }
      boxes = nextBoxes;
      scores = nextScores;
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

    // Fallback: if nothing detected, try adaptive threshold + dilation with smaller min area.
    if (selected.isEmpty) {
      // respect precision threshold semantics: if nothing is above the high threshold,
      // do not try adaptive fallback (prevents low precision from detecting).
      bool anyAboveHigh = false;
      for (final v in diffMap) {
        if (v >= thr) {
          anyAboveHigh = true;
          break;
        }
      }
      if (!anyAboveHigh) {
        // return empty detections
        final cats = _enabledCategories(settings);
        // keep API behavior: just return empty list
        return const <Detection>[];
      }
      final thrOtsu = otsuThreshold01(diffMap);
      final thr2 = (thrOtsu + thr) * 0.5; // blend to avoid too low threshold
      final low2 = (thr2 * 0.8).clamp(0.0, 1.0);
      final bin2 = hysteresisBinary(diffMap, width, height, high: thr2, low: low2);
      final bin2Dil = dilateBinary(bin2, width, height, iterations: 1);
      final minAreaPx2 = (refArea * (settings.minAreaPercent / 100)).ceil();
      var boxes2 = connectedComponentsBoundingBoxes(
        bin2Dil,
        width,
        height,
        eightConnected: true,
        minArea: minAreaPx2 < 2 ? 2 : minAreaPx2,
      );
      // apply the same max area cap
      final maxAreaPx2 = (width * height * 0.4).ceil();
      final scores2 = <double>[];
      for (final b in boxes2) {
        scores2.add(boxMaxScore(diffMap, width, b));
      }
      if (boxes2.isNotEmpty) {
        final nb = <IntRect>[];
        final ns = <double>[];
        for (var i = 0; i < boxes2.length; i++) {
          final area = boxes2[i].width * boxes2[i].height;
          if (area <= maxAreaPx2) {
            nb.add(boxes2[i]);
            ns.add(scores2[i]);
          }
        }
        boxes2 = nb;
        // scores2 will be re-bound below to ns
        // Rebuild scores2 to filtered list
        scores2
          ..clear()
          ..addAll(ns);
      }
      final idx2 = List<int>.generate(boxes2.length, (i) => i);
      idx2.sort((a, b) => scores2[b].compareTo(scores2[a]));
      for (final i in idx2) {
        bool sup = false;
        for (final kept in selected) {
          if (iou(boxes[kept], boxes2[i]) > iouThreshold) {
            sup = true;
            break;
          }
        }
        if (!sup) {
          // append as additional detections
          boxes.add(boxes2[i]);
          scores.add(scores2[i]);
          selected.add(boxes.length - 1);
          if (selected.length >= maxOutputs) break;
        }
      }
    }

    // Refine each box to tighten around peaks and filter elongated large regions
    final cats = _enabledCategories(settings);
    final out = <Detection>[];
    for (var i = 0; i < selected.length; i++) {
      final idxSel = selected[i];
      var b = boxes[idxSel];
      // Slightly looser quantile to keep structure
      b = refineBoxByQuantile(diffMap, width, height, b, quantile: 0.82);
      // Recenter around weighted centroid and ensure minimum visible size
      final argmax = argmaxByQuantile(diffMap, width, height, b, quantile: 0.8);
      if (argmax != null) {
        final (mx, my) = argmax;
        final minSide = (width * 0.08).round(); // 少し大きめに
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
      out.add(Detection(box: b, score: scores[idxSel], category: cat));
    }
    // If too few boxes, supplement with peak-based proposals
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
