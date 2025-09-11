import 'package:diffapp/image_pipeline.dart' as ip;

abstract class ImageOps {
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

