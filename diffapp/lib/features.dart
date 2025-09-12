import 'dart:math' as math;

class Keypoint {
  final int x;
  final int y;
  final double score;
  final double angle; // radians
  const Keypoint(
      {required this.x,
      required this.y,
      required this.score,
      required this.angle});
}

// Compute Harris corner response for each pixel (valid region only). Returns double list of size w*h.
List<double> harrisResponseU8(List<int> img, int w, int h,
    {int window = 3, double k = 0.04}) {
  if (img.length != w * h) {
    throw ArgumentError('image length must be w*h');
  }
  if (window < 1) throw ArgumentError('window must be >=1');
  // Simple Sobel gradients
  final gx = List<double>.filled(w * h, 0);
  final gy = List<double>.filled(w * h, 0);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final idx = y * w + x;
      final a = img[idx - w - 1].toDouble();
      final b = img[idx - w].toDouble();
      final c = img[idx - w + 1].toDouble();
      final d = img[idx - 1].toDouble();
      final f = img[idx + 1].toDouble();
      final g = img[idx + w - 1].toDouble();
      final h0 = img[idx + w].toDouble();
      final i = img[idx + w + 1].toDouble();
      gx[idx] = (c + 2 * f + i) - (a + 2 * d + g);
      gy[idx] = (g + 2 * h0 + i) - (a + 2 * b + c);
    }
  }
  final r = List<double>.filled(w * h, 0);
  final rad = window;
  for (var y = rad; y < h - rad; y++) {
    for (var x = rad; x < w - rad; x++) {
      double sxx = 0, syy = 0, sxy = 0;
      for (var yy = -rad; yy <= rad; yy++) {
        for (var xx = -rad; xx <= rad; xx++) {
          final gxi = gx[(y + yy) * w + (x + xx)];
          final gyi = gy[(y + yy) * w + (x + xx)];
          sxx += gxi * gxi;
          syy += gyi * gyi;
          sxy += gxi * gyi;
        }
      }
      final det = sxx * syy - sxy * sxy;
      final trace = sxx + syy;
      r[y * w + x] = det - k * trace * trace;
    }
  }
  return r;
}

// Non-maximum suppression on a score map. Returns candidate (x,y,score).
List<(int, int, double)> nms2d(List<double> score, int w, int h,
    {int radius = 3, double threshold = 1e6, int maxFeatures = 500}) {
  final out = <(int, int, double)>[];
  for (var y = radius; y < h - radius; y++) {
    for (var x = radius; x < w - radius; x++) {
      final s = score[y * w + x];
      if (s <= threshold) continue;
      var isMax = true;
      for (var yy = -radius; yy <= radius && isMax; yy++) {
        for (var xx = -radius; xx <= radius; xx++) {
          if (xx == 0 && yy == 0) continue;
          if (score[(y + yy) * w + (x + xx)] > s) {
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

// Estimate orientation by intensity centroid in a patch.
double _estimateOrientation(
    List<int> img, int w, int h, int cx, int cy, int radius) {
  double m10 = 0, m01 = 0;
  for (var y = -radius; y <= radius; y++) {
    final yy = cy + y;
    if (yy < 0 || yy >= h) continue;
    for (var x = -radius; x <= radius; x++) {
      final xx = cx + x;
      if (xx < 0 || xx >= w) continue;
      final v = img[yy * w + xx].toDouble();
      m10 += x * v;
      m01 += y * v;
    }
  }
  return math.atan2(m01, m10);
}

List<Keypoint> detectHarrisKeypointsU8(
  List<int> img,
  int w,
  int h, {
  int window = 3,
  double k = 0.04,
  int nmsRadius = 4,
  double responseThreshold = 1e7,
  int maxFeatures = 256,
  int orientationRadius = 8,
}) {
  final resp = harrisResponseU8(img, w, h, window: window, k: k);
  final cand = nms2d(resp, w, h,
      radius: nmsRadius,
      threshold: responseThreshold,
      maxFeatures: maxFeatures);
  final out = <Keypoint>[];
  for (final (x, y, s) in cand) {
    final ang = _estimateOrientation(img, w, h, x, y, orientationRadius);
    out.add(Keypoint(x: x, y: y, score: s, angle: ang));
  }
  return out;
}

// Compute BRIEF descriptors (N bytes per keypoint). Returns list of byte lists.
List<List<int>> computeBriefDescriptors(
  List<int> img,
  int w,
  int h,
  List<Keypoint> kps, {
  int bytes = 32,
  int patch = 31,
  int seed = 12345,
}) {
  final rng = math.Random(seed);
  final half = patch ~/ 2;
  // Pre-generate test pairs within patch
  final tests = <(int, int, int, int)>[]; // (x1,y1,x2,y2) relative to center
  for (var i = 0; i < bytes * 8; i++) {
    final x1 = rng.nextInt(patch) - half;
    final y1 = rng.nextInt(patch) - half;
    final x2 = rng.nextInt(patch) - half;
    final y2 = rng.nextInt(patch) - half;
    tests.add((x1, y1, x2, y2));
  }
  int clamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
  final descs = <List<int>>[];
  for (final kp in kps) {
    final bytesOut = List<int>.filled(bytes, 0);
    for (var i = 0; i < bytes; i++) {
      int b = 0;
      for (var bit = 0; bit < 8; bit++) {
        final (dx1, dy1, dx2, dy2) = tests[i * 8 + bit];
        final x1 = clamp(kp.x + dx1, 0, w - 1);
        final y1 = clamp(kp.y + dy1, 0, h - 1);
        final x2 = clamp(kp.x + dx2, 0, w - 1);
        final y2 = clamp(kp.y + dy2, 0, h - 1);
        final v1 = img[y1 * w + x1];
        final v2 = img[y2 * w + x2];
        b |= (v1 < v2 ? 1 : 0) << bit;
      }
      bytesOut[i] = b;
    }
    descs.add(bytesOut);
  }
  return descs;
}

int hammingDistance(List<int> a, List<int> b) {
  if (a.length != b.length) throw ArgumentError('descriptor length mismatch');
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    var v = a[i] ^ b[i];
    // count bits in v
    // Kernighan's algorithm
    while (v != 0) {
      v &= v - 1;
      d++;
    }
  }
  return d;
}

// Brute-force match with Hamming; returns list of (i,j,d)
List<(int, int, int)> matchDescriptorsHamming(
    List<List<int>> q, List<List<int>> t) {
  final out = <(int, int, int)>[];
  for (var i = 0; i < q.length; i++) {
    var bestJ = -1;
    var bestD = 1 << 30;
    for (var j = 0; j < t.length; j++) {
      final d = hammingDistance(q[i], t[j]);
      if (d < bestD) {
        bestD = d;
        bestJ = j;
      }
    }
    if (bestJ >= 0) out.add((i, bestJ, bestD));
  }
  return out;
}
