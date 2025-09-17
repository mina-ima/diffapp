import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../permissions.dart';

class SelectedImage {
  final String label;
  final int width;
  final int height;
  // 選択した画像のプレビュー用（任意）
  final Uint8List? bytes;
  // 端末上のファイルパス（プレビューは Image.file に委ねて高速化）
  final String? path;
  const SelectedImage({
    required this.label,
    required this.width,
    required this.height,
    this.bytes,
    this.path,
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

  // 画像ヘッダーから軽量に寸法を取得（PNG / JPEG のみ対応、その他はフォールバック）
  Future<(int,int)> _readImageSizeFast(String path) async {
    final file = File(path);
    final raf = await file.open();
    try {
      // Read first 32 bytes
      final sig = await raf.read(32);
      // PNG signature
      if (sig.length >= 24 &&
          sig[0] == 0x89 &&
          sig[1] == 0x50 && // P
          sig[2] == 0x4E && // N
          sig[3] == 0x47 && // G
          sig[4] == 0x0D &&
          sig[5] == 0x0A &&
          sig[6] == 0x1A &&
          sig[7] == 0x0A) {
        // IHDR: width/height at offset 16..23, big-endian
        int w = (sig[16] << 24) | (sig[17] << 16) | (sig[18] << 8) | sig[19];
        int h = (sig[20] << 24) | (sig[21] << 16) | (sig[22] << 8) | sig[23];
        if (w > 0 && h > 0) return (w, h);
      }
      // JPEG
      if (sig.length >= 2 && sig[0] == 0xFF && sig[1] == 0xD8) {
        // Iterate segments
        await raf.setPosition(2);
        for (int i = 0; i < 1000; i++) {
          // Find marker 0xFF
          int byte = (await raf.readByte());
          while (byte == 0xFF) {
            byte = (await raf.readByte());
          }
          final marker = byte;
          // Read segment length
          final lenHi = await raf.readByte();
          final lenLo = await raf.readByte();
          final segLen = (lenHi << 8) | lenLo;
          if (segLen < 2) break;
          // SOF markers that contain dimensions
          const sofMarkers = [
            0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF
          ];
          if (sofMarkers.contains(marker)) {
            // segment: [len(2)] [precision(1)] [height(2)] [width(2)] ...
            final data = await raf.read(5);
            if (data.length >= 5) {
              final h = (data[1] << 8) | data[2];
              final w = (data[3] << 8) | data[4];
              if (w > 0 && h > 0) return (w, h);
            }
            break;
          } else {
            // Skip the rest of this segment (already consumed 2 for length)
            await raf.setPosition((await raf.position()) + segLen - 2);
          }
        }
      }
    } catch (_) {
      // ignore and fallback
    } finally {
      await raf.close();
    }
    // Fallback: decode fast path
    final bytes = await File(path).readAsBytes();
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    final image = await completer.future;
    return (image.width, image.height);
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

      // 可能な限り軽量に寸法だけ取得（ヘッダー解析）。
      final dims = await _readImageSizeFast(picked.path);

      if (!context.mounted) return;
      final fileName = picked.name.isNotEmpty ? picked.name : '選択画像';
      _pick(
        context,
        SelectedImage(
          label: '$fileName (${dims.$1}x${dims.$2})',
          width: dims.$1,
          height: dims.$2,
          // プレビューはファイルを直接表示して描画負荷を軽減
          path: picked.path,
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
