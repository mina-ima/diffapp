// 画像入力関連の小ユーティリティ（Web 側）
// 仕様: prompt_spec.md 2.2 に基づく拡張子判定

const SUPPORTED_EXTS = ['jpg', 'jpeg', 'png'];

export function isSupportedImage(filename: string): boolean {
  if (!filename) return false;
  const trimmed = filename.trim();
  const dot = trimmed.lastIndexOf('.');
  if (dot < 0 || dot === trimmed.length - 1) return false;
  const ext = trimmed.slice(dot + 1).toLowerCase();
  return SUPPORTED_EXTS.includes(ext);
}
