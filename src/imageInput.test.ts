import { describe, it, expect } from 'vitest';
import { isSupportedImage } from './imageInput';

// 仕様: prompt_spec.md 2.2 画像入力
// - 対応拡張子: jpg/jpeg/png（大文字小文字不問）
// - 入力ファイル名の前後空白は無視して拡張子判定

describe('画像ファイル拡張子の判定 (Webユーティリティ)', () => {
  it('jpg/jpeg/png を大文字小文字不問で受け入れる', () => {
    expect(isSupportedImage('photo.JPG')).toBe(true);
    expect(isSupportedImage('scan.jpeg')).toBe(true);
    expect(isSupportedImage('picture.png')).toBe(true);
  });

  it('前後の空白を無視して判定する', () => {
    expect(isSupportedImage('  photo.jpg  ')).toBe(true);
    expect(isSupportedImage('\tpicture.PNG\n')).toBe(true);
  });

  it('未対応の拡張子は false を返す', () => {
    expect(isSupportedImage('document.pdf')).toBe(false);
    expect(isSupportedImage('archive.zip')).toBe(false);
  });
});
