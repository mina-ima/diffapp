import 'package:diffapp/image_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSupportedImageFormat: 前後の空白を無視して判定', () {
    test('前後に半角スペースがあっても受け入れる', () {
      expect(isSupportedImageFormat(' photo.JPG '), isTrue);
      expect(isSupportedImageFormat(' image.png '), isTrue);
      expect(isSupportedImageFormat(' picture.JPeg '), isTrue);
    });

    test('タブ/改行などの空白も許容', () {
      expect(isSupportedImageFormat('\tphoto.jpg\n'), isTrue);
      expect(isSupportedImageFormat('\nimage.PNG\t'), isTrue);
    });

    test('拡張子が無い/不正は弾く（空白除去後の判定）', () {
      expect(isSupportedImageFormat('  noext  '), isFalse);
      expect(isSupportedImageFormat('  invalid.gif  '), isFalse);
      expect(isSupportedImageFormat('   '), isFalse);
    });
  });
}

