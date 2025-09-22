// Minimal image pipeline helpers.
//
// For now this is pure-Dart logic to enable TDD without native deps.
import 'dart:math' as math;
import 'dart:typed_data';

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

/// Compute a robust score for a box: mean of top-[tailRatio] values within the box
/// from the given scalar map [values] (assumed 0..1), to favor peaky differences.
double boxTailMeanScore(
  List<double> values,
  int width,
  IntRect box, {
  double tailRatio = 0.1,
}) {
  final list = <double>[];
  for (var y = box.top; y < box.top + box.height; y++) {
    final row = y * width;
    for (var x = box.left; x < box.left + box.width; x++) {
      list.add(values[row + x]);
    }
  }
  if (list.isEmpty) return 0.0;
  list.sort();
  final start = (list.length * (1.0 - tailRatio)).floor().clamp(0, list.length - 1);
  double sum = 0.0;
  int cnt = 0;
  for (var i = start; i < list.length; i++) {
    sum += list[i];
    cnt++;
  }
  return cnt == 0 ? 0.0 : sum / cnt;
}

/// Compute a peak-emphasized score for a box: the maximum value inside the box.
/// 0..1 のスカラーマップ [values] に対して、ボックス内の最大値を返す。
/// 面積の広さよりも「強い局所ピーク」を優先してランク付けする用途に向く。
double boxMaxScore(
  List<double> values,
  int width,
  IntRect box,
) {
  double best = -1.0;
  for (var y = box.top; y < box.top + box.height; y++) {
    final row = y * width;
    for (var x = box.left; x < box.left + box.width; x++) {
      final v = values[row + x];
      if (v > best) {
        best = v;
      }
    }
  }
  if (best < 0) return 0.0;
  return best;
}

double _percentile(List<double> v, double q) {
  if (v.isEmpty) return 0.0;
  final sorted = List<double>.from(v)..sort();
  final p = (q * (sorted.length - 1)).clamp(0, (sorted.length - 1).toDouble());
  final i = p.floor();
  final f = p - i;
  if (i + 1 >= sorted.length) return sorted[i];
  return sorted[i] * (1.0 - f) + sorted[i + 1] * f;
}

/// Refine a bounding box by keeping only high-quantile pixels inside it,
/// then returning the tightest connected component with highest mean.
IntRect refineBoxByQuantile(
  List<double> values,
  int width,
  int height,
  IntRect box, {
  double quantile = 0.85,
}) {
  final vals = <double>[];
  for (var y = box.top; y < box.top + box.height; y++) {
    final row = y * width;
    for (var x = box.left; x < box.left + box.width; x++) {
      vals.add(values[row + x]);
    }
  }
  if (vals.isEmpty) return box;
  final thr = _percentile(vals, quantile);
  final bw = box.width, bh = box.height;
  final bin = List<int>.filled(bw * bh, 0);
  for (var y = 0; y < bh; y++) {
    final row = (box.top + y) * width;
    for (var x = 0; x < bw; x++) {
      final v = values[row + (box.left + x)];
      bin[y * bw + x] = (v >= thr) ? 1 : 0;
    }
  }
  final comps = connectedComponentsBoundingBoxes(bin, bw, bh,
      eightConnected: true, minArea: 3);
  if (comps.isEmpty) return box;
  // choose comp with highest mean
  double bestScore = -1;
  IntRect best = comps.first;
  for (final c in comps) {
    double sum = 0; int cnt = 0;
    for (var y = c.top; y < c.top + c.height; y++) {
      final row = (box.top + y) * width;
      for (var x = c.left; x < c.left + c.width; x++) {
        sum += values[row + (box.left + x)];
        cnt++;
      }
    }
    final m = cnt == 0 ? 0.0 : sum / cnt;
    if (m > bestScore) { bestScore = m; best = c; }
  }
  return IntRect(
    left: box.left + best.left,
    top: box.top + best.top,
    width: best.width,
    height: best.height,
  );
}

bool isElongated(IntRect r, {double ratio = 3.0}) {
  final w = r.width.toDouble();
  final h = r.height.toDouble();
  if (w == 0 || h == 0) return false;
  final ar = w > h ? w / h : h / w;
  return ar > ratio;
}

/// Expand a box by [pad] pixels on each side, and ensure minimum side length
/// [minSide], clamped to image bounds.
IntRect expandClampBox(IntRect b, int pad, int minSide, int maxW, int maxH) {
  int left = b.left - pad;
  int top = b.top - pad;
  int right = b.right + pad;
  int bottom = b.bottom + pad;
  if (right - left < minSide) {
    final grow = (minSide - (right - left));
    left -= grow ~/ 2;
    right += (grow - grow ~/ 2);
  }
  if (bottom - top < minSide) {
    final grow = (minSide - (bottom - top));
    top -= grow ~/ 2;
    bottom += (grow - grow ~/ 2);
  }
  if (left < 0) left = 0;
  if (top < 0) top = 0;
  if (right > maxW) right = maxW;
  if (bottom > maxH) bottom = maxH;
  final w = (right - left).clamp(1, maxW);
  final h = (bottom - top).clamp(1, maxH);
  return IntRect(left: left, top: top, width: w, height: h);
}

/// Compute weighted centroid within [box] using pixels above the given
/// quantile of values inside the box. Returns null if no valid pixels.
(double, double)? weightedCentroidByQuantile(
  List<double> values,
  int width,
  int height,
  IntRect box, {
  double quantile = 0.8,
}) {
  final vals = <double>[];
  for (var y = box.top; y < box.top + box.height; y++) {
    final row = y * width;
    for (var x = box.left; x < box.left + box.width; x++) {
      vals.add(values[row + x]);
    }
  }
  if (vals.isEmpty) return null;
  final thr = _percentile(vals, quantile);
  double sx = 0, sy = 0, sw = 0;
  for (var y = box.top; y < box.top + box.height; y++) {
    final row = y * width;
    for (var x = box.left; x < box.left + box.width; x++) {
      final wv = values[row + x];
      if (wv >= thr) {
        sx += x * wv;
        sy += y * wv;
        sw += wv;
      }
    }
  }
  if (sw == 0) return null;
  return (sx / sw, sy / sw);
}

/// Return the coordinates of the maximum value inside [box] considering only
/// pixels above the given quantile threshold. Falls back to global max inside
/// the box if no pixels exceed the quantile.
(int, int)? argmaxByQuantile(
  List<double> values,
  int width,
  int height,
  IntRect box, {
  double quantile = 0.8,
}) {
  final vals = <double>[];
  for (var y = box.top; y < box.top + box.height; y++) {
    final row = y * width;
    for (var x = box.left; x < box.left + box.width; x++) {
      vals.add(values[row + x]);
    }
  }
  if (vals.isEmpty) return null;
  final thr = _percentile(vals, quantile);
  double best = -1;
  int bestX = box.left, bestY = box.top;
  double bestAll = -1; int bestAllX = box.left, bestAllY = box.top;
  for (var y = box.top; y < box.top + box.height; y++) {
    final row = y * width;
    for (var x = box.left; x < box.left + box.width; x++) {
      final v = values[row + x];
      if (v > bestAll) { bestAll = v; bestAllX = x; bestAllY = y; }
      if (v >= thr && v > best) { best = v; bestX = x; bestY = y; }
    }
  }
  if (best < 0) return (bestAllX, bestAllY);
  return (bestX, bestY);
}

/// Compute per-pixel color difference map (0..1) from two RGBA buffers (8-bit per channel).
/// Uses L2 distance in RGB normalized by sqrt(3)*255.
List<double> colorDiffMapRgba(
  List<int> rgbaA,
  List<int> rgbaB,
  int width,
  int height,
) {
  final n = width * height;
  if (rgbaA.length != n * 4 || rgbaB.length != n * 4) {
    throw ArgumentError('RGBA buffers must be width*height*4 bytes');
  }
  const norm = 441.67295593; // sqrt(3)*255
  final out = List<double>.filled(n, 0.0);
  for (var i = 0, p = 0; i < n; i++, p += 4) {
    final dr = (rgbaA[p] - rgbaB[p]).abs().toDouble();
    final dg = (rgbaA[p + 1] - rgbaB[p + 1]).abs().toDouble();
    final db = (rgbaA[p + 2] - rgbaB[p + 2]).abs().toDouble();
    final d = math.sqrt(dr * dr + dg * dg + db * db) / norm;
    out[i] = d.isFinite ? d : 0.0;
  }
  return out;
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

/// Warp an RGBA image by applying homography H to output grid coordinates
/// (i.e., for each output (u,v) find source (x,y)=H(u,v) in the input) and
/// sampling bilinearly. Returns a Uint8List of length outW*outH*4.
Uint8List warpRgbaByHomography(
  Uint8List src,
  int srcW,
  int srcH,
  Homography h,
  int outW,
  int outH,
) {
  Uint8List out = Uint8List(outW * outH * 4);
  double clampd(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
  for (var y = 0; y < outH; y++) {
    for (var x = 0; x < outW; x++) {
      final p = applyHomography(Point2(x.toDouble(), y.toDouble()), h);
      final fx = clampd(p.x, 0.0, srcW - 1.001);
      final fy = clampd(p.y, 0.0, srcH - 1.001);
      final x0 = fx.floor();
      final y0 = fy.floor();
      final dx = fx - x0;
      final dy = fy - y0;
      int idx(int xx, int yy) => ((yy * srcW + xx) * 4);
      final i00 = idx(x0, y0);
      final i10 = idx((x0 + 1).clamp(0, srcW - 1), y0);
      final i01 = idx(x0, (y0 + 1).clamp(0, srcH - 1));
      final i11 = idx((x0 + 1).clamp(0, srcW - 1), (y0 + 1).clamp(0, srcH - 1));
      for (var c = 0; c < 4; c++) {
        final v00 = src[i00 + c].toDouble();
        final v10 = src[i10 + c].toDouble();
        final v01 = src[i01 + c].toDouble();
        final v11 = src[i11 + c].toDouble();
        final v0 = v00 * (1 - dx) + v10 * dx;
        final v1 = v01 * (1 - dx) + v11 * dx;
        final v = v0 * (1 - dy) + v1 * dy;
        out[(y * outW + x) * 4 + c] = v.round().clamp(0, 255);
      }
    }
  }
  return out;
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

  // Compute by scaling edges to preserve area as much as possible.
  int left = (rect.left * scaleX).round();
  int top = (rect.top * scaleY).round();
  int right = (rect.right * scaleX).round();
  int bottom = (rect.bottom * scaleY).round();

  // Ensure at least 1px in each dimension after rounding.
  if (right <= left) {
    right = left + 1;
  }
  if (bottom <= top) {
    bottom = top + 1;
  }

  // Clamp within destination bounds if necessary.
  if (left < 0) left = 0;
  if (top < 0) top = 0;
  if (right > toWidth) {
    // shift left if needed to keep width
    final deficit = right - toWidth;
    left = (left - deficit).clamp(0, toWidth - 1);
    right = toWidth;
  }
  if (bottom > toHeight) {
    final deficit = bottom - toHeight;
    top = (top - deficit).clamp(0, toHeight - 1);
    bottom = toHeight;
  }

  final width = right - left;
  final height = bottom - top;

  return IntRect(left: left, top: top, width: width, height: height);
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
// Gradient magnitude (Sobel) for uint8 grayscale
// -----------------------------

/// Compute Sobel gradient magnitude for an 8-bit grayscale image.
/// Returns values normalized to [0,1] using the max magnitude in the image.
List<double> sobelGradMagU8(List<int> img, int w, int h) {
  if (img.length != w * h) {
    throw ArgumentError('image length must be w*h');
  }
  final gx = List<double>.filled(w * h, 0);
  final gy = List<double>.filled(w * h, 0);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final a = img[i - w - 1].toDouble();
      final b = img[i - w].toDouble();
      final c = img[i - w + 1].toDouble();
      final d = img[i - 1].toDouble();
      final f = img[i + 1].toDouble();
      final g = img[i + w - 1].toDouble();
      final h0 = img[i + w].toDouble();
      final i0 = img[i + w + 1].toDouble();
      gx[i] = (c + 2 * f + i0) - (a + 2 * d + g);
      gy[i] = (g + 2 * h0 + i0) - (a + 2 * b + c);
    }
  }
  double maxMag = 0;
  final mag = List<double>.filled(w * h, 0);
  for (var i = 0; i < mag.length; i++) {
    final m = math.sqrt(gx[i] * gx[i] + gy[i] * gy[i]);
    mag[i] = m;
    if (m > maxMag) maxMag = m;
  }
  if (maxMag <= 0) return List<double>.filled(w * h, 0);
  for (var i = 0; i < mag.length; i++) {
    mag[i] = mag[i] / maxMag;
  }
  return mag;
}

// -----------------------------
// Thresholding & Connected Components
// -----------------------------

/// Threshold a list of doubles to 0/1 using [threshold].
/// Values >= threshold become 1, otherwise 0.
List<int> thresholdBinary(List<double> values, double threshold) {
  return values.map((v) => v >= threshold ? 1 : 0).toList();
}

/// Compute Otsu's threshold on [values] assumed to be in [0.0, 1.0].
/// Returns a threshold in [0.0, 1.0]. Uses 256-bin histogram.
double otsuThreshold01(List<double> values, {int bins = 256}) {
  if (values.isEmpty) return 0.5;
  final hist = List<int>.filled(bins, 0);
  for (final v in values) {
    var x = v;
    if (x.isNaN || x.isInfinite) continue;
    if (x < 0) x = 0;
    if (x > 1) x = 1;
    final idx = (x * (bins - 1)).round();
    hist[idx]++;
  }
  final total = values.length;
  double sumAll = 0;
  for (var i = 0; i < bins; i++) {
    sumAll += i * hist[i];
  }
  int wB = 0;
  double sumB = 0;
  double maxVar = -1;
  int thresholdIdx = 0;
  for (var i = 0; i < bins; i++) {
    wB += hist[i];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += i * hist[i];
    final mB = sumB / wB;
    final mF = (sumAll - sumB) / wF;
    final betweenVar = wB * wF * (mB - mF) * (mB - mF);
    if (betweenVar > maxVar) {
      maxVar = betweenVar;
      thresholdIdx = i;
    }
  }
  final thr = thresholdIdx / (bins - 1);
  return thr.isFinite ? thr : 0.5;
}

/// Morphological dilation on a binary image (0/1). Returns a new list.
List<int> dilateBinary(List<int> binary, int width, int height,
    {int iterations = 1}) {
  if (binary.length != width * height) {
    throw ArgumentError('binary length must equal width*height');
  }
  if (iterations <= 0) return List<int>.from(binary);
  List<int> cur = List<int>.from(binary);
  for (var it = 0; it < iterations; it++) {
    final out = List<int>.from(cur);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final idx = y * width + x;
        if (cur[idx] == 1) {
          out[idx] = 1;
          continue;
        }
        bool any = false;
        for (var dy = -1; dy <= 1 && !any; dy++) {
          final yy = y + dy;
          if (yy < 0 || yy >= height) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final xx = x + dx;
            if (xx < 0 || xx >= width) continue;
            if (cur[yy * width + xx] == 1) {
              any = true;
              break;
            }
          }
        }
        out[idx] = any ? 1 : out[idx];
      }
    }
    cur = out;
  }
  return cur;
}

/// Hysteresis thresholding (Canny-style) on a scalar map in [0,1].
/// Pixels >= high become strong seeds. Pixels >= low connected (8-neigh) to any strong seed are kept.
List<int> hysteresisBinary(
  List<double> values,
  int width,
  int height, {
  required double high,
  required double low,
}) {
  if (values.length != width * height) {
    throw ArgumentError('values length must equal width*height');
  }
  if (low > high) {
    final t = low;
    low = high;
    high = t;
  }
  final out = List<int>.filled(values.length, 0);
  final visited = List<bool>.filled(values.length, false);
  final q = <int>[];

  int idx(int x, int y) => y * width + x;

  // seed with strong pixels
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = idx(x, y);
      final v = values[i];
      if (v >= high) {
        out[i] = 1;
        visited[i] = true;
        q.add(i);
      }
    }
  }

  // BFS to include weak pixels connected to strong
  while (q.isNotEmpty) {
    final i = q.removeLast();
    final x = i % width;
    final y = i ~/ width;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final xx = x + dx;
        final yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= width || yy >= height) continue;
        final j = idx(xx, yy);
        if (visited[j]) continue;
        visited[j] = true;
        if (values[j] >= low) {
          out[j] = 1;
          q.add(j);
        }
      }
    }
  }
  return out;
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

// -----------------------------
// Peak detection (local maxima)
// -----------------------------

/// Find local maxima in a scalar map using a square neighborhood of given radius.
/// Returns list of (x, y, score) sorted by score descending, filtered by threshold.
List<(int, int, double)> localMaxima2d(
  List<double> values,
  int width,
  int height, {
  int radius = 3,
  double threshold = 0.5,
  int maxFeatures = 10,
}) {
  final out = <(int, int, double)>[];
  for (var y = radius; y < height - radius; y++) {
    for (var x = radius; x < width - radius; x++) {
      final s = values[y * width + x];
      if (s < threshold) continue;
      var isMax = true;
      for (var yy = -radius; yy <= radius && isMax; yy++) {
        for (var xx = -radius; xx <= radius; xx++) {
          if (xx == 0 && yy == 0) continue;
          if (values[(y + yy) * width + (x + xx)] > s) {
            isMax = false;
            break;
          }
        }
      }
      if (isMax) out.add((x, y, s));
    }
  }
  out.sort((a, b) => b.$3.compareTo(a.$3));
  if (out.length > maxFeatures) return out.sublist(0, maxFeatures);
  return out;
}

List<IntRect> boxesFromPeaks(
  List<(int, int, double)> peaks,
  int width,
  int height, {
  int side = 12,
}) {
  final out = <IntRect>[];
  final half = side ~/ 2;
  for (final (x, y, _) in peaks) {
    final left = (x - half).clamp(0, width - 1);
    final top = (y - half).clamp(0, height - 1);
    final w = (side).clamp(1, width - left);
    final h = (side).clamp(1, height - top);
    out.add(IntRect(left: left, top: top, width: w, height: h));
  }
  return out;
}
