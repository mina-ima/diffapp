import { useCallback, useEffect, useRef, useState } from 'react';

interface Props {
  title: string;
  onCapture: (file: File) => void;
  onClose: () => void;
}

/**
 * ライブプレビュー付きカメラ撮影コンポーネント。
 * - モバイルは背面カメラを優先（facingMode: 'environment'）
 * - PC は内蔵カメラを使用
 * - 撮影したフレームは JPEG File に変換して onCapture に渡す
 * - HTTPS または localhost でのみ動作（getUserMedia の仕様）
 */
export function CameraCapture({ title, onCapture, onClose }: Props) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [ready, setReady] = useState(false);
  const [preview, setPreview] = useState<{ file: File; url: string } | null>(null);
  const [facing, setFacing] = useState<'environment' | 'user'>('environment');

  const startStream = useCallback(async (mode: 'environment' | 'user') => {
    if (!navigator.mediaDevices?.getUserMedia) {
      setErr('このブラウザは getUserMedia に対応していません');
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: { ideal: mode },
          width: { ideal: 1920 },
          height: { ideal: 1080 },
        },
        audio: false,
      });
      if (streamRef.current) {
        streamRef.current.getTracks().forEach((t) => t.stop());
      }
      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        videoRef.current.onloadedmetadata = () => {
          videoRef.current?.play().catch(() => {});
          setReady(true);
        };
      }
      setErr(null);
    } catch (e) {
      setErr(e instanceof Error ? e.message : String(e));
    }
  }, []);

  useEffect(() => {
    startStream(facing);
    return () => {
      streamRef.current?.getTracks().forEach((t) => t.stop());
      streamRef.current = null;
    };
  }, [facing, startStream]);

  const handleShutter = useCallback(async () => {
    const video = videoRef.current;
    if (!video || video.readyState < 2) return;
    const w = video.videoWidth;
    const h = video.videoHeight;
    if (!w || !h) return;
    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.drawImage(video, 0, 0, w, h);
    const blob = await new Promise<Blob | null>((resolve) =>
      canvas.toBlob(resolve, 'image/jpeg', 0.92),
    );
    if (!blob) return;
    const file = new File([blob], `capture-${Date.now()}.jpg`, { type: 'image/jpeg' });
    setPreview({ file, url: URL.createObjectURL(file) });
  }, []);

  const handleConfirm = () => {
    if (!preview) return;
    onCapture(preview.file);
    URL.revokeObjectURL(preview.url);
    setPreview(null);
  };

  const handleRetake = () => {
    if (preview) URL.revokeObjectURL(preview.url);
    setPreview(null);
  };

  return (
    <div className="camera-overlay" role="dialog" aria-modal="true">
      <div className="camera-modal">
        <div className="camera-header">
          <span>{title}</span>
          <button className="btn" onClick={onClose} style={{ minHeight: 0, padding: '4px 10px' }}>
            ✕ 閉じる
          </button>
        </div>

        {err && <div className="error">カメラエラー: {err}</div>}

        <div className="camera-stage">
          {preview ? (
            <img src={preview.url} alt="preview" className="camera-media" />
          ) : (
            <video ref={videoRef} playsInline muted className="camera-media" />
          )}
        </div>

        {!preview ? (
          <div className="camera-controls">
            <button
              className="btn"
              onClick={() => setFacing(facing === 'environment' ? 'user' : 'environment')}
            >
              🔄 カメラ切替（{facing === 'environment' ? '背面' : '内側'}）
            </button>
            <button
              className="btn primary camera-shutter"
              disabled={!ready}
              onClick={handleShutter}
            >
              ● 撮影
            </button>
          </div>
        ) : (
          <div className="camera-controls">
            <button className="btn" onClick={handleRetake}>↺ 撮り直す</button>
            <button className="btn primary" onClick={handleConfirm}>
              ✓ この画像を使う
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
