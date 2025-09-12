import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS のスプラッシュ画面に中央ロゴ(LaunchImage)が表示される', () async {
    const path = 'ios/Runner/Base.lproj/LaunchScreen.storyboard';
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path が存在すること');

    final xml = await file.readAsString();
    // 画像ビューが LaunchImage を参照し、中央寄せの制約があること
    expect(
      xml.contains('<imageView') &&
          RegExp(r'image="LaunchImage"').hasMatch(xml) &&
          xml.contains('firstAttribute="centerX"') &&
          xml.contains('firstAttribute="centerY"'),
      isTrue,
      reason: 'LaunchScreen.storyboard に中央寄せの LaunchImage を表示する設定を追加してください',
    );
  });
}
