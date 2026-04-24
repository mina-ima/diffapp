import { useCallback, useRef, useState } from 'react';
import { CameraCapture } from './CameraCapture';

export interface LoadedImage {
  file: File;
  url: string;
  rgba: Uint8ClampedArray;
  width: number;
  height: number;
}

interface Props {
  label: string;
  badge: string;
  value: LoadedImage | null;
  onChange: (image: LoadedImage | null) => void;
  /** カメラ撮影で画像が取り込まれたときに呼ばれる。親が撮影モードへ切り替えるのに使う */
  onCameraUsed?: () => void;
  maxSide?: number;
}

// 長辺 4000px までは原寸維持（既存 diffapp と同じ方針）。これより大きい場合のみ縮小。
const MAX_SIDE_DEFAULT = 4000;

async function fileToLoaded(file: File, maxSide: number): Promise<LoadedImage> {
  const bmp = await createImageBitmap(file, {
    imageOrientation: 'from-image', // EXIF の回転を反映
    colorSpaceConversion: 'default',
    resizeQuality: 'high',
  });
  const scale = Math.min(1, maxSide / Math.max(bmp.width, bmp.height));
  const w = Math.round(bmp.width * scale);
  const h = Math.round(bmp.height * scale);
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) throw new Error('Canvas 2D context unavailable');
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(bmp, 0, 0, w, h);
  const imageData = ctx.getImageData(0, 0, w, h);
  bmp.close();
  return {
    file,
    url: URL.createObjectURL(file),
    rgba: imageData.data,
    width: w,
    height: h,
  };
}

export function ImageDrop({ label, badge, value, onChange, onCameraUsed, maxSide = MAX_SIDE_DEFAULT }: Props) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [dragOver, setDragOver] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [cameraOpen, setCameraOpen] = useState(false);

  const handleFile = useCallback(
    async (file: File | undefined) => {
      if (!file) return;
      if (!/^image\/(png|jpeg|webp|bmp)$/.test(file.type)) {
        setErr('jpg / png / webp 画像を選んでください');
        return;
      }
      try {
        const loaded = await fileToLoaded(file, maxSide);
        if (value?.url) URL.revokeObjectURL(value.url);
        onChange(loaded);
        setErr(null);
      } catch (e) {
        setErr(e instanceof Error ? e.message : '画像の読み込みに失敗しました');
      }
    },
    [maxSide, onChange, value],
  );

  return (
    <div>
      <div
        className={`image-slot${value ? ' has-image' : ''}${dragOver ? ' drag-over' : ''}`}
        onClick={() => inputRef.current?.click()}
        onDragOver={(e) => {
          e.preventDefault();
          setDragOver(true);
        }}
        onDragLeave={() => setDragOver(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDragOver(false);
          handleFile(e.dataTransfer.files?.[0]);
        }}
      >
        <span className="badge">{badge}</span>
        {value ? (
          <img src={value.url} alt={label} />
        ) : (
          <div className="placeholder">
            {label}
            <br />
            クリック or ドラッグ&ドロップ
          </div>
        )}
        <input
          ref={inputRef}
          type="file"
          accept="image/png,image/jpeg,image/webp,image/bmp"
          hidden
          onChange={(e) => handleFile(e.target.files?.[0])}
        />
      </div>
      <div className="image-slot-actions">
        <button
          type="button"
          className="btn"
          onClick={(e) => {
            e.stopPropagation();
            setCameraOpen(true);
          }}
          style={{ flex: 1, minHeight: 0, padding: '6px 8px', fontSize: 12 }}
        >
          📷 カメラで撮影
        </button>
        <button
          type="button"
          className="btn"
          onClick={(e) => {
            e.stopPropagation();
            inputRef.current?.click();
          }}
          style={{ flex: 1, minHeight: 0, padding: '6px 8px', fontSize: 12 }}
        >
          📁 ファイル選択
        </button>
      </div>
      {err && <div className="error">{err}</div>}
      {cameraOpen && (
        <CameraCapture
          title={label + ' を撮影'}
          onCapture={(file) => {
            setCameraOpen(false);
            handleFile(file);
            onCameraUsed?.();
          }}
          onClose={() => setCameraOpen(false)}
        />
      )}
    </div>
  );
}
