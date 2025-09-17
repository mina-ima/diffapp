import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../permissions.dart';

class SelectedImage {
  final String label;
  final int width;
  final int height;
  // 選択した画像のプレビュー用（任意）
  final Uint8List? bytes;
  const SelectedImage({
    required this.label,
    required this.width,
    required this.height,
    this.bytes,
  });
}

class ImageSelectPage extends StatelessWidget {
  final String title;
  final PermissionService permissionService;
  const ImageSelectPage(
      {super.key, required this.title, PermissionService? permissionService})
      : permissionService = permissionService ?? const BasicPermissionService();

  void _pick(BuildContext context, SelectedImage img) {
    Navigator.of(context).pop(img);
  }

  Future<void> _handleDenied(BuildContext context,
      {required String target}) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('$target へのアクセスが必要です。設定で許可してね'),
        action: SnackBarAction(
          label: '設定をひらく',
          onPressed: () {
            permissionService.openAppSettings();
          },
        ),
      ),
    );
  }

  Future<void> _onTapCamera(BuildContext context) async {
    final result = await permissionService.requestCamera();
    if (!context.mounted) return;
    if (!result.granted) {
      await _handleDenied(context, target: 'カメラ');
      return;
    }
    _pick(
      context,
      const SelectedImage(
        label: 'カメラ（ダミー）(1280x960)',
        width: 1280,
        height: 960,
      ),
    );
  }

  Future<void> _onTapGallery(BuildContext context) async {
    final result = await permissionService.requestGallery();
    if (!context.mounted) return;
    if (!result.granted) {
      await _handleDenied(context, target: '写真');
      return;
    }
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        // キャンセルされた場合はそのまま残る
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('キャンセルしました')));
        return;
      }

      final bytes = await picked.readAsBytes();
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (img) => completer.complete(img));
      final image = await completer.future;

      if (!context.mounted) return;
      final fileName = picked.name.isNotEmpty ? picked.name : '選択画像';
      _pick(
        context,
        SelectedImage(
          label: '$fileName (${image.width}x${image.height})',
          width: image.width,
          height: image.height,
          bytes: bytes,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像の取得に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ダミー選択肢', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pick(
                    context,
                    const SelectedImage(
                      label: 'サンプルA (4000x3000)',
                      width: 4000,
                      height: 3000,
                    ),
                  ),
                  icon: const Icon(Icons.image),
                  label: const Text('サンプルA'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pick(
                    context,
                    const SelectedImage(
                      label: 'サンプルB (3000x4000)',
                      width: 3000,
                      height: 4000,
                    ),
                  ),
                  icon: const Icon(Icons.image),
                  label: const Text('サンプルB'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pick(
                    context,
                    const SelectedImage(
                      label: 'サンプルC (1920x1080)',
                      width: 1920,
                      height: 1080,
                    ),
                  ),
                  icon: const Icon(Icons.image),
                  label: const Text('サンプルC'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('将来の実装', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('pick_gallery'),
                    onPressed: () => _onTapGallery(context),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('ギャラリーから選ぶ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('pick_camera'),
                    onPressed: () => _onTapCamera(context),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('カメラで撮影'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
