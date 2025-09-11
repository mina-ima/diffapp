import 'package:diffapp/screens/rect_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('矩形選択画面のモード切替（編集↔拡大）の表示が正しく変化する', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home:
          RectSelectPage(title: '左の範囲をえらぶ', imageWidth: 1280, imageHeight: 960),
    ));

    // 初期状態: 編集モード表記と、切替ボタンのツールチップが「拡大モードへ」
    expect(find.textContaining('編集モード：ドラッグで矩形を移動'), findsOneWidget);
    expect(find.byTooltip('拡大モードへ'), findsOneWidget);

    // 切替ボタンを押す → 拡大モード
    await tester.tap(find.byTooltip('拡大モードへ'));
    await tester.pump();
    expect(find.textContaining('拡大モード：ピンチで拡大・パン'), findsOneWidget);
    expect(find.byTooltip('編集モードへ'), findsOneWidget);

    // もう一度押す → 編集モードに戻る
    await tester.tap(find.byTooltip('編集モードへ'));
    await tester.pump();
    expect(find.textContaining('編集モード：ドラッグで矩形を移動'), findsOneWidget);
    expect(find.byTooltip('拡大モードへ'), findsOneWidget);
  });
}
