import 'package:diffapp/logger.dart';
import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeErrorLogger implements ErrorLogger {
  final List<String> tags = [];
  final List<Object> errors = [];
  final List<StackTrace> stacks = [];

  @override
  void record(Object error, StackTrace stack, {String tag = 'app'}) {
    tags.add(tag);
    errors.add(error);
    stacks.add(stack);
  }
}

void main() {
  testWidgets('内部例外で一般メッセージ表示とローカルログ記録', (tester) async {
    final prev = AppLog.instance;
    final fake = _FakeErrorLogger();
    AppLog.instance = fake;
    addTearDown(() => AppLog.instance = prev);

    const left = SelectedImage(label: 'L', width: 1920, height: 1080);
    const right = SelectedImage(label: 'R', width: 1920, height: 1080);

    await tester.pumpWidget(
      const MaterialApp(
        home: ComparePage(
          left: left,
          right: right,
          simulateInternalError: true,
        ),
      ),
    );

    await tester.tap(find.text('けんさをはじめる（ダミー）'));
    await tester.pump();

    // 一般メッセージが表示される
    expect(find.text('エラーが おきました。もういちどためしてね'), findsOneWidget);

    // ローカルログに1件記録される
    expect(fake.errors.length, 1);
    expect(fake.tags.single, 'detection');
  });
}
