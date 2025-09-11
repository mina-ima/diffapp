import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('タイムアウトしたら再試行案内メッセージを表示', (tester) async {
    const left = SelectedImage(label: 'L', width: 1920, height: 1080);
    const right = SelectedImage(label: 'R', width: 1920, height: 1080);

    await tester.pumpWidget(
      const MaterialApp(
        home: ComparePage(
          left: left,
          right: right,
          simulateTimeout: true,
        ),
      ),
    );

    await tester.tap(find.text('けんさをはじめる（ダミー）'));
    await tester.pump();

    expect(
      find.text('じかんぎれです。もういちどためしてね'),
      findsOneWidget,
    );
  });
}
