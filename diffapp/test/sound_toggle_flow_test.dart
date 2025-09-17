import 'package:diffapp/main.dart';
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
  testWidgets('設定で効果音OFFにすると比較開始時に再生されない', (tester) async {
    final prev = Sfx.instance;
    final fake = _FakeSoundPlayer();
    Sfx.instance = fake;
    addTearDown(() => Sfx.instance = prev);

    await tester.pumpWidget(const DiffApp());

    // 設定画面を開く
    final settingsBtn = find.byIcon(Icons.settings);
    expect(settingsBtn, findsOneWidget);
    await tester.tap(settingsBtn);
    await tester.pumpAndSettle();

    // 効果音トグルをOFFにする
    final soundToggle = find.widgetWithText(CheckboxListTile, '効果音');
    expect(soundToggle, findsOneWidget);
    // 現在ON想定 → 一度タップでOFF
    await tester.tap(soundToggle);
    await tester.pumpAndSettle();

    // 保存
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    // 左右画像を選択（ダミー）
    await tester.tap(find.text('左 の画像を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('サンプルA'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('右 の画像を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('サンプルC'));
    await tester.pumpAndSettle();

    // 比較画面へ遷移（継続アニメがあるため pump に留める）
    await tester.tap(find.text('けんさせっていへ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 比較画面に到達していることを確認
    expect(find.text('比較'), findsOneWidget);

    // 検出開始を押す → 効果音はOFFなので鳴らない
    await tester.tap(find.text('検査をはじめる'));
    await tester.pumpAndSettle();
    // 結果画面に遷移している（スクショ案内が見える）
    expect(find.text('スクショをとろう！'), findsOneWidget);
    
    expect(fake.calls, isEmpty);
  });
}
