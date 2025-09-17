import 'dart:convert';
import 'dart:typed_data';
import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 1x1 の透明PNG（base64）
  final Uint8List tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wm6p6kAAAAASUVORK5CYII=',
  );

  testWidgets('範囲指定ページに左画像が表示され、見出しが更新される', (tester) async {
    final left = SelectedImage(label: 'L', width: 400, height: 300, bytes: tinyPng);
    const right = SelectedImage(label: 'R', width: 1920, height: 1080);

    await tester.pumpWidget(
      MaterialApp(
        home: ComparePage(left: left, right: right),
      ),
    );

    // 範囲指定を開く（ComparePageは常時アニメ有のため settle は使わない）
    await tester.tap(find.text('範囲指定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 見出しが新仕様
    expect(find.text('範囲指定（左画像で設定）'), findsOneWidget);
    // 左画像のプレビュー（RectSelectPage 側のキー付き画像）が表示されている
    expect(find.byKey(const Key('rect-select-image')), findsOneWidget);
  });
}
