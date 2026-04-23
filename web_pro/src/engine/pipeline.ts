import type {
  Channel,
  DetectedBox,
  InspectInput,
  InspectResult,
} from '../lib/types';
import {
  resizeRgbaBilinear,
  cropRgba,
  normalizeFloat,
  makeImageData,
  gaussianBlur,
  warpPerspectiveRgba,
} from '../lib/image';
import { computeHomography, invert3x3 } from '../lib/homography';
import type { CornerSet } from '../lib/types';
import { matchLumaHistogramRgba } from './align/preprocess';
import { alignRightToLeft } from './align/align';
import { msssimDiffMap } from './channels/msssim';
import { ciede2000Map } from './channels/ciede2000';
import { edgeDiffMap } from './channels/edge';
import { lineartDiffMap } from './channels/lineart';
import {
  otsuBinarize,
  morphClose,
  percentileMask,
  orMasks,
} from './postprocess/binarize';
import { extractRegions, nms } from './postprocess/regions';
import { detectByTileClusters } from './postprocess/tile_fallback';
import { detectPeaks } from './postprocess/peaks';
import { autoAlign } from './align/auto_align';

export async function runInspect(input: InspectInput): Promise<InspectResult> {
  const started = performance.now();

  // 0) 画像準備
  //   (a) autoAlign が ON の場合は Harris+NCC+RANSAC で自動整列（推奨）
  //   (b) 4隅指定がある場合は透視変換で正規化長方形にワープ
  //   (c) それ以外は原寸のまま、右を左のサイズに揃える
  let leftImg: ImageData;
  let rightImg: ImageData;
  if (input.autoAlign) {
    const leftRawImg = makeImageData(input.leftRgba, input.leftWidth, input.leftHeight);
    const rightRawImg = makeImageData(input.rightRgba, input.rightWidth, input.rightHeight);
    const aa = autoAlign(leftRawImg, rightRawImg);
    leftImg = leftRawImg;
    if (aa.ok) {
      rightImg = aa.alignedRight;
    } else {
      // フォールバック: 右を左サイズへ、照明ヒストマッチ、類似変換整列
      const rightResized = resizeOrSame(
        input.rightRgba,
        input.rightWidth,
        input.rightHeight,
        input.leftWidth,
        input.leftHeight,
      );
      rightImg = rightResized;
    }
  } else if (input.leftCorners && input.rightCorners) {
    const OUT_W = Math.min(1600, Math.max(input.leftWidth, input.rightWidth));
    const OUT_H = Math.round((OUT_W * 3) / 4); // 4:3 の標準出力。画像内容に依存しないので安全
    leftImg = makeImageData(
      warpToNormalizedRect(input.leftRgba, input.leftWidth, input.leftHeight, input.leftCorners, OUT_W, OUT_H),
      OUT_W,
      OUT_H,
    );
    rightImg = makeImageData(
      warpToNormalizedRect(input.rightRgba, input.rightWidth, input.rightHeight, input.rightCorners, OUT_W, OUT_H),
      OUT_W,
      OUT_H,
    );
  } else {
    leftImg = makeImageData(input.leftRgba, input.leftWidth, input.leftHeight);
    if (
      input.rightWidth === input.leftWidth &&
      input.rightHeight === input.leftHeight
    ) {
      rightImg = makeImageData(input.rightRgba, input.rightWidth, input.rightHeight);
    } else {
      const resized = resizeRgbaBilinear(
        input.rightRgba,
        input.rightWidth,
        input.rightHeight,
        input.leftWidth,
        input.leftHeight,
      );
      rightImg = makeImageData(resized, input.leftWidth, input.leftHeight);
    }
  }

  // 1) 色合わせのみ軽く（ヒスト平坦化は色差を潰すので外す）→ フェーズ相関で整列
  const rightNorm = matchLumaHistogramRgba(leftImg, rightImg);
  const align = alignRightToLeft(leftImg, rightNorm);

  // 2) 解析空間に切り出し
  const analysisLeft = cropToAnalysis(leftImg, input.cropLeft, input.settings.analysisSize);
  const analysisRight = cropToAnalysis(align.alignedRight, input.cropLeft, input.settings.analysisSize);

  const { width: W, height: H } = analysisLeft;
  const lBuf = analysisLeft.data;
  const rBuf = analysisRight.data;

  // 3) 差分チャネル計算。lineartMode では line画 XOR 差分を edge チャネルに注入
  const mapMs = msssimDiffMap(lBuf, rBuf, W, H);
  const mapCe = ciede2000Map(lBuf, rBuf, W, H);
  const mapEd = input.settings.lineartMode
    ? lineartDiffMap(lBuf, rBuf, W, H)
    : edgeDiffMap(lBuf, rBuf, W, H);

  const perChannel: Partial<Record<Channel, Float32Array>> = {
    msssim: mapMs,
    ciede: mapCe,
    edge: mapEd,
  };

  const { weights } = input.settings;
  const wSum = weights.msssim + weights.ciede + weights.edge;
  const combined = new Float32Array(W * H);
  for (let i = 0; i < combined.length; i++) {
    combined[i] =
      (weights.msssim * mapMs[i] + weights.ciede * mapCe[i] + weights.edge * mapEd[i]) /
      Math.max(0.001, wSum);
  }
  // 合成マップをブラーして位置ズレノイズ・ハロー・エッジずれを吸収
  const blurred = gaussianBlur(combined, W, H, input.settings.blurRadius);
  const heatmap = normalizeFloat(blurred);

  // 4) 後処理 → 検出矩形
  //   感度 s を「Otsu 閾値調整」と「最終スコア下限」の両方に連動させる:
  //     minScore ≒ 1 - s（s が高いほど拾いやすい、低いほど厳しく絞る）
  const minScore = Math.max(0.1, Math.min(0.95, 1 - input.settings.sensitivity));

  //   (a) Otsu 二値化 + (b) 上位 1% の百分位マスク を OR 結合（小さな差分を救う）
  const { mask: maskOtsu } = otsuBinarize(heatmap, input.settings.sensitivity);
  const maskPct = percentileMask(heatmap, 1);
  const merged = orMasks(maskOtsu, maskPct);
  const closed = morphClose(merged, W, H, 1);
  const regions = extractRegions(
    closed,
    heatmap,
    W,
    H,
    { minAreaPercent: input.settings.minAreaPercent },
    perChannel,
  );

  //   (c) タイル分割フォールバック（連続する広い差分領域を救う）
  const tileBoxes = detectByTileClusters(heatmap, W, H, perChannel);

  //   (d) 両者を統合し、スコア下限でノイズを足切り → NMS → 上限で打ち止め
  const combinedBoxes = [
    ...regions,
    ...tileBoxes.map((b) => ({ ...b, area: b.w * b.h })),
  ].filter((b) => b.score >= minScore);
  const kept = nms(combinedBoxes, 0.3, input.settings.maxDetections);
  const boxes: DetectedBox[] = kept.map(({ x, y, w, h, score, channelScores }) => ({
    x,
    y,
    w,
    h,
    score,
    channelScores,
  }));

  //   (e) ピーク点検出（伝統的な間違い探し風の円表示用）
  //       ヒートマップのピークで最も強い N 個を、最小距離 D 以上離して採用
  const minDistance = Math.max(20, Math.round(Math.max(W, H) * 0.08));
  const peaks = detectPeaks(
    heatmap,
    W,
    H,
    {
      minDistance,
      maxCount: input.settings.maxDetections,
      minScore,
    },
    perChannel,
  );

  return {
    boxes,
    peaks,
    heatmap,
    heatmapWidth: W,
    heatmapHeight: H,
    alignedLeft: analysisLeft,
    alignedRight: analysisRight,
    perChannel,
    stats: {
      alignmentInliers: align.inliers,
      alignmentMethod: align.method,
      shiftX: align.shiftX,
      shiftY: align.shiftY,
      rotationDeg: align.rotationDeg,
      scale: align.scale,
      elapsedMs: performance.now() - started,
      leftSize: { w: input.leftWidth, h: input.leftHeight },
      rightInputSize: { w: input.rightWidth, h: input.rightHeight },
      sizeMatched:
        input.leftWidth === input.rightWidth && input.leftHeight === input.rightHeight,
    },
  };
}

/** 解像度が違う場合のみリサイズ、同じならそのまま ImageData 化 */
function resizeOrSame(
  src: Uint8ClampedArray,
  sw: number,
  sh: number,
  dw: number,
  dh: number,
): ImageData {
  if (sw === dw && sh === dh) return makeImageData(src, sw, sh);
  const resized = resizeRgbaBilinear(src, sw, sh, dw, dh);
  return makeImageData(resized, dw, dh);
}

/** 指定 4 点を正規化長方形に射影変換してワープする */
function warpToNormalizedRect(
  src: Uint8ClampedArray,
  sw: number,
  sh: number,
  corners: CornerSet,
  outW: number,
  outH: number,
): Uint8ClampedArray {
  // src 4 点 → 長方形 4 点への射影
  const srcPts = [corners.tl, corners.tr, corners.br, corners.bl];
  const dstPts = [
    { x: 0, y: 0 },
    { x: outW, y: 0 },
    { x: outW, y: outH },
    { x: 0, y: outH },
  ];
  const H = computeHomography(srcPts, dstPts);
  const Hinv = invert3x3(H);
  return warpPerspectiveRgba(src, sw, sh, outW, outH, Hinv);
}

function cropToAnalysis(
  src: ImageData,
  crop: InspectInput['cropLeft'] | undefined,
  target: number,
): ImageData {
  const w = src.width;
  const h = src.height;
  let sx = 0;
  let sy = 0;
  let sw = w;
  let sh = h;
  if (crop && crop.w > 8 && crop.h > 8) {
    sx = Math.max(0, Math.min(w - 1, Math.round(crop.x)));
    sy = Math.max(0, Math.min(h - 1, Math.round(crop.y)));
    sw = Math.max(8, Math.min(w - sx, Math.round(crop.w)));
    sh = Math.max(8, Math.min(h - sy, Math.round(crop.h)));
  }
  const cropped = cropRgba(src.data, w, h, sx, sy, sw, sh);
  const longSide = Math.max(sw, sh);
  const scale = target / longSide;
  const dw = Math.max(32, Math.round(sw * scale));
  const dh = Math.max(32, Math.round(sh * scale));
  const resized = resizeRgbaBilinear(cropped, sw, sh, dw, dh);
  return makeImageData(resized, dw, dh);
}
