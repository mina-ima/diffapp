import 'package:diffapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ホーム→左右選択→比較画面までの一連のフロー', (tester) async {
    await tester.pumpWidget(const DiffApp());

    // 左を選ぶ → サンプルA
    await tester.tap(find.text('左 の画像を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('サンプルA'));
    await tester.pumpAndSettle();

    // 右を選ぶ → サンプルC
    await tester.tap(find.text('右 の画像を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('サンプルC'));
    await tester.pumpAndSettle();

    // 比較開始→比較画面へ遷移
    await tester.tap(find.text('けんさをはじめる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 比較画面の要素が表示されていること
    expect(find.text('比較'), findsOneWidget);
    expect(find.text('スクショをとろう！'), findsOneWidget);

    // 赤枠ハイライトも存在（キーにより両側）
    expect(find.byKey(const Key('highlight-left')), findsOneWidget);
    expect(find.byKey(const Key('highlight-right')), findsOneWidget);
  });
}
