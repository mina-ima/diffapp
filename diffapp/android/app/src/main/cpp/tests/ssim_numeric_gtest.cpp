// gtest 雛形（将来的に実行）
#include <gtest/gtest.h>

TEST(SsimNumeric, Smoke) {
  EXPECT_NEAR(1.0, 1.0, 1e-9);
}

