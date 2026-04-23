# Diffapp Web Pro

**ブラウザ内で動作する高精度画像差分検査アプリ** — サーバー費用ゼロ、完全オフライン動作可能。

## 特徴

- **完全ブラウザ処理**: 画像は外部送信なし、プライバシー保護
- **4チャネル差分検出** を重み付き合成:
  1. **MS-SSIM** — 構造的な差分（ノイズ耐性）
  2. **CIEDE2000** — 知覚的色差
  3. **DINOv2**（ViT パッチ特徴コサイン距離）— 意味的差分（照明・ノイズに頑健）
  4. **Canny + 距離変換** — エッジ位置のズレ
- **OpenCV.js** による ORB + RANSAC ホモグラフィ整列 + CLAHE 照明均一化 + ヒストグラムマッチ色正規化
- **ONNX Runtime Web**（WASM + SIMD）で DINOv2 を実用速度で実行
- **PWA** — Service Worker で完全オフライン化、ホーム画面追加可能
- **完全無料**: OSS のみ、無料ホスティング（Cloudflare Pages / Vercel / GitHub Pages）に乗る

## セットアップ

```bash
cd diffapp/web_pro
pnpm install
pnpm fetch:models      # DINOv2-small ONNX を public/models/ に取得（オプション、約90MB）
pnpm dev               # http://localhost:5173
```

モデル取得に失敗しても DINO 以外の 3 チャネルは動作します（UIで自動的に無効化）。

## 本番ビルド

```bash
pnpm build
pnpm preview
```

`dist/` を静的ホスティングに配置するだけでデプロイ完了。Cloudflare Pages / Vercel / GitHub Pages など無料枠で動きます。

### 必要な HTTP ヘッダ

ONNX Runtime Web のマルチスレッド WASM を使う場合、以下のヘッダが必須です（`vite.config.ts` で開発サーバー用に設定済み）:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Cloudflare Pages なら `_headers` ファイルに記述。

## テスト

```bash
pnpm test              # Vitest 単発
pnpm test:watch        # Vitest watch
pnpm typecheck         # TypeScript 型チェックのみ
```

## アーキテクチャ

```
src/
├── engine/
│   ├── loaders/        OpenCV.js・ONNX Runtime Web のロード
│   ├── align/          CLAHE → ヒストグラムマッチ → ORB+RANSAC ホモグラフィ
│   ├── channels/       MS-SSIM / CIEDE2000 / DINO / Canny
│   ├── postprocess/    Otsu 二値化 → モルフォロジー → 連結成分 → NMS
│   └── pipeline.ts     上記を統合する単一エントリ
├── ui/                 React コンポーネント（ImageDrop / ParamPanel / ResultView）
├── lib/                画像ユーティリティ・型定義
└── App.tsx / main.tsx  エントリ
```

## 検査パイプライン

```
[左画像] [右画像]
   │       │
   ▼       ▼
 CLAHE（L チャンネル）
   │       │
   │       ▼
   │    ヒストグラムマッチ（色合わせ）
   │       │
   └───┬───┘
       ▼
 ORB → BFMatcher + 比率テスト → findHomography(RANSAC)
       │  ※失敗時は estimateAffinePartial2D にフォールバック
       ▼
 warpPerspective で整列
       │
       ▼
 [整列済み左] [整列済み右] に範囲クロップ → 解析解像度にリサイズ
       │
       ▼
 4 チャネル差分マップを計算
   ├─ MS-SSIM（3 スケール）
   ├─ CIEDE2000
   ├─ DINOv2 パッチ特徴コサイン距離
   └─ Canny + 距離変換差
       │
       ▼
 重み付き合成 → 正規化ヒートマップ
       │
       ▼
 Otsu 二値化 → 3×3 Closing → 連結成分 → 形状フィルタ → NMS
       │
       ▼
 検出矩形（スコア順上位 N 件）
```

## パラメータ

| 項目 | 意味 | 既定 |
|---|---|---|
| 感度 | Otsu しきい値からのオフセット。高いほど拾いやすい | 0.5 |
| 最小検出サイズ | 解析空間に対する面積%。細長領域は 25% まで緩和 | 0.4% |
| 解析解像度 | 長辺 px。大きいほど細部に強いが重い | 512 |
| 最大検出数 | NMS 後に残す上限 | 20 |
| チャネル重み | 4 チャネルそれぞれの寄与 | MS-SSIM=1.0 / CIEDE=0.8 / DINO=1.2 / Edge=0.4 |

## ライセンス・サードパーティ

- OpenCV.js: Apache-2.0
- ONNX Runtime Web: MIT
- DINOv2 (Xenova/dinov2-small): Apache-2.0
- React, Vite, Vitest: MIT

すべて商用利用可の OSS。サーバー通信・外部 API 呼び出しは一切なし。
