// Minimal image pipeline helpers.
//
// For now this is pure-Dart logic to enable TDD without native deps.
import 'dart:math' as math;

class Dimensions {
  final int width;
  final int height;

  const Dimensions(this.width, this.height);

  @override
  String toString() => 'Dimensions(width: $width, height: $height)';

  @override
  bool operator ==(Object other) =>
      other is Dimensions && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// Returns true if the given file name/path looks like a supported image.
/// Supports: .jpg, .jpeg, .png (case-insensitive)
bool isSupportedImageFormat(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return false;
  final dot = trimmed.lastIndexOf('.');
  if (dot <= 0 || dot == trimmed.length - 1) return false;
  final ext = trimmed.substring(dot + 1).toLowerCase();
  return ext == 'jpg' || ext == 'jpeg' || ext == 'png';
}

/// Clamp an image size so that it fits within [maxWidth] x [maxHeight]
/// while preserving aspect ratio. Returns new dimensions (width, height).
/// If already within bounds, returns original size.
Dimensions clampToMaxResolution(
  int width,
  int height, {
  int maxWidth = 4000,
  int maxHeight = 3000,
}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('width and height must be positive');
  }
  if (maxWidth <= 0 || maxHeight <= 0) {
    throw ArgumentError('maxWidth and maxHeight must be positive');
  }
  if (width <= maxWidth && height <= maxHeight) {
    return Dimensions(width, height);
  }
  final scaleW = maxWidth / width;
  final scaleH = maxHeight / height;
  final scale = scaleW < scaleH ? scaleW : scaleH;
  final newW = (width * scale).round();
  final newH = (height * scale).round();
  return Dimensions(newW, newH);
}

/// Calculate resized dimensions preserving aspect ratio.
/// - If [width] <= [targetMaxWidth], returns original dimensions.
/// - Otherwise scales so that the resulting width == [targetMaxWidth].
Dimensions calculateResizeDimensions(
  int width,
  int height, {
  int targetMaxWidth = 1280,
}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('width and height must be positive');
  }
  if (targetMaxWidth <= 0) {
    throw ArgumentError('targetMaxWidth must be positive');
  }

  if (width <= targetMaxWidth) {
    return Dimensions(width, height);
  }

  final scale = targetMaxWidth / width;
  final newWidth = targetMaxWidth;
  final newHeight = (height * scale).round();
  return Dimensions(newWidth, newHeight);
}

class IntRect {
  final int left;
  final int top;
  final int width;
  final int height;

  const IntRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  int get right => left + width;
  int get bottom => top + height;

  @override
  String toString() => 'IntRect(l:$left, t:$top, w:$width, h:$height)';

  @override
  bool operator ==(Object other) =>
      other is IntRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

// -----------------------------
// Tilt correction (Similarity Transform skeleton)
// -----------------------------

class Point2 {
  final double x;
  final double y;
  const Point2(this.x, this.y);

  @override
  String toString() => 'Point2($x, $y)';
}

/// 2D 相似変換（スケール + 回転 + 並進）の表現。
/// 回転は cos/sin を持ち、角度ラジアンは [rotationRad] で取得可能。
class SimilarityTransform {
  final double scale;
  final double cosTheta;
  final double sinTheta;
  final double tx;
  final double ty;

  const SimilarityTransform({
    required this.scale,
    required this.cosTheta,
    required this.sinTheta,
    required this.tx,
    required this.ty,
  });

  double get rotationRad => math.atan2(sinTheta, cosTheta);

  @override
  String toString() =>
      'SimT(scale:$scale, cos:$cosTheta, sin:$sinTheta, tx:$tx, ty:$ty)';
}

// (uses dart:math directly)

/// 相似変換の推定（最小二乗）。
/// - 入力は対応点のリスト [src] と [dst]（同数、2点以上）。
/// - 出力は s, R(cos/sin), t を満たす変換で、平均二乗誤差を最小化する近似解。
/// - 参考：複素数表現を用いた簡易導出
SimilarityTransform estimateSimilarityTransform(
  List<Point2> src,
  List<Point2> dst,
) {
  if (src.length != dst.length) {
    throw ArgumentError('src and dst must have same length');
  }
  if (src.length < 2) {
    throw ArgumentError('at least 2 point correspondences required');
  }

  // 平均を引いて中心化
  double meanX = 0, meanY = 0, meanU = 0, meanV = 0;
  for (var i = 0; i < src.length; i++) {
    meanX += src[i].x;
    meanY += src[i].y;
    meanU += dst[i].x;
    meanV += dst[i].y;
  }
  final n = src.length.toDouble();
  meanX /= n;
  meanY /= n;
  meanU /= n;
  meanV /= n;

  // gamma = sum(w * conj(z)) / sum(|z|^2)
  // w = u + i v, z = x + i y
  double numRe = 0, numIm = 0, den = 0;
  for (var i = 0; i < src.length; i++) {
    final x = src[i].x - meanX;
    final y = src[i].y - meanY;
    final u = dst[i].x - meanU;
    final v = dst[i].y - meanV;
    numRe += u * x + v * y; // Re(w * conj(z)) = u*x + v*y
    numIm += v * x - u * y; // Im(w * conj(z)) = v*x - u*y
    den += x * x + y * y;
  }
  if (den <= 0) {
    throw ArgumentError('degenerate configuration: zero variance in src');
  }

  final sCos = numRe / den;
  final sSin = numIm / den;
  final scale = math.sqrt(sCos * sCos + sSin * sSin);
  double cosT = 1.0;
  double sinT = 0.0;
  if (scale > 0) {
    cosT = sCos / scale;
    sinT = sSin / scale;
  }

  // t = mu_y - s R mu_x
  final tx = meanU - scale * (cosT * meanX - sinT * meanY);
  final ty = meanV - scale * (sinT * meanX + cosT * meanY);

  return SimilarityTransform(
    scale: scale,
    cosTheta: cosT,
    sinTheta: sinT,
    tx: tx,
    ty: ty,
  );
}

/// 相似変換の適用: p' = s R p + t
Point2 applySimilarityTransform(Point2 p, SimilarityTransform t) {
  final x = t.scale * (t.cosTheta * p.x - t.sinTheta * p.y) + t.tx;
  final y = t.scale * (t.sinTheta * p.x + t.cosTheta * p.y) + t.ty;
  return Point2(x, y);
}

/// RANSAC による相似変換のロバスト推定結果。
class RansacSimResult {
  final SimilarityTransform transform;
  final int inliersCount;
  const RansacSimResult(this.transform, this.inliersCount);

  @override
  String toString() => 'RansacSimResult(inliers:$inliersCount, $transform)';
}

/// RANSAC を用いて外れ値に頑健な相似変換（スケール+回転+並進）を推定する。
/// - [src], [dst] は同数、2点以上。
/// - [iterations] 回だけ 2点サンプルから仮推定 → 全体で誤差評価 → ベストを採用。
/// - [inlierThreshold] はピクセル誤差（L2距離）の閾値。
/// - ベストインライアで再推定して返す。
RansacSimResult estimateSimilarityTransformRansac(
  List<Point2> src,
  List<Point2> dst, {
  int iterations = 200,
  double inlierThreshold = 2.0,
  int? minInliers,
}) {
  if (src.length != dst.length) {
    throw ArgumentError('src and dst must have same length');
  }
  if (src.length < 2) {
    throw ArgumentError('at least 2 point correspondences required');
  }
  final n = src.length;
  if (minInliers != null && (minInliers < 2 || minInliers > n)) {
    throw ArgumentError('minInliers must be in [2, $n]');
  }
  int bestCount = -1;
  List<int> bestInliers = const [];

  double sqr(double v) => v * v;
  double err(Point2 a, Point2 b) => math.sqrt(sqr(a.x - b.x) + sqr(a.y - b.y));

  final rng = math.Random(12345);
  for (var it = 0; it < iterations; it++) {
    // ランダムに2点を選ぶ（重複なし）
    final i = rng.nextInt(n);
    var j = rng.nextInt(n - 1);
    if (j >= i) j++; // ensure j != i

    SimilarityTransform t;
    try {
      t = estimateSimilarityTransform([src[i], src[j]], [dst[i], dst[j]]);
    } catch (_) {
      continue; // 退化ケースはスキップ
    }

    final current = <int>[];
    for (var k = 0; k < n; k++) {
      final p = applySimilarityTransform(src[k], t);
      if (err(p, dst[k]) <= inlierThreshold) current.add(k);
    }
    if (current.length > bestCount) {
      bestCount = current.length;
      bestInliers = current;
    }
  }

  if (bestInliers.isEmpty) {
    // すべて失敗。最小二乗で投げるよりは、単純推定で例外に委ねる。
    throw StateError('RANSAC failed to find a valid model');
  }
  if (minInliers != null && bestInliers.length < minInliers) {
    throw StateError('Not enough inliers: ${bestInliers.length} < $minInliers');
  }

  // ベストインライア集合で再推定
  final inSrc = [for (final idx in bestInliers) src[idx]];
  final inDst = [for (final idx in bestInliers) dst[idx]];
  final refined = estimateSimilarityTransform(inSrc, inDst);
  return RansacSimResult(refined, bestInliers.length);
}

// -----------------------------
// Homography (Projective Transform) + RANSAC
// -----------------------------

class Homography {
  final double h11, h12, h13;
  final double h21, h22, h23;
  final double h31, h32, h33;
  const Homography({
    required this.h11,
    required this.h12,
    required this.h13,
    required this.h21,
    required this.h22,
    required this.h23,
    required this.h31,
    required this.h32,
    required this.h33,
  });

  Homography normalized() {
    if (h33 == 0) return this;
    return Homography(
      h11: h11 / h33,
      h12: h12 / h33,
      h13: h13 / h33,
      h21: h21 / h33,
      h22: h22 / h33,
      h23: h23 / h33,
      h31: h31 / h33,
      h32: h32 / h33,
      h33: 1.0,
    );
  }

  @override
  String toString() =>
      'H([[${h11.toStringAsFixed(4)}, ${h12.toStringAsFixed(4)}, ${h13.toStringAsFixed(1)}],'
      ' [${h21.toStringAsFixed(4)}, ${h22.toStringAsFixed(4)}, ${h23.toStringAsFixed(1)}],'
      ' [${h31.toStringAsFixed(6)}, ${h32.toStringAsFixed(6)}, ${h33.toStringAsFixed(1)}]])';
}

Point2 applyHomography(Point2 p, Homography h) {
  final w = h.h31 * p.x + h.h32 * p.y + h.h33;
  final u = (h.h11 * p.x + h.h12 * p.y + h.h13) / w;
  final v = (h.h21 * p.x + h.h22 * p.y + h.h23) / w;
  return Point2(u, v);
}

// Solve A x = b (square or overdetermined via normal equations) for small sizes.
List<double> _solveLeastSquares(List<List<double>> a, List<double> b) {
  final m = a.length;
  final n = a[0].length;
  // Build normal equations: AtA (n x n), Atb (n)
  final ata = List.generate(n, (_) => List<double>.filled(n, 0.0));
  final atb = List<double>.filled(n, 0.0);
  for (var i = 0; i < m; i++) {
    for (var c1 = 0; c1 < n; c1++) {
      atb[c1] += a[i][c1] * b[i];
      for (var c2 = 0; c2 < n; c2++) {
        ata[c1][c2] += a[i][c1] * a[i][c2];
      }
    }
  }
  // Solve ata * x = atb by Gaussian elimination with partial pivoting
  for (var i = 0; i < n; i++) {
    // Pivot
    var pivot = i;
    var maxAbs = ata[i][i].abs();
    for (var r = i + 1; r < n; r++) {
      final v = ata[r][i].abs();
      if (v > maxAbs) {
        maxAbs = v;
        pivot = r;
      }
    }
    if (pivot != i) {
      final tmp = ata[i];
      ata[i] = ata[pivot];
      ata[pivot] = tmp;
      final tb = atb[i];
      atb[i] = atb[pivot];
      atb[pivot] = tb;
    }
    final diag = ata[i][i];
    if (diag.abs() < 1e-12) {
      throw StateError('Singular normal matrix');
    }
    // Normalize row
    for (var c = i; c < n; c++) {
      ata[i][c] /= diag;
    }
    atb[i] /= diag;
    // Eliminate below/above
    for (var r = 0; r < n; r++) {
      if (r == i) continue;
      final f = ata[r][i];
      if (f == 0) continue;
      for (var c = i; c < n; c++) {
        ata[r][c] -= f * ata[i][c];
      }
      atb[r] -= f * atb[i];
    }
  }
  return atb; // now contains the solution
}

Homography estimateHomographyLeastSquares(List<Point2> src, List<Point2> dst) {
  if (src.length != dst.length) {
    throw ArgumentError('src and dst must have same length');
  }
  if (src.length < 4) {
    throw ArgumentError('at least 4 correspondences required');
  }

  final a = <List<double>>[];
  final b = <double>[];
  for (var i = 0; i < src.length; i++) {
    final x = src[i].x, y = src[i].y;
    final u = dst[i].x, v = dst[i].y;
    a.add([x, y, 1, 0, 0, 0, -u * x, -u * y]);
    b.add(u);
    a.add([0, 0, 0, x, y, 1, -v * x, -v * y]);
    b.add(v);
  }
  final h = _solveLeastSquares(a, b);
  return Homography(
    h11: h[0],
    h12: h[1],
    h13: h[2],
    h21: h[3],
    h22: h[4],
    h23: h[5],
    h31: h[6],
    h32: h[7],
    h33: 1.0,
  ).normalized();
}

class RansacHomographyResult {
  final Homography homography;
  final int inliersCount;
  const RansacHomographyResult(this.homography, this.inliersCount);

  @override
  String toString() =>
      'RansacHomographyResult(inliers:$inliersCount, $homography)';
}

RansacHomographyResult estimateHomographyRansac(
  List<Point2> src,
  List<Point2> dst, {
  int iterations = 300,
  double inlierThreshold = 2.0,
  int? minInliers,
}) {
  if (src.length != dst.length) {
    throw ArgumentError('src and dst must have same length');
  }
  if (src.length < 4) {
    throw ArgumentError('at least 4 correspondences required');
  }
  final n = src.length;
  if (minInliers != null && (minInliers < 4 || minInliers > n)) {
    throw ArgumentError('minInliers must be in [4, $n]');
  }
  int bestCount = -1;
  List<int> bestInliers = const [];
  final rng = math.Random(6789);

  double sq(double v) => v * v;
  double err(Point2 a, Point2 b) => math.sqrt(sq(a.x - b.x) + sq(a.y - b.y));

  List<int> sample4(int n) {
    final set = <int>{};
    while (set.length < 4) {
      set.add(rng.nextInt(n));
    }
    return set.toList(growable: false);
  }

  for (var it = 0; it < iterations; it++) {
    final idx = sample4(n);
    final s = [src[idx[0]], src[idx[1]], src[idx[2]], src[idx[3]]];
    final d = [dst[idx[0]], dst[idx[1]], dst[idx[2]], dst[idx[3]]];

    Homography h;
    try {
      h = estimateHomographyLeastSquares(s, d);
    } catch (_) {
      continue; // skip degenerate sample
    }

    final current = <int>[];
    for (var k = 0; k < n; k++) {
      final p = applyHomography(src[k], h);
      if (err(p, dst[k]) <= inlierThreshold) current.add(k);
    }
    if (current.length > bestCount) {
      bestCount = current.length;
      bestInliers = current;
    }
  }

  if (bestInliers.isEmpty) {
    throw StateError('RANSAC failed to find a valid homography');
  }
  if (minInliers != null && bestInliers.length < minInliers) {
    throw StateError('Not enough inliers: ${bestInliers.length} < $minInliers');
  }

  final inSrc = [for (final i in bestInliers) src[i]];
  final inDst = [for (final i in bestInliers) dst[i]];
  final refined = estimateHomographyLeastSquares(inSrc, inDst);
  return RansacHomographyResult(refined, bestInliers.length);
}

/// Apply simple auto-contrast on 8-bit grayscale values when [enabled] is true.
/// - Input: list of ints 0..255
/// - Behavior: if enabled, linearly stretch [min..max] to [0..255].
///   If min==max, returns a copy of the original values.
/// - If disabled, returns a copy of [values] unchanged.
List<int> applyAutoContrastIfEnabled(List<int> values,
    {required bool enabled}) {
  final out = List<int>.from(values);
  if (!enabled) return out;
  if (out.isEmpty) return out;

  int minV = 255;
  int maxV = 0;
  for (final v in out) {
    if (v < 0 || v > 255) {
      throw ArgumentError('values must be within 0..255');
    }
    if (v < minV) minV = v;
    if (v > maxV) maxV = v;
  }
  if (minV == maxV) {
    return out; // nothing to stretch
  }
  final range = (maxV - minV).toDouble();
  for (var i = 0; i < out.length; i++) {
    final v = out[i];
    final stretched = ((v - minV) * 255.0 / range).round();
    out[i] = stretched.clamp(0, 255);
  }
  return out;
}

/// Scale a rectangle defined on the original image to the resized image space.
/// Uses the same scale factor as [calculateResizeDimensions].
IntRect scaleRectForResizedImage(
  IntRect rect,
  int originalWidth,
  int originalHeight, {
  int targetMaxWidth = 1280,
}) {
  if (originalWidth <= 0 || originalHeight <= 0) {
    throw ArgumentError('originalWidth and originalHeight must be positive');
  }
  if (rect.width < 0 || rect.height < 0 || rect.left < 0 || rect.top < 0) {
    throw ArgumentError('rect coordinates and size must be non-negative');
  }
  if (rect.right > originalWidth || rect.bottom > originalHeight) {
    throw ArgumentError('rect exceeds original image bounds');
  }
  final dims = calculateResizeDimensions(
    originalWidth,
    originalHeight,
    targetMaxWidth: targetMaxWidth,
  );
  if (dims.width == originalWidth) {
    return rect;
  }
  final scale = dims.width / originalWidth;
  return IntRect(
    left: (rect.left * scale).round(),
    top: (rect.top * scale).round(),
    width: (rect.width * scale).round(),
    height: (rect.height * scale).round(),
  );
}

/// Scale a rectangle from one coordinate space to another by independent X/Y scales.
IntRect scaleRectBetweenSpaces(
  IntRect rect,
  int fromWidth,
  int fromHeight,
  int toWidth,
  int toHeight,
) {
  if (fromWidth <= 0 || fromHeight <= 0 || toWidth <= 0 || toHeight <= 0) {
    throw ArgumentError('dimensions must be positive');
  }
  if (rect.left < 0 ||
      rect.top < 0 ||
      rect.right > fromWidth ||
      rect.bottom > fromHeight) {
    throw ArgumentError('rect exceeds source bounds');
  }
  final scaleX = toWidth / fromWidth;
  final scaleY = toHeight / fromHeight;
  return IntRect(
    left: (rect.left * scaleX).round(),
    top: (rect.top * scaleY).round(),
    width: (rect.width * scaleX).round(),
    height: (rect.height * scaleY).round(),
  );
}

int _intersectArea(IntRect a, IntRect b) {
  final x1 = a.left > b.left ? a.left : b.left;
  final y1 = a.top > b.top ? a.top : b.top;
  final x2 = a.right < b.right ? a.right : b.right;
  final y2 = a.bottom < b.bottom ? a.bottom : b.bottom;
  final w = x2 - x1;
  final h = y2 - y1;
  if (w <= 0 || h <= 0) return 0;
  return w * h;
}

double iou(IntRect a, IntRect b) {
  final inter = _intersectArea(a, b).toDouble();
  final areaA = (a.width * a.height).toDouble();
  final areaB = (b.width * b.height).toDouble();
  final union = areaA + areaB - inter;
  if (union <= 0) return 0.0;
  return inter / union;
}

/// Non-maximum suppression for axis-aligned rectangles.
/// Returns boxes sorted by score desc after suppression and optional top-K.
List<IntRect> nonMaxSuppression(
  List<IntRect> boxes,
  List<double> scores, {
  double iouThreshold = 0.5,
  int? maxOutputs,
}) {
  if (boxes.length != scores.length) {
    throw ArgumentError('boxes and scores must have the same length');
  }
  final indices = List<int>.generate(boxes.length, (i) => i);
  indices.sort((a, b) => scores[b].compareTo(scores[a]));

  final selected = <IntRect>[];
  final suppressed = List<bool>.filled(boxes.length, false);

  for (final idx in indices) {
    if (suppressed[idx]) continue;
    final candidate = boxes[idx];
    selected.add(candidate);
    if (maxOutputs != null && selected.length >= maxOutputs) break;
    for (final j in indices) {
      if (j == idx || suppressed[j]) continue;
      if (iou(candidate, boxes[j]) > iouThreshold) {
        suppressed[j] = true;
      }
    }
  }
  return selected;
}

// -----------------------------
// SSIM score map (grayscale)
// -----------------------------

/// Compute SSIM score map for two 8-bit grayscale images of identical size.
/// Returns a list of doubles (per-pixel SSIM in [-1, 1], typically 0..1).
/// Uses a square window with given [windowRadius] (default 1 => 3x3 window).
List<double> computeSsimMapUint8(
  List<int> imgA,
  List<int> imgB,
  int width,
  int height, {
  int windowRadius = 1,
  double k1 = 0.01,
  double k2 = 0.03,
}) {
  if (imgA.length != imgB.length) {
    throw ArgumentError('imgA and imgB must have the same length');
  }
  if (width <= 0 || height <= 0) {
    throw ArgumentError('width and height must be positive');
  }
  if (imgA.length != width * height) {
    throw ArgumentError('image length must equal width*height');
  }
  if (windowRadius < 0) {
    throw ArgumentError('windowRadius must be >= 0');
  }

  const L = 255.0;
  final c1 = (k1 * L) * (k1 * L);
  final c2 = (k2 * L) * (k2 * L);

  final out = List<double>.filled(imgA.length, 0.0);
  final wr = windowRadius;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      // Accumulate local stats over window
      double sumA = 0, sumB = 0, sumAA = 0, sumBB = 0, sumAB = 0;
      int count = 0;
      final y0 = (y - wr);
      final y1 = (y + wr);
      final x0 = (x - wr);
      final x1 = (x + wr);
      for (var yy = y0; yy <= y1; yy++) {
        if (yy < 0 || yy >= height) continue;
        final row = yy * width;
        for (var xx = x0; xx <= x1; xx++) {
          if (xx < 0 || xx >= width) continue;
          final idx = row + xx;
          final a = imgA[idx].toDouble();
          final b = imgB[idx].toDouble();
          sumA += a;
          sumB += b;
          sumAA += a * a;
          sumBB += b * b;
          sumAB += a * b;
          count++;
        }
      }
      if (count == 0) {
        out[y * width + x] = 1.0;
        continue;
      }
      final meanA = sumA / count;
      final meanB = sumB / count;
      final varA = sumAA / count - meanA * meanA;
      final varB = sumBB / count - meanB * meanB;
      final covAB = sumAB / count - meanA * meanB;

      final num = (2 * meanA * meanB + c1) * (2 * covAB + c2);
      final den = (meanA * meanA + meanB * meanB + c1) * (varA + varB + c2);

      final ssim = den != 0.0 ? (num / den) : 1.0;
      out[y * width + x] = ssim;
    }
  }
  return out;
}

/// Normalize a list of doubles to [0.0, 1.0].
/// If all values are the same, returns all zeros.
List<double> normalizeToUnit(List<double> values) {
  if (values.isEmpty) return <double>[];
  var minV = values.first;
  var maxV = values.first;
  for (final v in values) {
    if (v < minV) minV = v;
    if (v > maxV) maxV = v;
  }
  final range = maxV - minV;
  if (range == 0) {
    return List<double>.filled(values.length, 0.0);
  }
  return values.map((v) => (v - minV) / range).toList();
}

// -----------------------------
// Thresholding & Connected Components
// -----------------------------

/// Threshold a list of doubles to 0/1 using [threshold].
/// Values >= threshold become 1, otherwise 0.
List<int> thresholdBinary(List<double> values, double threshold) {
  return values.map((v) => v >= threshold ? 1 : 0).toList();
}

/// Find connected components' bounding boxes in a binary image (0/1).
/// - [binary] length must be width*height.
/// - [eightConnected] chooses 8-connected (true) or 4-connected (false) neighbors.
/// - Filters out components with area < [minArea].
List<IntRect> connectedComponentsBoundingBoxes(
  List<int> binary,
  int width,
  int height, {
  bool eightConnected = true,
  int minArea = 1,
}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('width and height must be positive');
  }
  if (binary.length != width * height) {
    throw ArgumentError('binary length must equal width*height');
  }
  final visited = List<bool>.filled(binary.length, false);
  final boxes = <IntRect>[];

  const dirs4 = [
    (0, 1),
    (1, 0),
    (0, -1),
    (-1, 0),
  ];
  const dirs8 = [
    (0, 1),
    (1, 0),
    (0, -1),
    (-1, 0),
    (1, 1),
    (1, -1),
    (-1, 1),
    (-1, -1),
  ];
  final dirs = eightConnected ? dirs8 : dirs4;

  int idxOf(int x, int y) => y * width + x;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final startIdx = idxOf(x, y);
      if (binary[startIdx] == 0 || visited[startIdx]) continue;

      // BFS/DFS stack
      final stack = <(int, int)>[(x, y)];
      visited[startIdx] = true;

      var minX = x, maxX = x, minY = y, maxY = y;
      var area = 0;

      while (stack.isNotEmpty) {
        final (cx, cy) = stack.removeLast();
        area++;
        if (cx < minX) minX = cx;
        if (cx > maxX) maxX = cx;
        if (cy < minY) minY = cy;
        if (cy > maxY) maxY = cy;

        for (final (dx, dy) in dirs) {
          final nx = cx + dx;
          final ny = cy + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final nIdx = idxOf(nx, ny);
          if (visited[nIdx]) continue;
          if (binary[nIdx] == 0) continue;
          visited[nIdx] = true;
          stack.add((nx, ny));
        }
      }

      if (area >= minArea) {
        boxes.add(IntRect(
          left: minX,
          top: minY,
          width: maxX - minX + 1,
          height: maxY - minY + 1,
        ));
      }
    }
  }

  return boxes;
}
