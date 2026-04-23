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
  value: CropRect | null;
  onChange: (rect: CropRect | null) => void;
}

/**
 * 左画像の上でドラッグして矩形を描画するコンポーネント。
 * モバイル配慮:
 *   - デフォルトは「スクロール可能モード」(範囲選択ドラッグは無効)
 *   - 「✏️ 範囲を指定」ボタンで選択モードONにすると、ドラッグで範囲指定
 *   - 画像サイズは max-height: 50vh で制約、狭い画面では縦1列
 */
export function RangeSelector({ left, right, value, onChange }: Props) {
  const interactRef = useRef<HTMLDivElement>(null);
  const [dragStart, setDragStart] = useState<{ x: number; y: number } | null>(null);
  const [dragCurrent, setDragCurrent] = useState<{ x: number; y: number } | null>(null);
  const [selectMode, setSelectMode] = useState(false);

  // 画像差し替えで選択モード/矩形をリセット
  useEffect(() => {
    setSelectMode(false);
  }, [left.url, right.url]);

  const toImageCoords = useCallback(
    (clientX: number, clientY: number, el: HTMLElement) => {
      const rect = el.getBoundingClientRect();
      const naturalAspect = left.width / left.height;
      const boxAspect = rect.width / rect.height;
      // object-fit: contain を使うので、表示領域と実画像領域のオフセットを計算
      let dispW = rect.width;
      let dispH = rect.height;
      let offX = 0;
      let offY = 0;
      if (naturalAspect > boxAspect) {
        dispH = rect.width / naturalAspect;
        offY = (rect.height - dispH) / 2;
      } else {
        dispW = rect.height * naturalAspect;
        offX = (rect.width - dispW) / 2;
      }
      const localX = clientX - rect.left - offX;
      const localY = clientY - rect.top - offY;
      const x = (localX / dispW) * left.width;
      const y = (localY / dispH) * left.height;
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
    if (!selectMode) return;
    const target = e.currentTarget;
    target.setPointerCapture(e.pointerId);
    const p = toImageCoords(e.clientX, e.clientY, target);
    setDragStart(p);
    setDragCurrent(p);
  };

  const handlePointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    if (!selectMode || !dragStart) return;
    const p = toImageCoords(e.clientX, e.clientY, e.currentTarget);
    setDragCurrent(p);
  };

  const handlePointerUp = () => {
    if (!selectMode || !dragStart || !dragCurrent) return;
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
    setSelectMode(false); // 選択完了で自動OFF
  };

  return (
    <div className="range-selector">
      <div className="range-header">
        <span className="range-title">範囲指定</span>
        <div style={{ display: 'flex', gap: 6 }}>
          <button
            className={`btn ${selectMode ? 'primary' : ''}`}
            style={{ padding: '4px 10px', minHeight: 0, fontSize: 12 }}
            onClick={() => setSelectMode(!selectMode)}
          >
            {selectMode ? '✎ ドラッグで範囲指定中…' : '✎ 範囲を指定'}
          </button>
          <button
            className="btn"
            style={{ padding: '4px 10px', minHeight: 0, fontSize: 12 }}
            onClick={() => {
              onChange(null);
              setSelectMode(false);
            }}
            disabled={!value}
          >
            ↺ リセット
          </button>
        </div>
      </div>

      <div className="range-grid">
        <div
          ref={interactRef}
          className={`range-image${selectMode ? ' selecting' : ''}`}
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
          onPointerCancel={handlePointerUp}
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
              color="rgba(11, 91, 211, 0.9)"
              fill="rgba(11, 91, 211, 0.12)"
              label="範囲"
            />
          )}
          <span className="range-badge">L（この画像上でドラッグ）</span>
        </div>
        <div className="range-image">
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
          ? `選択範囲: (${value.x}, ${value.y}) 幅${value.w}×高${value.h}px`
          : selectMode
            ? '左画像の上でドラッグして範囲を描画してください'
            : '範囲未指定 → 画像全体を検査。範囲を絞るなら「✎ 範囲を指定」を押してからドラッグ'}
      </div>
    </div>
  );
}

function RectOverlay({
  rect,
  imgW,
  imgH,
  color,
  fill,
  label,
}: {
  rect: CropRect;
  imgW: number;
  imgH: number;
  color: string;
  fill: string;
  label: string;
}) {
  // object-fit: contain 下での座標は % で指定（親コンテナに対する割合）
  const leftPct = (rect.x / imgW) * 100;
  const topPct = (rect.y / imgH) * 100;
  const widthPct = (rect.w / imgW) * 100;
  const heightPct = (rect.h / imgH) * 100;
  // object-fit 領域は親より狭い場合があるので、inner wrapper で合わせる
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        pointerEvents: 'none',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div
        style={{
          position: 'relative',
          width: '100%',
          height: '100%',
          maxWidth: '100%',
          maxHeight: '100%',
          aspectRatio: `${imgW} / ${imgH}`,
          margin: 'auto',
        }}
      >
        <div
          style={{
            position: 'absolute',
            left: `${leftPct}%`,
            top: `${topPct}%`,
            width: `${widthPct}%`,
            height: `${heightPct}%`,
            border: `2px solid ${color}`,
            background: fill,
            boxSizing: 'border-box',
          }}
        >
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
      </div>
    </div>
  );
}

function clamp(v: number, lo: number, hi: number): number {
  return v < lo ? lo : v > hi ? hi : v;
}
