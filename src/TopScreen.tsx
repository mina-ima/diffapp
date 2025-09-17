import React from 'react';

export function TopScreen(): JSX.Element {
  const tapTargetStyle: React.CSSProperties = { minWidth: 48, minHeight: 48 };
  return (
    <div>
      <header>
        <h1>Diffapp</h1>
        <p>AIがちがいをみつけるよ</p>
        <button aria-label="設定" style={tapTargetStyle}>
          ⚙️
        </button>
      </header>
      <main>
        <div>
          <button type="button" style={tapTargetStyle}>
            左のがぞうをえらぶ
          </button>
          <button type="button" style={tapTargetStyle}>
            右のがぞうをえらぶ
          </button>
        </div>
        <div>
          <button type="button" style={tapTargetStyle}>
            けんさをはじめる
          </button>
        </div>
      </main>
    </div>
  );
}

export default TopScreen;
