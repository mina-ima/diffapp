import { normalizeFloat } from '../../lib/image';

/**
 * CIEDE2000 色差マップ。
 * RGB(sRGB, D65) → XYZ → Lab → ΔE00 をピクセル毎に計算。
 * ピクセル毎計算はやや重いため、3×3 平均にダウンサンプルするオプションを採用。
 */
export function ciede2000Map(
  leftRgba: Uint8ClampedArray,
  rightRgba: Uint8ClampedArray,
  w: number,
  h: number,
): Float32Array {
  const labL = rgbaToLab(leftRgba, w, h);
  const labR = rgbaToLab(rightRgba, w, h);
  const out = new Float32Array(w * h);
  for (let i = 0; i < w * h; i++) {
    out[i] = deltaE00(
      labL[i * 3],
      labL[i * 3 + 1],
      labL[i * 3 + 2],
      labR[i * 3],
      labR[i * 3 + 1],
      labR[i * 3 + 2],
    );
  }
  return normalizeFloat(out);
}

function rgbaToLab(rgba: Uint8ClampedArray, w: number, h: number): Float32Array {
  const out = new Float32Array(w * h * 3);
  for (let i = 0, j = 0; i < rgba.length; i += 4, j += 3) {
    const [L, a, b] = srgbToLab(rgba[i], rgba[i + 1], rgba[i + 2]);
    out[j] = L;
    out[j + 1] = a;
    out[j + 2] = b;
  }
  return out;
}

function srgbToLab(r: number, g: number, b: number): [number, number, number] {
  const lin = (c: number) => {
    const s = c / 255;
    return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  };
  const R = lin(r);
  const G = lin(g);
  const B = lin(b);
  const X = R * 0.4124564 + G * 0.3575761 + B * 0.1804375;
  const Y = R * 0.2126729 + G * 0.7151522 + B * 0.072175;
  const Z = R * 0.0193339 + G * 0.119192 + B * 0.9503041;
  const Xn = 0.95047;
  const Yn = 1.0;
  const Zn = 1.08883;
  const f = (t: number) =>
    t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116;
  const fx = f(X / Xn);
  const fy = f(Y / Yn);
  const fz = f(Z / Zn);
  const L = 116 * fy - 16;
  const a = 500 * (fx - fy);
  const bb = 200 * (fy - fz);
  return [L, a, bb];
}

function deltaE00(
  L1: number,
  a1: number,
  b1: number,
  L2: number,
  a2: number,
  b2: number,
): number {
  const kL = 1;
  const kC = 1;
  const kH = 1;
  const C1 = Math.hypot(a1, b1);
  const C2 = Math.hypot(a2, b2);
  const Cbar = (C1 + C2) / 2;
  const G = 0.5 * (1 - Math.sqrt(Math.pow(Cbar, 7) / (Math.pow(Cbar, 7) + Math.pow(25, 7))));
  const a1p = (1 + G) * a1;
  const a2p = (1 + G) * a2;
  const C1p = Math.hypot(a1p, b1);
  const C2p = Math.hypot(a2p, b2);
  const h1p = atan2Deg(b1, a1p);
  const h2p = atan2Deg(b2, a2p);
  const dLp = L2 - L1;
  const dCp = C2p - C1p;
  let dhp = 0;
  if (C1p * C2p !== 0) {
    const diff = h2p - h1p;
    if (Math.abs(diff) <= 180) dhp = diff;
    else if (diff > 180) dhp = diff - 360;
    else dhp = diff + 360;
  }
  const dHp = 2 * Math.sqrt(C1p * C2p) * Math.sin((dhp * Math.PI) / 360);
  const Lbarp = (L1 + L2) / 2;
  const Cbarp = (C1p + C2p) / 2;
  let Hbarp = h1p + h2p;
  if (C1p * C2p !== 0) {
    if (Math.abs(h1p - h2p) <= 180) Hbarp = (h1p + h2p) / 2;
    else if (h1p + h2p < 360) Hbarp = (h1p + h2p + 360) / 2;
    else Hbarp = (h1p + h2p - 360) / 2;
  }
  const T =
    1 -
    0.17 * Math.cos(deg2rad(Hbarp - 30)) +
    0.24 * Math.cos(deg2rad(2 * Hbarp)) +
    0.32 * Math.cos(deg2rad(3 * Hbarp + 6)) -
    0.2 * Math.cos(deg2rad(4 * Hbarp - 63));
  const SL = 1 + (0.015 * (Lbarp - 50) * (Lbarp - 50)) / Math.sqrt(20 + (Lbarp - 50) * (Lbarp - 50));
  const SC = 1 + 0.045 * Cbarp;
  const SH = 1 + 0.015 * Cbarp * T;
  const dTheta = 30 * Math.exp(-Math.pow((Hbarp - 275) / 25, 2));
  const RC = 2 * Math.sqrt(Math.pow(Cbarp, 7) / (Math.pow(Cbarp, 7) + Math.pow(25, 7)));
  const RT = -RC * Math.sin(deg2rad(2 * dTheta));
  const termL = dLp / (kL * SL);
  const termC = dCp / (kC * SC);
  const termH = dHp / (kH * SH);
  return Math.sqrt(termL * termL + termC * termC + termH * termH + RT * termC * termH);
}

function deg2rad(d: number): number {
  return (d * Math.PI) / 180;
}

function atan2Deg(y: number, x: number): number {
  let d = (Math.atan2(y, x) * 180) / Math.PI;
  if (d < 0) d += 360;
  return d;
}
