import 'package:diffapp/image_pipeline.dart' as ip;
import 'bindings.dart';

abstract class ImageOps {
  // RGB24 -> Gray8
  List<int> rgbToGrayscaleU8(List<int> rgb, int width, int height);
  List<double> computeSsimMapUint8(List<int> imgA, List<int> imgB, int width, int height, {int windowRadius = 1});
  List<double> normalizeToUnit(List<double> values);
  List<int> thresholdBinary(List<double> values, double threshold);
  List<ip.IntRect> connectedComponentsBoundingBoxes(
    List<int> binary,
    int width,
    int height, {
    bool eightConnected = true,
    int minArea = 1,
  });
}

class DartImageOps implements ImageOps {
  @override
  List<int> rgbToGrayscaleU8(List<int> rgb, int width, int height) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('width/height must be positive');
    }
    if (rgb.length != width * height * 3) {
      throw ArgumentError('rgb length must be width*height*3');
    }
    final out = List<int>.filled(width * height, 0);
    for (var i = 0, j = 0; i < rgb.length; i += 3, j++) {
      final r = rgb[i];
      final g = rgb[i + 1];
      final b = rgb[i + 2];
      final y = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
      out[j] = y;
    }
    return out;
  }
  @override
  List<double> computeSsimMapUint8(List<int> imgA, List<int> imgB, int width, int height, {int windowRadius = 1}) =>
      ip.computeSsimMapUint8(imgA, imgB, width, height, windowRadius: windowRadius);

  @override
  List<double> normalizeToUnit(List<double> values) => ip.normalizeToUnit(values);

  @override
  List<int> thresholdBinary(List<double> values, double threshold) => ip.thresholdBinary(values, threshold);

  @override
  List<ip.IntRect> connectedComponentsBoundingBoxes(List<int> binary, int width, int height,
          {bool eightConnected = true, int minArea = 1}) =>
      ip.connectedComponentsBoundingBoxes(binary, width, height, eightConnected: eightConnected, minArea: minArea);
}

/// FFI 実装の土台。現時点ではDart実装にフォールバックする。
class FfiImageOps implements ImageOps {
  final DartImageOps _fallback = DartImageOps();
  FfiImageOps() {
    // Native availability check deferred until actual integration.
    NativeBindings.available();
  }

  @override
  List<int> rgbToGrayscaleU8(List<int> rgb, int width, int height) {
    // ネイティブが利用可能なら将来そちらを使用。現在は常にフォールバック。
    return _fallback.rgbToGrayscaleU8(rgb, width, height);
  }

  @override
  List<double> computeSsimMapUint8(List<int> imgA, List<int> imgB, int width, int height, {int windowRadius = 1}) {
    // TODO: 後日 FFI 呼び出しに置換
    return _fallback.computeSsimMapUint8(imgA, imgB, width, height, windowRadius: windowRadius);
  }

  @override
  List<double> normalizeToUnit(List<double> values) {
    // TODO: 後日 FFI 呼び出しに置換
    return _fallback.normalizeToUnit(values);
  }

  @override
  List<int> thresholdBinary(List<double> values, double threshold) {
    // TODO: 後日 FFI 呼び出しに置換
    return _fallback.thresholdBinary(values, threshold);
  }

  @override
  List<ip.IntRect> connectedComponentsBoundingBoxes(List<int> binary, int width, int height,
      {bool eightConnected = true, int minArea = 1}) {
    // TODO: 後日 FFI 呼び出しに置換
    return _fallback.connectedComponentsBoundingBoxes(binary, width, height,
        eightConnected: eightConnected, minArea: minArea);
  }
}

// (bindings are imported above)
