export type Channel = 'msssim' | 'ciede' | 'edge';

export type InputMode = 'digital' | 'photo';

export interface InspectSettings {
  weights: Record<Channel, number>;
  sensitivity: number;
  maxDetections: number;
  minAreaPercent: number;
  analysisSize: number;
  inputMode: InputMode;
  blurRadius: number;
}

export const DEFAULT_SETTINGS: InspectSettings = {
  weights: { msssim: 1.0, ciede: 1.0, edge: 0.6 },
  sensitivity: 0.5,
  maxDetections: 20,
  minAreaPercent: 0.15,
  analysisSize: 640,
  inputMode: 'digital',
  blurRadius: 1,
};

/** 写真撮影モード用プリセット。撮影時の傾き・反射・ベゼル写り込みに強く、誤検出を抑制。 */
export const PHOTO_MODE_SETTINGS: Partial<InspectSettings> = {
  sensitivity: 0.3,         // スコア下限 0.7（厳しく絞る）
  minAreaPercent: 0.5,      // より大きな差分のみ拾う
  blurRadius: 3,            // 位置ズレ吸収を強化
  weights: { msssim: 1.0, ciede: 0.5, edge: 0.3 }, // 色差重み減、エッジ差分減
};

export const DIGITAL_MODE_SETTINGS: Partial<InspectSettings> = {
  sensitivity: 0.5,
  minAreaPercent: 0.15,
  blurRadius: 1,
  weights: { msssim: 1.0, ciede: 1.0, edge: 0.6 },
};

export interface DetectedBox {
  x: number;
  y: number;
  w: number;
  h: number;
  score: number;
  channelScores: Partial<Record<Channel, number>>;
}

export interface InspectResult {
  boxes: DetectedBox[];
  heatmap: Float32Array;
  heatmapWidth: number;
  heatmapHeight: number;
  alignedLeft: ImageData;
  alignedRight: ImageData;
  perChannel: Partial<Record<Channel, Float32Array>>;
  stats: {
    alignmentInliers: number;
    alignmentMethod: 'translation' | 'none';
    shiftX: number;
    shiftY: number;
    elapsedMs: number;
    leftSize: { w: number; h: number };
    rightInputSize: { w: number; h: number };
    sizeMatched: boolean;
  };
}

export interface InspectInput {
  leftRgba: Uint8ClampedArray;
  leftWidth: number;
  leftHeight: number;
  rightRgba: Uint8ClampedArray;
  rightWidth: number;
  rightHeight: number;
  cropLeft?: { x: number; y: number; w: number; h: number };
  settings: InspectSettings;
}
