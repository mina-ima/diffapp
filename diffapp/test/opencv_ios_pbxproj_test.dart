import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Xcode プロジェクトの pbxproj にネイティブ連携の下地がある', () async {
    const path = 'ios/Runner.xcodeproj/project.pbxproj';
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path が存在すること');

    final pbx = await file.readAsString();

    // Swift-ObjC ブリッジングヘッダ設定（ネイティブ連携でよく使う）
    expect(
      pbx.contains('SWIFT_OBJC_BRIDGING_HEADER = "Runner/Runner-Bridging-Header.h";'),
      isTrue,
      reason: 'SWIFT_OBJC_BRIDGING_HEADER が設定されていること',
    );

    // C++ ランタイム（libc++）の利用設定（OpenCV等のC++連携で前提となる）
    expect(
      pbx.contains('CLANG_CXX_LIBRARY = "libc++";'),
      isTrue,
      reason: 'CLANG_CXX_LIBRARY が libc++ に設定されていること',
    );

    // Frameworks ビルドフェーズが存在する（フレームワークリンクの前提）
    expect(
      pbx.contains('/* Frameworks */ = {') || pbx.contains('PBXFrameworksBuildPhase'),
      isTrue,
      reason: 'Frameworks のビルドフェーズが定義されていること',
    );

    // 実機向けデプロイターゲット（13以上）
    expect(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET\s*=\s*1[3-9]\.').hasMatch(pbx),
      isTrue,
      reason: 'iOS のデプロイターゲットが 13 以上であること',
    );
  });
}

