import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CI に署名付きリリース用ジョブが定義されている', () async {
    // リポジトリルートのワークフロー定義を読む（テストのCWDは diffapp/）
    const path = '../.github/workflows/flutter-ci.yml';
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'flutter-ci.yml が存在すること');

    final yml = await file.readAsString();

    // Android 署名付きリリース
    expect(
      yml.contains('release_android_signed:'),
      isTrue,
      reason: 'Android 署名付きリリースジョブが存在すること',
    );

    // iOS 署名付きリリース
    expect(
      yml.contains('release_ios_signed:'),
      isTrue,
      reason: 'iOS 署名付きリリースジョブが存在すること',
    );
  });
}
