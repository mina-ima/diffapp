import 'package:flutter/material.dart';
import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/screens/rect_select_page.dart';

class ComparePage extends StatefulWidget {
  final String leftLabel;
  final String rightLabel;

  const ComparePage({super.key, required this.leftLabel, required this.rightLabel});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  IntRect? _leftRect;

  void _startDetection(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('検出は未実装（ダミー） 矩形: ${_leftRect ?? '未指定'}')),
    );
  }

  Future<void> _selectRect() async {
    final result = await Navigator.of(context).push<IntRect>(
      MaterialPageRoute(
        builder: (_) => const RectSelectPage(title: '左の範囲をえらぶ'),
      ),
    );
    if (result != null) {
      setState(() => _leftRect = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('比較'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _placeholderCard(label: '左: ${widget.leftLabel}', rect: _leftRect)),
                  const SizedBox(width: 12),
                  Expanded(child: _placeholderCard(label: '右: ${widget.rightLabel}')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectRect,
                    icon: const Icon(Icons.crop),
                    label: const Text('範囲指定（左）'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _startDetection(context),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('けんさをはじめる（ダミー）'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderCard({required String label, IntRect? rect}) {
    return Card(
      elevation: 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image, size: 64, color: Colors.grey),
            const SizedBox(height: 8),
            Text(label),
            if (rect != null) ...[
              const SizedBox(height: 8),
              Text('選択: l=${rect.left}, t=${rect.top}, w=${rect.width}, h=${rect.height}',
                  style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
