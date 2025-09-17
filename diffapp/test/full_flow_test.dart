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

    // 比較画面へ遷移
    await tester.tap(find.text('けんさせっていへ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 比較（設定）画面の見出しが新仕様に沿っていること
    expect(find.text('けんさせってい'), findsOneWidget);
    // 赤枠ハイライトも存在（キーにより両側）
    expect(find.byKey(const Key('highlight-left')), findsOneWidget);
    expect(find.byKey(const Key('highlight-right')), findsOneWidget);

    // 検査開始→結果画面でスクショ案内が表示される
    await tester.tap(find.text('検査をはじめる'));
    await tester.pumpAndSettle();
    expect(find.text('スクショをとろう！'), findsOneWidget);
  });
}
