import 'dart:convert';
import 'dart:typed_data';

import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/screens/compare_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 1x1透明PNG
  final Uint8List tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wm6p6kAAAAASUVORK5CYII=',
  );

  testWidgets('切り出しプレビューのオフセットは表示スケールに追従する', (tester) async {
    // 左画像: 400x300（1280正規化なし）
    final left = SelectedImage(label: 'L', width: 400, height: 300, bytes: tinyPng);
    final right = SelectedImage(label: 'R', width: 800, height: 600, bytes: tinyPng);

    // 明確な矩形（左上から 50,40 オフセット、サイズ 120x80）
    const rect = IntRect(left: 50, top: 40, width: 120, height: 80);

    await tester.pumpWidget(
      MaterialApp(home: ComparePage(left: left, right: right, initialLeftRect: rect)),
    );

    // 範囲指定→同座標適用（右へ）でプレビュー表示を有効化
    await tester.tap(find.text('範囲指定'));
    // push アニメーション完了を十分に待つ（Compare側の常時アニメを避けるため settle は使わない）
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('同座標適用（右へ）'));
    // pop 後にCompareへ戻るまで待機
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 350));

    // ビューポートのサイズから実際のスケールを算出
    final viewportFinder = find.byKey(const Key('cropped-left-viewport'));
    expect(viewportFinder, findsOneWidget);
    final viewportSize = tester.getSize(viewportFinder);
    final s = viewportSize.width / rect.width; // 横方向スケール

    // Transform.translate のオフセット（左プレビュー）を取得
    final transformFinder = find.ancestor(
      of: find.byKey(const Key('cropped-left')),
      matching: find.byType(Transform),
    );
    expect(transformFinder, findsWidgets);
    final Transform transform = tester.widget(transformFinder.first);
    final m = transform.transform.storage;
    final tx = m[12];
    final ty = m[13];

    // 期待値は -rect.left * s, -rect.top * s（±1px の誤差を許容）
    expect(tx, moreOrLessEquals(-rect.left * s, epsilon: 1.0));
    expect(ty, moreOrLessEquals(-rect.top * s, epsilon: 1.0));
  });
}
