import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { LoadedImage } from './ImageDrop';

export interface Corners {
  tl: { x: number; y: number };
  tr: { x: number; y: number };
  br: { x: number; y: number };
  bl: { x: number; y: number };
}

interface Props {
  image: LoadedImage;
  label: string;
  value: Corners;
  onChange: (v: Corners) => void;
}

const CORNER_KEYS: Array<keyof Corners> = ['tl', 'tr', 'br', 'bl'];
const CORNER_LABELS: Record<keyof Corners, string> = {
  tl: '①左上',
  tr: '②右上',
  br: '③右下',
  bl: '④左下',
};

/**
 * 画像上で4隅（TL→TR→BR→BL）の位置をドラッグで指定するコンポーネント。
 * 既存の点をドラッグで移動、点から離れた場所をタップすると「次の点」に選択が移る。
 */
export function CornerCalibration({ image, label, value, onChange }: Props) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const [activeKey, setActiveKey] = useState<keyof Corners>('tl');
  const [displayScale, setDisplayScale] = useState(1);

  useEffect(() => {
    const recompute = () => {
      if (!wrapRef.current) return;
      const maxW = wrapRef.current.clientWidth;
      const maxH = window.innerHeight * 0.6;
      const scale = Math.min(maxW / image.width, maxH / image.height, 1);
      setDisplayScale(scale);
    };
    recompute();
    window.addEventListener('resize', recompute);
    return () => window.removeEventListener('resize', recompute);
  }, [image.width, image.height]);

  const dispW = Math.max(160, Math.round(image.width * displayScale));
  const dispH = Math.max(120, Math.round(image.height * displayScale));

  const toImageCoords = useCallback(
    (clientX: number, clientY: number, el: HTMLElement) => {
      const rect = el.getBoundingClientRect();
      const x = ((clientX - rect.left) / rect.width) * image.width;
      const y = ((clientY - rect.top) / rect.height) * image.height;
      return {
        x: Math.max(0, Math.min(image.width, x)),
        y: Math.max(0, Math.min(image.height, y)),
      };
    },
    [image.width, image.height],
  );

  const nearestKey = useCallback(
    (p: { x: number; y: number }): keyof Corners => {
      let best: keyof Corners = 'tl';
      let bestD = Infinity;
      for (const k of CORNER_KEYS) {
        const q = value[k];
        const d = (q.x - p.x) ** 2 + (q.y - p.y) ** 2;
        if (d < bestD) {
          bestD = d;
          best = k;
        }
      }
      return best;
    },
    [value],
  );

  const handlePointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    e.currentTarget.setPointerCapture(e.pointerId);
    const p = toImageCoords(e.clientX, e.clientY, e.currentTarget);
    const k = nearestKey(p);
    setActiveKey(k);
    onChange({ ...value, [k]: p });
  };

  const handlePointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    if (e.buttons === 0) return;
    const p = toImageCoords(e.clientX, e.clientY, e.currentTarget);
    onChange({ ...value, [activeKey]: p });
  };

  const polygonPath = useMemo(() => {
    const pts = [value.tl, value.tr, value.br, value.bl];
    const s = displayScale;
    return pts.map((p) => `${p.x * s},${p.y * s}`).join(' ');
  }, [value, displayScale]);

  return (
    <div className="corner-calib">
      <div className="corner-header">
        <strong>{label}</strong>
        <span style={{ fontSize: 12, color: 'var(--ink-sub)' }}>
          {CORNER_LABELS[activeKey]} をドラッグ。順に ① → ② → ③ → ④
        </span>
      </div>
      <div
        className="corner-stage"
        ref={wrapRef}
        style={{ width: dispW, height: dispH }}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
      >
        <img
          src={image.url}
          alt={label}
          draggable={false}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'fill',
            display: 'block',
            pointerEvents: 'none',
            userSelect: 'none',
          }}
        />
        <svg
          width={dispW}
          height={dispH}
          style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}
        >
          <polygon
            points={polygonPath}
            fill="rgba(11, 91, 211, 0.12)"
            stroke="rgba(11, 91, 211, 0.9)"
            strokeWidth={2}
          />
          {CORNER_KEYS.map((k, idx) => {
            const p = value[k];
            return (
              <g key={k}>
                <circle
                  cx={p.x * displayScale}
                  cy={p.y * displayScale}
                  r={activeKey === k ? 10 : 7}
                  fill={activeKey === k ? '#0b5bd3' : '#fff'}
                  stroke="#0b5bd3"
                  strokeWidth={2}
                />
                <text
                  x={p.x * displayScale}
                  y={p.y * displayScale - 14}
                  fill="#0b5bd3"
                  fontSize={11}
                  fontWeight={600}
                  textAnchor="middle"
                >
                  {idx + 1}
                </text>
              </g>
            );
          })}
        </svg>
      </div>
    </div>
  );
}

export function defaultCorners(image: LoadedImage): Corners {
  const m = 0.05;
  return {
    tl: { x: image.width * m, y: image.height * m },
    tr: { x: image.width * (1 - m), y: image.height * m },
    br: { x: image.width * (1 - m), y: image.height * (1 - m) },
    bl: { x: image.width * m, y: image.height * (1 - m) },
  };
}
