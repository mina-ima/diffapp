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
import 'dart:math' as math;
import 'package:diffapp/widgets/cropped_image.dart';
import 'package:diffapp/cnn_detection.dart';
import 'package:diffapp/features.dart';

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
  late Settings _settings; // 画面内で現在の検査設定を保持

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
    // 検査結果ページへ遷移（検出矩形と表示寸法・元画像を渡す）
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute(
            builder: (_) => ResultPage(
              noDifferences: results.isEmpty,
              detections: results,
              leftNorm: _leftNorm,
              left: widget.left,
              right: widget.right,
              selectedLeftRect: _leftRect,
            ),
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
    // 同一サイズに揃える（64x64固定）。選択範囲があればその矩形のみを切り出して解析。
    const targetW = 128;
    const targetH = 128;

    Rect? leftCropSrc;
    Rect? rightCropSrc;
    double leftOffsetX = 0;
    double leftOffsetY = 0;
    if (_leftRect != null) {
      // 左: 正規化空間(_leftNorm)での矩形を実画像ピクセル空間へ変換
      final sxL = imgL.width / _leftNorm.width;
      final syL = imgL.height / _leftNorm.height;
      leftCropSrc = Rect.fromLTWH(
        _leftRect!.left * sxL,
        _leftRect!.top * syL,
        _leftRect!.width * sxL,
        _leftRect!.height * syL,
      );

      // 右: 右の正規化空間へマッピング（_rightRect が未設定なら変換して得る）
      final mappedRight = _rightRect ?? scaleRectBetweenSpaces(
        _leftRect!,
        _leftNorm.width,
        _leftNorm.height,
        _rightNorm.width,
        _rightNorm.height,
      );
      final sxR = imgR.width / _rightNorm.width;
      final syR = imgR.height / _rightNorm.height;
      rightCropSrc = Rect.fromLTWH(
        mappedRight.left * sxR,
        mappedRight.top * syR,
        mappedRight.width * sxR,
        mappedRight.height * syR,
      );

      // 検出ボックスは targetW x targetH のフル空間に対する座標で返すため、
      // クロップ領域の原点オフセット（target系）を加算して戻す。
      leftOffsetX = _leftRect!.left * (targetW / _leftNorm.width);
      leftOffsetY = _leftRect!.top * (targetH / _leftNorm.height);
    }

    final rgbaL = await _toRgba(imgL, targetW, targetH, srcRect: leftCropSrc);
    final rgbaR0 = await _toRgba(imgR, targetW, targetH, srcRect: rightCropSrc);
    var rgbaR = rgbaR0;
    // グレースケールもクロップ矩形を正しく適用した上で計算する
    var grayL = await _toGrayscale(imgL, targetW, targetH, srcRect: leftCropSrc);
    var grayR = await _toGrayscale(imgR, targetW, targetH, srcRect: rightCropSrc);

    // 画像の微小ズレを補正: Harris+BRIEFで対応点→ホモグラフィ推定→右画像を左にワーピング
    try {
      final kL = detectHarrisKeypointsU8(grayL, targetW, targetH,
          responseThreshold: 1e6, maxFeatures: 400);
      final kR = detectHarrisKeypointsU8(grayR, targetW, targetH,
          responseThreshold: 1e6, maxFeatures: 400);
      if (kL.length >= 8 && kR.length >= 8) {
        final dL = computeBriefDescriptors(grayL, targetW, targetH, kL);
        final dR = computeBriefDescriptors(grayR, targetW, targetH, kR);
        final m = matchDescriptorsHamming(dL, dR);
        if (m.length >= 20) {
          final src = <Point2>[];
          final dst = <Point2>[];
          for (var i = 0; i < m.length && i < 200; i++) {
            final (qi, tj, _) = m[i];
            src.add(Point2(kL[qi].x.toDouble(), kL[qi].y.toDouble()));
            dst.add(Point2(kR[tj].x.toDouble(), kR[tj].y.toDouble()));
          }
          final hr = estimateHomographyRansac(src, dst,
              iterations: 300, inlierThreshold: 2.0, minInliers: 20);
          final warped = warpRgbaByHomography(rgbaR0, targetW, targetH, hr.homography, targetW, targetH);
          rgbaR = warped;
          grayR = _rgbaToGray(warped);
        }
      }
    } catch (_) {
      // アライン失敗時はフォールバック（無視）
    }

    // SSIM の前に軽いボックスブラーを適用し、1pxレベルのエッジずれを抑制
    final blurL = boxBlurU8(grayL, targetW, targetH, radius: 1);
    final blurR = boxBlurU8(grayR, targetW, targetH, radius: 1);
    // SSIM差分 + 色差分 + 勾配差分 を統合
    final ssim = computeSsimMapUint8(blurL, blurR, targetW, targetH, windowRadius: 0);
    final diffSsim = ssim.map((v) => 1.0 - v).toList();
    final diffColor = colorDiffMapRgba(rgbaL, rgbaR, targetW, targetH);
    // 勾配マップの差分（向きや輪郭の違いを強調）
    final gradL = sobelGradMagU8(grayL, targetW, targetH);
    final gradR = sobelGradMagU8(grayR, targetW, targetH);
    final diffGrad = List<double>.generate(diffSsim.length, (i) => (gradL[i] - gradR[i]).abs());
    final diffGradN = normalizeToUnit(diffGrad);
    // 構造(SSIM)と色の両方が高い場所を持ち上げる（幾何平均）+ 妥当な線形ブレンド
    final geom = List<double>.generate(diffSsim.length, (i) => math.sqrt(diffSsim[i] * diffColor[i]));
    final diffCombined = List<double>.generate(diffSsim.length, (i) {
      final s = diffSsim[i] * 0.7 + diffGradN[i] * 0.3;
      final c = diffColor[i] * 0.9; // 色の寄与をやや強めに
      final g = geom[i] * 1.1;      // 両方高いピクセルを強調
      final m1 = s > c ? s : c;
      return m1 > g ? m1 : g;
    });
    final diffN = normalizeToUnit(diffCombined);

    final detector = widget.detector ?? FfiCnnDetector();
    await detector.load(Uint8List(0)); // モデル無しでもロード済み扱い
    final detections = detector.detectFromDiffMap(
      diffN,
      targetW,
      targetH,
      // 直近で保存された設定を使用
      settings: _settings,
      maxOutputs: 20,
      iouThreshold: 0.3,
    );
    // クロップを適用した場合は、ボックスの原点をフル画像の 64x64 座標へ戻す
    final boxes = detections.map((d) => d.box).toList();
    if (_leftRect != null) {
      return boxes
          .map((d) => IntRect(
                left: (d.left + leftOffsetX).round(),
                top: (d.top + leftOffsetY).round(),
                width: d.width,
                height: d.height,
              ))
          .toList();
    }
    return boxes;
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

  Future<List<int>> _toGrayscale(ui.Image image, int outW, int outH, {Rect? srcRect}) async {
    // draw scaled to outW x outH then read pixels
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final srcSize = Size(image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());
    final paint = Paint();
    final src = srcRect ?? (Offset.zero & srcSize);
    canvas.drawImageRect(image, src, dstRect, paint);
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

  Future<Uint8List> _toRgba(ui.Image image, int outW, int outH, {Rect? srcRect}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final srcSize = Size(image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());
    final paint = Paint();
    final src = srcRect ?? (Offset.zero & srcSize);
    canvas.drawImageRect(image, src, dstRect, paint);
    final picture = recorder.endRecording();
    final scaled = await picture.toImage(outW, outH);
    final byteData = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  List<int> _rgbaToGray(Uint8List rgba) {
    final out = List<int>.filled(rgba.length ~/ 4, 0);
    for (var i = 0, p = 0; i < out.length; i++, p += 4) {
      final r = rgba[p];
      final g = rgba[p + 1];
      final b = rgba[p + 2];
      out[i] = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
    }
    return out;
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
    // ログ: 左→右に矩形を適用したイベント
    debugPrint('[Diffapp][rect] left=${_leftRect} -> right=${_rightRect} (L$_leftNorm R$_rightNorm)');
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
                      // 設定ページへ遷移し、レ点で戻った値を即時反映
                      final result = await Navigator.of(context).push<Settings>(
                        MaterialPageRoute(
                          builder: (_) => SettingsPage(initial: _settings),
                        ),
                      );
                      if (!mounted) return;
                      if (result != null) {
                        setState(() => _settings = result);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('設定を保存しました')),
                        );
                      }
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
    // ログ: 入力寸法と表示正規化寸法
    debugPrint('[Diffapp][init] leftInput=${widget.left.width}x${widget.left.height} rightInput=${widget.right.width}x${widget.right.height}');
    debugPrint('[Diffapp][init] leftNorm=${_leftNorm.width}x${_leftNorm.height} rightNorm=${_rightNorm.width}x${_rightNorm.height}');
    // 初期矩形（テストや再入場時向けのフック）
    _leftRect = widget.initialLeftRect ?? _leftRect;
    _rightRect = widget.initialRightRect ?? _rightRect;
    // 設定初期値（ホームから渡されたものがあればそれを使用）
    _settings = widget.settings ?? Settings.initial();
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
