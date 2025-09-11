import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('検出ゼロ件なら「ちがいは みつかりませんでした」を表示', (tester) async {
    const left = SelectedImage(label: 'L', width: 3000, height: 2000);
    const right = SelectedImage(label: 'R', width: 1920, height: 1080);

    await tester.pumpWidget(
      const MaterialApp(
        home: ComparePage(left: left, right: right),
      ),
    );

    // 「けんさをはじめる」を押すと、ゼロ件想定でメッセージを表示する
    await tester.tap(find.text('けんさをはじめる（ダミー）'));
    await tester.pump();

    expect(find.text('ちがいは みつかりませんでした'), findsOneWidget);
  });
}
