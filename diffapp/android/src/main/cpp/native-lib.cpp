#include <cstdint>

extern "C" __attribute__((visibility("default")))
int to_grayscale_u8(const uint8_t* rgb, int width, int height, uint8_t* out) {
  if (!rgb || !out || width <= 0 || height <= 0) {
    return -1;
  }
  const int total = width * height;
  for (int i = 0, j = 0; i < total; ++i) {
    const int r = rgb[j++];
    const int g = rgb[j++];
    const int b = rgb[j++];
    int y = static_cast<int>(0.299 * r + 0.587 * g + 0.114 * b + 0.5);
    if (y < 0) y = 0; if (y > 255) y = 255;
    out[i] = static_cast<uint8_t>(y);
  }
  return 0;
}

