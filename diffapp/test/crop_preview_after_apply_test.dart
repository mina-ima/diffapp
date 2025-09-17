import 'dart:convert';
import 'dart:typed_data';
import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diffapp/image_pipeline.dart';

void main() {
  // 1x1透明PNG（テスト用に十分）
  final Uint8List tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wm6p6kAAAAASUVORK5CYII=',
  );

  testWidgets('同座標適用後は左右とも切り出しプレビューが表示される', (tester) async {
    // 左右とも実画像（左は bytes を設定）
    final left = SelectedImage(label: 'L', width: 400, height: 300, bytes: tinyPng);
    final right = SelectedImage(label: 'R', width: 1920, height: 1080, bytes: tinyPng);

    // 左の初期矩形を用意
    const rect = IntRect(left: 10, top: 10, width: 50, height: 40);

    await tester.pumpWidget(
      MaterialApp(
        home: ComparePage(left: left, right: right, initialLeftRect: rect),
      ),
    );

    // 範囲指定を開いて「同座標適用（右へ）」
    await tester.tap(find.text('範囲指定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('同座標適用（右へ）'));
    await tester.pump();

    // 切り出しプレビューのキーが両側に現れる
    expect(find.byKey(const Key('cropped-left')), findsOneWidget);
    expect(find.byKey(const Key('cropped-right')), findsOneWidget);
  });
}
