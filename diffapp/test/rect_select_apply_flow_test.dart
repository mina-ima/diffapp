import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('範囲指定→保存で左の選択が反映される', (tester) async {
    const left = SelectedImage(label: 'L', width: 4000, height: 3000);
    const right = SelectedImage(label: 'R', width: 1920, height: 1080);

    await tester.pumpWidget(
      const MaterialApp(
        home: ComparePage(left: left, right: right),
      ),
    );

    // まだ左側は未選択
    expect(find.textContaining('選択: l=').evaluate().length, 0);

    // 範囲指定を開く（ComparePageに常時アニメがあるため、pumpAndSettleは使わない）
    await tester.tap(find.text('範囲指定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // そのまま保存（RectSelectPage の初期矩形 100,80,300,200 を返す）
    await tester.tap(find.byTooltip('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 左側に選択が反映される
    expect(find.text('選択: l=100, t=80, w=300, h=200'), findsOneWidget);
  });
}
