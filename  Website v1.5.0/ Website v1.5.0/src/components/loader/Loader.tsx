'use client';

import React from 'react';
// import { useTheme } from 'next-themes';
import GiftLoader from './GiftLoader';

interface LoaderProps {
  background?: string;
  height?: string | number;
  width?: string | number;
  screen?: string;
  size?: number;
}

/** Loading indicator: the animated gift box (full-screen overlay when screen="full"). */
const Loader = ({ background, height, width, screen, size }: LoaderProps) => {
  if (screen === 'full') {
    return (
      <div className="fixed inset-0 z-[999] flex items-center justify-center bg-white">
        <GiftLoader size={180} />
      </div>
    );
  }

  const dim = Math.max(size || 36, 40);
  return (
    <div
      className="flex items-center justify-center"
      style={{
        width,
        height,
        background: background || 'transparent',
      }}
    >
      <GiftLoader size={dim * 1.8} />
    </div>
  );
};

export default Loader;
