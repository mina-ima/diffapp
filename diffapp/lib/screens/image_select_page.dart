import 'package:flutter/material.dart';

class ImageSelectPage extends StatelessWidget {
  final String title;
  const ImageSelectPage({super.key, required this.title});

  void _pick(BuildContext context, String label) {
    Navigator.of(context).pop(label);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
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
                  onPressed: () => _pick(context, 'サンプルA'),
                  icon: const Icon(Icons.image),
                  label: const Text('サンプルA'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pick(context, 'サンプルB'),
                  icon: const Icon(Icons.image),
                  label: const Text('サンプルB'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pick(context, 'サンプルC'),
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
                    onPressed: () => _pick(context, 'ギャラリー（ダミー）'),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('ギャラリーから選ぶ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(context, 'カメラ（ダミー）'),
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

