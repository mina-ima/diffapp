import { useEffect, useMemo, useRef, useState } from 'react';
import type { Channel, InspectResult } from '../lib/types';

interface Props {
  result: InspectResult;
}

type Layer = 'detect' | 'heatmap' | 'msssim' | 'ciede' | 'edge' | 'left' | 'right';

export function ResultView({ result }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const overlayRef = useRef<HTMLCanvasElement>(null);
  const [layer, setLayer] = useState<Layer>('detect');

  const availableLayers = useMemo<Layer[]>(
    () => ['detect', 'heatmap', 'left', 'right', 'msssim', 'ciede', 'edge'],
    [],
  );

  useEffect(() => {
    const cv = canvasRef.current;
    if (!cv) return;
    cv.width = result.heatmapWidth;
    cv.height = result.heatmapHeight;
    const ctx = cv.getContext('2d');
    if (!ctx) return;

    if (layer === 'left' || layer === 'detect') {
      ctx.putImageData(result.alignedLeft, 0, 0);
    } else if (layer === 'right') {
      ctx.putImageData(result.alignedRight, 0, 0);
    } else {
      const source =
        layer === 'heatmap'
          ? result.heatmap
          : result.perChannel[layer as Channel];
      if (source) drawHeatmap(ctx, source, result.heatmapWidth, result.heatmapHeight);
    }

    const ov = overlayRef.current;
    if (!ov) return;
    ov.width = result.heatmapWidth;
    ov.height = result.heatmapHeight;
    const octx = ov.getContext('2d');
    if (!octx) return;
    octx.clearRect(0, 0, ov.width, ov.height);
    if (layer === 'detect') drawBoxes(octx, result);
  }, [result, layer]);

  return (
    <div>
      <div className="tabs">
        {availableLayers.map((l) => (
          <button
            key={l}
            className={`tab${layer === l ? ' active' : ''}`}
            onClick={() => setLayer(l)}
          >
            {layerLabel(l)}
          </button>
        ))}
      </div>
      <div className="result-stage">
        <canvas ref={canvasRef} />
        <canvas className="overlay" ref={overlayRef} />
      </div>
      <div className="stat-grid">
        <div className="stat"><div>検出件数</div><div className="val">{result.boxes.length}</div></div>
        <div className="stat"><div>整列方式</div><div className="val">{result.stats.alignmentMethod}</div></div>
        <div className="stat">
          <div>平行移動</div>
          <div className="val" style={{ fontSize: 13 }}>Δx={result.stats.shiftX} Δy={result.stats.shiftY}</div>
        </div>
        <div className="stat">
          <div>回転/拡縮</div>
          <div className="val" style={{ fontSize: 13 }}>
            {result.stats.rotationDeg.toFixed(1)}° / ×{result.stats.scale.toFixed(3)}
          </div>
        </div>
        <div className="stat"><div>相関強度</div><div className="val">{result.stats.alignmentInliers}</div></div>
        <div className="stat"><div>処理時間</div><div className="val">{(result.stats.elapsedMs / 1000).toFixed(2)}s</div></div>
        <div className="stat">
          <div>入力解像度</div>
          <div className="val" style={{ fontSize: 12 }}>
            L: {result.stats.leftSize.w}×{result.stats.leftSize.h}
            {!result.stats.sizeMatched && (
              <>
                <br />
                R: {result.stats.rightInputSize.w}×{result.stats.rightInputSize.h}
                <br />
                <span style={{ color: 'var(--warn)' }}>→ L サイズに合わせて比較</span>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function layerLabel(l: Layer): string {
  return {
    detect: '検出結果',
    heatmap: '総合ヒート',
    msssim: '構造',
    ciede: '色',
    edge: 'エッジ',
    left: '左（整列後）',
    right: '右（整列後）',
  }[l];
}

function drawHeatmap(
  ctx: CanvasRenderingContext2D,
  map: Float32Array,
  w: number,
  h: number,
) {
  const img = ctx.createImageData(w, h);
  for (let i = 0; i < w * h; i++) {
    const v = Math.min(1, Math.max(0, map[i]));
    const [r, g, b] = viridis(v);
    img.data[i * 4] = r;
    img.data[i * 4 + 1] = g;
    img.data[i * 4 + 2] = b;
    img.data[i * 4 + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
}

function viridis(v: number): [number, number, number] {
  const stops: Array<[number, [number, number, number]]> = [
    [0, [68, 1, 84]],
    [0.25, [59, 82, 139]],
    [0.5, [33, 145, 140]],
    [0.75, [94, 201, 98]],
    [1, [253, 231, 37]],
  ];
  for (let i = 0; i < stops.length - 1; i++) {
    const [t0, c0] = stops[i];
    const [t1, c1] = stops[i + 1];
    if (v <= t1) {
      const f = (v - t0) / (t1 - t0 || 1);
      return [
        Math.round(c0[0] + (c1[0] - c0[0]) * f),
        Math.round(c0[1] + (c1[1] - c0[1]) * f),
        Math.round(c0[2] + (c1[2] - c0[2]) * f),
      ];
    }
  }
  return stops[stops.length - 1][1];
}

function drawBoxes(ctx: CanvasRenderingContext2D, result: InspectResult) {
  ctx.lineWidth = Math.max(1.5, result.heatmapWidth / 320);
  ctx.font = `${Math.max(10, result.heatmapWidth / 40)}px sans-serif`;
  ctx.textBaseline = 'top';
  result.boxes.forEach((b, idx) => {
    ctx.strokeStyle = 'hsl(0, 85%, 55%)';
    ctx.strokeRect(b.x + 0.5, b.y + 0.5, b.w, b.h);
    const label = `${idx + 1}  s=${b.score.toFixed(2)}`;
    const textW = ctx.measureText(label).width + 6;
    const textH = parseInt(ctx.font, 10) + 4;
    const tx = b.x;
    const ty = Math.max(0, b.y - textH);
    ctx.fillStyle = 'rgba(217, 44, 76, 0.85)';
    ctx.fillRect(tx, ty, textW, textH);
    ctx.fillStyle = '#fff';
    ctx.fillText(label, tx + 3, ty + 2);
  });
}
