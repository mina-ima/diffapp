// gtest 数値検証（合成データ）
#include <gtest/gtest.h>
#include <vector>
#include <cstdint>

// ssimGrayU8 の簡易版（テスト内に同等ロジックを持たせる）
static double ssimGrayU8(const std::vector<uint8_t>& a,
                         const std::vector<uint8_t>& b) {
  const size_t n = a.size();
  if (n == 0 || n != b.size()) return 0.0;
  double sum_x = 0.0, sum_y = 0.0;
  for (size_t i = 0; i < n; ++i) { sum_x += a[i]; sum_y += b[i]; }
  const double mu_x = sum_x / n, mu_y = sum_y / n;
  double vx = 0.0, vy = 0.0, vxy = 0.0;
  for (size_t i = 0; i < n; ++i) {
    const double dx = a[i] - mu_x, dy = b[i] - mu_y;
    vx += dx * dx; vy += dy * dy; vxy += dx * dy;
  }
  const double sigma_x2 = vx / n, sigma_y2 = vy / n, sigma_xy = vxy / n;
  const double L = 255.0, k1 = 0.01, k2 = 0.03;
  const double C1 = (k1 * L) * (k1 * L), C2 = (k2 * L) * (k2 * L);
  const double num = (2 * mu_x * mu_y + C1) * (2 * sigma_xy + C2);
  const double den = (mu_x * mu_x + mu_y * mu_y + C1) * (sigma_x2 + sigma_y2 + C2);
  if (den == 0.0) return 0.0;
  return num / den;
}

TEST(SsimNumeric, IdenticalIsOne) {
  std::vector<uint8_t> a(1000, 128);
  std::vector<uint8_t> b = a;
  const double s = ssimGrayU8(a, b);
  EXPECT_NEAR(s, 1.0, 1e-9);
}
