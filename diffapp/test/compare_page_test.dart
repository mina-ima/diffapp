import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('結果画面にスクショ案内が表示される', (tester) async {
    const left = SelectedImage(label: 'L', width: 4000, height: 3000);
    const right = SelectedImage(label: 'R', width: 1920, height: 1080);

    await tester.pumpWidget(
      const MaterialApp(
        home: ComparePage(left: left, right: right),
      ),
    );
    // 検査開始→結果画面へ
    await tester.tap(find.text('検査をはじめる'));
    await tester.pumpAndSettle();

    expect(find.text('スクショをとろう！'), findsOneWidget);
  });

  testWidgets('結果画面の再比較ボタンでCompareへ戻りSnackBarが出る', (tester) async {
    const left = SelectedImage(label: 'L', width: 4000, height: 3000);
    const right = SelectedImage(label: 'R', width: 1920, height: 1080);

    await tester.pumpWidget(
      const MaterialApp(
        home: ComparePage(left: left, right: right),
      ),
    );
    // 結果画面へ
    await tester.tap(find.text('検査をはじめる'));
    await tester.pumpAndSettle();
    // 再比較を押す→戻ってSnackBar
    await tester.tap(find.text('再比較'));
    await tester.pump();
    expect(find.text('最初からやりなおします'), findsOneWidget);
  });
}
