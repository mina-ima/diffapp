import { useCallback, useEffect, useMemo, useState } from 'react';
import { ImageDrop, type LoadedImage } from './ui/ImageDrop';
import { ParamPanel } from './ui/ParamPanel';
import { ResultView } from './ui/ResultView';
import { RangeSelector, type CropRect } from './ui/RangeSelector';
import { DEFAULT_SETTINGS, type InspectResult, type InspectSettings } from './lib/types';
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

  // 画像を差し替えたら範囲をリセット
  useEffect(() => {
    setCropRect(null);
  }, [left?.url, right?.url]);

  const canRun = useMemo(
    () => !!left && !!right && !loading,
    [left, right, loading],
  );

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
  }, [left, right, settings, cropRect]);

  return (
    <div className="app">
      <header className="app-header">
        <div style={{ width: 32, height: 32, background: 'var(--accent)', borderRadius: 8 }} />
        <div>
          <h1>Diffapp Web Pro</h1>
          <div className="sub">高精度画像差分検査 — 純ブラウザ内処理（外部依存なし）</div>
        </div>
      </header>

      <div className="layout">
        <div>
          <div className="card">
            <div className="image-pair">
              <ImageDrop label="左画像（基準）" badge="L" value={left} onChange={setLeft} />
              <ImageDrop label="右画像（比較対象）" badge="R" value={right} onChange={setRight} />
            </div>
            {left && right && (
              <RangeSelector
                left={left}
                right={right}
                value={cropRect}
                onChange={setCropRect}
              />
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
