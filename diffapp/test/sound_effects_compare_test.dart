import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:diffapp/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSoundPlayer implements SoundPlayer {
  final List<String> calls = [];
  @override
  Future<void> play(String key) async {
    calls.add(key);
  }
}

void main() {
  testWidgets('けんさ開始で効果音が再生される（startキー）', (tester) async {
    final prev = Sfx.instance;
    final fake = _FakeSoundPlayer();
    Sfx.instance = fake;
    addTearDown(() => Sfx.instance = prev);

    const left = SelectedImage(label: 'L', width: 4000, height: 3000);
    const right = SelectedImage(label: 'R', width: 1920, height: 1080);

    await tester.pumpWidget(
      const MaterialApp(
        home: ComparePage(left: left, right: right),
      ),
    );

    await tester.tap(find.text('検査をはじめる'));
    await tester.pump();

    expect(fake.calls.contains('start'), isTrue);
  });
}
