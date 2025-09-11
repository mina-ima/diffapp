import 'dart:io';

import 'package:diffapp/sdk_compat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dart/Flutter SDK 互換性チェック', () {
    test('pubspec の SDK 範囲が FVM の Flutter 3.22.0 に同梱の Dart に適合する', () async {
      const pubspecPath = 'pubspec.yaml';
      const fvmConfigPath = 'fvm/fvm_config.json';

      // Sanity: ファイルが存在すること（CI で flutter create を待たずにチェック可能）
      expect(File(pubspecPath).existsSync(), isTrue);
      expect(File(fvmConfigPath).existsSync(), isTrue);

      final result = await checkCompatibilityFromFiles(
        pubspecPath: pubspecPath,
        fvmConfigPath: fvmConfigPath,
      );

      expect(result.ok, isTrue,
          reason: '現状の pubspec の Dart 範囲と FVM の Flutter 版が矛盾しないこと');
    });

    test('セマンティックバージョンの範囲評価（>=3.4.0 <4.0.0）', () {
      expect(satisfiesConstraint('3.4.0', '>=3.4.0 <4.0.0'), isTrue);
      expect(satisfiesConstraint('3.4.3', '>=3.4.0 <4.0.0'), isTrue);
      expect(satisfiesConstraint('3.9.9', '>=3.4.0 <4.0.0'), isTrue);
      expect(satisfiesConstraint('4.0.0', '>=3.4.0 <4.0.0'), isFalse);
      expect(satisfiesConstraint('3.3.9', '>=3.4.0 <4.0.0'), isFalse);
    });
  });
}
