import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

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
