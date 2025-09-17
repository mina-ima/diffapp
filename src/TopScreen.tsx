import React from 'react';

export function TopScreen(): JSX.Element {
  return (
    <div>
      <header>
        <h1>Diffapp</h1>
        <p>AIがちがいをみつけるよ</p>
        <button aria-label="設定">⚙️</button>
      </header>
      <main>
        <div>
          <button type="button">左のがぞうをえらぶ</button>
          <button type="button">右のがぞうをえらぶ</button>
        </div>
        <div>
          <button type="button">けんさをはじめる</button>
        </div>
      </main>
    </div>
  );
}

export default TopScreen;
