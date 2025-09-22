import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:diffapp/image_pipeline.dart';

/// 厳密な切り出しプレビュー。
/// - 入力 `rect` は [normalizedWidth] x [normalizedHeight] 空間での座標。
/// - 実画像のピクセル空間へスケールしてから `Canvas.drawImageRect` で描画する。
class CroppedImage extends StatelessWidget {
  final Uint8List? bytes;
  final String? path;
  final int originalWidth;
  final int originalHeight;
  final int normalizedWidth;
  final int normalizedHeight;
  final IntRect rect;
  final double preferredViewportHeight;
  final Key? viewportKey;
  final Key? imageKey;

  const CroppedImage({
    super.key,
    required this.bytes,
    required this.path,
    required this.originalWidth,
    required this.originalHeight,
    required this.normalizedWidth,
    required this.normalizedHeight,
    required this.rect,
    this.preferredViewportHeight = 160.0,
    this.viewportKey,
    this.imageKey,
  });

  Future<ui.Image> _decode() async {
    final data = bytes ?? await File(path!).readAsBytes();
    // 大きな画像をフル解像度でデコードすると端末によってはメモリ不足で
    // 表示できないことがあるため、表示基準（normalizedWidth）に合わせて
    // デコード段階でダウンサンプルする。
    // 高さは省略してアスペクト比を維持する。
    final codec = await ui.instantiateImageCodec(
      data,
      targetWidth: normalizedWidth,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  Widget build(BuildContext context) {
    if (bytes == null && path == null) {
      return const Icon(Icons.image, size: 64, color: Colors.grey);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // 表示用スケール（高さ優先、幅オーバーは再調整）
        double s = preferredViewportHeight / rect.height;
        double viewportW = rect.width * s;
        double viewportH = rect.height * s;
        if (viewportW > constraints.maxWidth) {
          s = constraints.maxWidth / rect.width;
          viewportW = rect.width * s;
          viewportH = rect.height * s;
        }

        // 画面上は Transform.translate で -rect*scale を適用し、
        // 子は「正規化画像を s 倍」にスケーリングして全面描画する。
        // これによりテストで Transform の tx/ty を検証可能。
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            key: viewportKey,
            width: viewportW,
            height: viewportH,
            child: Transform(
              // 期待: tx = -rect.left * s, ty = -rect.top * s
              transform: Matrix4.identity()
                ..translate(-rect.left * s, -rect.top * s),
              child: RepaintBoundary(
                key: imageKey,
                child: FutureBuilder<ui.Image>(
                  future: _decode(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      // 構造は維持（Transform/Boundary は生成済み）
                      return const SizedBox.shrink();
                    }
                    final image = snapshot.data!;
                    return CustomPaint(
                      // 正規化画像全体を s 倍で描画（src=全体、dst=normalized*s）
                      painter: _ScaledImagePainter(
                        image: image,
                        dstWidth: normalizedWidth * s,
                        dstHeight: normalizedHeight * s,
                      ),
                      size: Size(normalizedWidth * s, normalizedHeight * s),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScaledImagePainter extends CustomPainter {
  final ui.Image image;
  final double dstWidth;
  final double dstHeight;

  _ScaledImagePainter({
    required this.image,
    required this.dstWidth,
    required this.dstHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, dstWidth, dstHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScaledImagePainter old) {
    return old.image != image || old.dstWidth != dstWidth || old.dstHeight != dstHeight;
  }
}
