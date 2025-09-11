import 'package:diffapp/screens/image_select_page.dart';
import 'package:diffapp/permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePermissionService implements PermissionService {
  bool opened = false;
  final bool cameraGranted;
  final bool galleryGranted;
  _FakePermissionService({required this.cameraGranted, required this.galleryGranted});

  @override
  Future<void> openAppSettings() async {
    opened = true;
  }

  @override
  Future<PermissionResult> requestCamera() async =>
      PermissionResult(granted: cameraGranted, permanentlyDenied: !cameraGranted);

  @override
  Future<PermissionResult> requestGallery() async =>
      PermissionResult(granted: galleryGranted, permanentlyDenied: !galleryGranted);
}

void main() {
  testWidgets('権限拒否時に設定アプリへの導線が表示され、押下で openAppSettings が呼ばれる（カメラ）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    final fake = _FakePermissionService(cameraGranted: false, galleryGranted: true);

    await tester.pumpWidget(MaterialApp(
      home: ImageSelectPage(title: '選択', permissionService: fake),
    ));

    // カメラで撮影ボタンをタップ
    await tester.tap(find.byKey(const Key('pick_camera')));
    await tester.pump();

    // SnackBar が表示される
    expect(find.textContaining('カメラ へのアクセスが必要です', findRichText: true), findsOneWidget);
    expect(find.byType(SnackBarAction), findsOneWidget);

    // SnackBarAction の onPressed を直接呼ぶ（オフスクリーンでも確実に検証）
    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    action.onPressed();
    await tester.pump();
    expect(fake.opened, isTrue);
  });

  testWidgets('権限拒否時に設定アプリへの導線が表示され、押下で openAppSettings が呼ばれる（ギャラリー）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    final fake = _FakePermissionService(cameraGranted: true, galleryGranted: false);

    await tester.pumpWidget(MaterialApp(
      home: ImageSelectPage(title: '選択', permissionService: fake),
    ));

    // ギャラリーから選ぶボタンをタップ
    await tester.tap(find.byKey(const Key('pick_gallery')));
    await tester.pump();

    // SnackBar が表示される
    expect(find.textContaining('写真 へのアクセスが必要です', findRichText: true), findsOneWidget);
    expect(find.byType(SnackBarAction), findsOneWidget);
    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    action.onPressed();
    await tester.pump();
    expect(fake.opened, isTrue);
  });
}
