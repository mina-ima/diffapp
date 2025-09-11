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
