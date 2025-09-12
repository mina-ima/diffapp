import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Gradle に TensorFlow Lite ランタイムが追加されている', () async {
    const path = 'android/app/build.gradle.kts';
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path が存在すること');

    final gradle = await file.readAsString();
    // 依存関係として org.tensorflow:tensorflow-lite が含まれること
    final hasTflite = RegExp(
      r'implementation\(\s*"org\.tensorflow:tensorflow-lite:[^"\n]+"\s*\)',
    ).hasMatch(gradle);
    expect(
      hasTflite,
      isTrue,
      reason: 'app/build.gradle.kts の dependencies に tensorflow-lite を追加してください',
    );
  });
}

