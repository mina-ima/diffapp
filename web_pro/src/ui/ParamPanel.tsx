import type { InspectSettings, Channel, InputMode } from '../lib/types';
import {
  DIGITAL_MODE_SETTINGS,
  PHOTO_MODE_SETTINGS,
  PHOTO_STRICT_SETTINGS,
  LINEART_MODE_SETTINGS,
} from '../lib/types';

interface Props {
  value: InspectSettings;
  onChange: (next: InspectSettings) => void;
  onRun?: () => void;
  canRun?: boolean;
  loading?: boolean;
}

const CHANNEL_LABELS: Record<Channel, string> = {
  msssim: 'MS-SSIM（構造）',
  ciede: 'CIEDE2000（色）',
  edge: 'Sobel（エッジ）',
};

export function ParamPanel({ value, onChange, onRun, canRun = false, loading = false }: Props) {
  const update = (patch: Partial<InspectSettings>) =>
    onChange({ ...value, ...patch });
  const updateWeight = (k: Channel, v: number) =>
    onChange({ ...value, weights: { ...value.weights, [k]: v } });
  const applyMode = (mode: InputMode) => {
    const preset =
      mode === 'photo'
        ? PHOTO_MODE_SETTINGS
        : mode === 'photo-strict'
          ? PHOTO_STRICT_SETTINGS
          : mode === 'lineart'
            ? LINEART_MODE_SETTINGS
            : DIGITAL_MODE_SETTINGS;
    onChange({ ...value, ...preset, inputMode: mode });
  };

  return (
    <div className="panel">
      <h2>検査設定</h2>

      <div className="row">
        <label>対象画像の種類</label>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6 }}>
          <button
            className={`btn ${value.inputMode === 'digital' ? 'primary' : ''}`}
            style={{ minHeight: 0, padding: '6px 8px', fontSize: 12 }}
            onClick={() => applyMode('digital')}
          >
            🖥️ スクショ / Web画像
          </button>
          <button
            className={`btn ${value.inputMode === 'photo' ? 'primary' : ''}`}
            style={{ minHeight: 0, padding: '6px 8px', fontSize: 12 }}
            onClick={() => applyMode('photo')}
          >
            📱 スマホ写真
          </button>
          <button
            className={`btn ${value.inputMode === 'photo-strict' ? 'primary' : ''}`}
            style={{ minHeight: 0, padding: '6px 8px', fontSize: 12 }}
            onClick={() => applyMode('photo-strict')}
          >
            🎯 スマホ写真（厳密）
          </button>
          <button
            className={`btn ${value.inputMode === 'lineart' ? 'primary' : ''}`}
            style={{ minHeight: 0, padding: '6px 8px', fontSize: 12 }}
            onClick={() => applyMode('lineart')}
          >
            ✏️ マンガ / 線画
          </button>
        </div>
        <div style={{ fontSize: 11, color: 'var(--ink-sub)', marginTop: 4, lineHeight: 1.5 }}>
          {
            {
              digital: 'スクリーンショットや Web から保存した画像など、劣化のないデジタル画像向け',
              photo: 'スマホで物やモニタを撮影した写真。手ブレ・反射・照明差を吸収',
              'photo-strict': 'スマホ写真で誤検出ゼロ優先。大きく明確な差分だけを拾う',
              lineart: 'マンガ・イラスト・手書き線画の間違い探し専用。色を無視し線のズレだけで比較',
            }[value.inputMode]
          }
        </div>
      </div>

      {onRun && (
        <div className="row" style={{ marginBottom: 16 }}>
          <button
            className="btn primary"
            disabled={!canRun}
            onClick={onRun}
            style={{ width: '100%' }}
          >
            {loading ? '検査中...' : '🔍 この設定で検査'}
          </button>
        </div>
      )}

      <div className="row">
        <label>
          感度 <span>{value.sensitivity.toFixed(2)}（スコア下限 {Math.max(0.1, Math.min(0.95, 1 - value.sensitivity)).toFixed(2)}）</span>
        </label>
        <input
          type="range"
          min={0}
          max={1}
          step={0.01}
          value={value.sensitivity}
          onChange={(e) => update({ sensitivity: Number(e.target.value) })}
        />
        <div style={{ fontSize: 11, color: 'var(--ink-sub)' }}>
          低：厳しく絞る（少数精鋭） ⟷ 高：広く拾う（取りこぼし減）
        </div>
      </div>

      <div className="row">
        <label>
          最小検出サイズ（面積%）
          <span>{value.minAreaPercent.toFixed(2)}%</span>
        </label>
        <input
          type="range"
          min={0.05}
          max={5}
          step={0.05}
          value={value.minAreaPercent}
          onChange={(e) => update({ minAreaPercent: Number(e.target.value) })}
        />
      </div>

      <div className="row">
        <label>解析解像度 <span>{value.analysisSize}px</span></label>
        <input
          type="range"
          min={256}
          max={768}
          step={32}
          value={value.analysisSize}
          onChange={(e) => update({ analysisSize: Number(e.target.value) })}
        />
      </div>

      <div className="row">
        <label>最大検出数 <span>{value.maxDetections}</span></label>
        <input
          type="range"
          min={1}
          max={50}
          step={1}
          value={value.maxDetections}
          onChange={(e) => update({ maxDetections: Number(e.target.value) })}
        />
      </div>

      <div className="row">
        <label>チャネル重み</label>
        {(Object.keys(CHANNEL_LABELS) as Channel[]).map((k) => (
          <div key={k} style={{ marginTop: 4 }}>
            <label style={{ fontSize: 12 }}>
              <span>{CHANNEL_LABELS[k]}</span>
              <span>{value.weights[k].toFixed(2)}</span>
            </label>
            <input
              type="range"
              min={0}
              max={2}
              step={0.05}
              value={value.weights[k]}
              onChange={(e) => updateWeight(k, Number(e.target.value))}
            />
          </div>
        ))}
      </div>

      {onRun && (
        <div className="row" style={{ marginTop: 8 }}>
          <button
            className="btn primary"
            disabled={!canRun}
            onClick={onRun}
            style={{ width: '100%' }}
          >
            {loading ? '検査中...' : '🔍 この設定で再検査'}
          </button>
        </div>
      )}
    </div>
  );
}
