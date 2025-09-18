import 'dart:io';
import 'package:flutter/material.dart';
import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/screens/image_select_page.dart';

class ResultPage extends StatelessWidget {
  final bool noDifferences;
  // 検出矩形（64x64座標系）
  final List<IntRect> detections;
  // 表示用の正規化寸法（ComparePageと同じ基準）
  final Dimensions leftNorm;
  final Dimensions rightNorm;
  // 元画像（表示のために受け取る）
  final SelectedImage left;
  final SelectedImage right;

  const ResultPage({
    super.key,
    required this.noDifferences,
    required this.detections,
    required this.leftNorm,
    required this.rightNorm,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('検査結果')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (noDifferences)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('ちがいは みつかりませんでした'),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('検出数: ${detections.length}'),
              ),
            // 左右の結果オーバーレイ
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _DetectionOverlay(
                      tag: 'left',
                      image: left,
                      norm: leftNorm,
                      detections: detections,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DetectionOverlay(
                      tag: 'right',
                      image: right,
                      norm: rightNorm,
                      detections: detections,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'スクショをとろう！',
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: const Key('retry-compare'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('再比較'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectionOverlay extends StatelessWidget {
  final String tag; // 'left' / 'right'
  final SelectedImage image;
  final Dimensions norm;
  final List<IntRect> detections; // 64x64 座標
  final double preferredViewportHeight;

  const _DetectionOverlay({
    required this.tag,
    required this.image,
    required this.norm,
    required this.detections,
    this.preferredViewportHeight = 160.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 高さ優先で表示スケールを決定（幅オーバー時は幅に合わせて再スケール）
        double s = preferredViewportHeight / norm.height;
        double viewW = norm.width * s;
        double viewH = norm.height * s;
        if (viewW > constraints.maxWidth) {
          s = constraints.maxWidth / norm.width;
          viewW = norm.width * s;
          viewH = norm.height * s;
        }

        Widget imageChild;
        if (image.bytes != null) {
          imageChild = Image.memory(image.bytes!, fit: BoxFit.fill);
        } else if (image.path != null) {
          imageChild = Image.file(File(image.path!), fit: BoxFit.fill);
        } else {
          imageChild = const Icon(Icons.image, size: 64, color: Colors.grey);
        }

        // 64x64 → 正規化寸法 → 表示スケールs
        const srcW = 64;
        const srcH = 64;
        final scaleX = (norm.width / srcW) * s;
        final scaleY = (norm.height / srcH) * s;

        return Center(
          child: SizedBox(
            width: viewW,
            height: viewH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Transform.scale(
                    alignment: Alignment.topLeft,
                    scale: s,
                    child: SizedBox(
                      width: norm.width.toDouble(),
                      height: norm.height.toDouble(),
                      child: FittedBox(
                        fit: BoxFit.fill,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: norm.width.toDouble(),
                          height: norm.height.toDouble(),
                          child: imageChild,
                        ),
                      ),
                    ),
                  ),
                ),
                // 矩形オーバーレイ
                for (var i = 0; i < detections.length; i++)
                  Positioned(
                    key: Key('det-$tag-$i'),
                    left: detections[i].left * scaleX,
                    top: detections[i].top * scaleY,
                    width: detections[i].width * scaleX,
                    height: detections[i].height * scaleY,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.redAccent, width: 2),
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
