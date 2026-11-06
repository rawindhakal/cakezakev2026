<template>
    <div class="hb-color">
        <div class="hb-color-top">
            <!-- Trigger: the colour itself over a checkerboard, so alpha is visible. -->
            <button type="button" class="hb-color-swatch" ref="trigger" :title="__('choose_color')"
                @click="toggle">
                <span class="hb-color-fill" :style="{ background: css }"></span>
            </button>
            <input v-if="showHex" type="text" class="form-control form-control-sm hb-color-text"
                :value="modelValue" :placeholder="placeholder"
                @change="setRaw($event.target.value)">
        </div>

        <!-- Picker panel: saturation/value square, hue bar, opacity bar, hex box.
             Fixed-positioned off the trigger's rect so a scrolling or overflow-hidden
             parent can never clip it. -->
        <teleport to="body">
            <div v-if="open" class="hb-cp" :style="panelStyle" ref="panel">
                <div class="hb-cp-sv" ref="sv" @pointerdown="startDrag('sv', $event)"
                    :style="{ background: hueCss }">
                    <div class="hb-cp-sv-white"></div>
                    <div class="hb-cp-sv-black"></div>
                    <span class="hb-cp-dot" :style="{ left: hsv.s * 100 + '%', top: (1 - hsv.v) * 100 + '%' }"></span>
                </div>

                <div class="hb-cp-bar hb-cp-hue" ref="hue" @pointerdown="startDrag('hue', $event)">
                    <span class="hb-cp-handle" :style="{ left: (hsv.h / 360) * 100 + '%' }"></span>
                </div>

                <div class="hb-cp-bar hb-cp-alpha" ref="alpha" @pointerdown="startDrag('alpha', $event)">
                    <span class="hb-cp-alpha-fill" :style="{ background: alphaGradient }"></span>
                    <span class="hb-cp-handle" :style="{ left: alpha * 100 + '%' }"></span>
                </div>

                <div class="hb-cp-foot">
                    <span class="hb-cp-preview"><span class="hb-cp-fill" :style="{ background: css }"></span></span>
                    <button v-if="hasDropper" type="button" class="hb-cp-drop" :title="__('pick_color_from_screen')"
                        @click="pickFromScreen">
                        <Pipette :size="14" />
                    </button>
                    <input type="text" class="form-control form-control-sm" :value="modelValue"
                        @change="setRaw($event.target.value)">
                    <span class="hb-cp-pct">{{ Math.round(alpha * 100) }}%</span>
                </div>
            </div>
        </teleport>
    </div>
</template>

<script>
import { Pipette } from 'lucide-vue-next';

// Colours are stored as hex: #RRGGBB while fully opaque, #RRGGBBAA once opacity is
// dialled down. Both are valid CSS and are what the apps already read, so nothing
// downstream changes.
const FALLBACK = '#000000';

function parse(value) {
    let v = String(value || '').trim();
    if (v[0] !== '#') v = '#' + v;
    if (/^#[0-9a-f]{3}$/i.test(v)) v = '#' + v[1] + v[1] + v[2] + v[2] + v[3] + v[3];
    if (/^#[0-9a-f]{8}$/i.test(v)) {
        return { hex: v.slice(0, 7).toLowerCase(), alpha: parseInt(v.slice(7), 16) / 255 };
    }
    if (/^#[0-9a-f]{6}$/i.test(v)) return { hex: v.toLowerCase(), alpha: 1 };
    return { hex: FALLBACK, alpha: 1 };
}

function hexToHsv(hex) {
    const r = parseInt(hex.slice(1, 3), 16) / 255;
    const g = parseInt(hex.slice(3, 5), 16) / 255;
    const b = parseInt(hex.slice(5, 7), 16) / 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
    let h = 0;
    if (d) {
        if (max === r) h = 60 * (((g - b) / d) % 6);
        else if (max === g) h = 60 * ((b - r) / d + 2);
        else h = 60 * ((r - g) / d + 4);
    }
    if (h < 0) h += 360;
    return { h, s: max ? d / max : 0, v: max };
}

function hsvToHex(h, s, v) {
    const c = v * s, x = c * (1 - Math.abs(((h / 60) % 2) - 1)), m = v - c;
    const i = Math.floor(h / 60) % 6;
    const [r, g, b] = [
        [c, x, 0], [x, c, 0], [0, c, x], [0, x, c], [x, 0, c], [c, 0, x],
    ][i < 0 ? 0 : i];
    const to = (n) => Math.round((n + m) * 255).toString(16).padStart(2, '0');
    return '#' + to(r) + to(g) + to(b);
}

const clamp01 = (n) => Math.min(1, Math.max(0, n));

export default {
    name: 'ColorInput',
    components: { Pipette },
    props: {
        modelValue: { type: String, default: '' },
        showHex: { type: Boolean, default: false },
        placeholder: { type: String, default: '#000000' },
    },
    emits: ['update:modelValue'],
    data() {
        return {
            open: false,
            panelStyle: {},
            drag: null,
            hasDropper: typeof window !== 'undefined' && 'EyeDropper' in window,
            dropping: false,
            // Hue is kept aside: a black or grey colour carries no hue of its own,
            // so reading it back from the hex would reset the bar to red.
            hue: hexToHsv(parse(this.modelValue).hex).h,
        };
    },
    computed: {
        parsed() { return parse(this.modelValue); },
        hex() { return this.parsed.hex; },
        alpha() { return this.parsed.alpha; },
        hsv() {
            const c = hexToHsv(this.hex);
            return { h: c.s === 0 ? this.hue : c.h, s: c.s, v: c.v };
        },
        hueCss() { return hsvToHex(this.hsv.h, 1, 1); },
        css() {
            return this.alpha >= 1 ? this.hex
                : this.hex + Math.round(this.alpha * 255).toString(16).padStart(2, '0');
        },
        alphaGradient() {
            return `linear-gradient(to right, ${this.hex}00, ${this.hex})`;
        },
    },
    beforeUnmount() { this.teardown(); },
    methods: {
        emit(hex, alpha) {
            if (alpha >= 1) return this.$emit('update:modelValue', hex);
            const aa = Math.round(Math.max(0, alpha) * 255).toString(16).padStart(2, '0');
            this.$emit('update:modelValue', hex + aa);
        },
        // Typed text may carry its own alpha; honour it as written.
        setRaw(v) {
            const p = parse(v);
            this.hue = hexToHsv(p.hex).h || this.hue;
            this.emit(p.hex, p.alpha);
        },
        toggle() { this.open ? this.close() : this.show(); },
        show() {
            this.hue = this.hsv.h;
            this.open = true;
            this.place();
            this.$nextTick(() => {
                document.addEventListener('pointerdown', this.onOutside, true);
                document.addEventListener('keydown', this.onKey);
                window.addEventListener('scroll', this.close, true);
                window.addEventListener('resize', this.close);
            });
        },
        close() {
            this.open = false;
            this.teardown();
        },
        teardown() {
            document.removeEventListener('pointerdown', this.onOutside, true);
            document.removeEventListener('keydown', this.onKey);
            window.removeEventListener('scroll', this.close, true);
            window.removeEventListener('resize', this.close);
            this.stopDrag();
        },
        // Sample any pixel on screen, keeping the current opacity.
        pickFromScreen() {
            if (!this.hasDropper) return;
            this.dropping = true;
            new window.EyeDropper().open()
                .then((r) => {
                    const p = parse(r.sRGBHex);
                    this.hue = hexToHsv(p.hex).h || this.hue;
                    this.emit(p.hex, this.alpha);
                })
                .catch(() => {})           // the user pressed Esc
                .finally(() => { this.dropping = false; });
        },
        onOutside(e) {
            if (this.dropping) return;
            const panel = this.$refs.panel, trigger = this.$refs.trigger;
            if (panel && panel.contains(e.target)) return;
            if (trigger && trigger.contains(e.target)) return;
            this.close();
        },
        onKey(e) { if (e.key === 'Escape' && !this.dropping) this.close(); },
        // Flip above the trigger when the panel would run past the viewport.
        place() {
            const r = this.$refs.trigger.getBoundingClientRect();
            const W = 232, H = 250;
            const left = Math.min(Math.max(8, r.left), window.innerWidth - W - 8);
            const below = r.bottom + 6;
            const top = below + H > window.innerHeight ? Math.max(8, r.top - H - 6) : below;
            this.panelStyle = { left: left + 'px', top: top + 'px', width: W + 'px' };
        },
        startDrag(which, e) {
            this.drag = which;
            e.currentTarget.setPointerCapture?.(e.pointerId);
            this.applyDrag(e);
            window.addEventListener('pointermove', this.applyDrag);
            window.addEventListener('pointerup', this.stopDrag);
        },
        stopDrag() {
            this.drag = null;
            window.removeEventListener('pointermove', this.applyDrag);
            window.removeEventListener('pointerup', this.stopDrag);
        },
        applyDrag(e) {
            if (!this.drag) return;
            const el = this.$refs[this.drag];
            if (!el) return;
            const r = el.getBoundingClientRect();
            const x = clamp01((e.clientX - r.left) / r.width);
            if (this.drag === 'sv') {
                const y = clamp01((e.clientY - r.top) / r.height);
                this.emit(hsvToHex(this.hsv.h, x, 1 - y), this.alpha);
            } else if (this.drag === 'hue') {
                this.hue = x * 360;
                this.emit(hsvToHex(this.hue, this.hsv.s, this.hsv.v), this.alpha);
            } else {
                this.emit(this.hex, x);
            }
        },
    },
};
</script>

<style scoped>
/* Checkerboard behind anything that can be see-through. */
.hb-color-swatch,
.hb-cp-alpha,
.hb-cp-preview {
    background-image:
        linear-gradient(45deg, #ccc 25%, transparent 25%),
        linear-gradient(-45deg, #ccc 25%, transparent 25%),
        linear-gradient(45deg, transparent 75%, #ccc 75%),
        linear-gradient(-45deg, transparent 75%, #ccc 75%);
    background-size: 8px 8px;
    background-position: 0 0, 0 4px, 4px -4px, -4px 0;
}

.hb-color { display: flex; align-items: center; gap: .4rem; }
.hb-color-top { display: flex; align-items: center; gap: .4rem; flex: 1 1 auto; min-width: 0; }
.hb-color-text { flex: 1 1 auto; min-width: 0; }
.hb-color-swatch {
    width: 34px; height: 31px; flex: 0 0 34px; padding: 2px;
    border: 1px solid var(--app-card-border); border-radius: .35rem;
    background-color: transparent; cursor: pointer;
}
.hb-color-fill { display: block; width: 100%; height: 100%; border-radius: .2rem; }
</style>

<style>
/* Teleported to body, so the panel cannot be scoped. */
.hb-cp {
    position: fixed; z-index: 2000;
    background: var(--app-card-bg, #fff);
    border: 1px solid var(--app-card-border, #ddd);
    border-radius: .5rem; padding: .5rem;
    box-shadow: 0 8px 24px rgba(0, 0, 0, .18);
    display: flex; flex-direction: column; gap: .5rem;
    user-select: none; touch-action: none;
}
.hb-cp-sv { position: relative; height: 140px; border-radius: .35rem; cursor: crosshair; overflow: hidden; }
.hb-cp-sv-white, .hb-cp-sv-black { position: absolute; inset: 0; }
.hb-cp-sv-white { background: linear-gradient(to right, #fff, rgba(255, 255, 255, 0)); }
.hb-cp-sv-black { background: linear-gradient(to top, #000, rgba(0, 0, 0, 0)); }
.hb-cp-dot {
    position: absolute; width: 12px; height: 12px; margin: -6px 0 0 -6px;
    border: 2px solid #fff; border-radius: 50%; box-shadow: 0 0 0 1px rgba(0, 0, 0, .35); pointer-events: none;
}
.hb-cp-bar { position: relative; height: 12px; border-radius: 6px; cursor: pointer; }
.hb-cp-hue {
    background: linear-gradient(to right, #f00, #ff0, #0f0, #0ff, #00f, #f0f, #f00);
}
.hb-cp-alpha-fill { position: absolute; inset: 0; border-radius: 6px; }
.hb-cp-handle {
    position: absolute; top: 50%; width: 12px; height: 16px; margin: -8px 0 0 -6px;
    background: #fff; border: 1px solid rgba(0, 0, 0, .3); border-radius: 3px;
    box-shadow: 0 1px 2px rgba(0, 0, 0, .3); pointer-events: none;
}
.hb-cp-foot { display: flex; align-items: center; gap: .4rem; }
.hb-cp-preview { width: 26px; height: 26px; flex: 0 0 26px; border: 1px solid var(--app-card-border, #ddd); border-radius: .25rem; }
.hb-cp-fill { display: block; width: 100%; height: 100%; border-radius: .18rem; }
.hb-cp-pct { font-size: .7rem; color: var(--app-muted, #888); width: 34px; text-align: right; }
.hb-cp-drop {
    width: 26px; height: 26px; flex: 0 0 26px; padding: 0;
    display: inline-flex; align-items: center; justify-content: center;
    border: 1px solid var(--app-card-border, #ddd); border-radius: .25rem;
    background: transparent; color: var(--app-muted, #888); cursor: pointer;
}
.hb-cp-drop:hover { color: var(--bs-primary); border-color: var(--bs-primary); }
</style>
