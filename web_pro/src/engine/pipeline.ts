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
} from '../lib/image';
import { matchLumaHistogramRgba } from './align/preprocess';
import { alignRightToLeft } from './align/align';
import { msssimDiffMap } from './channels/msssim';
import { ciede2000Map } from './channels/ciede2000';
import { edgeDiffMap } from './channels/edge';
import {
  otsuBinarize,
  morphClose,
  percentileMask,
  orMasks,
} from './postprocess/binarize';
import { extractRegions, nms } from './postprocess/regions';
import { detectByTileClusters } from './postprocess/tile_fallback';

export async function runInspect(input: InspectInput): Promise<InspectResult> {
  const started = performance.now();

  const leftImg = makeImageData(input.leftRgba, input.leftWidth, input.leftHeight);

  // 0) 左右の解像度が違うと全領域が差分扱いになるので、右を左のサイズに揃える
  let rightImg: ImageData;
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

  // 1) 色合わせのみ軽く（ヒスト平坦化は色差を潰すので外す）→ フェーズ相関で整列
  const rightNorm = matchLumaHistogramRgba(leftImg, rightImg);
  const align = alignRightToLeft(leftImg, rightNorm);

  // 2) 解析空間に切り出し
  const analysisLeft = cropToAnalysis(leftImg, input.cropLeft, input.settings.analysisSize);
  const analysisRight = cropToAnalysis(align.alignedRight, input.cropLeft, input.settings.analysisSize);

  const { width: W, height: H } = analysisLeft;
  const lBuf = analysisLeft.data;
  const rBuf = analysisRight.data;

  // 3) 3 チャネル差分
  const mapMs = msssimDiffMap(lBuf, rBuf, W, H);
  const mapCe = ciede2000Map(lBuf, rBuf, W, H);
  const mapEd = edgeDiffMap(lBuf, rBuf, W, H);

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
  const heatmap = normalizeFloat(combined);

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

  return {
    boxes,
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
      elapsedMs: performance.now() - started,
      leftSize: { w: input.leftWidth, h: input.leftHeight },
      rightInputSize: { w: input.rightWidth, h: input.rightHeight },
      sizeMatched:
        input.leftWidth === input.rightWidth && input.leftHeight === input.rightHeight,
    },
  };
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
