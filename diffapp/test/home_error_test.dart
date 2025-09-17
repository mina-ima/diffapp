import 'package:diffapp/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('画像未選択で開始すると警告が出る', (tester) async {
    await tester.pumpWidget(const DiffApp());

    // まだ左右未選択のまま次へボタンを押す
    await tester.tap(find.text('けんさせっていへ'));
    await tester.pump();

    expect(find.text('がぞうを えらんでね'), findsOneWidget);
  });
}
