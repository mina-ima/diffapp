import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('同座標適用で右にも矩形が反映される', (tester) async {
    // 左 4000x3000 -> 正規化 1280x960、右 1920x1080 -> 正規化 1280x720
    // 左矩形(100,200,300,400) を右正規化空間へ: xは等倍、yは0.75倍
    const left = SelectedImage(label: 'L', width: 4000, height: 3000);
    const right = SelectedImage(label: 'R', width: 1920, height: 1080);
    const leftRect = IntRect(left: 100, top: 200, width: 300, height: 400);

    await tester.pumpWidget(
      const MaterialApp(
        home: ComparePage(
          left: left,
          right: right,
          initialLeftRect: leftRect,
        ),
      ),
    );

    // 左の選択表示があることを確認
    expect(find.text('選択: l=100, t=200, w=300, h=400'), findsOneWidget);

    // 初期状態では右は未選択
    expect(find.textContaining('選択: l=').evaluate().length, 1);

    // 同座標適用を押す
    final applyBtn = find.text('同座標適用（右へ）');
    expect(applyBtn, findsOneWidget);
    await tester.tap(applyBtn);
    await tester.pump();

    // 右側にも矩形が反映（y方向のみ0.75倍される想定）
    expect(find.text('選択: l=100, t=150, w=300, h=300'), findsOneWidget);
  });
}
