import { useCallback, useEffect, useMemo, useState } from 'react';
import { ImageDrop, type LoadedImage } from './ui/ImageDrop';
import { ParamPanel } from './ui/ParamPanel';
import { ResultView } from './ui/ResultView';
import { RangeSelector, type CropRect } from './ui/RangeSelector';
import { CornerCalibration, defaultCorners, type Corners } from './ui/CornerCalibration';
import { DEFAULT_SETTINGS, PHOTO_MODE_SETTINGS, type InspectResult, type InspectSettings } from './lib/types';
import { runInspect } from './engine/pipeline';

export default function App() {
  const [left, setLeft] = useState<LoadedImage | null>(null);
  const [right, setRight] = useState<LoadedImage | null>(null);
  const [settings, setSettings] = useState<InspectSettings>(DEFAULT_SETTINGS);
  const [result, setResult] = useState<InspectResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [log, setLog] = useState<string>('');
  const [cropRect, setCropRect] = useState<CropRect | null>(null);
  const [useAutoAlign, setUseAutoAlign] = useState(true);
  const [useCornerCalibration, setUseCornerCalibration] = useState(false);
  const [leftCorners, setLeftCorners] = useState<Corners | null>(null);
  const [rightCorners, setRightCorners] = useState<Corners | null>(null);

  useEffect(() => {
    setCropRect(null);
    setLeftCorners(null);
    setRightCorners(null);
    setUseCornerCalibration(false);
  }, [left?.url, right?.url]);

  useEffect(() => {
    if (useCornerCalibration && left && !leftCorners) setLeftCorners(defaultCorners(left));
    if (useCornerCalibration && right && !rightCorners) setRightCorners(defaultCorners(right));
  }, [useCornerCalibration, left, right, leftCorners, rightCorners]);

  const canRun = useMemo(
    () => !!left && !!right && !loading,
    [left, right, loading],
  );

  /** カメラで撮影したときに、まだ初期値（デジタル）のままならスマホ写真モードに切り替える */
  const handleCameraUsed = useCallback(() => {
    setSettings((s) =>
      s.inputMode === 'digital'
        ? { ...s, ...PHOTO_MODE_SETTINGS, inputMode: 'photo' }
        : s,
    );
  }, []);

  const handleRun = useCallback(async () => {
    if (!left || !right) return;
    setLoading(true);
    setErr(null);
    setLog('検査中...');
    try {
      const res = await runInspect({
        leftRgba: left.rgba,
        leftWidth: left.width,
        leftHeight: left.height,
        rightRgba: right.rgba,
        rightWidth: right.width,
        rightHeight: right.height,
        cropLeft: cropRect ?? undefined,
        settings,
        autoAlign: useAutoAlign,
        leftCorners: !useAutoAlign && useCornerCalibration ? leftCorners ?? undefined : undefined,
        rightCorners: !useAutoAlign && useCornerCalibration ? rightCorners ?? undefined : undefined,
      });
      setResult(res);
      setLog(
        `完了: ${(res.stats.elapsedMs / 1000).toFixed(2)}s / 整列=${res.stats.alignmentMethod}(Δx=${res.stats.shiftX} Δy=${res.stats.shiftY} θ=${res.stats.rotationDeg.toFixed(1)}° ×${res.stats.scale.toFixed(3)}) / 検出=${res.boxes.length}`,
      );
    } catch (e) {
      setErr(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [left, right, settings, cropRect, useAutoAlign, useCornerCalibration, leftCorners, rightCorners]);

  return (
    <div className="app">
      <header className="app-header">
        <div style={{ width: 32, height: 32, background: 'var(--accent)', borderRadius: 8 }} />
        <div>
          <h1>
            Diffapp Web Pro{' '}
            <span
              style={{
                fontSize: 12,
                fontWeight: 600,
                color: 'var(--accent)',
                background: '#eef2ff',
                padding: '2px 8px',
                borderRadius: 10,
                marginLeft: 6,
                verticalAlign: 'middle',
              }}
              title={`build ${__BUILD_TIME__}`}
            >
              v{__APP_VERSION__}
            </span>
          </h1>
          <div className="sub">
            高精度画像差分検査 — 純ブラウザ内処理（外部依存なし） ·{' '}
            <span style={{ color: '#6b7280' }}>
              build {__BUILD_TIME__.replace('T', ' ').slice(0, 16)} UTC
            </span>
          </div>
        </div>
      </header>

      <div className="layout">
        <div>
          <div className="card">
            <div className="image-pair">
              <ImageDrop label="左画像（基準）" badge="L" value={left} onChange={setLeft} onCameraUsed={handleCameraUsed} />
              <ImageDrop label="右画像（比較対象）" badge="R" value={right} onChange={setRight} onCameraUsed={handleCameraUsed} />
            </div>
            {left && right && (
              <>
                <div style={{ marginTop: 12, padding: '8px 10px', background: '#f2f4fa', borderRadius: 6, display: 'flex', flexDirection: 'column', gap: 6 }}>
                  <label style={{ fontSize: 13, display: 'flex', alignItems: 'center', gap: 6 }}>
                    <input
                      type="checkbox"
                      checked={useAutoAlign}
                      onChange={(e) => setUseAutoAlign(e.target.checked)}
                    />
                    🤖 自動整列（Harris 特徴点 + RANSAC ホモグラフィ推定、撮影画像では必須）
                  </label>
                  <label style={{ fontSize: 13, display: 'flex', alignItems: 'center', gap: 6, opacity: useAutoAlign ? 0.5 : 1 }}>
                    <input
                      type="checkbox"
                      checked={useCornerCalibration}
                      disabled={useAutoAlign}
                      onChange={(e) => setUseCornerCalibration(e.target.checked)}
                    />
                    🎯 手動で4隅を指定（自動整列を OFF にしたときのみ）
                  </label>
                  {!useAutoAlign && useCornerCalibration && leftCorners && rightCorners && (
                    <div className="corner-pair">
                      <CornerCalibration
                        image={left}
                        label="左画像の4隅"
                        value={leftCorners}
                        onChange={setLeftCorners}
                      />
                      <CornerCalibration
                        image={right}
                        label="右画像の4隅"
                        value={rightCorners}
                        onChange={setRightCorners}
                      />
                    </div>
                  )}
                </div>
                <RangeSelector
                  left={left}
                  right={right}
                  value={cropRect}
                  onChange={setCropRect}
                />
              </>
            )}
            <div className="actions">
              <button className="btn primary" disabled={!canRun} onClick={handleRun}>
                {loading ? '検査中...' : '検査を実行'}
              </button>
              <button
                className="btn"
                disabled={loading}
                onClick={() => {
                  setLeft(null);
                  setRight(null);
                  setResult(null);
                  setLog('');
                  setCropRect(null);
                }}
              >
                リセット
              </button>
            </div>
            {err && <div className="error">{err}</div>}
            {log && <div className="log">{log}</div>}
          </div>

          {result && (
            <div className="card" style={{ marginTop: 16 }}>
              <ResultView result={result} />
            </div>
          )}
        </div>

        <div className="card">
          <ParamPanel
            value={settings}
            onChange={setSettings}
            onRun={handleRun}
            canRun={canRun}
            loading={loading}
          />
        </div>
      </div>
    </div>
  );
}
