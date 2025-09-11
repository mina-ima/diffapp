import 'package:flutter/material.dart';
import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/screens/rect_select_page.dart';
import 'package:diffapp/screens/image_select_page.dart';

class ComparePage extends StatefulWidget {
  final SelectedImage left;
  final SelectedImage right;

  const ComparePage({super.key, required this.left, required this.right});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  IntRect? _leftRect;
  IntRect? _rightRect;
  late final Dimensions _leftNorm;
  late final Dimensions _rightNorm;

  void _startDetection(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '検出は未実装（ダミー） 左:${_leftRect ?? '未指定'} / 右:${_rightRect ?? '未指定'}',
        ),
      ),
    );
  }

  Future<void> _selectRect() async {
    final result = await Navigator.of(context).push<IntRect>(
      MaterialPageRoute(
        builder: (_) => RectSelectPage(
          title: '左の範囲をえらぶ',
          imageWidth: _leftNorm.width,
          imageHeight: _leftNorm.height,
        ),
      ),
    );
    if (result != null) {
      setState(() => _leftRect = result);
    }
  }

  void _applySameRectToRight() {
    if (_leftRect == null) return;
    // Map from left normalized space -> right normalized space
    final mapped = scaleRectBetweenSpaces(
      _leftRect!,
      _leftNorm.width,
      _leftNorm.height,
      _rightNorm.width,
      _rightNorm.height,
    );
    setState(() => _rightRect = mapped);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('比較')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _placeholderCard(
                      label: '左: ${widget.left.label}',
                      dims: _leftNorm,
                      rect: _leftRect,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _placeholderCard(
                      label: '右: ${widget.right.label}',
                      dims: _rightNorm,
                      rect: _rightRect,
                    ),
                  ),
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
                  child: OutlinedButton.icon(
                    onPressed: _leftRect != null ? _applySameRectToRight : null,
                    icon: const Icon(Icons.copy_all),
                    label: const Text('同座標適用（右へ）'),
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

  @override
  void initState() {
    super.initState();
    _leftNorm = calculateResizeDimensions(
      widget.left.width,
      widget.left.height,
      targetMaxWidth: 1280,
    );
    _rightNorm = calculateResizeDimensions(
      widget.right.width,
      widget.right.height,
      targetMaxWidth: 1280,
    );
  }

  Widget _placeholderCard({
    required String label,
    required Dimensions dims,
    IntRect? rect,
  }) {
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
            Text('$label  (${dims.width}x${dims.height})'),
            if (rect != null) ...[
              const SizedBox(height: 8),
              Text(
                '選択: l=${rect.left}, t=${rect.top}, w=${rect.width}, h=${rect.height}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
