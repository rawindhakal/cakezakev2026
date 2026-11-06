<template>
    <div class="dim-slider">
        <label v-if="label" class="dim-slider-label">{{ label }}</label>
        <div class="d-flex align-items-center gap-2">
            <input type="range" class="form-range dim-slider-range" :min="min" :max="max" :step="step"
                :value="num" @input="emitVal($event.target.value)" />
            <div class="input-group input-group-sm dim-slider-num" :style="numWidth ? { width: numWidth + 'px' } : {}">
                <input type="number" class="form-control" :min="min" :max="max" :step="step"
                    :value="num" @input="emitVal($event.target.value)" />
                <span v-if="suffix" class="input-group-text">{{ suffix }}</span>
            </div>
        </div>
    </div>
</template>

<script>
/**
 * Labeled range slider + manual number input, kept in sync. Emits a clamped Number.
 *   <DimensionSlider v-model="cfg.border_radius" :min="0" :max="50" label="Radius" suffix="px" />
 */
export default {
    name: 'DimensionSlider',
    props: {
        modelValue: { type: [Number, String], default: 0 },
        min: { type: Number, default: 0 },
        max: { type: Number, default: 100 },
        step: { type: Number, default: 1 },
        label: { type: String, default: '' },
        suffix: { type: String, default: 'px' },
        numWidth: { type: [Number, String], default: 0 },
    },
    emits: ['update:modelValue'],
    computed: {
        num() {
            const n = Number(this.modelValue);
            return Number.isFinite(n) ? n : this.min;
        },
    },
    methods: {
        emitVal(v) {
            let n = Number(v);
            if (!Number.isFinite(n)) n = this.min;
            if (n < this.min) n = this.min;
            if (n > this.max) n = this.max;
            this.$emit('update:modelValue', n);
        },
    },
};
</script>

<style scoped>
.dim-slider-label {
    font-size: .72rem;
    font-weight: 600;
    color: var(--app-muted, #667085);
    margin-bottom: 2px;
    display: block;
    text-transform: uppercase;
    letter-spacing: .3px;
}
.dim-slider-range { flex: 1 1 auto; min-width: 0; accent-color: var(--bs-primary); }
.dim-slider-num { width: 92px; flex: 0 0 auto; }
</style>
