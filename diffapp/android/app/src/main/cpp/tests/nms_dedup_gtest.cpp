// gtest 数値検証（合成データ）
#include <gtest/gtest.h>
#include <vector>

struct Rect { float x, y, w, h; float score; };

static double iou(const Rect& a, const Rect& b) {
  const float ax2 = a.x + a.w, ay2 = a.y + a.h;
  const float bx2 = b.x + b.w, by2 = b.y + b.h;
  const float ix1 = std::max(a.x, b.x);
  const float iy1 = std::max(a.y, b.y);
  const float ix2 = std::min(ax2, bx2);
  const float iy2 = std::min(ay2, by2);
  const float iw = std::max(0.0f, ix2 - ix1);
  const float ih = std::max(0.0f, iy2 - iy1);
  const float inter = iw * ih;
  const float areaA = a.w * a.h;
  const float areaB = b.w * b.h;
  const float uni = areaA + areaB - inter;
  return uni > 0 ? static_cast<double>(inter) / static_cast<double>(uni) : 0.0;
}

static std::vector<Rect> nonMaxSuppressionRect(std::vector<Rect> boxes, float iouThreshold) {
  std::sort(boxes.begin(), boxes.end(), [](const Rect& a, const Rect& b) { return a.score > b.score; });
  std::vector<Rect> selected;
  for (const auto& b : boxes) {
    bool keep = true;
    for (const auto& s : selected) {
      if (iou(b, s) > iouThreshold) { keep = false; break; }
    }
    if (keep) selected.push_back(b);
  }
  return selected;
}

TEST(NmsDedup, SuppressByIoU) {
  std::vector<Rect> boxes = {
    {0, 0, 10, 10, 0.9f},
    {1, 1, 10, 10, 0.8f}, // 高IoUで抑制されるはず
    {20, 20, 10, 10, 0.7f},
  };
  auto kept = nonMaxSuppressionRect(boxes, 0.5f);
  EXPECT_EQ(kept.size(), 2u);
}
