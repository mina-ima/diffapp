import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diffapp/screens/settings_page.dart';
import 'package:diffapp/settings.dart';

void main() {
  testWidgets('設定画面からOSSライセンス一覧へ遷移できる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(initial: Settings.initial()),
      ),
    );

    // ライセンスリンクが表示されていること
    expect(find.text('OSS ライセンス'), findsOneWidget);

    // タップでライセンスページ（LicensePage）が開くこと
    await tester.tap(find.text('OSS ライセンス'));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });
}
