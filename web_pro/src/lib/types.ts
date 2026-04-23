export type Channel = 'msssim' | 'ciede' | 'edge';

export type InputMode = 'digital' | 'photo' | 'photo-strict' | 'lineart';

export interface InspectSettings {
  weights: Record<Channel, number>;
  sensitivity: number;
  maxDetections: number;
  minAreaPercent: number;
  analysisSize: number;
  inputMode: InputMode;
  blurRadius: number;
  /** 線画モード: 左右をグレースケール→大津二値化→膨張してから XOR で比較。撮影の色/照明差に頑健。 */
  lineartMode: boolean;
}

export const DEFAULT_SETTINGS: InspectSettings = {
  weights: { msssim: 1.0, ciede: 1.0, edge: 0.6 },
  sensitivity: 0.5,
  maxDetections: 20,
  minAreaPercent: 0.15,
  analysisSize: 640,
  inputMode: 'digital',
  blurRadius: 1,
  lineartMode: false,
};

export const DIGITAL_MODE_SETTINGS: Partial<InspectSettings> = {
  sensitivity: 0.5,
  minAreaPercent: 0.15,
  blurRadius: 1,
  weights: { msssim: 1.0, ciede: 1.0, edge: 0.6 },
  lineartMode: false,
};

/** 撮影モード: 撮影時の傾き・反射・ベゼル写り込みに強い標準プリセット。 */
export const PHOTO_MODE_SETTINGS: Partial<InspectSettings> = {
  sensitivity: 0.3,
  minAreaPercent: 0.5,
  blurRadius: 3,
  weights: { msssim: 1.0, ciede: 0.5, edge: 0.3 },
  lineartMode: false,
};

/** 超厳格モード: 誤検出ゼロを優先、大きく明確な差分のみ拾う。 */
export const PHOTO_STRICT_SETTINGS: Partial<InspectSettings> = {
  sensitivity: 0.15,         // スコア下限 0.85（かなり厳しい）
  minAreaPercent: 1.5,       // 面積 1.5% 以上のみ
  blurRadius: 5,             // さらに強い平滑化
  weights: { msssim: 1.2, ciede: 0.3, edge: 0.2 },
  lineartMode: false,
};

/** 線画比較モード: 色情報を無視し線の位置ズレだけで比較。モノクロ線画の間違い探しに最適。 */
export const LINEART_MODE_SETTINGS: Partial<InspectSettings> = {
  sensitivity: 0.45,
  minAreaPercent: 0.3,
  blurRadius: 2,
  weights: { msssim: 0.3, ciede: 0.0, edge: 2.0 },
  lineartMode: true,
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
    alignmentMethod: 'translation' | 'similarity' | 'none';
    shiftX: number;
    shiftY: number;
    rotationDeg: number;
    scale: number;
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
