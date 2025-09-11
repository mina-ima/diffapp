// Minimal image pipeline helpers.
//
// For now this is pure-Dart logic to enable TDD without native deps.

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
  if (name.isEmpty) return false;
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return false;
  final ext = name.substring(dot + 1).toLowerCase();
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

/// Apply simple auto-contrast on 8-bit grayscale values when [enabled] is true.
/// - Input: list of ints 0..255
/// - Behavior: if enabled, linearly stretch [min..max] to [0..255].
///   If min==max, returns a copy of the original values.
/// - If disabled, returns a copy of [values] unchanged.
List<int> applyAutoContrastIfEnabled(List<int> values, {required bool enabled}) {
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
