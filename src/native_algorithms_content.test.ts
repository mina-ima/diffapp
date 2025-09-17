import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

const read = (p: string) => readFileSync(p, 'utf-8');

describe('C++ アルゴリズム骨子の内容検証', () => {
  it('ORB/SIFT マッチング（ORB実装）: OpenCVヘッダと関数骨子がある', () => {
    const t = read('diffapp/android/app/src/main/cpp/tests/orb_sift_matching_test.cpp');
    expect(t).toMatch(/#include\s+<opencv2\/features2d.hpp>/);
    expect(t).toMatch(/cv::ORB::create/);
    expect(t).toMatch(/cv::BFMatcher/);
    expect(t).toMatch(/std::vector<\s*cv::KeyPoint\s*>/);
    expect(t).toMatch(/std::vector<\s*cv::DMatch\s*>/);
    expect(t).toMatch(/matchFeaturesORB\s*\(/);
  });

  it('SSIM 数値検証: 数式の主要項と関数がある', () => {
    const t = read('diffapp/android/app/src/main/cpp/tests/ssim_numeric_test.cpp');
    expect(t).toMatch(/double\s+ssimGrayU8\s*\(/);
    expect(t).toMatch(/C1/);
    expect(t).toMatch(/C2/);
    expect(t).toMatch(/mu_x/);
    expect(t).toMatch(/mu_y/);
    expect(t).toMatch(/sigma_x2/);
    expect(t).toMatch(/sigma_y2/);
    expect(t).toMatch(/sigma_xy/);
  });

  it('NMS 重複除去: Rect, IoU, NMS関数がある', () => {
    const t = read('diffapp/android/app/src/main/cpp/tests/nms_dedup_test.cpp');
    expect(t).toMatch(/struct\s+Rect/);
    expect(t).toMatch(/double\s+iou\s*\(/);
    expect(t).toMatch(/nonMaxSuppressionRect\s*\(/);
    expect(t).toMatch(/std::sort/);
    expect(t).toMatch(/std::vector<\s*Rect\s*>/);
  });
});
