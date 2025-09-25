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
    // precision:1..5 => threshold 0.85 .. 0.65 程度（高精度ほどしきい値を下げて検出しやすく）
    if (p < Settings.minPrecision) p = Settings.minPrecision;
    if (p > Settings.maxPrecision) p = Settings.maxPrecision;
    final t = 0.9 - (p - 1) * 0.05; // p=3 -> 0.8, p=5 -> 0.7
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
    final thr = _thresholdForPrecision(settings.precision);
    // Hysteresis: strong/weak thresholds to avoid large faint regions and keep connected strong signals
    final lowThr = (thr * 0.8).clamp(0.0, 1.0);
    final bin = hysteresisBinary(diffMap, width, height, high: thr, low: lowThr);
    // 最小面積（%）は基準解像度64x64に対するピクセル数として扱い、
    // 解析解像度が上がっても絶対面積しきい値が過度に増えないようにする。
    const refArea = 64 * 64; // 4096
    final minAreaPx = (refArea * (settings.minAreaPercent / 100)).ceil();
    // まずは小領域も含めて連結成分を抽出（最小面積は後段の形状別フィルタで調整）
    var boxes = connectedComponentsBoundingBoxes(
      bin,
      width,
      height,
      eightConnected: true,
      minArea: 2,
    );

    // scores = peak (max) diff value within each box（広域よりも局所の強さを優先）
    var scores = <double>[];
    for (final b in boxes) {
      scores.add(boxMaxScore(diffMap, width, b));
    }

    // 面積・形状に応じたフィルタリング
    // - 広域（画面の30%以上）は除外
    // - 通常は minAreaPx 未満を除外
    // - ただし細長い領域（比率>=4.0）は minAreaPx の25% 以上なら許容（背表紙のような細い差分を拾う）
    final maxAreaPx = (width * height * 0.3).ceil();
    if (boxes.isNotEmpty) {
      final nextBoxes = <IntRect>[];
      final nextScores = <double>[];
      for (var i = 0; i < boxes.length; i++) {
        final b = boxes[i];
        final area = b.width * b.height;
        if (area > maxAreaPx) continue; // 大きすぎる
        final elongated = isElongated(b, ratio: 4.0);
        final enoughArea = area >= minAreaPx || (elongated && area >= (minAreaPx * 0.25));
        if (!enoughArea) continue;
        nextBoxes.add(b);
        nextScores.add(scores[i]);
      }
      boxes = nextBoxes;
      scores = nextScores;
    }

    // NMS (keeping indices)
    var selected = _runNms(
      boxes,
      scores,
      iouThreshold: iouThreshold,
      maxOutputs: maxOutputs,
    );

    // Fallback: if nothing detected, try adaptive threshold + dilation even if全体が弱い場合
    if (selected.isEmpty) {
      final thrOtsu = otsuThreshold01(diffMap);
      final thr2 = (thrOtsu + thr) * 0.5; // 固定値よりも画像分布に寄せる
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
          final b = boxes2[i];
          final area = b.width * b.height;
          if (area > maxAreaPx2) continue;
          final elongated = isElongated(b, ratio: 4.0);
          final enoughArea = area >= minAreaPx2 || (elongated && area >= (minAreaPx2 * 0.25));
          if (!enoughArea) continue;
          nb.add(b);
          ns.add(scores2[i]);
        }
        boxes2 = nb;
        scores2
          ..clear()
          ..addAll(ns);
      }
      final idx2 = List<int>.generate(boxes2.length, (i) => i)
        ..sort((a, b) => scores2[b].compareTo(scores2[a]));
      for (final i in idx2) {
        boxes.add(boxes2[i]);
        scores.add(scores2[i]);
      }
      selected = _runNms(
        boxes,
        scores,
        iouThreshold: iouThreshold,
        maxOutputs: maxOutputs,
      );
    }

    // Refine each box to tighten around peaks and filter elongated large regions
    final cats = _enabledCategories(settings);
    final refinedBoxes = <IntRect>[];
    final refinedScores = <double>[];
    final refinedCats = <DetectionCategory>[];
    for (var i = 0; i < selected.length; i++) {
      final idxSel = selected[i];
      final peak = scores[idxSel];
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

      final refinedScore = _refineScoreTailMean(
        diffMap,
        width,
        b,
        peakScore: peak,
      );
      if (refinedScore == null) {
        continue;
      }

      refinedBoxes.add(b);
      refinedScores.add(refinedScore);
      refinedCats.add(cats[refinedCats.length % cats.length]);
    }

    final out = <Detection>[];
    if (refinedBoxes.isNotEmpty) {
      final secondPassIndices = _runNms(
        refinedBoxes,
        refinedScores,
        iouThreshold: (iouThreshold * 0.85).clamp(0.2, 0.5),
        maxOutputs: maxOutputs,
      );
      for (final idx in secondPassIndices) {
        out.add(Detection(
          box: refinedBoxes[idx],
          score: refinedScores[idx],
          category: refinedCats[idx],
        ));
      }
    }
    // Peak proposals: regardlessの件数で上位ピークを補完（最大5件 or maxOutputs まで）
    final remainingSlots = math.max(0, maxOutputs - out.length);
    if (remainingSlots > 0) {
      final side = (width * 0.12).round();
      final thrPeak = math.max(otsuThreshold01(diffMap), thr * 0.6);
      final peakLimit = math.min(8, remainingSlots + 3);
      final peaks = localMaxima2d(diffMap, width, height,
          radius: 3, threshold: thrPeak, maxFeatures: peakLimit);
      final props = boxesFromPeaks(peaks, width, height, side: side);
      var added = 0;
      for (var i = 0; i < props.length; i++) {
        final p = props[i];
        bool overlaps = false;
        for (final d in out) {
          if (iou(d.box, p) > 0.35) { overlaps = true; break; }
        }
        if (!overlaps) {
          final peakScore = (i < peaks.length) ? peaks[i].$3 : 1.0;
          out.add(Detection(
            box: p,
            score: peakScore,
            category: cats[out.length % cats.length],
          ));
          added++;
          if (out.length >= maxOutputs || added >= remainingSlots) break;
        }
      }
    }

    // Tile-cluster fallback/augmentation (e.g., detect long thin structures like book spines)
    // 20x20=400 タイルに分割し、タイルごとに平均（高分位）スコアを計算 →
    // 閾値以上のタイルの連なりを連結成分として抽出して上位を追加。
    final tileAug = _detectByTileClusters(
      diffMap, width, height,
      settings: settings,
      gridW: 20, gridH: 20,
      maxClusters: math.min(10, maxOutputs),
    );
    if (tileAug.isNotEmpty) {
      // 既存検出と重複しないものを追加
      for (final d in tileAug) {
        bool overlaps = false;
        for (final e in out) {
          if (iou(d.box, e.box) > 0.4) { overlaps = true; break; }
        }
        if (!overlaps) {
          out.add(d);
          if (out.length >= maxOutputs) break;
        }
      }
    }

    if (out.length > maxOutputs) {
      final boxesFinal = out.map((d) => d.box).toList();
      final scoresFinal = out.map((d) => d.score).toList();
      final keep = _runNms(
        boxesFinal,
        scoresFinal,
        iouThreshold: iouThreshold,
        maxOutputs: maxOutputs,
      );
      final dedup = <Detection>[];
      for (final idx in keep) {
        dedup.add(out[idx]);
      }
      out
        ..clear()
        ..addAll(dedup);
    }

    return out;
  }

  double? _refineScoreTailMean(
    List<double> diff,
    int width,
    IntRect box, {
    required double peakScore,
    double tailRatio = 0.18,
  }) {
    final tailMean = boxTailMeanScore(diff, width, box, tailRatio: tailRatio);
    final gate = math.max(0.18, peakScore * 0.55);
    if (tailMean < gate) return null;

    final area = box.width * box.height;
    if (area <= 0) return null;
    final hotThreshold = math.max(tailMean, peakScore * 0.68);
    int hotCount = 0;
    double hotAccum = 0;
    for (var y = box.top; y < box.top + box.height; y++) {
      final row = y * width;
      for (var x = box.left; x < box.left + box.width; x++) {
        final v = diff[row + x];
        if (v >= hotThreshold) {
          hotCount++;
          hotAccum += v;
        }
      }
    }
    final minHot = math.max(6, (area * 0.05).round());
    if (hotCount < minHot) return null;
    final hotMean = hotAccum / hotCount;

    final combined = (peakScore * 0.45) + (tailMean * 0.35) + (hotMean * 0.20);
    if (combined < 0.26) return null;
    return combined.clamp(0.0, 1.0);
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

  List<Detection> _detectByTileClusters(
    List<double> diff,
    int w,
    int h, {
    required Settings settings,
    int gridW = 20,
    int gridH = 20,
    int maxClusters = 10,
  }) {
    if (gridW <= 0 || gridH <= 0) return const <Detection>[];
    final cats = _enabledCategories(settings);

    // タイル平均（上位分位の平均）を計算
    final tileScores = List<double>.filled(gridW * gridH, 0.0);
    final tileCounts = List<int>.filled(gridW * gridH, 0);
    final cellW = w / gridW;
    final cellH = h / gridH;
    for (var ty = 0; ty < gridH; ty++) {
      for (var tx = 0; tx < gridW; tx++) {
        final left = (tx * cellW).floor();
        final top = (ty * cellH).floor();
        final right = (((tx + 1) * cellW).ceil()).clamp(1, w) - 1;
        final bottom = (((ty + 1) * cellH).ceil()).clamp(1, h) - 1;
        final vals = <double>[];
        for (var y = top; y <= bottom; y++) {
          final row = y * w;
          for (var x = left; x <= right; x++) {
            vals.add(diff[row + x]);
          }
        }
        if (vals.isNotEmpty) {
          vals.sort();
          final start = (vals.length * 0.8).floor().clamp(0, vals.length - 1);
          double sum = 0; int cnt = 0;
          for (var i = start; i < vals.length; i++) { sum += vals[i]; cnt++; }
          final meanTop = cnt == 0 ? 0.0 : sum / cnt;
          final idx = ty * gridW + tx;
          tileScores[idx] = meanTop;
          tileCounts[idx] = (right - left + 1) * (bottom - top + 1);
        }
      }
    }

    // タイルスコアに対してしきい値
    final otsu = otsuThreshold01(tileScores);
    final base = (0.9 - (settings.precision - 1) * 0.05).clamp(0.6, 0.9);
    final thr = math.max(otsu, base * 0.7); // 多少緩め

    // 二値化 → 連結成分（タイル空間）
    final bin = tileScores.map((s) => s >= thr ? 1 : 0).toList(growable: false);
    var comps = connectedComponentsBoundingBoxes(bin, gridW, gridH,
        eightConnected: true, minArea: 1);

    // タイルコンポーネントをピクセル矩形へ変換しスコア付け
    final items = <(IntRect box, double score)>[];
    for (final c in comps) {
      // ピクセル座標へ
      final leftPx = (c.left * cellW).floor();
      final topPx = (c.top * cellH).floor();
      final rightPx = (((c.left + c.width) * cellW).ceil()).clamp(1, w) - 1;
      final bottomPx = (((c.top + c.height) * cellH).ceil()).clamp(1, h) - 1;
      final box = IntRect(
        left: leftPx.clamp(0, w - 1),
        top: topPx.clamp(0, h - 1),
        width: (rightPx - leftPx + 1).clamp(1, w),
        height: (bottomPx - topPx + 1).clamp(1, h),
      );
      // コンポーネント内のタイルスコア合算
      double sum = 0.0; int cnt = 0;
      for (var ty = c.top; ty < c.top + c.height; ty++) {
        for (var tx = c.left; tx < c.left + c.width; tx++) {
          sum += tileScores[ty * gridW + tx] * tileCounts[ty * gridW + tx];
          cnt += tileCounts[ty * gridW + tx];
        }
      }
      final s = cnt == 0 ? 0.0 : sum / cnt;
      items.add((box, s));
    }

    // スコア降順で上位を採用、さらに軽いNMSで重複除去
    items.sort((a, b) => b.$2.compareTo(a.$2));
    final out = <Detection>[];
    for (final it in items) {
      bool sup = false;
      for (final d in out) {
        if (iou(d.box, it.$1) > 0.4) { sup = true; break; }
      }
      if (!sup) {
        final b = expandClampBox(it.$1, 2, (w * 0.06).round(), w, h);
        out.add(Detection(box: b, score: it.$2, category: cats[out.length % cats.length]));
        if (out.length >= maxClusters) break;
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
