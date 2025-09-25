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
  static const int _alignmentPasses = 2;
  static const int _analysisSize = 256;
  static const int _alignmentSize = 384; // 高精度アライン用ワークサイズ
  IntRect? _leftRect;
  IntRect? _rightRect;
  late final Dimensions _leftNorm;
  late final Dimensions _rightNorm;
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late Settings _settings; // 画面内で現在の検査設定を保持
  Future<void>? _leftPreparation;
  Uint8List? _leftAlignmentRgba;
  List<int>? _leftAlignmentGray;
  List<Keypoint>? _leftKeypoints;
  List<List<int>>? _leftDescriptors;

  Future<void> _startDetection(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    // 効果音
    if (widget.enableSound) {
      Sfx.instance.play('start');
    }
    // モデル読込失敗をシミュレート（テスト用）
    if (widget.simulateModelLoadFailure) {
      messenger.showSnackBar(
        const SnackBar(content: Text('けんさに しっぱいしました。もういちどためしてね')),
      );
      return;
    }

    // タイムアウトをシミュレート（テスト用）
    if (widget.simulateTimeout) {
      messenger.showSnackBar(
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
        messenger.showSnackBar(
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
    if (!mounted) {
      return;
    }
    // 結果メッセージ
    if (results.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ちがいは みつかりませんでした')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('検出数: ${results.length}')),
      );
    }
    // 検査結果ページへ遷移（検出矩形と表示寸法・元画像を渡す）
    if (!mounted) {
      return;
    }

    navigator
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
    final overrideDetector = widget.detector;
    if (overrideDetector != null) {
      // テスト差し替え用の検出器では高負荷な前処理を行わず、設定伝搬のみ確認する。
      if (!overrideDetector.isLoaded) {
        await overrideDetector.load(Uint8List(0));
      }
      overrideDetector.detectFromDiffMap(
        const <double>[0.0],
        1,
        1,
        settings: _settings,
        maxOutputs: 1,
        iouThreshold: 0.3,
      );
      return const <IntRect>[];
    }

    await (_leftPreparation ??= _prepareLeftAlignment());

    final rgbaLeftWork = _leftAlignmentRgba;
    final grayLeftWork = _leftAlignmentGray;
    final leftKeypoints = _leftKeypoints;
    final leftDescriptors = _leftDescriptors;
    if (rgbaLeftWork == null ||
        grayLeftWork == null ||
        leftKeypoints == null ||
        leftDescriptors == null ||
        leftKeypoints.isEmpty) {
      return <IntRect>[];
    }

    final imgR = await _decodeAndScaleTo(_getBytesOrNull(widget.right), widget.right.path);
    if (imgR == null) {
      return <IntRect>[];
    }

    final rgbaRightWork = await _toRgba(
      imgR,
      _alignmentSize,
      _alignmentSize,
      quality: ui.FilterQuality.high,
    );
    final grayRightWork = _rgbaToGray(rgbaRightWork);
    var workingRightRgba = rgbaRightWork;
    var workingRightGray = grayRightWork;

    // 画像の微小ズレを多段で補正: Harris+BRIEFで対応点→ホモグラフィ/相似変換推定
    try {
      final grayRightOriginal = List<int>.from(grayRightWork);
      final rgbaRightOriginal = Uint8List.fromList(rgbaRightWork);
      Homography? alignmentHomography;
      Uint8List alignedRgba = rgbaRightWork;
      List<int> alignedGray = grayRightWork;

      for (var pass = 0; pass < _alignmentPasses; pass++) {
        final kLPass = leftKeypoints;
        final kRPass = detectHarrisKeypointsU8(alignedGray, _alignmentSize, _alignmentSize,
            responseThreshold: 2e5, maxFeatures: 800);
        if (kLPass.length < 8 || kRPass.length < 8) {
          break;
        }
        final dLPass = leftDescriptors;
        final dRPass = computeBriefDescriptors(alignedGray, _alignmentSize, _alignmentSize, kRPass);
        final matches = matchDescriptorsHammingRatioCross(
          dLPass,
          dRPass,
          ratio: 0.76,
          crossCheck: true,
          maxMatches: 900,
        );
        if (matches.isEmpty) {
          break;
        }

        final src = <Point2>[];
        final dst = <Point2>[];
        for (var i = 0; i < matches.length && i < 300; i++) {
          final (qi, tj, _) = matches[i];
          src.add(Point2(kLPass[qi].x.toDouble(), kLPass[qi].y.toDouble()));
          dst.add(Point2(kRPass[tj].x.toDouble(), kRPass[tj].y.toDouble()));
        }

        Homography? stepHomography;
        if (matches.length >= 16) {
          try {
            stepHomography = estimateHomographyRansac(
              src,
              dst,
              iterations: 600,
              inlierThreshold: 1.1,
              minInliers: 20,
            ).homography;
          } catch (_) {
            stepHomography = null;
          }
        }
        if (stepHomography == null && matches.length >= 8) {
          stepHomography = _estimateSimilarityHomography(src, dst);
        }
        if (stepHomography == null) {
          break;
        }

        alignmentHomography = alignmentHomography == null
            ? stepHomography
            : composeHomography(alignmentHomography, stepHomography);

        final warped = warpRgbaByHomography(
          rgbaRightOriginal,
          _alignmentSize,
          _alignmentSize,
          alignmentHomography,
          _alignmentSize,
          _alignmentSize,
        );
        alignedRgba = warped;
        alignedGray = _rgbaToGray(warped);
      }

      if (alignmentHomography != null) {
        workingRightRgba = alignedRgba;
        workingRightGray = alignedGray;
      } else {
        workingRightGray = grayRightOriginal;
      }
    } catch (_) {
      // アライン失敗時はフォールバック（無視）
    }

    final alignmentRect = _leftRect != null
        ? _alignmentRectFromSelection(_leftRect!)
        : const IntRect(left: 0, top: 0, width: _alignmentSize, height: _alignmentSize);

    final rgbaLeftRegion = _extractRgbaRegion(
      rgbaLeftWork,
      _alignmentSize,
      _alignmentSize,
      alignmentRect,
    );
    final rgbaRightRegion = _extractRgbaRegion(
      workingRightRgba,
      _alignmentSize,
      _alignmentSize,
      alignmentRect,
    );
    final grayLeftRegion = _extractGrayRegion(
      grayLeftWork,
      _alignmentSize,
      _alignmentSize,
      alignmentRect,
    );
    final grayRightRegion = _extractGrayRegion(
      workingRightGray,
      _alignmentSize,
      _alignmentSize,
      alignmentRect,
    );

    final regionW = alignmentRect.width;
    final regionH = alignmentRect.height;

    final rgbaL = _resizeRgbaBilinear(
      rgbaLeftRegion,
      regionW,
      regionH,
      _analysisSize,
      _analysisSize,
    );
    final rgbaR = _resizeRgbaBilinear(
      rgbaRightRegion,
      regionW,
      regionH,
      _analysisSize,
      _analysisSize,
    );
    var grayL = _resizeGrayBilinear(
      grayLeftRegion,
      regionW,
      regionH,
      _analysisSize,
      _analysisSize,
    );
    var grayR = _resizeGrayBilinear(
      grayRightRegion,
      regionW,
      regionH,
      _analysisSize,
      _analysisSize,
    );

    // SSIM の前に軽いボックスブラーを適用し、1pxレベルのエッジずれを抑制
    final blurL = boxBlurU8(grayL, _analysisSize, _analysisSize, radius: 1);
    final blurR = boxBlurU8(grayR, _analysisSize, _analysisSize, radius: 1);
    // SSIM差分 + 色差分 + 勾配差分 を統合
    final ssim = computeSsimMapUint8(blurL, blurR, _analysisSize, _analysisSize, windowRadius: 0);
    final diffSsim = ssim.map((v) => 1.0 - v).toList();
    // 明度差に頑健な色差（クロマ重視）で差分を算出
    final diffColor = colorDiffMapRgbaRobust(rgbaL, rgbaR, _analysisSize, _analysisSize);
    // 勾配マップの差分（向きや輪郭の違いを強調）
    final gradL = sobelGradMagU8(grayL, _analysisSize, _analysisSize);
    final gradR = sobelGradMagU8(grayR, _analysisSize, _analysisSize);
    final diffGrad = List<double>.generate(diffSsim.length, (i) => (gradL[i] - gradR[i]).abs());
    final diffGradN = normalizeToUnit(diffGrad);
    // 構造(SSIM)と色の両方が高い場所を持ち上げる（幾何平均）+ 妥当な線形ブレンド
    final geom = List<double>.generate(diffSsim.length, (i) => math.sqrt(diffSsim[i] * diffColor[i]));
    final diffCombined = List<double>.generate(diffSsim.length, (i) {
      final s = diffSsim[i] * 0.6 + diffGradN[i] * 0.4; // エッジ差分の比重をやや上げる
      final c = diffColor[i] * 1.35; // 色差の寄与を強化（明度補正込み）
      final g = geom[i] * 1.1;       // 両方高いピクセルを強調
      final m1 = s > c ? s : c;
      return m1 > g ? m1 : g;
    });
    // 画像間で共通して強いエッジ（min(gradL,gradR)）は誤検出の温床になりやすいので抑制
    final edgeCommon = List<double>.generate(diffCombined.length, (i) {
      final a = gradL[i];
      final b = gradR[i];
      return a < b ? a : b;
    });
    final edgeSuppression = List<double>.generate(edgeCommon.length, (i) => 1.0 - edgeCommon[i]);
    final diffFinal = List<double>.generate(diffCombined.length, (i) {
      final mask = 0.75 + 0.25 * edgeSuppression[i]; // 共通エッジでは~0.75倍にとどめる
      return diffCombined[i] * mask;
    });
    final diffN = normalizeToUnit(diffFinal);

    final detector = FfiCnnDetector();
    await detector.load(Uint8List(0)); // モデル無しでもロード済み扱い
    final detections = detector.detectFromDiffMap(
      diffN,
      _analysisSize,
      _analysisSize,
      // 直近で保存された設定を使用
      settings: _settings,
      maxOutputs: 20,
      iouThreshold: 0.3,
    );
    // クロップを適用した場合は、ボックスの原点をフル画像の 256x256 座標へ戻す
    final boxes = detections.map((d) => d.box).toList();
    if (_leftRect != null) {
      final double analysisScaleX = _analysisSize / _leftNorm.width;
      final double analysisScaleY = _analysisSize / _leftNorm.height;
      final double regionAnalysisLeft = _leftRect!.left * analysisScaleX;
      final double regionAnalysisTop = _leftRect!.top * analysisScaleY;
      final double regionAnalysisWidth = _leftRect!.width * analysisScaleX;
      final double regionAnalysisHeight = _leftRect!.height * analysisScaleY;
      final double regionFactorX = regionAnalysisWidth / _analysisSize;
      final double regionFactorY = regionAnalysisHeight / _analysisSize;

      return boxes.map((d) {
        final double leftAnalysis = regionAnalysisLeft + d.left * regionFactorX;
        final double topAnalysis = regionAnalysisTop + d.top * regionFactorY;
        final double rightAnalysis = leftAnalysis + d.width * regionFactorX;
        final double bottomAnalysis = topAnalysis + d.height * regionFactorY;

        final int left = leftAnalysis.floor().clamp(0, _analysisSize - 1);
        final int top = topAnalysis.floor().clamp(0, _analysisSize - 1);
        final int right = math.min(
          _analysisSize,
          math.max(left + 1, rightAnalysis.ceil()),
        );
        final int bottom = math.min(
          _analysisSize,
          math.max(top + 1, bottomAnalysis.ceil()),
        );

        final int width = math.max(1, right - left);
        final int height = math.max(1, bottom - top);

        return IntRect(
          left: left,
          top: top,
          width: width,
          height: height,
        );
      }).toList();
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

  Future<void> _prepareLeftAlignment() async {
    _leftAlignmentRgba = null;
    _leftAlignmentGray = null;
    _leftKeypoints = null;
    _leftDescriptors = null;

    final image = await _decodeAndScaleTo(_getBytesOrNull(widget.left), widget.left.path);
    if (!mounted) return;
    if (image == null) {
      return;
    }

    final rgba = await _toRgba(
      image,
      _alignmentSize,
      _alignmentSize,
      quality: ui.FilterQuality.high,
    );
    final gray = _rgbaToGray(rgba);
    final keypoints = detectHarrisKeypointsU8(
      gray,
      _alignmentSize,
      _alignmentSize,
      responseThreshold: 2e5,
      maxFeatures: 800,
    );
    final descriptors = computeBriefDescriptors(
      gray,
      _alignmentSize,
      _alignmentSize,
      keypoints,
    );

    if (!mounted) return;
    _leftAlignmentRgba = rgba;
    _leftAlignmentGray = gray;
    _leftKeypoints = keypoints;
    _leftDescriptors = descriptors;
  }

  Future<Uint8List> _toRgba(
    ui.Image image,
    int outW,
    int outH, {
    Rect? srcRect,
    ui.FilterQuality quality = ui.FilterQuality.low,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final srcSize = Size(image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());
    final paint = Paint()..filterQuality = quality;
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

  List<int> _resizeGrayBilinear(
    List<int> src,
    int srcW,
    int srcH,
    int dstW,
    int dstH,
  ) {
    if (srcW == dstW && srcH == dstH) {
      return List<int>.from(src);
    }
    final dst = List<int>.filled(dstW * dstH, 0);
    if (dstW == 0 || dstH == 0) return dst;
    final scaleX = srcW / dstW;
    final scaleY = srcH / dstH;
    for (var y = 0; y < dstH; y++) {
      final srcY = ((y + 0.5) * scaleY) - 0.5;
      final srcYClamped = math.max(0.0, math.min(srcY, (srcH - 1).toDouble()));
      final y0 = srcYClamped.floor();
      final y1 = math.min(y0 + 1, srcH - 1);
      final fy = srcYClamped - y0;
      final oneMinusFy = 1.0 - fy;
      for (var x = 0; x < dstW; x++) {
        final srcX = ((x + 0.5) * scaleX) - 0.5;
        final srcXClamped = math.max(0.0, math.min(srcX, (srcW - 1).toDouble()));
        final x0 = srcXClamped.floor();
        final x1 = math.min(x0 + 1, srcW - 1);
        final fx = srcXClamped - x0;
        final oneMinusFx = 1.0 - fx;

        final idx00 = y0 * srcW + x0;
        final idx01 = y0 * srcW + x1;
        final idx10 = y1 * srcW + x0;
        final idx11 = y1 * srcW + x1;

        final w00 = oneMinusFx * oneMinusFy;
        final w01 = fx * oneMinusFy;
        final w10 = oneMinusFx * fy;
        final w11 = fx * fy;

        final value = src[idx00] * w00 +
            src[idx01] * w01 +
            src[idx10] * w10 +
            src[idx11] * w11;
        dst[y * dstW + x] = value.round().clamp(0, 255);
      }
    }
    return dst;
  }

  Uint8List _resizeRgbaBilinear(
    Uint8List src,
    int srcW,
    int srcH,
    int dstW,
    int dstH,
  ) {
    if (srcW == dstW && srcH == dstH) {
      return Uint8List.fromList(src);
    }
    final dst = Uint8List(dstW * dstH * 4);
    if (dstW == 0 || dstH == 0) return dst;
    final scaleX = srcW / dstW;
    final scaleY = srcH / dstH;
    for (var y = 0; y < dstH; y++) {
      final srcY = ((y + 0.5) * scaleY) - 0.5;
      final srcYClamped = math.max(0.0, math.min(srcY, (srcH - 1).toDouble()));
      final y0 = srcYClamped.floor();
      final y1 = math.min(y0 + 1, srcH - 1);
      final fy = srcYClamped - y0;
      final oneMinusFy = 1.0 - fy;
      for (var x = 0; x < dstW; x++) {
        final srcX = ((x + 0.5) * scaleX) - 0.5;
        final srcXClamped = math.max(0.0, math.min(srcX, (srcW - 1).toDouble()));
        final x0 = srcXClamped.floor();
        final x1 = math.min(x0 + 1, srcW - 1);
        final fx = srcXClamped - x0;
        final oneMinusFx = 1.0 - fx;

        final idx00 = (y0 * srcW + x0) * 4;
        final idx01 = (y0 * srcW + x1) * 4;
        final idx10 = (y1 * srcW + x0) * 4;
        final idx11 = (y1 * srcW + x1) * 4;

        final w00 = oneMinusFx * oneMinusFy;
        final w01 = fx * oneMinusFy;
        final w10 = oneMinusFx * fy;
        final w11 = fx * fy;

        final dstIndex = (y * dstW + x) * 4;
        for (var c = 0; c < 4; c++) {
          final value = src[idx00 + c] * w00 +
              src[idx01 + c] * w01 +
              src[idx10 + c] * w10 +
              src[idx11 + c] * w11;
          dst[dstIndex + c] = value.round().clamp(0, 255);
        }
      }
    }
    return dst;
  }

  IntRect _alignmentRectFromSelection(IntRect selected) {
    final scaleX = _alignmentSize / _leftNorm.width;
    final scaleY = _alignmentSize / _leftNorm.height;
    final left = math.max(0, math.min(_alignmentSize - 1, (selected.left * scaleX).floor()));
    final top = math.max(0, math.min(_alignmentSize - 1, (selected.top * scaleY).floor()));
    final rightRaw = ((selected.left + selected.width) * scaleX).ceil();
    final bottomRaw = ((selected.top + selected.height) * scaleY).ceil();
    final right = math.max(left + 1, math.min(_alignmentSize, rightRaw));
    final bottom = math.max(top + 1, math.min(_alignmentSize, bottomRaw));
    final width = math.max(1, right - left);
    final height = math.max(1, bottom - top);
    return IntRect(left: left, top: top, width: width, height: height);
  }

  List<int> _extractGrayRegion(
    List<int> src,
    int srcW,
    int srcH,
    IntRect region,
  ) {
    if (region.left == 0 && region.top == 0 &&
        region.width == srcW && region.height == srcH) {
      return List<int>.from(src);
    }
    final dst = List<int>.filled(region.width * region.height, 0);
    for (var y = 0; y < region.height; y++) {
      final srcRow = (region.top + y) * srcW;
      final dstRow = y * region.width;
      for (var x = 0; x < region.width; x++) {
        dst[dstRow + x] = src[srcRow + region.left + x];
      }
    }
    return dst;
  }

  Uint8List _extractRgbaRegion(
    Uint8List src,
    int srcW,
    int srcH,
    IntRect region,
  ) {
    if (region.left == 0 && region.top == 0 &&
        region.width == srcW && region.height == srcH) {
      return Uint8List.fromList(src);
    }
    final dst = Uint8List(region.width * region.height * 4);
    for (var y = 0; y < region.height; y++) {
      final srcRow = ((region.top + y) * srcW + region.left) * 4;
      final dstRow = y * region.width * 4;
      dst.setRange(dstRow, dstRow + region.width * 4, src, srcRow);
    }
    return dst;
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
      });
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
    // ログ: 左→右に矩形を適用したイベント
    debugPrint('[Diffapp][rect] left=$_leftRect -> right=$_rightRect (L$_leftNorm R$_rightNorm)');
  }

  Homography? _estimateSimilarityHomography(
    List<Point2> src,
    List<Point2> dst,
  ) {
    if (src.length < 2 || dst.length < 2) return null;
    final minPts = src.length >= 12 ? 12 : 8;
    try {
      final sim = estimateSimilarityTransformRansac(
        src,
        dst,
        iterations: 500,
        inlierThreshold: 1.1,
        minInliers: minPts,
      );
      if (sim.inliersCount < minPts) return null;
      final scale = sim.transform.scale;
      if (!scale.isFinite || scale < 0.85 || scale > 1.18) {
        return null;
      }
      return homographyFromSimilarity(sim.transform);
    } catch (_) {
      return null;
    }
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
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      // 設定ページへ遷移し、レ点で戻った値を即時反映
                      final result = await navigator.push<Settings>(
                        MaterialPageRoute(
                          builder: (_) => SettingsPage(initial: _settings),
                        ),
                      );
                      if (!mounted) return;
                      if (result != null) {
                        setState(() => _settings = result);
                        messenger.showSnackBar(
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
    _leftPreparation = _prepareLeftAlignment();
  }

  @override
  void didUpdateWidget(covariant ComparePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPath = oldWidget.left.path;
    final newPath = widget.left.path;
    final oldBytes = oldWidget.left.bytes;
    final newBytes = widget.left.bytes;
    if (oldPath != newPath || oldBytes != newBytes) {
      _leftPreparation = _prepareLeftAlignment();
    }
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
