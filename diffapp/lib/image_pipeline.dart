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
