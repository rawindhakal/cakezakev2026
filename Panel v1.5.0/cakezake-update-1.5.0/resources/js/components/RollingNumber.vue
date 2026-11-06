<template>
    <span class="rolling-number" :style="rootStyle">
        <span class="rn-track" ref="track" aria-hidden="true">
            <span
                v-for="slot in slots"
                :key="slot.index"
                class="rn-slot"
                :class="{ 'rn-slot-new': slot.isNew }"
                :style="{ '--rn-delay': slot.delay + 'ms' }"
            >
                <Transition :name="transitionName">
                    <span class="rn-char" :key="slot.char">{{ slot.display }}</span>
                </Transition>
            </span>
        </span>

        <!-- Screen readers get the whole value once, not a stream of single characters. -->
        <span class="rn-sr" aria-live="polite">{{ text }}</span>
    </span>
</template>

<script>
/**
 * SwiftUI's `.contentTransition(.numericText())`, in CSS.
 *
 * Takes already-formatted text ("11.17 GB", "₹1,24,500") and animates only the
 * characters that changed. Separators, spaces and units are characters like any other,
 * so they stay still for free — nothing here knows what a digit is.
 *
 * Direction is shared by every slot in one update, because that is what reads as a
 * single number rolling: up when the value grew, down when it shrank.
 */
export default {
    name: 'RollingNumber',
    props: {
        value: { type: [String, Number], default: '' },
        duration: { type: Number, default: 480 },
        /**
         * 'down' (the default) always rolls top → bottom: the new character drops in
         * from above and the old one leaves through the floor. 'up' is the mirror, and
         * 'auto' picks per update — up when the value grew, down when it shrank.
         */
        direction: { type: String, default: 'down' },
        /** Per-character stagger, right to left. 0 disables it. */
        stagger: { type: Number, default: 8 },
        /**
         * Spring overshoot on the arriving character, 0 → 1. The incoming digit slides
         * a little past its resting line and settles back, which is the bit that reads
         * as weight rather than a slide. 0 is a flat ease.
         */
        bounce: { type: Number, default: 1 },
        /**
         * Motion blur on the travelling character, in px. 0 — the default — keeps every
         * digit sharp end to end; the blur reads as smeared text at card sizes, where the
         * roll is short and the figure is the thing being read.
         */
        blur: { type: Number, default: 0 },
    },
    data() {
        return {
            rollUp: true,
            prevText: '',
            // Index from which the characters are brand new (999 → 1,000). Set only when
            // the value changes — if it were recomputed after every render it would strip
            // the entry animation off a slot that is still playing it.
            newFrom: Infinity,
            // Measured track width, so the box grows and shrinks smoothly on 999 → 1,000
            // instead of snapping. null until the first measurement.
            trackW: null,
            reduceMotion: false,
        };
    },
    computed: {
        text() { return String(this.value ?? ''); },
        slots() {
            const chars = Array.from(this.text);
            const n = chars.length;
            return chars.map((char, index) => ({
                index,
                char,
                // A space would collapse inside an inline-block slot.
                display: char === ' ' ? ' ' : char,
                isNew: index >= this.newFrom,
                delay: this.stagger > 0 ? Math.max(0, n - 1 - index) * this.stagger : 0,
            }));
        },
        transitionName() {
            if (this.reduceMotion) return 'rn-fade';
            return this.rollUp ? 'rn-up' : 'rn-down';
        },
        /**
         * Overshoot lives in the second control point: a y above 1 carries the character
         * past its target before it comes back, which is a spring's settle without a
         * spring's bookkeeping. Only the transform gets it — opacity would clip and
         * blur, when it is on at all, would go negative.
         */
        enterEase() {
            const b = Math.max(0, Math.min(1, Number(this.bounce) || 0));
            return `cubic-bezier(0.2, ${(1 + 0.28 * b).toFixed(3)}, 0.35, 1)`;
        },
        rootStyle() {
            const blur = Math.max(0, Number(this.blur) || 0);
            const s = {
                '--rn-duration': this.duration + 'ms',
                '--rn-ease-enter': this.enterEase,
                // `none`, not `blur(0px)`: a zero blur is still a filter, and a filtered
                // element gets its own layer, which is what softens the glyph.
                '--rn-filter': blur > 0 ? `blur(${blur}px)` : 'none',
            };
            if (this.trackW != null) s.width = this.trackW + 'px';
            return s;
        },
    },
    watch: {
        // Pre-flush, so the direction is settled before the new characters render.
        value() { this.readDirection(); },
    },
    created() {
        this.reduceMotion = !!(window.matchMedia
            && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
        // A forced direction is known before the first change, so don't wait for the
        // watcher to discover it.
        if (this.direction !== 'auto') this.rollUp = this.direction !== 'down';
        this.prevText = this.text;
    },
    mounted() { this.measure(); },
    updated() { this.measure(); },
    methods: {
        /** Numeric part of a formatted string: "842 MB" → 842, "₹1,200" → 1200. */
        numeric(s) {
            const v = parseFloat(String(s).replace(/[^\d.\-]/g, ''));
            return Number.isFinite(v) ? v : null;
        },
        readDirection() {
            const prevLen = Array.from(this.prevText).length;
            const len = Array.from(this.text).length;
            this.newFrom = len > prevLen && prevLen > 0 ? prevLen : Infinity;

            if (this.direction !== 'auto') {
                this.rollUp = this.direction !== 'down';
            } else {
                const a = this.numeric(this.prevText);
                const b = this.numeric(this.text);
                if (a !== null && b !== null && a !== b) this.rollUp = b > a;
            }
            this.prevText = this.text;
        },
        measure() {
            const el = this.$refs.track;
            if (!el) return;
            // scrollWidth, not the bounding rect: a slot that is mid-roll has a leaving
            // character out of flow, and the rect would then report the old width.
            const w = Math.ceil(el.scrollWidth);
            if (w > 0 && w !== this.trackW) this.trackW = w;
        },
    },
};
</script>

<style scoped>
.rolling-number {
    display: inline-flex;
    position: relative;
    /* Digits must not shift sideways while a neighbour rolls. */
    font-variant-numeric: tabular-nums;
    font-feature-settings: 'tnum' 1;
    transition: width var(--rn-duration, 480ms) cubic-bezier(0.2, 0.9, 0.3, 1);
}

.rn-track {
    display: inline-flex;
    align-items: baseline;
    /* Keeps its natural width while the box around it animates to match. */
    flex: 0 0 auto;
}

.rn-slot {
    /* One grid cell, and both the leaving and the arriving character are placed in it.
       The old version took the leaving one out of flow with position: absolute, which
       put it half a line's leading off the character it was replacing — that offset is
       what showed up as a stray line of text under the figure. In a grid cell both are
       in flow and land on the same baseline. */
    display: inline-grid;
    grid-template-areas: 'c';
    /* Clips the roll to one line box. */
    overflow: hidden;
    /* Matches the surrounding text, so the clip never cuts a tall glyph. */
    line-height: inherit;
    white-space: pre;
}

.rn-char {
    grid-area: c;
    /* Deliberately no will-change and no filter at rest: either one promotes the glyph
       to its own layer, and a layer is what makes text look soft. The hint is added
       only while a roll is actually running. */
}

/* A character the value just grew into (999 → 1,000) simply fades up in place. */
.rn-slot-new > .rn-char {
    animation: rn-pop calc(var(--rn-duration, 480ms) * 0.45) ease-out both;
    animation-delay: var(--rn-delay, 0ms);
}

@keyframes rn-pop {
    from { opacity: 0; }
    to   { opacity: 1; }
}

/* ---- the roll ----------------------------------------------------------------
   Enter and leave run at the same time, stacked in the slot's single grid cell, so the
   arriving character already owns its place while the old one is still on its way out. */

/* Arriving: the transform springs past its line and settles. */
.rn-up-enter-active,
.rn-down-enter-active {
    will-change: transform, opacity;
    transition:
        transform var(--rn-duration, 480ms) var(--rn-ease-enter, cubic-bezier(0.2, 1.52, 0.35, 1)),
        opacity calc(var(--rn-duration, 480ms) * 0.45) cubic-bezier(0.2, 0.9, 0.3, 1),
        filter calc(var(--rn-duration, 480ms) * 0.45) cubic-bezier(0.2, 0.9, 0.3, 1);
    transition-delay: var(--rn-delay, 0ms);
}

/* Leaving: out fast and early, and no overshoot.
   The old character shares the slot with the arriving one, so every millisecond it
   lingers is a millisecond of doubled text. It covers its distance in half the time the
   new one takes to settle, and its opacity is gone in a third of that — by the time the
   new digit springs back onto its line, there is nothing underneath it. */
.rn-up-leave-active,
.rn-down-leave-active {
    will-change: transform, opacity;
    transition:
        transform calc(var(--rn-duration, 480ms) * 0.55) cubic-bezier(0.45, 0, 0.9, 0.75),
        opacity calc(var(--rn-duration, 480ms) * 0.34) ease-out,
        filter calc(var(--rn-duration, 480ms) * 0.34) ease-out;
    transition-delay: var(--rn-delay, 0ms);
}

.rn-up-leave-active,
.rn-down-leave-active,
.rn-fade-leave-active {
    pointer-events: none;
}

.rn-up-enter-from { transform: translateY(72%); opacity: 0; filter: var(--rn-filter, none); }
.rn-up-leave-to   { transform: translateY(-86%); opacity: 0; filter: var(--rn-filter, none); }

.rn-down-enter-from { transform: translateY(-72%); opacity: 0; filter: var(--rn-filter, none); }
.rn-down-leave-to   { transform: translateY(86%); opacity: 0; filter: var(--rn-filter, none); }

/* ---- reduced motion: cross-fade only, no movement, no blur ---- */
.rn-fade-enter-active,
.rn-fade-leave-active { transition: opacity var(--rn-duration, 480ms) linear; }
.rn-fade-enter-from,
.rn-fade-leave-to { opacity: 0; }

@media (prefers-reduced-motion: reduce) {
    .rolling-number { transition: none; }
    .rn-slot-new > .rn-char { animation: none; }
}

.rn-sr {
    position: absolute;
    width: 1px;
    height: 1px;
    margin: -1px;
    padding: 0;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
}
</style>
