import 'package:flutter/material.dart';
import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/screens/rect_select_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:diffapp/sound_effects.dart';

class ComparePage extends StatefulWidget {
  final SelectedImage left;
  final SelectedImage right;
  final IntRect? initialLeftRect;
  final IntRect? initialRightRect;

  const ComparePage({
    super.key,
    required this.left,
    required this.right,
    this.initialLeftRect,
    this.initialRightRect,
  });

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage>
    with TickerProviderStateMixin {
  IntRect? _leftRect;
  IntRect? _rightRect;
  late final Dimensions _leftNorm;
  late final Dimensions _rightNorm;
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  void _startDetection(BuildContext context) {
    // 効果音
    Sfx.instance.play('start');
    // いまはダミー検出：常にゼロ件とする
    final List<IntRect> results = <IntRect>[];
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ちがいは みつかりませんでした')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('検出数: ${results.length}')),
      );
    }
  }

  void _reset() {
    setState(() {
      _leftRect = null;
      _rightRect = null;
    });
    Sfx.instance.play('reset');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('最初からやりなおします')),
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
                      isLeft: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _placeholderCard(
                      label: '右: ${widget.right.label}',
                      dims: _rightNorm,
                      rect: _rightRect,
                      isLeft: false,
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
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'スクショをとろう！',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('再比較'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween<double>(begin: 0.96, end: 1.04)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _pulse.repeat(reverse: true);
    // 入力が 4000x3000 を超える場合は、まず自動リサイズ（クランプ）。
    final leftClamped = clampToMaxResolution(
      widget.left.width,
      widget.left.height,
      maxWidth: 4000,
      maxHeight: 3000,
    );
    final rightClamped = clampToMaxResolution(
      widget.right.width,
      widget.right.height,
      maxWidth: 4000,
      maxHeight: 3000,
    );

    // その後、幅 1280 への正規化を行う。
    _leftNorm = calculateResizeDimensions(
      leftClamped.width,
      leftClamped.height,
      targetMaxWidth: 1280,
    );
    _rightNorm = calculateResizeDimensions(
      rightClamped.width,
      rightClamped.height,
      targetMaxWidth: 1280,
    );
    // 初期矩形（テストや再入場時向けのフック）
    _leftRect = widget.initialLeftRect ?? _leftRect;
    _rightRect = widget.initialRightRect ?? _rightRect;
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _placeholderCard({
    required String label,
    required Dimensions dims,
    IntRect? rect,
    required bool isLeft,
  }) {
    return Card(
      elevation: 1,
      child: Stack(
        children: [
          Container(
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
          // 赤枠ハイライト（ポヨンアニメ）
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _scale,
                  builder: (context, child) => Transform.scale(
                    scale: _scale.value,
                    child: child,
                  ),
                  child: Container(
                    key: Key(isLeft ? 'highlight-left' : 'highlight-right'),
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.redAccent, width: 3),
                      color: Colors.redAccent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
