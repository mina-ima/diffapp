import 'dart:math';

import 'package:diffapp/ffi/bindings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DefaultNativeOps 直呼びはネイティブ未接続時に UnsupportedError を投げる', () {
    // ホスト環境では動的ライブラリ未配置想定 → isAvailable は false
    const native = DefaultNativeOps();
    expect(native.isAvailable, isFalse);

    const w = 4, h = 3;
    final rnd = Random(99);
    final rgb = List<int>.generate(w * h * 3, (_) => rnd.nextInt(256));

    expect(
      () => native.rgbToGrayscaleU8(rgb, w, h),
      throwsA(isA<UnsupportedError>()),
      reason: '未接続環境での直呼びは明示的に未対応エラーを返す',
    );
  });
}
