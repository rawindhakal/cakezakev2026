const isOnScreen = (el: Element) => {
  const r = el.getBoundingClientRect();
  return (
    r.width > 0 &&
    r.height > 0 &&
    r.bottom > 0 &&
    r.right > 0 &&
    r.top < window.innerHeight &&
    r.left < window.innerWidth
  );
};

// Nearest *visible* img walking up from `source`. Visibility matters: the cards
// render a md:hidden mobile gallery before the desktop one, so the first img in
// the card is display:none on desktop and vice versa.
const nearestImage = (source: HTMLElement) => {
  let card: HTMLElement | null = source;
  while (card) {
    const visible = Array.from(card.querySelectorAll("img")).find(isOnScreen);
    if (visible) return visible;
    card = card.parentElement;
  }
  return null;
};

const rect = (left: number, top: number, size = 36) =>
  ({ left, top, width: size, height: size }) as DOMRect;

// Where the mobile "View Cart" pill sits (MobileViewCartPill): bottom centre,
// above the bottom nav. Used when the pill has not mounted yet — the phone's
// cart is always down there, so the flight must never head for the header.
const mobilePillRect = () => rect(window.innerWidth / 2 - 18, window.innerHeight - 110);

// Corner the desktop header cart occupies, for when no icon is on screen.
const headerCornerRect = () => {
  const rtl = document.documentElement.dir === "rtl";
  return rect(rtl ? 16 : window.innerWidth - 52, 16, 24);
};

// Landing feedback on the cart icon: a bounce on the icon itself plus a ring
// drawn on <body>, so an anchor inside an overflow-hidden pill is not clipped.
const pulseAnchor = (el?: HTMLElement) => {
  if (!el) return;

  el.animate(
    [
      { transform: "scale(1)" },
      { transform: "scale(1.35)", offset: 0.35 },
      { transform: "scale(0.92)", offset: 0.6 },
      { transform: "scale(1.08)", offset: 0.8 },
      { transform: "scale(1)" },
    ],
    { duration: 480, easing: "ease-out" },
  );

  const r = el.getBoundingClientRect();
  const size = Math.max(r.width, r.height);
  const color =
    getComputedStyle(document.documentElement)
      .getPropertyValue("--primary-color")
      .trim() || "#2A55E5";

  const ring = document.createElement("span");
  ring.style.cssText = `position:fixed;left:${r.left + r.width / 2 - size / 2}px;top:${r.top + r.height / 2 - size / 2}px;width:${size}px;height:${size}px;border:2px solid ${color};border-radius:9999px;z-index:9998;pointer-events:none;will-change:transform,opacity;`;
  document.body.appendChild(ring);

  const pulse = ring.animate(
    [
      { transform: "scale(0.6)", opacity: 0.7 },
      { transform: "scale(1.9)", opacity: 0 },
    ],
    { duration: 520, easing: "cubic-bezier(0.2, 0.7, 0.3, 1)" },
  );
  pulse.onfinish = () => ring.remove();
  pulse.oncancel = () => ring.remove();
};

// The first add mounts the cart pill only once the cart request resolves, which
// is well after a 700ms flight. Hold take-off until it is there (or give up).
const waitForTarget = (
  resolve_: () => HTMLElement | undefined,
  maxMs: number,
): Promise<HTMLElement | undefined> => {
  const found = resolve_();
  if (found) return Promise.resolve(found);
  return new Promise((resolve) => {
    let done = false;
    const finish = (el?: HTMLElement) => {
      if (done) return;
      done = true;
      observer.disconnect();
      clearTimeout(timer);
      resolve(el);
    };
    const observer = new MutationObserver(() => {
      const el = resolve_();
      if (el) finish(el);
    });
    observer.observe(document.body, { childList: true, subtree: true });
    const timer = setTimeout(() => finish(undefined), maxMs);
  });
};

// Flies a product image to the cart. `imageSelector` picks a specific container
// (e.g. PDP gallery); otherwise the nearest img to `source` is used.
export const flyToCart = (source: HTMLElement | null, imageSelector?: string) => {
  if (typeof window === "undefined" || !source) return;
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

  const picked = imageSelector
    ? Array.from(document.querySelectorAll(`${imageSelector} img`)).find(isOnScreen)
    : null;
  const img = (picked ?? (source ? nearestImage(source) : null)) as HTMLImageElement | null;
  if (!img) return;

  if (!img.getBoundingClientRect().width) return;

  const isPhone = window.matchMedia("(max-width: 767px)").matches;
  const src = img.currentSrc || img.src;

  // On a phone the cart lives at the bottom, on desktop in the header. Pick the
  // matching on-screen anchor and never cross over: flying up on a phone (or
  // waiting for the pill to mount) is what broke both layouts.
  const resolveTarget = () => {
    const anchors = Array.from(
      document.querySelectorAll<HTMLElement>("[data-cart-target]"),
    ).filter(isOnScreen);
    return isPhone
      ? anchors.find((el) => Number(el.dataset.cartPriority ?? 0) > 0)
      : anchors[0];
  };

  const targetRect = (el?: HTMLElement) =>
    el
      ? el.getBoundingClientRect()
      : isPhone
        ? mobilePillRect()
        : headerCornerRect();

  const launch = (target?: HTMLElement) => {
    // Measured here, not at click time: the wait below can span a scroll.
    const from = img.getBoundingClientRect();
    if (!from.width || !from.height || !isOnScreen(img)) return;
    const to = targetRect(target);

    // Shrunk copy of the product image, no plate behind it: a full-size copy
    // looked like a second card sliding across the grid.
    const size = Math.min(from.width, from.height, 72);
    const cx = from.left + from.width / 2;
    const cy = from.top + from.height / 2;

    const clone = document.createElement("img");
    clone.src = src;
    clone.alt = "";
    clone.style.cssText = `position:fixed;left:${cx - size / 2}px;top:${cy - size / 2}px;width:${size}px;height:${size}px;object-fit:contain;z-index:9999;pointer-events:none;will-change:transform,opacity;`;
    document.body.appendChild(clone);

    const dx = to.left + to.width / 2 - cx;
    const dy = to.top + to.height / 2 - cy;
    // Land at the anchor's own size so the image is still visible when it
    // arrives, instead of shrinking to a speck short of the icon.
    const anchorSize = Math.min(to.width, to.height) || 32;
    const endScale = Math.max(Math.min(anchorSize / size, 1), 0.12);
    // Bow along the direction of travel, sized to the trip: a flat 60px lift
    // looked like a lurch on the short hops a phone grid produces.
    const bow = Math.min(Math.max(Math.abs(dy) * 0.18, 8), 48) * (dy < 0 ? -1 : 1);

    const flight = clone.animate(
      [
        { transform: "translate(0, 0) scale(1)", opacity: 1 },
        {
          transform: `translate(${dx * 0.5}px, ${dy * 0.5 + bow}px) scale(${(1 + endScale) / 2})`,
          opacity: 0.9,
          offset: 0.5,
        },
        {
          transform: `translate(${dx}px, ${dy}px) scale(${endScale})`,
          opacity: 1,
          offset: 0.88,
        },
        { transform: `translate(${dx}px, ${dy}px) scale(${endScale * 0.7})`, opacity: 0 },
      ],
      { duration: 620, easing: "cubic-bezier(0.4, 0, 0.6, 1)" },
    );

    flight.oncancel = () => clone.remove();
    flight.onfinish = () => {
      clone.remove();
      pulseAnchor(target ?? resolveTarget());
    };
  };

  const ready = resolveTarget();
  if (ready) {
    launch(ready);
    return;
  }
  // No anchor yet (first add): wait for the pill rather than flying at a guess.
  // If it never arrives on a phone (routes that hide it), skip the flight.
  void waitForTarget(resolveTarget, 1500).then((el) => {
    if (!el && isPhone) return;
    // The pill slides up over ~300ms; measuring it the instant it mounts aims
    // the flight ~16px below where the icon ends up.
    if (el) setTimeout(() => launch(el), 340);
    else launch(el);
  });
};
