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
import 'dart:ui' as ui;
import 'package:diffapp/widgets/cropped_image.dart';
import 'package:diffapp/cnn_detection.dart';

class ComparePage extends StatefulWidget {
  final SelectedImage left;
  final SelectedImage right;
  final IntRect? initialLeftRect;
  final IntRect? initialRightRect;
  final bool enableSound;
  // 検出の設定（精度やカテゴリ）。指定が無い場合は初期設定。
  final Settings? settings;
  // テスト・デモ用のフック：モデル読込失敗をシミュレート
  final bool simulateModelLoadFailure;
  // テスト・デモ用のフック：タイムアウトをシミュレート
  final bool simulateTimeout;
  // テスト・デモ用のフック：内部例外をシミュレート
  final bool simulateInternalError;
  // テスト用：検出器を差し替えられるようにする
  final CnnDetector? detector;

  const ComparePage({
    super.key,
    required this.left,
    required this.right,
    this.initialLeftRect,
    this.initialRightRect,
    this.enableSound = true,
    this.settings,
    this.simulateModelLoadFailure = false,
    this.simulateTimeout = false,
    this.simulateInternalError = false,
    this.detector,
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
  bool _showCroppedPreviews = false;

  Future<void> _startDetection(BuildContext context) async {
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

    // 検出処理
    List<IntRect> results = <IntRect>[];
    try {
      results = await _runDetection();
    } catch (e, st) {
      AppLog.instance.record(e, st, tag: 'detection');
      // 失敗時はゼロ件として扱う
      results = <IntRect>[];
    }
    // 結果メッセージ
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

  Future<List<IntRect>> _runDetection() async {
    // 画像からピクセル取得（bytes優先、なければ path）
    final imgL = await _decodeAndScaleTo(_getBytesOrNull(widget.left), widget.left.path);
    final imgR = await _decodeAndScaleTo(_getBytesOrNull(widget.right), widget.right.path);
    if (imgL == null || imgR == null) {
      return <IntRect>[];
    }
    // 同一サイズに揃える（64x64固定）
    const targetW = 64;
    const targetH = 64;
    final grayL = await _toGrayscale(imgL, targetW, targetH);
    final grayR = await _toGrayscale(imgR, targetW, targetH);

    // SSIM → 差分正規化 → 二値化 → 連結成分 → NMS（モックCNNでスコア）
    final ssim = computeSsimMapUint8(grayL, grayR, targetW, targetH, windowRadius: 0);
    final diff = ssim.map((v) => 1.0 - v).toList();
    final diffN = normalizeToUnit(diff);

    final detector = widget.detector ?? FfiCnnDetector();
    await detector.load(Uint8List(0)); // モデル無しでもロード済み扱い
    final detections = detector.detectFromDiffMap(
      diffN,
      targetW,
      targetH,
      settings: widget.settings ?? Settings.initial(),
      maxOutputs: 20,
      iouThreshold: 0.3,
    );
    return detections.map((d) => d.box).toList();
  }

  Uint8List? _getBytesOrNull(SelectedImage img) => img.bytes;

  Future<ui.Image?> _decodeAndScaleTo(Uint8List? bytes, String? path) async {
    try {
      Uint8List? data = bytes;
      if (data == null && path != null) {
        data = await File(path).readAsBytes();
      }
      if (data == null) return null;
      final codec = await ui.instantiateImageCodec(data);
      final fi = await codec.getNextFrame();
      return fi.image;
    } catch (_) {
      return null;
    }
  }

  Future<List<int>> _toGrayscale(ui.Image image, int outW, int outH) async {
    // draw scaled to outW x outH then read pixels
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final srcSize = Size(image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());
    final paint = Paint();
    canvas.drawImageRect(image, Offset.zero & srcSize, dstRect, paint);
    final picture = recorder.endRecording();
    final scaled = await picture.toImage(outW, outH);
    final byteData = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = byteData!.buffer.asUint8List();
    final gray = List<int>.filled(outW * outH, 0);
    for (var i = 0, p = 0; i < gray.length; i++, p += 4) {
      final r = rgba[p];
      final g = rgba[p + 1];
      final b = rgba[p + 2];
      // simple luma
      final y = (0.299 * r + 0.587 * g + 0.114 * b).round();
      gray[i] = y.clamp(0, 255);
    }
    return gray;
  }

  void _reset() {
    setState(() {
      _leftRect = null;
      _rightRect = null;
    });
    if (widget.enableSound) {
      Sfx.instance.play('reset');
    }
    final messenger = ScaffoldMessenger.of(context);
    // 直前に表示していたメッセージを確実に消してから、フレーム後に新しいSnackBarを出す。
    messenger.clearSnackBars();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('最初からやりなおします')),
      );
    });
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
      setState(() {
        _leftRect = result;
        _showCroppedPreviews = false; // まだ右へ適用していない段階
      });
    } else if (result is (IntRect, bool)) {
      final (rect, applyRight) = result;
      setState(() => _leftRect = rect);
      if (applyRight == true) {
        _applySameRectToRight();
        setState(() {
          _showCroppedPreviews = true; // 左も右もプレビューを切り出し表示
        });
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
                if (rect != null)
                  _buildCroppedPreview(
                    isLeft: isLeft,
                    bytes: bytes,
                    path: path,
                    dims: dims,
                    rect: rect,
                  )
                else ...[
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
                ],
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
          if (rect == null)
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

  Widget _buildCroppedPreview({
    required bool isLeft,
    Uint8List? bytes,
    String? path,
    required Dimensions dims,
    required IntRect rect,
  }) {
    // 画像が無い場合はそのままプレースホルダを返す
    if (bytes == null && path == null) {
      return const Icon(Icons.image, size: 64, color: Colors.grey);
    }

    // 実画像ピクセル空間での厳密クロップを使う。
    // 端末・デコーダ差によるアラインメントの差異を排除するため drawImageRect を採用。
    return CroppedImage(
      bytes: bytes,
      path: path,
      originalWidth: isLeft ? widget.left.width : widget.right.width,
      originalHeight: isLeft ? widget.left.height : widget.right.height,
      normalizedWidth: dims.width,
      normalizedHeight: dims.height,
      rect: rect,
      viewportKey: Key(isLeft ? 'cropped-left-viewport' : 'cropped-right-viewport'),
      imageKey: Key(isLeft ? 'cropped-left' : 'cropped-right'),
    );
  }
}
