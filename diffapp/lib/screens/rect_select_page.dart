import 'package:diffapp/image_pipeline.dart';
import 'package:flutter/material.dart';

class RectSelectPage extends StatefulWidget {
  final String title;
  final int imageWidth;
  final int imageHeight;
  final IntRect? initialRect;

  const RectSelectPage({
    super.key,
    required this.title,
    this.imageWidth = 1280,
    this.imageHeight = 960,
    this.initialRect,
  });

  @override
  State<RectSelectPage> createState() => _RectSelectPageState();
}

class _RectSelectPageState extends State<RectSelectPage> {
  late IntRect _rect;
  bool _editMode = true; // 編集: 矩形移動 / 非編集: 拡大・パン

  @override
  void initState() {
    super.initState();
    _rect = widget.initialRect ?? const IntRect(left: 100, top: 80, width: 300, height: 200);
  }

  void _save() {
    Navigator.of(context).pop(_rect);
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
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '保存',
            onPressed: _save,
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
            Expanded(
              child: _editMode ? _buildEditable() : _buildZoomable(),
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
              children: [
                _imagePlaceholder(),
                _buildDraggableRect(scale),
              ],
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
              child: Stack(
                children: [
                  _imagePlaceholder(),
                  _buildRectOnly(scale),
                ],
              ),
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

  Widget _imagePlaceholder() {
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
    return Positioned(
      left: pxLeft,
      top: pxTop,
      width: pxW,
      height: pxH,
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
    );
  }
}

