import { render, screen } from '@testing-library/react';
import { describe, test, expect } from 'vitest';
import React from 'react';
import { TopScreen } from './TopScreen';

// 仕様: prompt_spec.md の「2.1 トップ画面」に基づく最低要件
// - キャッチコピー: "AIがちがいをみつけるよ"
// - 左右の画像選択ボタン
// - 「けんさをはじめる」ボタン
// - 設定アイコン（ここでは aria-label="設定" のボタンで代替）

describe('TopScreen (仕様: トップ画面)', () => {
  test('キャッチコピーを表示する', () => {
    render(<TopScreen />);
    expect(screen.getByText('AIがちがいをみつけるよ')).toBeInTheDocument();
  });

  test('左右の画像選択ボタンを表示する', () => {
    render(<TopScreen />);
    expect(screen.getByRole('button', { name: '左のがぞうをえらぶ' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '右のがぞうをえらぶ' })).toBeInTheDocument();
  });

  test('「けんさをはじめる」ボタンを表示する', () => {
    render(<TopScreen />);
    expect(screen.getByRole('button', { name: 'けんさをはじめる' })).toBeInTheDocument();
  });

  test('設定ボタンを表示する（aria-label="設定"）', () => {
    render(<TopScreen />);
    expect(screen.getByRole('button', { name: '設定' })).toBeInTheDocument();
  });

  test('主要ボタンのタップ領域が48x48以上である', () => {
    render(<TopScreen />);
    const left = screen.getByRole('button', { name: '左のがぞうをえらぶ' });
    const right = screen.getByRole('button', { name: '右のがぞうをえらぶ' });
    const start = screen.getByRole('button', { name: 'けんさをはじめる' });
    const settings = screen.getByRole('button', { name: '設定' });

    // JSDOMではレイアウト計算がないため、style属性の最小寸法を検証する
    const assertMinSize = (el: HTMLElement) => {
      const style = (el as HTMLElement).style;
      expect(style.minWidth).toBeDefined();
      expect(style.minHeight).toBeDefined();
      expect(style.minWidth).toMatch(/48(px)?/);
      expect(style.minHeight).toMatch(/48(px)?/);
    };

    assertMinSize(left);
    assertMinSize(right);
    assertMinSize(start);
    assertMinSize(settings);
  });
});
