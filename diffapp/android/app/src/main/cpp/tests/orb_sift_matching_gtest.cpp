// gtest 数値検証（合成データ）
#include <gtest/gtest.h>
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <vector>

// matchFeaturesORB の簡易プロトタイプ（本体は別cppにある想定）
static std::vector<cv::DMatch> matchFeaturesORB(const cv::Mat& img1, const cv::Mat& img2, int nfeatures = 500);

TEST(OrbSiftMatching, FindsCorrespondences) {
  // 簡単な合成画像（白い円を少し移動）
  cv::Mat a(200, 200, CV_8UC1, cv::Scalar(0));
  cv::Mat b(200, 200, CV_8UC1, cv::Scalar(0));
  cv::circle(a, {100, 100}, 30, cv::Scalar(255), -1);
  cv::circle(b, {105, 100}, 30, cv::Scalar(255), -1);

  auto matches = matchFeaturesORB(a, b, 300);
  // 少なくともいくつかの対応点が見つかる想定
  EXPECT_GE(static_cast<int>(matches.size()), 5);
}
