import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android のスプラッシュ画面にロゴが中心表示される設定になっている', () async {
    const path = 'android/app/src/main/res/drawable/launch_background.xml';
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path が存在すること');

    final xml = await file.readAsString();
    // 中央にロゴ（ic_launcher）を配置する bitmap 要素が含まれること
    expect(
      xml.contains('<bitmap') &&
          RegExp('android:src\s*=\s*"@mipmap/ic_launcher"').hasMatch(xml) &&
          RegExp('android:gravity\s*=\s*"center"').hasMatch(xml),
      isTrue,
      reason:
          'launch_background.xml に <bitmap android:gravity="center" android:src="@mipmap/ic_launcher"/> を追加してください',
    );
  });
}
