import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/screens/rect_select_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:diffapp/sound_effects.dart';
import 'package:diffapp/logger.dart';
import 'package:diffapp/settings.dart';
import 'package:diffapp/screens/settings_page.dart';
import 'package:diffapp/screens/result_page.dart';
import 'dart:io';

class ComparePage extends StatefulWidget {
  final SelectedImage left;
  final SelectedImage right;
  final IntRect? initialLeftRect;
  final IntRect? initialRightRect;
  final bool enableSound;
  // テスト・デモ用のフック：モデル読込失敗をシミュレート
  final bool simulateModelLoadFailure;
  // テスト・デモ用のフック：タイムアウトをシミュレート
  final bool simulateTimeout;
  // テスト・デモ用のフック：内部例外をシミュレート
  final bool simulateInternalError;

  const ComparePage({
    super.key,
    required this.left,
    required this.right,
    this.initialLeftRect,
    this.initialRightRect,
    this.enableSound = true,
    this.simulateModelLoadFailure = false,
    this.simulateTimeout = false,
    this.simulateInternalError = false,
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
    if (widget.enableSound) {
      Sfx.instance.play('start');
    }
    // モデル読込失敗をシミュレート（テスト用）
    if (widget.simulateModelLoadFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('けんさに しっぱいしました。もういちどためしてね')),
      );
      return;
    }

    // タイムアウトをシミュレート（テスト用）
    if (widget.simulateTimeout) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('じかんぎれです。もういちどためしてね')),
      );
      return;
    }

    // 内部例外をシミュレート（テスト用）
    if (widget.simulateInternalError) {
      try {
        throw Exception('simulated internal error');
      } catch (e, st) {
        AppLog.instance.record(e, st, tag: 'detection');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('エラーが おきました。もういちどためしてね')),
        );
      }
      return;
    }

    // いまはダミー検出：常にゼロ件とする
    final List<IntRect> results = <IntRect>[];
    // 結果メッセージ（従来の挙動を維持）
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ちがいは みつかりませんでした')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('検出数: ${results.length}')),
      );
    }
    // 検査結果ページへ遷移
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute(
            builder: (_) => ResultPage(noDifferences: results.isEmpty),
          ),
        )
        .then((reset) {
      if (reset == true) {
        _reset();
      }
    });
  }

  void _reset() {
    setState(() {
      _leftRect = null;
      _rightRect = null;
    });
    if (widget.enableSound) {
      Sfx.instance.play('reset');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('最初からやりなおします')),
    );
  }

  Future<void> _selectRect() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RectSelectPage(
          title: '範囲指定（左画像で設定）',
          imageWidth: _leftNorm.width,
          imageHeight: _leftNorm.height,
          initialRect: _leftRect,
          imageBytes: widget.left.bytes,
          imagePath: widget.left.path,
        ),
      ),
    );
    if (result == null) return;
    if (result is IntRect) {
      setState(() => _leftRect = result);
    } else if (result is (IntRect, bool)) {
      final (rect, applyRight) = result;
      setState(() => _leftRect = rect);
      if (applyRight == true) {
        _applySameRectToRight();
      }
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
      appBar: AppBar(title: const Text('けんさせってい')),
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
                      bytes: widget.left.bytes,
                      path: widget.left.path,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _placeholderCard(
                      label: '右: ${widget.right.label}',
                      dims: _rightNorm,
                      rect: _rightRect,
                      isLeft: false,
                      bytes: widget.right.bytes,
                      path: widget.right.path,
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
                    label: const Text('範囲指定'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      // 設定ページへ（ホームの歯車と同じ遷移先）
                      await Navigator.of(context).push<Settings>(
                        MaterialPageRoute(
                            builder: (_) => SettingsPage(initial: Settings.initial())),
                      );
                    },
                    icon: const Icon(Icons.tune),
                    label: const Text('検査精度設定'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _startDetection(context),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('検査をはじめる'),
                  ),
                ),
              ],
            ),
            // スクショ案内と再比較ボタンは検査結果ページへ移動
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
    Uint8List? bytes,
    String? path,
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
                if (bytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 160,
                      child: Image.memory(bytes, fit: BoxFit.cover),
                    ),
                  )
                else if (path != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 160,
                      child: Image.file(File(path), fit: BoxFit.cover),
                    ),
                  )
                else
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
                  child: Semantics(
                    label: '検出ハイライト',
                    container: true,
                    child: Container(
                      key: Key(isLeft ? 'highlight-left' : 'highlight-right'),
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.redAccent, width: 3),
                        color: Colors.redAccent.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
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
