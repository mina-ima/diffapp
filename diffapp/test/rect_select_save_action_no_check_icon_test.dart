import 'package:diffapp/screens/rect_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('範囲指定ページにチェックアイコンが無く、保存ボタンは残る', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: RectSelectPage(
        title: '範囲指定（左画像で設定）',
        imageWidth: 1280,
        imageHeight: 960,
      ),
    ));

    // チェック（レ点）アイコンは存在しない
    expect(find.byIcon(Icons.check), findsNothing);
    // 保存操作は残る（ツールチップで検出可能）
    expect(find.byTooltip('保存'), findsOneWidget);
  });
}

