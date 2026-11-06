"use client";
import React from "react";

// Loading animation: a gift box slides in, the lid pops open with a heart and confetti, then it slides away.
// Colours follow the store's primary colour (--primary-color).
const css = `
    .gl-box{animation:gl-slide 2.8s cubic-bezier(.45,0,.2,1) infinite}
    .gl-shadow{transform-box:fill-box;transform-origin:center;animation:gl-shadow 2.8s ease-in-out infinite}
    .gl-lid{transform-box:fill-box;transform-origin:0% 100%;animation:gl-lid 2.8s cubic-bezier(.3,1.4,.5,1) infinite}
    .gl-spark{opacity:0;animation:gl-pop 2.8s ease-out infinite}
    .gl-s2{animation-delay:.08s}.gl-s3{animation-delay:.16s}.gl-s4{animation-delay:.05s}.gl-s5{animation-delay:.12s}
    .gl-heart{opacity:0;transform-box:fill-box;transform-origin:center;animation:gl-heart 2.8s ease-out infinite}
    @keyframes gl-slide{
      0%{transform:translateX(-95px);opacity:0}
      6%{opacity:1}
      28%,70%{transform:translateX(0);opacity:1}
      94%{opacity:1}
      100%{transform:translateX(95px);opacity:0}}
    @keyframes gl-shadow{0%{opacity:0;transform:scaleX(.4)}28%,70%{opacity:.28;transform:scaleX(1)}100%{opacity:0;transform:scaleX(.4)}}
    @keyframes gl-lid{
      0%,36%{transform:translate(0,0) rotate(0)}
      46%{transform:translate(-7px,-26px) rotate(-30deg)}
      52%{transform:translate(-5px,-22px) rotate(-24deg)}
      62%{transform:translate(-5px,-22px) rotate(-24deg)}
      72%,100%{transform:translate(0,0) rotate(0)}}
    @keyframes gl-pop{
      0%,38%{opacity:0;transform:translate(0,0) scale(.3)}
      46%{opacity:1}
      62%{opacity:1}
      74%,100%{opacity:0;transform:translate(var(--dx),var(--dy)) scale(1)}}
    @keyframes gl-heart{
      0%,40%{opacity:0;transform:translateY(0) scale(.2)}
      50%{opacity:1;transform:translateY(-14px) scale(1.15)}
      64%{opacity:1;transform:translateY(-30px) scale(1)}
      76%,100%{opacity:0;transform:translateY(-40px) scale(.9)}}
  
.gl-wrap{--gl-primary:var(--primary-color,#fe3c5e);--gl-dark:color-mix(in srgb,var(--gl-primary) 82%,#000)}
@media (prefers-reduced-motion:reduce){.gl-box,.gl-lid,.gl-spark,.gl-heart,.gl-shadow{animation-duration:6s}}`;

export default function GiftLoader({ size = 120, className = "" }: { size?: number; className?: string }) {
  return (
    <span
      className={`gl-wrap inline-block ${className}`}
      style={{ width: size, height: (size * 120) / 160 }}
      role="status"
      aria-label="Loading"
    >
      <style>{css}</style>
      <svg viewBox="0 0 160 120" width="100%" height="100%" aria-hidden="true">

  <ellipse className="gl-shadow" cx="80" cy="104" rx="38" ry="5" fill="#1a1a2e"/>
  <g className="gl-box">
    
    <path className="gl-heart" d="M80 62c-6-9-17-3-12 5 3 5 12 10 12 10s9-5 12-10c5-8-6-14-12-5z" fill="#ff8fa3"/>
    <circle className="gl-spark" style={{ '--dx': '-30px', '--dy': '-34px' } as React.CSSProperties} cx="80" cy="60" r="3.2" fill="#ffc83d"/>
    <circle className="gl-spark gl-s2" style={{ '--dx': '30px', '--dy': '-30px' } as React.CSSProperties} cx="80" cy="60" r="2.6" fill="#7ad7c8"/>
    <rect className="gl-spark gl-s3" style={{ '--dx': '-18px', '--dy': '-48px' } as React.CSSProperties} x="78" y="58" width="5" height="5" rx="1" fill="var(--gl-primary)"/>
    <rect className="gl-spark gl-s4" style={{ '--dx': '20px', '--dy': '-46px' } as React.CSSProperties} x="78" y="58" width="5" height="5" rx="1" fill="#ffc83d"/>
    <circle className="gl-spark gl-s5" style={{ '--dx': '2px', '--dy': '-52px' } as React.CSSProperties} cx="80" cy="60" r="2.2" fill="#fff"/>
    
    <rect x="52" y="66" width="56" height="38" rx="5" fill="var(--gl-primary)"/>
    <rect x="52" y="66" width="56" height="9" fill="var(--gl-dark)" opacity=".35"/>
    <rect x="76" y="66" width="8" height="38" fill="#fff3f5"/>
    <rect x="56" y="70" width="4" height="28" rx="2" fill="#fff" opacity=".28"/>
    
    <g className="gl-lid">
      <rect x="48" y="52" width="64" height="16" rx="5" fill="var(--gl-dark)"/>
      <rect x="76" y="52" width="8" height="16" fill="#fff3f5"/>
      <path d="M80 52c-7-14-22-10-18-2 2 4 12 4 18 2z" fill="#fff3f5" stroke="var(--gl-primary)" strokeWidth="2.2" strokeLinejoin="round"/>
      <path d="M80 52c7-14 22-10 18-2-2 4-12 4-18 2z" fill="#fff3f5" stroke="var(--gl-primary)" strokeWidth="2.2" strokeLinejoin="round"/>
      <circle cx="80" cy="52" r="4" fill="#ff8fa3"/>
    </g>
  </g>

      </svg>
    </span>
  );
}
