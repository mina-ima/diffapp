import 'dart:io';
import 'dart:typed_data';
import 'package:diffapp/image_pipeline.dart';
import 'package:flutter/material.dart';

class RectSelectPage extends StatefulWidget {
  final String title;
  final int imageWidth;
  final int imageHeight;
  final IntRect? initialRect;
  final Uint8List? imageBytes;
  final String? imagePath;

  const RectSelectPage({
    super.key,
    required this.title,
    this.imageWidth = 1280,
    this.imageHeight = 960,
    this.initialRect,
    this.imageBytes,
    this.imagePath,
  });

  @override
  State<RectSelectPage> createState() => _RectSelectPageState();
}

enum _ResizeHandle { tl, t, tr, r, br, b, bl, l }

class _RectSelectPageState extends State<RectSelectPage> {
  late IntRect _rect;
  bool _editMode = true; // 編集: 矩形移動 / 非編集: 拡大・パン
  static const int _minSize = 32;

  @override
  void initState() {
    super.initState();
    _rect = widget.initialRect ??
        const IntRect(left: 100, top: 80, width: 300, height: 200);
  }

  void _save() {
    Navigator.of(context).pop(_rect);
  }
  void _saveAndApplyRight() {
    // 戻り値は (IntRect, bool applyToRight)
    Navigator.of(context).pop((_rect, true));
  }

  void _toggleMode() {
    setState(() => _editMode = !_editMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: _editMode ? '拡大モードへ' : '編集モードへ',
            icon: Icon(_editMode ? Icons.search : Icons.edit),
            onPressed: _toggleMode,
          ),
          Tooltip(
            message: '保存',
            child: TextButton(
              onPressed: _save,
              child: const Text('保存'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editMode ? '編集モード：ドラッグで矩形を移動' : '拡大モード：ピンチで拡大・パン',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Expanded(child: _editMode ? _buildEditable() : _buildZoomable()),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('apply-same-rect-right'),
              onPressed: _saveAndApplyRight,
              icon: const Icon(Icons.copy_all),
              label: const Text('同座標適用（右へ）'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _scaleToFit(constraints.maxWidth, constraints.maxHeight);
        final viewW = widget.imageWidth * scale;
        final viewH = widget.imageHeight * scale;
        return Center(
          child: SizedBox(
            width: viewW,
            height: viewH,
            child: Stack(
              children: [_imageLayer(), _buildDraggableRect(scale)],
            ),
          ),
        );
      },
    );
  }

  Widget _buildZoomable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _scaleToFit(constraints.maxWidth, constraints.maxHeight);
        final viewW = widget.imageWidth * scale;
        final viewH = widget.imageHeight * scale;

        return Center(
          child: SizedBox(
            width: viewW,
            height: viewH,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Stack(children: [_imageLayer(), _buildRectOnly(scale)]),
            ),
          ),
        );
      },
    );
  }

  double _scaleToFit(double maxW, double maxH) {
    final sx = maxW / widget.imageWidth;
    final sy = maxH / widget.imageHeight;
    return sx < sy ? sx : sy;
  }

  Widget _imageLayer() {
    final bytes = widget.imageBytes;
    final path = widget.imagePath;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox.expand(
          key: const Key('rect-select-image'),
          child: Image.memory(bytes, fit: BoxFit.fill),
        ),
      );
    }
    if (path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox.expand(
          key: const Key('rect-select-image'),
          child: Image.file(File(path), fit: BoxFit.fill),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
        gradient: LinearGradient(
          colors: [Colors.grey.shade200, Colors.grey.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildRectOnly(double scale) {
    return Positioned(
      left: _rect.left * scale,
      top: _rect.top * scale,
      width: _rect.width * scale,
      height: _rect.height * scale,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.redAccent, width: 2),
            color: Colors.redAccent.withOpacity(0.08),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableRect(double scale) {
    final pxLeft = _rect.left * scale;
    final pxTop = _rect.top * scale;
    final pxW = _rect.width * scale;
    final pxH = _rect.height * scale;
    const handleSize = 16.0;
    return Positioned(
      left: pxLeft,
      top: pxTop,
      width: pxW,
      height: pxH,
      child: Stack(
        children: [
          // Move area
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (details) {
                final dxImage = details.delta.dx / scale;
                final dyImage = details.delta.dy / scale;
                final newLeft = (_rect.left + dxImage).round();
                final newTop = (_rect.top + dyImage).round();
                setState(() {
                  _rect = IntRect(
                    left: newLeft.clamp(0, widget.imageWidth - _rect.width),
                    top: newTop.clamp(0, widget.imageHeight - _rect.height),
                    width: _rect.width,
                    height: _rect.height,
                  );
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent, width: 2),
                  color: Colors.redAccent.withOpacity(0.08),
                ),
                child: const Center(
                  child: Icon(Icons.drag_indicator, color: Colors.redAccent),
                ),
              ),
            ),
          ),

          // Handles
          _buildHandle(_ResizeHandle.tl, scale, handleSize),
          _buildHandle(_ResizeHandle.t, scale, handleSize),
          _buildHandle(_ResizeHandle.tr, scale, handleSize),
          _buildHandle(_ResizeHandle.r, scale, handleSize),
          _buildHandle(_ResizeHandle.br, scale, handleSize),
          _buildHandle(_ResizeHandle.b, scale, handleSize),
          _buildHandle(_ResizeHandle.bl, scale, handleSize),
          _buildHandle(_ResizeHandle.l, scale, handleSize),
        ],
      ),
    );
  }

  Widget _buildHandle(_ResizeHandle h, double scale, double size) {
    // Position handle within the rect area (local to rect)
    double localLeft, localTop;
    final pxW = _rect.width * scale;
    final pxH = _rect.height * scale;

    switch (h) {
      case _ResizeHandle.tl:
        localLeft = -size / 2;
        localTop = -size / 2;
        break;
      case _ResizeHandle.t:
        localLeft = pxW / 2 - size / 2;
        localTop = -size / 2;
        break;
      case _ResizeHandle.tr:
        localLeft = pxW - size / 2;
        localTop = -size / 2;
        break;
      case _ResizeHandle.r:
        localLeft = pxW - size / 2;
        localTop = pxH / 2 - size / 2;
        break;
      case _ResizeHandle.br:
        localLeft = pxW - size / 2;
        localTop = pxH - size / 2;
        break;
      case _ResizeHandle.b:
        localLeft = pxW / 2 - size / 2;
        localTop = pxH - size / 2;
        break;
      case _ResizeHandle.bl:
        localLeft = -size / 2;
        localTop = pxH - size / 2;
        break;
      case _ResizeHandle.l:
        localLeft = -size / 2;
        localTop = pxH / 2 - size / 2;
        break;
    }

    return Positioned(
      left: localLeft,
      top: localTop,
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final dx = details.delta.dx / scale;
          final dy = details.delta.dy / scale;
          _resizeFromHandle(h, dx, dy);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.redAccent, width: 2),
            shape: BoxShape.rectangle,
          ),
        ),
      ),
    );
  }

  void _resizeFromHandle(_ResizeHandle h, double dxImage, double dyImage) {
    double left = _rect.left.toDouble();
    double right = _rect.right.toDouble();
    double top = _rect.top.toDouble();
    double bottom = _rect.bottom.toDouble();

    bool affectsLeft =
        h == _ResizeHandle.tl || h == _ResizeHandle.l || h == _ResizeHandle.bl;
    bool affectsRight =
        h == _ResizeHandle.tr || h == _ResizeHandle.r || h == _ResizeHandle.br;
    bool affectsTop =
        h == _ResizeHandle.tl || h == _ResizeHandle.t || h == _ResizeHandle.tr;
    bool affectsBottom =
        h == _ResizeHandle.bl || h == _ResizeHandle.b || h == _ResizeHandle.br;

    if (affectsLeft) left += dxImage;
    if (affectsRight) right += dxImage;
    if (affectsTop) top += dyImage;
    if (affectsBottom) bottom += dyImage;

    // Clamp within image bounds first
    left = left.clamp(0, widget.imageWidth.toDouble());
    right = right.clamp(0, widget.imageWidth.toDouble());
    top = top.clamp(0, widget.imageHeight.toDouble());
    bottom = bottom.clamp(0, widget.imageHeight.toDouble());

    // Enforce minimum size depending on the moving side
    if (right - left < _minSize) {
      if (affectsLeft && !affectsRight) {
        left = right - _minSize;
      } else {
        right = left + _minSize;
      }
    }
    if (bottom - top < _minSize) {
      if (affectsTop && !affectsBottom) {
        top = bottom - _minSize;
      } else {
        bottom = top + _minSize;
      }
    }

    // Final clamp to keep rectangle within bounds
    if (left < 0) {
      right -= left; // shift right by deficit
      left = 0;
    }
    if (right > widget.imageWidth) {
      left -= (right - widget.imageWidth);
      right = widget.imageWidth.toDouble();
    }
    if (top < 0) {
      bottom -= top;
      top = 0;
    }
    if (bottom > widget.imageHeight) {
      top -= (bottom - widget.imageHeight);
      bottom = widget.imageHeight.toDouble();
    }

    int iLeft = left.round();
    int iTop = top.round();
    int iRight = right.round();
    int iBottom = bottom.round();

    final newW = iRight - iLeft;
    final newH = iBottom - iTop;
    if (newW < _minSize || newH < _minSize) return; // safety

    setState(() {
      _rect = IntRect(left: iLeft, top: iTop, width: newW, height: newH);
    });
  }
}
