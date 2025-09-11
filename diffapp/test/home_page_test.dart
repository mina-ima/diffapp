import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diffapp/main.dart';

void main() {
  testWidgets('ホーム画面にロゴとキャッチコピーが表示される', (tester) async {
    await tester.pumpWidget(const DiffApp());

    // ロゴ（仮）とキャッチコピーの表示を確認
    expect(find.byKey(const Key('app-logo')), findsOneWidget);
    expect(find.text('AIがちがいをみつけるよ'), findsOneWidget);
  });
}
