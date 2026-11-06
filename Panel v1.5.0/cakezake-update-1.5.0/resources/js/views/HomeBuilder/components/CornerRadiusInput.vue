<template>
    <div class="hb-corner">
        <div class="d-flex align-items-center justify-content-between mb-1">
            <label class="hb-lbl mb-0 d-inline-flex align-items-center gap-1">
                {{ label }}
                <Info v-if="hint" :size="13" class="hb-info" v-b-tooltip.hover :title="hint" />
            </label>
            <!-- Off: one number, written to all four corners. On: each corner set on
                 its own. Switching back collapses to the top-left value. -->
            <div class="form-check form-switch m-0 hb-switch">
                <label class="form-check-label hb-lbl" :for="uid">{{ __('custom_corners') }}</label>
                <input class="form-check-input" type="checkbox" role="switch" :id="uid"
                    :checked="custom" @change="toggleCustom($event.target.checked)">
            </div>
        </div>

        <div class="hb-box">
            <!-- simple: one radius for the whole box -->
            <DimensionSlider v-if="!custom" :suffix="suffix" :min="min" :max="max"
                :model-value="cornerOf('top_left')" @update:model-value="setAll($event)" />

            <!-- custom: one slider per corner -->
            <template v-else>
                <DimensionSlider v-for="c in corners" :key="c.k" :label="__(c.t)" :suffix="suffix"
                    :min="min" :max="max"
                    :model-value="cornerOf(c.k)" @update:model-value="setCorner(c.k, $event)" />
            </template>
        </div>
    </div>
</template>

<script>
import { Info } from 'lucide-vue-next';
import DimensionSlider from './DimensionSlider.vue';
import { newCorners, toCornerRadius } from '../homeBuilderHelpers.js';

let seq = 0;

export default {
    name: 'CornerRadiusInput',
    components: { Info, DimensionSlider },
    props: {
        label: { type: String, default: '' },
        hint: { type: String, default: '' },
        // { top_left, top_right, bottom_left, bottom_right }
        modelValue: { type: [Object, Number, String], default: () => ({}) },
        custom: { type: Boolean, default: false },
        min: { type: Number, default: 0 },
        max: { type: Number, default: 50 },
        suffix: { type: String, default: 'px' },
    },
    emits: ['update:modelValue', 'update:custom'],
    data() {
        return {
            uid: 'hb-corner-' + (++seq),
            corners: [
                { k: 'top_left', t: 'top_left' },
                { k: 'top_right', t: 'top_right' },
                { k: 'bottom_left', t: 'bottom_left' },
                { k: 'bottom_right', t: 'bottom_right' },
            ],
        };
    },
    computed: {
        value() { return toCornerRadius(this.modelValue); },
    },
    methods: {
        cornerOf(corner) { return Number(this.value?.[corner]) || 0; },
        emit(next) { this.$emit('update:modelValue', next); },
        setAll(v) { this.emit(newCorners(v)); },
        setCorner(corner, v) { this.emit({ ...this.value, [corner]: Number(v) || 0 }); },
        toggleCustom(on) {
            // Collapsing back to one radius keeps the top-left value, so the simple
            // view never claims a shape it cannot show.
            if (!on) {
                this.emit(newCorners(this.cornerOf('top_left')));
            }
            this.$emit('update:custom', on);
        },
    },
};
</script>

<style scoped>
.hb-lbl { font-size: .72rem; color: var(--app-muted); }
.hb-info { color: var(--app-muted); cursor: help; }
.hb-info:hover { color: var(--bs-primary); }

/* Text left, switch right: undo Bootstrap's leading-input layout. */
.hb-switch {
    display: flex;
    align-items: center;
    gap: .4rem;
    padding-left: 0;
}
.hb-switch .form-check-input {
    float: none;
    margin: 0;
}

/* Same framed group as the platform-wise inputs, so the panel reads as one family. */
.hb-box {
    display: flex;
    flex-direction: column;
    gap: .4rem;
    border: 1px solid var(--app-card-border);
    border-radius: .4rem;
    padding: .5rem;
    background: var(--app-thead-bg);
}
</style>
