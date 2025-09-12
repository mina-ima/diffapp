import 'package:diffapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('主要ボタンは最小48x48のタップ領域を満たす', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    await tester.pumpWidget(const DiffApp());
    await tester.pumpAndSettle();

    Size sizeOf(Finder finder) => tester.getSize(finder);

    final startBtn = find.byKey(const Key('start-inspect'));
    final leftBtn = find.byKey(const Key('pick_左_button'));
    final rightBtn = find.byKey(const Key('pick_右_button'));

    final s1 = sizeOf(startBtn);
    final s2 = sizeOf(leftBtn);
    final s3 = sizeOf(rightBtn);

    const minSide = 48.0;
    expect(s1.width >= minSide && s1.height >= minSide, isTrue,
        reason: '開始ボタンが最小タップ領域を満たす');
    expect(s2.width >= minSide && s2.height >= minSide, isTrue,
        reason: '左ボタンが最小タップ領域を満たす');
    expect(s3.width >= minSide && s3.height >= minSide, isTrue,
        reason: '右ボタンが最小タップ領域を満たす');
  });
}
