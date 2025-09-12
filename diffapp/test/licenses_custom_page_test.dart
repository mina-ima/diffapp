import 'package:diffapp/screens/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diffapp/settings.dart';
import 'package:diffapp/screens/licenses_page.dart';

void main() {
  testWidgets('設定画面からカスタムOSSライセンスページに遷移する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(initial: Settings.initial()),
      ),
    );

    // 「OSS ライセンス」をタップ
    await tester.tap(find.text('OSS ライセンス'));
    await tester.pumpAndSettle();

    // カスタムページに遷移していること
    expect(find.byType(OssLicensesPage), findsOneWidget);
  });
}

