import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android CMake が OpenCV 検出とリンク雛形を含み、外部ビルドが有効', () async {
    const cmakePath = 'android/src/main/cpp/CMakeLists.txt';
    final cmake = await File(cmakePath).readAsString();
    // ライブラリ名
    expect(cmake.contains('add_library(\n  diffapp_ffi'), isTrue,
        reason: 'diffapp_ffi ライブラリを定義していること');
    // OpenCV の検出（REQUIREDでなくQUIETでも可）
    expect(cmake.contains('find_package(OpenCV'), isTrue,
        reason: 'OpenCV の検出(find_package)を追加してください');
    // 見つかった場合のリンク（${...} のまま文字として含まれていることを確認）
    expect(cmake.contains(r'target_link_libraries(diffapp_ffi ${OpenCV_LIBS})'),
        isTrue,
        reason: 'OpenCV に見つかった場合はリンクしてください');

    // Gradle 側の externalNativeBuild が設定されている
    const gradlePath = 'android/app/build.gradle.kts';
    final gradle = await File(gradlePath).readAsString();
    expect(gradle.contains('externalNativeBuild'), isTrue,
        reason: 'externalNativeBuild の CMake 設定が必要です');

    // ABI フィルタ（arm64-v8a / armeabi-v7a）が含まれる
    final hasArm64 = RegExp(r'abiFilters[\s\S]*\"arm64-v8a\"').hasMatch(gradle);
    final hasArmeabiV7a =
        RegExp(r'abiFilters[\s\S]*\"armeabi-v7a\"').hasMatch(gradle);
    expect(hasArm64 && hasArmeabiV7a, isTrue,
        reason: 'abiFilters に arm64-v8a / armeabi-v7a を含めてください');
  });
}
