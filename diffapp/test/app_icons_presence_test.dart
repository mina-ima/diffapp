import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android のアプリアイコンが各密度で存在し、Manifest に設定されている', () async {
    const paths = [
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    ];
    for (final p in paths) {
      expect(File(p).existsSync(), isTrue, reason: '$p が存在すること');
    }

    final manifest =
        await File('android/app/src/main/AndroidManifest.xml').readAsString();
    expect(
      manifest.contains('android:icon="@mipmap/ic_launcher"'),
      isTrue,
      reason: 'AndroidManifest.xml で @mipmap/ic_launcher が設定されていること',
    );
  });

  test('iOS の AppIcon セットに代表的なサイズが存在する', () {
    const base = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    const paths = [
      '$base/Icon-App-60x60@2x.png',
      '$base/Icon-App-60x60@3x.png',
      '$base/Icon-App-76x76@2x.png',
      '$base/Icon-App-20x20@3x.png',
      '$base/Icon-App-1024x1024@1x.png',
    ];
    for (final p in paths) {
      expect(File(p).existsSync(), isTrue, reason: '$p が存在すること');
    }
  });
}
