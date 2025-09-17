// ORB/SIFT マッチング精度確認（雛形実装）
// - 実行は未接続（gtest導入前）。Web側のVitestでソースの骨子を検証します。

#include <opencv2/features2d.hpp>
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <vector>

// 画像ペアから ORB 特徴を抽出し、BruteForce-Hamming でマッチング
static std::vector<cv::DMatch> matchFeaturesORB(
    const cv::Mat& img1, const cv::Mat& img2, int nfeatures = 500) {
  auto orb = cv::ORB::create(nfeatures);
  std::vector<cv::KeyPoint> k1, k2;
  cv::Mat d1, d2;
  orb->detectAndCompute(img1, cv::noArray(), k1, d1);
  orb->detectAndCompute(img2, cv::noArray(), k2, d2);

  cv::BFMatcher matcher(cv::NORM_HAMMING, /*crossCheck=*/true);
  std::vector<cv::DMatch> matches;
  if (!d1.empty() && !d2.empty()) {
    matcher.match(d1, d2, matches);
  }
  return matches;
}

// NOTE: 実行テストは未設定。将来 gtest で EXPECT_GE(matches.size(), N) などを確認予定。
int main() { return 0; }
