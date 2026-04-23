export type Channel = 'msssim' | 'ciede' | 'edge';

export interface InspectSettings {
  weights: Record<Channel, number>;
  sensitivity: number;
  maxDetections: number;
  minAreaPercent: number;
  analysisSize: number;
}

export const DEFAULT_SETTINGS: InspectSettings = {
  weights: { msssim: 1.0, ciede: 1.0, edge: 0.6 },
  sensitivity: 0.5,
  maxDetections: 20,
  minAreaPercent: 0.15,
  analysisSize: 640,
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
