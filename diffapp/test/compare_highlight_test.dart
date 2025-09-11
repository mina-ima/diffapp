import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('結果画面に左右の赤枠ハイライトが表示される', (tester) async {
    const left = SelectedImage(label: 'L', width: 3000, height: 2000);
    const right = SelectedImage(label: 'R', width: 1920, height: 1080);

    await tester.pumpWidget(
      const MaterialApp(
        home: ComparePage(left: left, right: right),
      ),
    );

    // ハイライト用のウィジェット（キーで識別）
    expect(find.byKey(const Key('highlight-left')), findsOneWidget);
    expect(find.byKey(const Key('highlight-right')), findsOneWidget);
  });
}

