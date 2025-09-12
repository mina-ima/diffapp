import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android jniLibs に OpenCV のプリビルド .so が配置されている', () {
    const base = 'android/app/src/main/jniLibs';
    final arm64 = Directory('$base/arm64-v8a');
    final v7a = Directory('$base/armeabi-v7a');

    expect(arm64.existsSync(), isTrue,
        reason: 'arm64-v8a ディレクトリが存在すること');
    expect(v7a.existsSync(), isTrue,
        reason: 'armeabi-v7a ディレクトリが存在すること');

    bool hasOpencvSo(Directory d) {
      if (!d.existsSync()) return false;
      final files = d
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split(Platform.pathSeparator).last)
          .toList();
      // 一般的な OpenCV の .so 名称の一つでも含まれているか（ここでは java4 を基準にする）
      return files.any((name) =>
          name == 'libopencv_java4.so' ||
          name == 'libopencv_world.so' ||
          name.startsWith('libopencv_'));
    }

    expect(hasOpencvSo(arm64), isTrue,
        reason: 'arm64-v8a に OpenCV の .so が必要です');
    expect(hasOpencvSo(v7a), isTrue,
        reason: 'armeabi-v7a に OpenCV の .so が必要です');
  });
}

