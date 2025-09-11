import 'package:diffapp/image_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('thresholdBinary returns 0/1 correctly', () {
    final src = [0.1, 0.5, 0.9];
    expect(thresholdBinary(src, 0.8), [0, 0, 1]);
    expect(thresholdBinary(src, 0.5), [0, 1, 1]); // >= threshold => 1
  });

  test('connected components (8-connected) returns bounding boxes', () {
    const w = 8, h = 8;
    // Two separate 2x2 blocks: one at (1,1)-(2,2), another at (5,4)-(6,5)
    final bin = List<int>.filled(w * h, 0);
    void setBlock(int x0, int y0) {
      for (var y = y0; y < y0 + 2; y++) {
        for (var x = x0; x < x0 + 2; x++) {
          bin[y * w + x] = 1;
        }
      }
    }
    setBlock(1, 1);
    setBlock(5, 4);

    final boxes = connectedComponentsBoundingBoxes(bin, w, h, eightConnected: true);
    expect(boxes.length, 2);
    // Order is not guaranteed; sort by left/top for assertion.
    boxes.sort((a, b) => a.left != b.left ? a.left - b.left : a.top - b.top);
    expect(boxes[0].left, 1);
    expect(boxes[0].top, 1);
    expect(boxes[0].width, 2);
    expect(boxes[0].height, 2);
    expect(boxes[1].left, 5);
    expect(boxes[1].top, 4);
    expect(boxes[1].width, 2);
    expect(boxes[1].height, 2);
  });

  test('connected components respects minArea filter', () {
    const w = 6, h = 4;
    final bin = List<int>.filled(w * h, 0);
    // one 1-pixel dot and one 2x2 block
    bin[1 * w + 1] = 1; // area=1 (should be filtered out for minArea=2)
    for (var y = 1; y <= 2; y++) {
      for (var x = 3; x <= 4; x++) {
        bin[y * w + x] = 1; // area=4
      }
    }

    final boxes = connectedComponentsBoundingBoxes(bin, w, h, eightConnected: true, minArea: 2);
    expect(boxes.length, 1);
    final b = boxes.first;
    expect(b.left, 3);
    expect(b.top, 1);
    expect(b.width, 2);
    expect(b.height, 2);
  });
}

