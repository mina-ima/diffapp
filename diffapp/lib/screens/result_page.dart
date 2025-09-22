import 'dart:io';
import 'package:flutter/material.dart';
import 'package:diffapp/image_pipeline.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:diffapp/widgets/cropped_image.dart';

class ResultPage extends StatelessWidget {
  final bool noDifferences;
  // 検出矩形（64x64座標系）
  final List<IntRect> detections;
  // 表示用の正規化寸法（ComparePageと同じ基準）
  final Dimensions leftNorm;
  // 元画像（表示のために受け取る）
  final SelectedImage left;
  final SelectedImage right;
  // 範囲指定（左の正規化空間）。null の場合は全体表示。
  final IntRect? selectedLeftRect;

  const ResultPage({
    super.key,
    required this.noDifferences,
    required this.detections,
    required this.leftNorm,
    required this.left,
    required this.right,
    this.selectedLeftRect,
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
              Builder(builder: (context) {
                // 表示中件数（クロップ内）を算出
                const srcW = 64;
                const srcH = 64;
                final toNormX = leftNorm.width / srcW;
                final toNormY = leftNorm.height / srcH;
                final viewport = selectedLeftRect ??
                    IntRect(left: 0, top: 0, width: leftNorm.width, height: leftNorm.height);
                bool intersects(IntRect a, IntRect b) {
                  final ax2 = a.left + a.width;
                  final ay2 = a.top + a.height;
                  final bx2 = b.left + b.width;
                  final by2 = b.top + b.height;
                  return !(ax2 <= b.left || bx2 <= a.left || ay2 <= b.top || by2 <= a.top);
                }
                int visible = 0;
                for (final d in detections) {
                  final n = IntRect(
                    left: (d.left * toNormX).round(),
                    top: (d.top * toNormY).round(),
                    width: (d.width * toNormX).round(),
                    height: (d.height * toNormY).round(),
                  );
                  if (intersects(n, viewport)) visible++;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('検出数: ${detections.length}（表示中: $visible）'),
                );
              }),
            // 左画像のみ表示（けんさせってい画面と同じ基準のプレビュー）
            Expanded(
              child: _DetectionOverlay(
                tag: 'left',
                image: left,
                norm: leftNorm,
                detections: detections,
                crop: selectedLeftRect,
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
  // 正規化空間でのクロップ矩形（けんさせっていで選択）。null なら全体表示。
  final IntRect? crop;

  const _DetectionOverlay({
    required this.tag,
    required this.image,
    required this.norm,
    required this.detections,
    this.preferredViewportHeight = 160.0,
    this.crop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 表示対象（全体 or クロップ）に合わせてスケールを決定
        final targetRect = crop ?? IntRect(left: 0, top: 0, width: norm.width, height: norm.height);
        double s = preferredViewportHeight / targetRect.height;
        double viewW = targetRect.width * s;
        double viewH = targetRect.height * s;
        if (viewW > constraints.maxWidth) {
          s = constraints.maxWidth / targetRect.width;
          viewW = targetRect.width * s;
          viewH = targetRect.height * s;
        }

        // 64x64 → 正規化寸法 → 表示スケール s（さらにクロップ原点を原点に）
        const srcW = 64;
        const srcH = 64;
        final toNormX = norm.width / srcW;
        final toNormY = norm.height / srcH;
        final cropLeft = targetRect.left;
        final cropTop = targetRect.top;

        return Center(
          child: SizedBox(
            width: viewW,
            height: viewH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 画像（bytes優先）。結果ページでも Compare と同じ描画方式を用いて確実に表示する
                if (image.bytes == null && image.path == null)
                  // プレビュー欠如時のフォールバック（Nodeテストがこの文言とレイアウトを検証）
                  Container(
                    alignment: Alignment.center,
                    child: const Text('プレビューなし'),
                  )
                else
                  CroppedImage(
                    bytes: image.bytes,
                    path: image.path,
                    originalWidth: image.width,
                    originalHeight: image.height,
                    normalizedWidth: norm.width,
                    normalizedHeight: norm.height,
                    rect: targetRect,
                    // この高さを渡すことで内部のスケールと本Widgetのスケールを一致させる
                    preferredViewportHeight: viewH,
                    viewportKey: const Key('result-image-viewport'),
                    imageKey: const Key('result-image'),
                  ),

                // 検出矩形オーバーレイ
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      for (var i = 0; i < detections.length; i++)
                        Positioned(
                          key: Key('det-$tag-$i'),
                          left: (detections[i].left * toNormX - cropLeft) * s,
                          top: (detections[i].top * toNormY - cropTop) * s,
                          width: (detections[i].width * toNormX) * s,
                          height: (detections[i].height * toNormY) * s,
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
              ],
            ),
          ),
        );
      },
    );
  }
}
