import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TFLite モデルアセット', () {
    test('pubspec.yaml に assets/models/ が宣言されている', () async {
      final pubspec = File('pubspec.yaml');
      expect(pubspec.existsSync(), isTrue, reason: 'pubspec.yaml が存在すること');
      final content = await pubspec.readAsString();
      // 最低限、assets セクションに assets/models/ が含まれていることを確認
      final hasAssetsBlock = content.contains(
        RegExp(r'^\s*assets:\n\s*-\s*assets/models/?\s*$', multiLine: true),
      );
      final hasModelsLine = content.contains(
        RegExp(r'^\s*-\s*assets/models/?\s*$', multiLine: true),
      );
      expect(
        hasAssetsBlock || hasModelsLine,
        isTrue,
        reason: 'pubspec.yaml の flutter:assets に assets/models/ を追加してください',
      );
    });

    test('assets/models/ に .tflite ファイルが少なくとも1つ存在', () async {
      final dir = Directory('assets/models');
      expect(dir.existsSync(), isTrue, reason: 'assets/models ディレクトリが必要');
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.tflite'))
          .toList();
      expect(files.isNotEmpty, isTrue, reason: '.tflite モデルファイルを配置してください');
    });
  });
}
