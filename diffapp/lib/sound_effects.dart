import 'package:flutter/services.dart';

abstract class SoundPlayer {
  Future<void> play(String key);
}

class DefaultSoundPlayer implements SoundPlayer {
  @override
  Future<void> play(String key) async {
    // 簡易実装: すべてクリック音にフォールバック
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {
      // テスト環境などで失敗しても無視
    }
  }
}

class Sfx {
  static SoundPlayer instance = DefaultSoundPlayer();
}
