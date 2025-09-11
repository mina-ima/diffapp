import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('幅は小さいが高さが大きすぎる場合は3000pxに自動リサイズ', (tester) async {
    // 左は 1000x10000（幅は 1280 以下だが高さが 3000 を超える）
    // 期待：まず 4000x3000 以内にクランプ → 1000x10000 は比率維持で 300x3000
    // その後、幅1280への正規化は幅が 1280 以下のためスケールなし → 300x3000 のまま表示
    const left = SelectedImage(label: 'L', width: 1000, height: 10000);
    const right = SelectedImage(label: 'R', width: 1600, height: 900);

    await tester.pumpWidget(
      const MaterialApp(
        home: ComparePage(left: left, right: right),
      ),
    );

    // 左側の表示寸法が 300x3000 にクランプされていること
    expect(find.text('左: L  (300x3000)'), findsOneWidget);
    // 右側は通常の 1280 幅への正規化（1600x900 → 1280x720）
    expect(find.text('右: R  (1280x720)'), findsOneWidget);
  });
}
