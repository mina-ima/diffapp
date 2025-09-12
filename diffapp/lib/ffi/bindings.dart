import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart' as pkg_ffi;

/// ネイティブ実装のインタフェース。
/// 単体テストで差し替え可能にするための抽象化。
abstract class ImageOpsNative {
  bool get isAvailable;
  List<int> rgbToGrayscaleU8(List<int> rgb, int width, int height);
}

class NativeBindings {
  static ffi.DynamicLibrary? _cachedLib;
  static ffi.DynamicLibrary _openLib() {
    return _cachedLib ??= ffi.DynamicLibrary.open(_libraryName());
  }

  static bool available() {
    try {
      // Try opening; if it fails, an exception is thrown.
      _openLib();
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

  // to_grayscale_u8(rgb, width, height, out) -> int (0:ok)
  static int _toGray(
    ffi.Pointer<ffi.Uint8> rgb,
    int width,
    int height,
    ffi.Pointer<ffi.Uint8> out,
  ) {
    final lib = _openLib();
    final fn = lib.lookupFunction<
        ffi.Int32 Function(ffi.Pointer<ffi.Uint8>, ffi.Int32, ffi.Int32,
            ffi.Pointer<ffi.Uint8>),
        int Function(ffi.Pointer<ffi.Uint8>, int, int, ffi.Pointer<ffi.Uint8>)>(
      'to_grayscale_u8',
    );
    return fn(rgb, width, height, out);
  }

  static List<int> callRgbToGrayscaleU8(List<int> rgb, int width, int height) {
    final total = width * height;
    if (width <= 0 || height <= 0) {
      throw ArgumentError('width/height must be positive');
    }
    if (rgb.length != total * 3) {
      throw ArgumentError('rgb length must be width*height*3');
    }
    final inPtr = pkg_ffi.malloc<ffi.Uint8>(rgb.length);
    final outPtr = pkg_ffi.malloc<ffi.Uint8>(total);
    try {
      // copy input
      for (var i = 0; i < rgb.length; i++) {
        inPtr[i] = rgb[i];
      }
      final rc = _toGray(inPtr, width, height, outPtr);
      if (rc != 0) {
        throw StateError('native to_grayscale_u8 failed: rc=$rc');
      }
      final out = List<int>.filled(total, 0);
      for (var i = 0; i < total; i++) {
        out[i] = outPtr[i];
      }
      return out;
    } finally {
      pkg_ffi.malloc.free(inPtr);
      pkg_ffi.malloc.free(outPtr);
    }
  }
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
    // ネイティブが未接続なら直呼びは未対応（FfiImageOps 側でフォールバックする想定）
    if (!_avail) {
      throw UnsupportedError('Native ImageOps is not available');
    }
    return NativeBindings.callRgbToGrayscaleU8(rgb, width, height);
  }
}
