<template>
  <div class="wheel-preview">
    <!-- The card the customer sees: everything on it is derived from the theme — the
         one background colour gives the gradients, glow and panel shades; the pointer,
         rim and button take their own colours. -->
    <div class="wheel-card" :style="cardStyle">
      <div class="wheel-title" v-if="titleLines.length">
        <span class="wheel-title-top" :style="titleStyle(1)">{{ titleLines[0] }}</span>
        <span class="wheel-title-main" v-if="titleLines[1]" :style="titleStyle(2)">{{ titleLines[1] }}</span>
      </div>

      <div class="wheel-stage">
        <!-- Feet: a chamfered strip either side of the cabinet, tucked behind the
             backplate so only the part outside its edge shows. -->
        <svg class="wheel-wings" viewBox="0 0 800 355" aria-hidden="true">
          <defs>
            <linearGradient :id="wingId" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" :stop-color="shade(colors.bg, 0.3)" />
              <stop offset="40%" :stop-color="shade(colors.bg, -0.4)" />
              <stop offset="100%" :stop-color="shade(colors.bg, -0.65)" />
            </linearGradient>
          </defs>
          <!-- Pillars filling the corner between the backplate's edge and the wider
               cabinet: a slanted top running down into the cabinet. -->
          <path d="M 76 -100 L 10 -30 L 10 250 L 76 250 Z" :fill="`url(#${wingId})`" :stroke="shade(colors.bg, 0.4)" stroke-width="2" stroke-linejoin="round" />
          <path d="M 724 -100 L 790 -30 L 790 250 L 724 250 Z" :fill="`url(#${wingId})`" :stroke="shade(colors.bg, 0.4)" stroke-width="2" stroke-linejoin="round" />
        </svg>

        <!-- Backplate: the brand-coloured card the wheel is mounted on. -->
        <div class="wheel-backplate" :style="backplateStyle"></div>

        <svg :viewBox="`0 0 ${box} ${box}`" class="wheel-svg" role="img" :aria-label="__('wheel_preview')">
          <defs>
            <radialGradient v-for="w in wedges" :key="'g' + w.key" :id="gradientId(w)"
              gradientUnits="userSpaceOnUse" :cx="center" :cy="center" :r="radius">
              <stop offset="0%" :stop-color="w.light" />
              <stop offset="55%" :stop-color="w.color" />
              <stop offset="100%" :stop-color="w.dark" />
            </radialGradient>
            <linearGradient :id="rimId" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" :stop-color="rim.light" />
              <stop offset="50%" :stop-color="rim.base" />
              <stop offset="100%" :stop-color="rim.dark" />
            </linearGradient>
            <linearGradient :id="pointerId" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" :stop-color="pointer.light" />
              <stop offset="100%" :stop-color="pointer.dark" />
            </linearGradient>
            <radialGradient :id="hubId" cx="50%" cy="40%" r="60%">
              <stop offset="0%" :stop-color="rim.light" />
              <stop offset="100%" :stop-color="rim.dark" />
            </radialGradient>
            <clipPath :id="hubClipId">
              <circle :cx="center" :cy="center" :r="hub - 8" />
            </clipPath>
          </defs>

          <!-- Rim: a thick ring with a row of bulbs around it. -->
          <circle :cx="center" :cy="center" :r="radius + 7" fill="none" :stroke="`url(#${rimId})`" stroke-width="16" />
          <circle v-for="(b, i) in bulbs" :key="'b' + i" :cx="b.x" :cy="b.y" r="3.2" fill="#ffffff" />

          <!-- Everything that turns. Wedges are equal-sized whatever the odds are: the
               wheel is a layout, the odds decide where it stops. -->
          <g :style="rotorStyle">
            <template v-if="wedges.length === 1">
              <circle :cx="center" :cy="center" :r="radius" :fill="fillFor(wedges[0])"
                :opacity="wedges[0].available ? 1 : 0.35" class="wheel-wedge" @click="$emit('select', 0)" />
            </template>
            <template v-else>
              <path v-for="w in wedges" :key="'p' + w.key" :d="w.path" :fill="fillFor(w)"
                :stroke="w.selected ? '#ffffff' : 'none'" :stroke-width="w.selected ? 4 : 0"
                :opacity="w.available ? 1 : 0.35" class="wheel-wedge" @click="$emit('select', w.index)" />
              <line v-for="w in wedges" :key="'dv' + w.key" :x1="center" :y1="center" :x2="w.edge.x" :y2="w.edge.y"
                :stroke="lineColor" stroke-width="3" stroke-linecap="round" pointer-events="none" />
            </template>

            <g v-for="w in wedges" :key="'l' + w.key" :transform="`rotate(${w.mid} ${center} ${center})`">
              <g :transform="w.flip ? `rotate(180 ${labelX} ${center})` : ''" :opacity="w.available ? 1 : 0.45">
                <image v-if="w.showIcon && w.icon_url" :href="w.icon_url" :x="labelX - iconSize / 2"
                  :y="iconY(w)" :width="iconSize" :height="iconSize" preserveAspectRatio="xMidYMid meet" />
                <text v-if="w.showLabel" :x="labelX" :y="textY(w)" :fill="w.text_color" :font-size="fontSize"
                  text-anchor="middle" dominant-baseline="middle" font-weight="700">
                  {{ trim(w.label) }}
                </text>
              </g>
            </g>
          </g>

          <!-- Hub: a gold disc carrying the brand mark. -->
          <circle :cx="center" :cy="center" :r="hub" :fill="`url(#${hubId})`" />
          <image v-if="hubIconUrl" :href="hubIconUrl" :x="center - hub + 8" :y="center - hub + 8"
            :width="(hub - 8) * 2" :height="(hub - 8) * 2" preserveAspectRatio="xMidYMid meet"
            :clip-path="`url(#${hubClipId})`" />

          <!-- Pointer, hanging down from the top edge. -->
          <polygon :points="pointerPoints" :fill="`url(#${pointerId})`" :stroke="pointer.dark" stroke-width="2"
            stroke-linejoin="round" />
        </svg>

        <div class="wheel-stand">
          <svg class="wheel-stand-svg" viewBox="0 0 800 355" aria-hidden="true" :style="{ filter: `drop-shadow(0 12px 20px ${cab.shadow})` }">
            <defs>
              <linearGradient :id="cabBodyId" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0" :stop-color="cab.c1" />
                <stop offset="1" :stop-color="cab.c2" />
              </linearGradient>
              <linearGradient :id="cabInnerId" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" :stop-color="cab.c1" />
                <stop offset="25%" :stop-color="cab.c2" />
                <stop offset="50%" :stop-color="cab.c3" />
                <stop offset="75%" :stop-color="cab.c4" />
                <stop offset="100%" :stop-color="cab.c5" />
              </linearGradient>
              <linearGradient :id="cabBaseId" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0" :stop-color="cab.c3" />
                <stop offset="1" :stop-color="cab.c5" />
              </linearGradient>
              <clipPath :id="cabClipId"><path :d="cabinetPath" /></clipPath>
            </defs>
            <!-- Plinth, painted first so the cabinet covers all but its lower band. -->
            <path :d="basePath" :fill="`url(#${cabBaseId})`" :stroke="shade(colors.bg, 0.4)" stroke-opacity=".3" stroke-width="1.5" stroke-linejoin="round" />
            <path :d="cabinetPath" :fill="`url(#${cabBodyId})`" :stroke="cab.stroke" stroke-width="3" stroke-linejoin="round" />
            <g :clip-path="`url(#${cabClipId})`">
              <path :d="panelPath" :fill="`url(#${cabInnerId})`" />
            </g>
          </svg>

          <span v-for="(d, i) in standDots" :key="'d' + i" class="wheel-stand-dot" :class="{ 'is-on': lightOn(d.row) }"
            :style="dotStyle(d)"></span>

          <div class="wheel-key-wrap">
            <button type="button" class="wheel-key" :disabled="spinning || !canSpin" @click="spin">
              <span class="wheel-key-cradle" :style="{ background: key.cradle }"></span>
              <span class="wheel-key-lip" :style="{ background: `linear-gradient(180deg, ${key.lipBottom} 0%, ${key.lipTop} 100%)` }"></span>
              <span class="wheel-key-face" :style="keyFaceStyle">{{ spinning ? '…' : buttonText }}</span>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Result of the last test spin. Nothing is issued — this only rolls the odds. -->
    <div class="wheel-result" v-if="result">
      <span class="wheel-result-pill" :class="result.isWin ? 'is-win' : 'is-loss'">
        {{ result.label }}
      </span>
      <small class="text-muted d-block">{{ result.detail }}</small>
    </div>
    <div class="wheel-result" v-else>
      <small class="text-muted">{{ __('click_spin_to_test_the_odds') }}</small>
    </div>

    <div class="wheel-foot">
      <span class="wheel-total" :class="isBalanced ? 'is-ok' : 'is-bad'">
        {{ __('total_win_chance') }}: {{ round(totalChance) }}% / 100%
      </span>
      <small class="text-muted">{{ __('wedges_are_equal_sized_hint') }}</small>
    </div>
  </div>
</template>

<script>
/**
 * The wheel as the customer sees it, plus a test spin for the admin.
 *
 * Two things are deliberately separate here: every wedge gets an equal slice of the
 * circle (a 2% prize drawn as a sliver would be unreadable and is not how the app draws
 * it), while where the wheel STOPS is rolled from win_chance — the same weighted draw
 * the server does, minus the prize. Nothing is written; this only shows the odds.
 *
 * Hand-rolled SVG rather than a chart library: a pie chart cannot put a label and an
 * icon on each wedge, nor spin to a chosen one.
 */
const DEFAULTS = {
  bg_color: '#FE3C5E',
  pointer_color: '#f4b400',
  border_color: '#f4b400',
  button_color: '#f4b400',
  button_text: 'SPIN',
  title_color: '#b9f2c3',
  light_color: '#ffffff',
};

/** Any CSS colour the picker can produce → {r, g, b, a}, or null when unreadable. */
function parseColor(value) {
  const text = String(value || '').trim();
  const hex = text.match(/^#([0-9a-f]{3,8})$/i);
  if (hex) {
    let h = hex[1];
    if (h.length === 3 || h.length === 4) h = h.split('').map(c => c + c).join('');
    const num = parseInt(h.slice(0, 6), 16);
    return {
      r: (num >> 16) & 255, g: (num >> 8) & 255, b: num & 255,
      a: h.length === 8 ? parseInt(h.slice(6, 8), 16) / 255 : 1,
    };
  }
  const rgb = text.match(/^rgba?\(([^)]+)\)$/i);
  if (rgb) {
    const parts = rgb[1].split(',').map(p => parseFloat(p));
    if (parts.length >= 3) {
      return { r: parts[0], g: parts[1], b: parts[2], a: parts.length > 3 ? parts[3] : 1 };
    }
  }
  return null;
}

/** Mix a colour toward white (ratio > 0) or black (ratio < 0). */
function shade(value, ratio) {
  const c = parseColor(value);
  if (!c) return value;
  const target = ratio >= 0 ? 255 : 0;
  const k = Math.abs(ratio);
  const mix = (channel) => Math.round(channel + (target - channel) * k);

  return `rgba(${mix(c.r)}, ${mix(c.g)}, ${mix(c.b)}, ${c.a})`;
}

/** Dark text on a light colour, light text on a dark one. */
function contrastText(value) {
  const c = parseColor(value);
  if (!c) return '#1f2937';
  const lum = (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) / 255;
  return lum > 0.6 ? '#1f2937' : '#ffffff';
}

const PALETTE = ['#f97316', '#0ea5e9', '#22c55e', '#a855f7', '#ef4444', '#eab308', '#14b8a6', '#ec4899'];

export default {
  name: 'WheelPreview',
  props: {
    // Each: { id, label, win_chance, color, text_color, display_mode, icon_url,
    //         type, available, prize } — `available` false = not offered in the
    //         previewed country, `prize` is the line shown when it is landed on.
    segments: { type: Array, default: () => [] },
    // { bg_color, pointer_color, border_color, button_color, button_text, hub_icon_url, segment_fill }
    theme: { type: Object, default: () => ({}) },
    title: { type: String, default: '' },
    // Highlights the wedge being edited, so list, wheel and form agree on "this one".
    selectedIndex: { type: Number, default: -1 },
  },
  emits: ['spun', 'select'],
  data() {
    return {
      box: 340, hub: 42, fontSize: 11, iconSize: 20,
      rotation: 0,
      spinning: false,
      result: null,
      lightStep: 0,
      _timer: null,
      _lights: null,
    };
  },
  computed: {
    center() { return this.box / 2; },
    radius() { return this.center - 26; },
    labelX() { return this.center + this.radius * 0.62; },
    rimId() { return 'sw-rim-' + this._uid; },
    pointerId() { return 'sw-ptr-' + this._uid; },
    hubClipId() { return 'sw-hub-' + this._uid; },
    hubId() { return 'sw-hubg-' + this._uid; },
    cabBodyId() { return 'sw-cab-' + this._uid; },
    cabInnerId() { return 'sw-cabi-' + this._uid; },
    cabClipId() { return 'sw-cabc-' + this._uid; },
    cabBaseId() { return 'sw-cabb-' + this._uid; },
    wingId() { return 'sw-wing-' + this._uid; },
    // Cabinet outline: the top edge ramps up from each shoulder to a crowned centre.
    cabinetPath() {
      return 'M 8 105 Q 8 78 36 68 L 310 10 Q 400 -8 490 10 L 764 68 Q 792 78 792 105 L 792 250 Q 792 294 748 294 L 52 294 Q 8 294 8 250 Z';
    },
    // The plinth the cabinet stands on — a darker slab showing below its bottom edge.
    basePath() {
      return 'M 8 240 L 792 240 L 792 318 Q 792 350 760 350 L 40 350 Q 8 350 8 318 Z';
    },
    // The recessed panel, the same ramp-and-crown inset by a uniform band.
    panelPath() {
      return 'M 36 134 Q 36 112 62 103 L 322 52 Q 400 36 478 52 L 738 103 Q 764 112 764 134 L 764 244 Q 764 266 742 266 L 58 266 Q 36 266 36 244 Z';
    },
    // Three bulbs per side, seated inside the panel; % of the 800x355 box.
    standDots() {
      const out = [];
      [74, 726].forEach(x => [155, 195, 235].forEach((y, row) => out.push({ left: (x / 800 * 100) + '%', top: (y / 355 * 100) + '%', row: row + 1 })));
      return out;
    },
    // Cabinet ramp, lightest to darkest, all mixes of the one background colour.
    cab() {
      const bg = this.colors.bg;
      return {
        c1: shade(bg, 0.45), c2: shade(bg, 0.22), c3: shade(bg, -0.28), c4: shade(bg, -0.48), c5: shade(bg, -0.54),
        stroke: shade(bg, 0.78), shadow: shade(bg, -0.78),
      };
    },
    // The Spin key: a cap over its own underside, seated in a dark cradle.
    key() {
      const b = this.colors.button;
      return {
        top: shade(b, 0.62), mid: shade(b, 0.28), bottom: b,
        lipTop: shade(b, -0.2), lipBottom: shade(b, -0.42),
        cradle: shade(b, -0.76), text: shade(b, -0.62),
      };
    },
    keyFaceStyle() {
      const k = this.key;
      return {
        background: `linear-gradient(180deg, ${k.top} 0%, ${k.mid} 45%, ${k.bottom} 100%)`,
        color: this.colors.buttonText || k.text,
        boxShadow: `inset 0 1.5px 0 rgba(255,255,255,.75), inset 0 -2px 3px ${shade(this.colors.button, -0.3)}`,
      };
    },
    // Bulbs spaced around the rim.
    bulbs() {
      const n = 24, r = this.radius + 7, out = [];
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2;
        out.push({ x: this.center + r * Math.cos(a), y: this.center + r * Math.sin(a) });
      }
      return out;
    },
    pointerPoints() {
      const c = this.center, top = this.center - this.radius - 22;
      return `${c - 13},${top} ${c + 13},${top} ${c},${top + 30}`;
    },
    colors() {
      const t = this.theme || {};
      return {
        bg: t.bg_color || window.adminThemeColor || DEFAULTS.bg_color,
        pointer: t.pointer_color || DEFAULTS.pointer_color,
        rim: t.border_color || DEFAULTS.border_color,
        button: t.button_color || DEFAULTS.button_color,
        buttonText: t.button_text_color || '',
        light: t.light_color || DEFAULTS.light_color,
      };
    },
    // Dividers, the inner ring and the hub's edge all take the background colour, so
    // the wheel reads as one piece with the deck behind it.
    lineColor() { return (this.theme || {}).line_color || shade(this.colors.bg, -0.35); },
    rim() {
      return { base: this.colors.rim, light: shade(this.colors.rim, 0.45), dark: shade(this.colors.rim, -0.3) };
    },
    pointer() {
      return { base: this.colors.pointer, light: shade(this.colors.pointer, 0.4), dark: shade(this.colors.pointer, -0.3) };
    },
    buttonText() {
      const t = String((this.theme || {}).button_text || '').trim();
      return t || DEFAULTS.button_text;
    },
    hubIconUrl() {
      return (this.theme || {}).hub_icon_url || '';
    },
    // Everything purple is a shade of the one background colour: the near-black
    // backdrop, the deck behind the wheel, the control bar and the title lettering.
    cardStyle() {
      const bg = this.colors.bg;
      return {
        background: `linear-gradient(180deg, ${shade(bg, -0.7)} 0%, ${shade(bg, -0.62)} 100%)`,
      };
    },
    // Dark at the top, lit toward the bottom by the cabinet's own glow.
    backplateStyle() {
      const bg = this.colors.bg;
      return {
        background: `linear-gradient(180deg, ${shade(bg, -0.58)} 0%, ${shade(bg, -0.53)} 25%, ${shade(bg, -0.47)} 50%, ${shade(bg, -0.1)} 85%, ${bg} 100%)`,
        border: `1px solid ${shade(bg, 0.68)}`,
        borderBottomWidth: '0',
        boxShadow: `0 4px 12px ${shade(bg, -0.78)}55, 0 18px 48px ${shade(bg, -0.78)}66`,
      };
    },
    // "spin the wheel" → ["spin", "the wheel"]: break only at the first space.
    titleLines() {
      const text = String(this.title || '').trim();
      if (!text) return [];
      const i = text.indexOf(' ');
      return i < 0 ? [text] : [text.slice(0, i), text.slice(i + 1).trim()];
    },
    rotorStyle() {
      return {
        transform: `rotate(${this.rotation}deg)`,
        transformOrigin: `${this.center}px ${this.center}px`,
        transition: this.spinning ? 'transform 3.4s cubic-bezier(.16,.84,.25,1)' : 'none',
      };
    },
    isGlossy() {
      return (this.theme || {}).segment_fill === 'glossy';
    },
    sweep() {
      return this.segments.length ? 360 / this.segments.length : 360;
    },
    totalChance() {
      return (this.segments || []).reduce((sum, s) => sum + (Number(s.win_chance) || 0), 0);
    },
    isBalanced() {
      return Math.abs(this.totalChance - 100) < 0.01;
    },
    canSpin() {
      return this.segments.length > 0;
    },
    wedges() {
      const sweep = this.sweep;
      return (this.segments || []).map((s, i) => {
        const start = -90 + i * sweep;
        const mid = start + sweep / 2;
        const mode = s.display_mode || 'both';
        const norm = ((mid % 360) + 360) % 360;
        const color = s.color || PALETTE[i % PALETTE.length];

        return {
          key: s.id != null ? s.id : 'n' + i,
          index: i,
          selected: i === this.selectedIndex,
          label: s.label || '',
          icon_url: s.icon_url || '',
          color,
          text_color: s.text_color || '#ffffff',
          available: s.available !== false,
          showLabel: mode !== 'icon',
          showIcon: mode !== 'name',
          light: shade(color, 0.32),
          dark: shade(color, -0.16),
          path: this.arc(start, start + sweep),
          edge: this.point(start),
          mid,
          // Past the halfway mark a radial label would read upside down.
          flip: norm > 90 && norm < 270,
        };
      });
    },
  },
  methods: {
    shade,
    // Each title line has its own colour; the outline is a lighter tint of it and the
    // drop shadow a darker one, so any colour the admin picks still reads as lettering.
    titleStyle(line) {
      const t = this.theme || {};
      const first = t.title_color || DEFAULTS.title_color;
      const c = (line === 1 ? first : (t.title_color_2 || first));
      const edge = parseColor(first) || { r: 255, g: 255, b: 255 };
      const strokeAlpha = line === 1 ? 0.45 : 1;
      return {
        color: c,
        '-webkit-text-stroke': `2px rgba(${edge.r}, ${edge.g}, ${edge.b}, ${strokeAlpha})`,
        textShadow: `0 3px 0 ${shade(first, -0.5)}, 0 6px 14px rgba(0,0,0,.55)`,
      };
    },
    arc(startDeg, endDeg) {
      const p1 = this.point(startDeg);
      const p2 = this.point(endDeg);
      const large = endDeg - startDeg > 180 ? 1 : 0;
      return `M ${this.center} ${this.center} L ${p1.x} ${p1.y} `
        + `A ${this.radius} ${this.radius} 0 ${large} 1 ${p2.x} ${p2.y} Z`;
    },
    point(deg) {
      const rad = (deg * Math.PI) / 180;
      return {
        x: this.center + this.radius * Math.cos(rad),
        y: this.center + this.radius * Math.sin(rad),
      };
    },
    gradientId(w) {
      return 'sw-fill-' + this._uid + '-' + w.key;
    },
    fillFor(w) {
      return this.isGlossy ? `url(#${this.gradientId(w)})` : w.color;
    },
    // Icon over label, both centred on the wedge: stacked perpendicular to the radius,
    // so the pair stays upright together however the wedge is rotated.
    iconY(w) {
      return w.showLabel ? this.center - this.iconSize - 1 : this.center - this.iconSize / 2;
    },
    textY(w) {
      return w.showIcon && w.icon_url ? this.center + 9 : this.center;
    },
    trim(label) {
      const text = String(label || '');
      return text.length > 14 ? text.slice(0, 13) + '…' : text;
    },
    round(value) {
      return String(Math.round((Number(value) || 0) * 100) / 100);
    },
    // Stand lights: at rest the bottom one is lit and the two above sit dark in the
    // theme colour; while the wheel turns the lit one chases up the column.
    lightOn(n) {
      return this.spinning ? this.lightStep % 3 === n - 1 : n === 3;
    },
    dotStyle(d) {
      const on = this.lightOn(d.row);
      const lit = this.colors.light;
      const off = shade(this.colors.bg, -0.25);
      return on
        ? { left: d.left, top: d.top, background: `radial-gradient(circle at 35% 30%, ${shade(lit, 0.5)} 0%, ${lit} 70%)`, boxShadow: `0 0 8px ${lit}, inset 0 -1px 2px rgba(0,0,0,.25)` }
        : { left: d.left, top: d.top, background: `radial-gradient(circle at 35% 30%, ${shade(off, 0.25)} 0%, ${off} 70%)`, boxShadow: 'inset 0 1px 2px rgba(0,0,0,.45)' };
    },
    /**
     * The server's draw, without the prize: unavailable wedges are dropped and their
     * chance goes to the no-luck wedge, then a weighted random picks the winner.
     */
    pick() {
      const usable = [];
      let dropped = 0;
      let noLuckAt = -1;

      this.segments.forEach((s, i) => {
        if (s.available === false) {
          dropped += Number(s.win_chance) || 0;
          return;
        }
        if (s.type === 'no_luck' && noLuckAt < 0) noLuckAt = usable.length;
        usable.push({ index: i, chance: Number(s.win_chance) || 0 });
      });
      if (!usable.length) return -1;
      if (dropped > 0 && noLuckAt >= 0) usable[noLuckAt].chance += dropped;

      const total = usable.reduce((sum, u) => sum + Math.max(0, u.chance), 0);
      if (total <= 0) return noLuckAt >= 0 ? usable[noLuckAt].index : usable[0].index;

      let roll = Math.random() * total;
      for (const u of usable) {
        roll -= Math.max(0, u.chance);
        if (roll <= 0) return u.index;
      }
      return usable[usable.length - 1].index;
    },
    spin() {
      if (this.spinning || !this.canSpin) return;

      const index = this.pick();
      if (index < 0) return;

      const segment = this.segments[index];
      this.result = null;
      this.spinning = true;
      this.lightStep = 0;
      clearInterval(this._lights);
      this._lights = setInterval(() => { this.lightStep += 1; }, 140);

      // Land the chosen wedge's centre under the pointer, after four full turns so it
      // reads as a spin rather than a jump.
      const want = ((-(index + 0.5) * this.sweep) % 360 + 360) % 360;
      const base = Math.ceil(this.rotation / 360) * 360;
      this.rotation = base + 360 * 4 + want;

      clearTimeout(this._timer);
      this._timer = setTimeout(() => {
        this.spinning = false;
        clearInterval(this._lights);
        this.result = {
          isWin: segment.type !== 'no_luck',
          label: segment.label || __('segment'),
          detail: segment.prize || '',
        };
        this.$emit('spun', { index, segment });
      }, 3450);
    },
  },
  beforeUnmount() {
    clearTimeout(this._timer);
    clearInterval(this._lights);
  },
};
</script>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@1,900&display=swap');

.wheel-preview { display: flex; flex-direction: column; align-items: center; gap: 10px; }

.wheel-card {
  position: relative; width: 100%; max-width: 340px; border-radius: 18px; padding: 18px 12px 14px;
  overflow: hidden; display: flex; flex-direction: column; align-items: center;
  box-shadow: 0 14px 34px rgba(0, 0, 0, .35);
}

/* The lettered title. Font is set on the spans themselves — the shell forces its UI
   font on every <span> with !important, and only a more specific !important beats it. */
.wheel-title { display: flex; flex-direction: column; align-items: center; line-height: .9; margin-bottom: 6px; z-index: 2; }
.wheel-card .wheel-title span {
  font-family: 'Playfair Display', 'Georgia', 'Times New Roman', serif !important;
  font-style: italic; font-weight: 900; paint-order: stroke fill;
}
.wheel-title-top { font-size: 2rem; }
.wheel-title-main { font-size: 2.6rem; }

.wheel-stage {
  position: relative; width: 100%; display: flex; flex-direction: column; align-items: center; padding: 4px 0 14px;
}
.wheel-backplate { position: absolute; z-index: 1; left: 6%; right: 6%; top: 13px; bottom: 4%; border-radius: 40px 40px 0 0; pointer-events: none; }
.wheel-wings { position: absolute; z-index: 0; left: 0; width: 100%; bottom: 14px; aspect-ratio: 800 / 355; overflow: visible; pointer-events: none; }
.wheel-svg { position: relative; z-index: 3; width: 100%; max-width: 330px; height: auto; filter: drop-shadow(0 8px 14px rgba(0, 0, 0, .5)); }
.wheel-wedge { cursor: pointer; }

/* The stand tucks its crowned top under the wheel's bezel. */
.wheel-stand { position: relative; z-index: 2; width: 100%; margin-top: -10%; }
.wheel-stand-svg { display: block; width: 100%; height: auto; aspect-ratio: 800 / 355; overflow: visible; }
.wheel-stand-dot {
  position: absolute; z-index: 5; width: 3.2%; aspect-ratio: 1; border-radius: 50%; transform: translate(-50%, -50%);
  transition: background .12s, box-shadow .12s;
}
.wheel-key-wrap { position: absolute; left: 50%; top: 54%; width: 36%; max-width: 175px; transform: translate(-50%, -50%); z-index: 6; }
.wheel-key { position: relative; display: block; width: 100%; height: 47px; border: 0; padding: 0; background: transparent; cursor: pointer; }
.wheel-key:disabled { cursor: default; }
.wheel-key-cradle { position: absolute; left: -3px; right: -3px; top: 1px; bottom: -2px; border-radius: 10px; box-shadow: 0 3px 7px rgba(0, 0, 0, .5); }
.wheel-key-lip { position: absolute; left: 0; right: 0; top: 3px; bottom: 0; border-radius: 7px; box-shadow: 0 2px 4px rgba(0, 0, 0, .35); transition: transform 70ms; }
.wheel-key-face {
  position: absolute; left: 0; right: 0; top: 0; bottom: 5px; border-radius: 6px;
  display: flex; align-items: center; justify-content: center;
  font-size: .95rem; font-weight: 900; letter-spacing: 1px; text-transform: uppercase;
  text-shadow: 0 1px 0 rgba(255, 255, 255, .5); transition: transform 70ms;
}
.wheel-key:active:not(:disabled) .wheel-key-face { transform: translateY(5px); }
.wheel-key:active:not(:disabled) .wheel-key-lip { transform: translateY(3px); }
.wheel-key:disabled .wheel-key-face { opacity: .85; }

.wheel-result { text-align: center; min-height: 38px; }
.wheel-result-pill {
  display: inline-block; font-size: 13px; font-weight: 600; padding: 3px 12px; border-radius: 999px;
}
.wheel-result-pill.is-win { color: #15803d; background: rgba(34, 197, 94, .14); }
.wheel-result-pill.is-loss { color: #92400e; background: rgba(245, 158, 11, .16); }
.wheel-foot { display: flex; flex-direction: column; align-items: center; gap: 3px; text-align: center; }
.wheel-total { font-size: 13px; font-weight: 600; padding: 3px 10px; border-radius: 999px; }
.wheel-total.is-ok { color: #15803d; background: rgba(34, 197, 94, .12); }
.wheel-total.is-bad { color: #b91c1c; background: rgba(239, 68, 68, .12); }
</style>
