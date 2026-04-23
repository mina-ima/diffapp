import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { LoadedImage } from './ImageDrop';

export interface CropRect {
  x: number;
  y: number;
  w: number;
  h: number;
}

interface Props {
  left: LoadedImage;
  right: LoadedImage;
  /** 左画像のピクセル座標系での px 矩形。null で全体 */
  value: CropRect | null;
  onChange: (rect: CropRect | null) => void;
}

/**
 * 左画像の上でドラッグして矩形を描画するコンポーネント。
 * 左右それぞれの画像を原寸に近いサイズで表示し、選択した矩形（左画像のピクセル座標系）を
 * 両方に重ねて表示する。右画像はパイプライン側で左サイズにリサイズされる前提なので、
 * 左画像の座標系をそのまま右画像にも適用できる。
 */
export function RangeSelector({ left, right, value, onChange }: Props) {
  const wrapperRef = useRef<HTMLDivElement>(null);
  const interactRef = useRef<HTMLDivElement>(null);
  const [dragStart, setDragStart] = useState<{ x: number; y: number } | null>(null);
  const [dragCurrent, setDragCurrent] = useState<{ x: number; y: number } | null>(null);
  const [displayScale, setDisplayScale] = useState(1);

  useEffect(() => {
    const recompute = () => {
      if (!wrapperRef.current) return;
      const maxW = wrapperRef.current.clientWidth / 2 - 8;
      const scale = Math.min(1, maxW / Math.max(1, left.width));
      setDisplayScale(scale);
    };
    recompute();
    window.addEventListener('resize', recompute);
    return () => window.removeEventListener('resize', recompute);
  }, [left.width]);

  const dispW = Math.max(80, Math.round(left.width * displayScale));
  const dispH = Math.max(60, Math.round(left.height * displayScale));

  const toImageCoords = useCallback(
    (clientX: number, clientY: number, el: HTMLElement) => {
      const rect = el.getBoundingClientRect();
      const x = ((clientX - rect.left) / rect.width) * left.width;
      const y = ((clientY - rect.top) / rect.height) * left.height;
      return { x: clamp(x, 0, left.width), y: clamp(y, 0, left.height) };
    },
    [left.width, left.height],
  );

  const overlayRect = useMemo(() => {
    if (dragStart && dragCurrent) {
      const x = Math.min(dragStart.x, dragCurrent.x);
      const y = Math.min(dragStart.y, dragCurrent.y);
      const w = Math.abs(dragCurrent.x - dragStart.x);
      const h = Math.abs(dragCurrent.y - dragStart.y);
      return { x, y, w, h };
    }
    return value;
  }, [dragStart, dragCurrent, value]);

  const handlePointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    const target = e.currentTarget;
    target.setPointerCapture(e.pointerId);
    const p = toImageCoords(e.clientX, e.clientY, target);
    setDragStart(p);
    setDragCurrent(p);
  };

  const handlePointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    if (!dragStart) return;
    const p = toImageCoords(e.clientX, e.clientY, e.currentTarget);
    setDragCurrent(p);
  };

  const handlePointerUp = () => {
    if (!dragStart || !dragCurrent) return;
    const x = Math.min(dragStart.x, dragCurrent.x);
    const y = Math.min(dragStart.y, dragCurrent.y);
    const w = Math.abs(dragCurrent.x - dragStart.x);
    const h = Math.abs(dragCurrent.y - dragStart.y);
    setDragStart(null);
    setDragCurrent(null);
    if (w < 10 || h < 10) {
      onChange(null);
    } else {
      onChange({ x: Math.round(x), y: Math.round(y), w: Math.round(w), h: Math.round(h) });
    }
  };

  return (
    <div className="range-selector">
      <div className="range-header">
        <span className="range-title">範囲指定（左画像上でドラッグ）</span>
        <button
          className="btn"
          style={{ padding: '4px 10px', minHeight: 0 }}
          onClick={() => onChange(null)}
          disabled={!value}
        >
          範囲をリセット（全体を検査）
        </button>
      </div>
      <div className="range-grid" ref={wrapperRef}>
        <div
          ref={interactRef}
          className="range-image interactive"
          style={{ width: dispW, height: dispH }}
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
        >
          <img
            src={left.url}
            alt="left"
            draggable={false}
            style={{
              width: '100%',
              height: '100%',
              objectFit: 'contain',
              display: 'block',
              userSelect: 'none',
              pointerEvents: 'none',
            }}
          />
          {overlayRect && (
            <RectOverlay
              rect={overlayRect}
              imgW={left.width}
              imgH={left.height}
              dispW={dispW}
              dispH={dispH}
              color="rgba(11, 91, 211, 0.9)"
              fill="rgba(11, 91, 211, 0.12)"
              label="範囲"
            />
          )}
          <span className="range-badge">L</span>
        </div>
        <div className="range-image" style={{ width: dispW, height: dispH }}>
          <img
            src={right.url}
            alt="right"
            draggable={false}
            style={{
              width: '100%',
              height: '100%',
              objectFit: 'contain',
              display: 'block',
              userSelect: 'none',
              pointerEvents: 'none',
            }}
          />
          {value && (
            <RectOverlay
              rect={value}
              imgW={left.width}
              imgH={left.height}
              dispW={dispW}
              dispH={dispH}
              color="rgba(217, 44, 76, 0.9)"
              fill="rgba(217, 44, 76, 0.12)"
              label="同座標"
            />
          )}
          <span className="range-badge">R</span>
        </div>
      </div>
      <div className="log">
        {value
          ? `選択範囲: (${value.x}, ${value.y}) 幅${value.w}×高${value.h}px（左画像基準）`
          : '範囲未指定 → 画像全体を検査'}
      </div>
    </div>
  );
}

function RectOverlay({
  rect,
  imgW,
  imgH,
  dispW,
  dispH,
  color,
  fill,
  label,
}: {
  rect: CropRect;
  imgW: number;
  imgH: number;
  dispW: number;
  dispH: number;
  color: string;
  fill: string;
  label: string;
}) {
  const sx = dispW / imgW;
  const sy = dispH / imgH;
  const style: React.CSSProperties = {
    position: 'absolute',
    left: rect.x * sx,
    top: rect.y * sy,
    width: rect.w * sx,
    height: rect.h * sy,
    border: `2px solid ${color}`,
    background: fill,
    pointerEvents: 'none',
    boxSizing: 'border-box',
  };
  return (
    <div style={style}>
      <span
        style={{
          position: 'absolute',
          top: -18,
          left: 0,
          fontSize: 10,
          background: color,
          color: '#fff',
          padding: '1px 6px',
          borderRadius: 3,
          whiteSpace: 'nowrap',
        }}
      >
        {label}
      </span>
    </div>
  );
}

function clamp(v: number, lo: number, hi: number): number {
  return v < lo ? lo : v > hi ? hi : v;
}
