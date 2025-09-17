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
});
