import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:diffapp/ffi/image_ops.dart';
import 'package:diffapp/ffi/bindings.dart';

void main() {
  test('DefaultNativeOps が未接続環境では isAvailable=false でフォールバックされる', () {
    // NOTE: CI/ローカル（ホストOS）ではネイティブライブラリは未配置想定。
    // DefaultNativeOps.isAvailable == false の場合、FfiImageOps は Dart 実装にフォールバックする。
    const native = DefaultNativeOps();
    expect(native.isAvailable, isFalse, reason: '未接続環境では false のはず');

    const w = 6, h = 5;
    final rnd = Random(7);
    final rgb = List<int>.generate(w * h * 3, (_) => rnd.nextInt(256));

    final dartOps = DartImageOps();
    final viaFfi = FfiImageOps(native: native);

    final gDart = dartOps.rgbToGrayscaleU8(rgb, w, h);
    final gFfi = viaFfi.rgbToGrayscaleU8(rgb, w, h);
    expect(gFfi, equals(gDart), reason: 'ネイティブ未接続ならDart実装に一致する');
  });
}
