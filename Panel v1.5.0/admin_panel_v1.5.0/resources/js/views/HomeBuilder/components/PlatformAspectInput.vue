<template>
    <div class="hb-tri">
        <label class="hb-lbl mb-1 d-inline-flex align-items-center gap-1">
            {{ label }}
            <Info v-if="hint" :size="13" class="hb-info" v-b-tooltip.hover :title="hint" />
        </label>
        <div class="hb-tri-col">
            <template v-for="p in plats" :key="p.k">
                <div class="hb-aspect-row">
                    <span class="hb-aspect-plat">{{ p.t }}</span>
                    <AppSelect class="form-select form-select-sm" :searchable="false"
                        :options="options"
                        :model-value="selectOf(p.k)"
                        @update:model-value="pick(p.k, $event)" />
                </div>
                <!-- Custom: the ratio is any w:h the user types, not one of the presets. -->
                <div v-if="selectOf(p.k) === CUSTOM" class="hb-aspect-row hb-aspect-custom">
                    <span class="hb-aspect-plat"></span>
                    <input type="number" class="form-control form-control-sm" min="1" step="1"
                        :aria-label="__('width')" :value="partOf(p.k, 0)"
                        @input="setPart(p.k, 0, $event.target.value)">
                    <span class="hb-aspect-sep">:</span>
                    <input type="number" class="form-control form-control-sm" min="1" step="1"
                        :aria-label="__('height')" :value="partOf(p.k, 1)"
                        @input="setPart(p.k, 1, $event.target.value)">
                </div>
            </template>
        </div>
    </div>
</template>

<script>
import { Info } from 'lucide-vue-next';
import AppSelect from '../../../components/AppSelect.vue';

// Width-independent image sizing: the ratio is applied via CSS aspect-ratio in
// the preview AND by the app/web, so a banner keeps the same proportions on any
// screen width. Value stored as a "w:h" string.
const ASPECT_OPTIONS = [
    // Wide (width > height)
    { id: '21:9', name: '21:9 (Ultra-wide)' },
    { id: '4:1', name: '4:1 (Strip)' },
    { id: '3:1', name: '3:1 (Slim banner)' },
    { id: '2:1', name: '2:1 (Banner)' },
    { id: '16:9', name: '16:9 (Wide)' },
    { id: '3:2', name: '3:2 (Photo)' },
    { id: '4:3', name: '4:3 (Standard)' },
    // Square
    { id: '1:1', name: '1:1 (Square)' },
    // Tall (height > width)
    { id: '3:4', name: '3:4 (Tall)' },
    { id: '2:3', name: '2:3 (Tall photo)' },
    { id: '4:5', name: '4:5 (Portrait)' },
    { id: '9:16', name: '9:16 (Full portrait)' },
];

const CUSTOM = 'custom';

export default {
    name: 'PlatformAspectInput',
    components: { Info, AppSelect },
    props: {
        label: { type: String, default: '' },
        hint: { type: String, default: '' },
        modelValue: { type: Object, default: () => ({ app: '16:9', web: '16:9', tablet: '16:9' }) },
    },
    emits: ['update:modelValue'],
    data() {
        return {
            CUSTOM,
            options: [...ASPECT_OPTIONS, { id: CUSTOM, name: __('custom') }],
            customOn: {},
            plats: [
                { k: 'app', t: 'App' },
                { k: 'tablet', t: 'Tablet' },
                { k: 'web', t: 'Web' },
            ],
        };
    },
    methods: {
        valOf(k) {
            return (this.modelValue && this.modelValue[k]) || '16:9';
        },
        // A stored ratio that is not a preset is by definition a custom one.
        selectOf(k) {
            const v = this.valOf(k);
            if (this.customOn[k]) return CUSTOM;
            return ASPECT_OPTIONS.some(o => o.id === v) ? v : CUSTOM;
        },
        partOf(k, i) {
            const n = parseFloat(String(this.valOf(k)).split(':')[i]);
            return n > 0 ? n : (i === 0 ? 16 : 9);
        },
        pick(k, v) {
            if (v === CUSTOM) {
                // Keep the ratio it already had; only the editor changes.
                this.customOn = { ...this.customOn, [k]: true };
                this.update(k, this.valOf(k));
                return;
            }
            this.customOn = { ...this.customOn, [k]: false };
            this.update(k, v);
        },
        setPart(k, i, raw) {
            const n = Math.max(1, Math.round(Number(raw) || 0));
            const parts = [this.partOf(k, 0), this.partOf(k, 1)];
            parts[i] = n;
            this.customOn = { ...this.customOn, [k]: true };
            this.update(k, parts[0] + ':' + parts[1]);
        },
        update(k, v) {
            const next = { ...(this.modelValue || {}) };
            next[k] = v || '16:9';
            this.$emit('update:modelValue', next);
        },
    },
};
</script>

<style scoped>
.hb-lbl {
    font-size: .72rem;
    color: var(--app-muted);
    margin-bottom: .15rem;
    display: block;
}
.hb-info {
    color: var(--app-muted);
    cursor: help;
    flex-shrink: 0;
}
.hb-info:hover {
    color: var(--bs-primary);
}
.hb-tri-col {
    display: flex;
    flex-direction: column;
    gap: .4rem;
    border: 1px solid var(--app-card-border);
    border-radius: .4rem;
    padding: .5rem;
    background: var(--app-thead-bg);
}
.hb-aspect-row {
    display: flex;
    align-items: center;
    gap: .5rem;
}
.hb-aspect-plat {
    font-size: .72rem;
    color: var(--app-muted);
    width: 48px;
    flex: 0 0 48px;
}
.hb-aspect-custom {
    margin-top: -.15rem;
}
.hb-aspect-sep {
    color: var(--app-muted);
    font-size: .8rem;
}
</style>
