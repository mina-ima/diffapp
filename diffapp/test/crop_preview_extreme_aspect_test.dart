import 'dart:convert';
import 'dart:typed_data';
import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/screens/compare_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 1x1透明PNG（テスト用ダミー）
  final Uint8List tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wm6p6kAAAAASUVORK5CYII=',
  );

  testWidgets('極端に縦長/横長でも切り出しプレビューが表示される', (tester) async {
    final left = SelectedImage(label: 'L', width: 1280, height: 960, bytes: tinyPng);
    final right = SelectedImage(label: 'R', width: 640, height: 480, bytes: tinyPng);

    // 左の初期矩形を極端に縦長/横長に切り替えて検証
    const tall = IntRect(left: 100, top: 10, width: 12, height: 600);
    const wide = IntRect(left: 10, top: 120, width: 1000, height: 8);

    // 1) 縦長
    await tester.pumpWidget(
      MaterialApp(
        home: ComparePage(left: left, right: right, initialLeftRect: tall),
      ),
    );
    await tester.tap(find.text('範囲指定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('同座標適用（右へ）'));
    await tester.pump();

    final leftVp1 = find.byKey(const Key('cropped-left-viewport'));
    final rightVp1 = find.byKey(const Key('cropped-right-viewport'));
    expect(leftVp1, findsOneWidget);
    expect(rightVp1, findsOneWidget);
    expect(tester.getSize(leftVp1).width, greaterThan(0));
    expect(tester.getSize(leftVp1).height, greaterThan(0));
    expect(tester.getSize(rightVp1).width, greaterThan(0));
    expect(tester.getSize(rightVp1).height, greaterThan(0));

    // 2) 横長（新しいツリーで検証）
    await tester.pumpWidget(
      MaterialApp(
        home: ComparePage(left: left, right: right, initialLeftRect: wide),
      ),
    );
    await tester.tap(find.text('範囲指定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('同座標適用（右へ）'));
    await tester.pump();

    final leftVp2 = find.byKey(const Key('cropped-left-viewport'));
    final rightVp2 = find.byKey(const Key('cropped-right-viewport'));
    expect(leftVp2, findsOneWidget);
    expect(rightVp2, findsOneWidget);
    expect(tester.getSize(leftVp2).width, greaterThan(0));
    expect(tester.getSize(leftVp2).height, greaterThan(0));
    expect(tester.getSize(rightVp2).width, greaterThan(0));
    expect(tester.getSize(rightVp2).height, greaterThan(0));
  });
}

