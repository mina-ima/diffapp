import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('見出しは「けんさせってい」であること', (tester) async {
    const left = SelectedImage(label: 'L', width: 2000, height: 1500);
    const right = SelectedImage(label: 'R', width: 1920, height: 1080);

    await tester.pumpWidget(
      const MaterialApp(
        home: ComparePage(left: left, right: right),
      ),
    );

    expect(find.text('けんさせってい'), findsOneWidget);
    expect(find.text('比較'), findsNothing);
  });

  testWidgets('「検査をはじめる」はOutlinedButtonで統一されていること', (tester) async {
    const left = SelectedImage(label: 'L', width: 2000, height: 1500);
    const right = SelectedImage(label: 'R', width: 1920, height: 1080);

    await tester.pumpWidget(
      const MaterialApp(
        home: ComparePage(left: left, right: right),
      ),
    );

    // ラベルは存在すること
    expect(find.text('検査をはじめる'), findsOneWidget);

    // 3つのボタン（範囲指定/検査精度設定/検査をはじめる）が同じ種類のボタンであることを確認
    final buttonA = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('範囲指定'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ).first,
    );
    final buttonB = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('検査精度設定'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ).first,
    );
    final buttonStart = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('検査をはじめる'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ).first,
    );
    expect(buttonStart.runtimeType, equals(buttonA.runtimeType));
    expect(buttonStart.runtimeType, equals(buttonB.runtimeType));
  });
}
