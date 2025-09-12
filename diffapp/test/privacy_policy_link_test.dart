import 'package:diffapp/screens/settings_page.dart';
import 'package:diffapp/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('設定にプライバシーポリシーへのリンクがあり、ページが開く', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(initial: Settings.initial()),
    ));

    // リンクが存在する
    expect(find.text('プライバシーポリシー'), findsOneWidget);

    // タップしてページに遷移
    await tester.tap(find.text('プライバシーポリシー'));
    await tester.pumpAndSettle();

    // タイトルと本文の一部が表示される
    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.textContaining('本アプリは完全オフラインで動作'), findsOneWidget);
  });
}
