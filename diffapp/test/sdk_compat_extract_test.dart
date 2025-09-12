import 'package:diffapp/sdk_compat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pubspec の SDK 制約抽出', () {
    test('二重引用で抽出できる', () {
      const yaml = '''
environment:
  sdk: ">=3.4.0 <4.0.0"
''';
      expect(extractSdkConstraintFromPubspec(yaml), '>=3.4.0 <4.0.0');
    });

    test('単一引用で抽出できる', () {
      const yaml = '''
environment:
  sdk: '>=3.4.0 <4.0.0'
''';
      expect(extractSdkConstraintFromPubspec(yaml), '>=3.4.0 <4.0.0');
    });

    test('無引用でも抽出できる（行末コメントを無視）', () {
      const yaml = '''
environment:
  sdk: >=3.4.0 <4.0.0  # comment
''';
      expect(extractSdkConstraintFromPubspec(yaml), '>=3.4.0 <4.0.0');
    });

    test('空白を保持（satisfiesConstraint 側で許容）', () {
      const yaml = '''
environment:
  sdk: ">= 3.4.0 < 4.0.0"
''';
      expect(extractSdkConstraintFromPubspec(yaml), '>= 3.4.0 < 4.0.0');
    });
  });
}
