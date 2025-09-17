// SSIM 数値検証（雛形実装）
#include <vector>
#include <cmath>
#include <cstdint>

// 簡易SSIM（グレースケール u8, 同一サイズ前提, 正規化なしの簡易版）
static double ssimGrayU8(const std::vector<uint8_t>& a,
                         const std::vector<uint8_t>& b) {
  const size_t n = a.size();
  if (n == 0 || n != b.size()) return 0.0;

  // 平均
  double sum_x = 0.0, sum_y = 0.0;
  for (size_t i = 0; i < n; ++i) { sum_x += a[i]; sum_y += b[i]; }
  const double mu_x = sum_x / n;
  const double mu_y = sum_y / n;

  // 分散と共分散
  double vx = 0.0, vy = 0.0, vxy = 0.0;
  for (size_t i = 0; i < n; ++i) {
    const double dx = a[i] - mu_x;
    const double dy = b[i] - mu_y;
    vx += dx * dx;
    vy += dy * dy;
    vxy += dx * dy;
  }
  const double sigma_x2 = vx / n;
  const double sigma_y2 = vy / n;
  const double sigma_xy = vxy / n;

  const double L = 255.0;
  const double k1 = 0.01, k2 = 0.03;
  const double C1 = (k1 * L) * (k1 * L);
  const double C2 = (k2 * L) * (k2 * L);

  const double num = (2 * mu_x * mu_y + C1) * (2 * sigma_xy + C2);
  const double den = (mu_x * mu_x + mu_y * mu_y + C1) * (sigma_x2 + sigma_y2 + C2);
  if (den == 0.0) return 0.0;
  return num / den;
}

int main() { return 0; }
