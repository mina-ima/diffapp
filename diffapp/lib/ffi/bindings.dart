import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

/// ネイティブ実装のインタフェース。
/// 単体テストで差し替え可能にするための抽象化。
abstract class ImageOpsNative {
  bool get isAvailable;
  List<int> rgbToGrayscaleU8(List<int> rgb, int width, int height);
}

class NativeBindings {
  static bool available() {
    try {
      final libName = _libraryName();
      // Try opening; if it fails, an exception is thrown.
      ffi.DynamicLibrary.open(libName);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _libraryName() {
    if (Platform.isAndroid) return 'libdiffapp_ffi.so';
    if (Platform.isIOS) return 'diffapp_ffi.framework/diffapp_ffi';
    if (Platform.isMacOS) return 'libdiffapp_ffi.dylib';
    if (Platform.isWindows) return 'diffapp_ffi.dll';
    if (Platform.isLinux) return 'libdiffapp_ffi.so';
    throw UnsupportedError('Unsupported platform');
  }

  // 将来: ここに to_grayscale_u8 の呼び出し実装を追加予定。
}

/// 既定のダミー実装（ネイティブ未接続）。
class NoopNativeOps implements ImageOpsNative {
  const NoopNativeOps();

  @override
  bool get isAvailable => false;

  @override
  List<int> rgbToGrayscaleU8(List<int> rgb, int width, int height) {
    throw UnsupportedError('Native ImageOps is not available');
  }
}

/// 既定のネイティブ実装（スタブ）。
/// - `isAvailable` は動的ライブラリの存在可否のみを報告。
/// - 現段階では実関数呼び出しは未接続のため、フォールバック互換の値を返す。
///   （将来的に C++ 実装 `to_grayscale_u8` へ接続する）
class DefaultNativeOps implements ImageOpsNative {
  static final bool _avail = NativeBindings.available();

  const DefaultNativeOps();

  @override
  bool get isAvailable => _avail;

  @override
  List<int> rgbToGrayscaleU8(List<int> rgb, int width, int height) {
    // スタブ段階: BT.601 係数でグレースケールを算出（将来 FFI 呼び出しに置換）
    if (width <= 0 || height <= 0) {
      throw ArgumentError('width/height must be positive');
    }
    if (rgb.length != width * height * 3) {
      throw ArgumentError('rgb length must be width*height*3');
    }
    final out = List<int>.filled(width * height, 0);
    for (var i = 0, j = 0; i < out.length; i++) {
      final r = rgb[j++];
      final g = rgb[j++];
      final b = rgb[j++];
      final y = (0.299 * r + 0.587 * g + 0.114 * b).round();
      out[i] = y.clamp(0, 255);
    }
    return out;
  }
}
