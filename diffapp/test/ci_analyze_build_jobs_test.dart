import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CI に解析/テスト/ビルド用のジョブが定義されている', () async {
    // リポジトリルートのワークフロー定義を読む（テストのCWDは diffapp/）
    const path = '../.github/workflows/flutter-ci.yml';
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'flutter-ci.yml が存在すること');

    final yml = await file.readAsString();

    // 解析+テストジョブ
    expect(
      yml.contains('analyze_test:'),
      isTrue,
      reason: '解析/テストジョブ(analyze_test)が存在すること',
    );
    expect(
      yml.contains('flutter analyze'),
      isTrue,
      reason: 'flutter analyze ステップが含まれること',
    );
    expect(
      yml.contains('flutter test'),
      isTrue,
      reason: 'flutter test ステップが含まれること',
    );

    // Android デバッグビルドジョブ
    expect(
      yml.contains('build_android:'),
      isTrue,
      reason: 'Android ビルドジョブ(build_android)が存在すること',
    );

    // iOS シミュレータビルドジョブ
    expect(
      yml.contains('build_ios:'),
      isTrue,
      reason: 'iOS ビルドジョブ(build_ios)が存在すること',
    );
  });
}
