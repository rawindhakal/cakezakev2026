<template>
    <div class="hb-tri">
        <label class="hb-lbl mb-1 d-inline-flex align-items-center gap-1">
            {{ label }}
            <Info v-if="hint" :size="13" class="hb-info" v-b-tooltip.hover :title="hint" />
        </label>
        <div class="hb-tri-col">
            <DimensionSlider v-for="p in plats" :key="p.k" :label="p.t" :suffix="suffix"
                :min="min" :max="max" :step="step"
                :model-value="modelValue && modelValue[p.k] !== '' && modelValue[p.k] != null ? modelValue[p.k] : min"
                @update:model-value="update(p.k, $event)" />
        </div>
    </div>
</template>

<script>
import { Info } from 'lucide-vue-next';
import DimensionSlider from './DimensionSlider.vue';
export default {
    name: 'PlatformTriInput',
    components: { Info, DimensionSlider },
    props: {
        label: { type: String, default: '' },
        hint: { type: String, default: '' },
        modelValue: { type: Object, default: () => ({ app: '', web: '', tablet: '' }) },
        min: { type: Number, default: 0 },
        max: { type: Number, default: 100 },
        step: { type: Number, default: 1 },
        suffix: { type: String, default: 'px' },
    },
    emits: ['update:modelValue'],
    data() {
        return {
            plats: [
                { k: 'app', t: 'App' },
                { k: 'tablet', t: 'Tablet' },
                { k: 'web', t: 'Web' },
            ],
        };
    },
    methods: {
        update(k, v) {
            const next = { ...(this.modelValue || {}) };
            next[k] = v === '' ? '' : Number(v);
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
</style>
