<template>
    <div class="hb-tab-item">
        <div class="hb-tab-item-head" @click="open = !open">
            <component :is="open ? 'ChevronDown' : 'ChevronRight'" :size="15" />
            <span class="fw-bold">{{ __('tab') }} {{ index + 1 }}</span>
            <span class="text-muted small ms-2 text-truncate" v-if="displayTitle">— {{ displayTitle }}</span>
            <div class="ms-auto d-flex gap-1" @click.stop>
                <button type="button" class="btn btn-xs btn-light" :disabled="index === 0"
                    @click="$emit('move-up')"><ArrowUp :size="14" /></button>
                <button type="button" class="btn btn-xs btn-light" :disabled="index === count - 1"
                    @click="$emit('move-down')"><ArrowDown :size="14" /></button>
                <button type="button" class="btn btn-xs btn-light text-danger"
                    @click="$emit('remove')"><Trash2 :size="14" /></button>
            </div>
        </div>

        <div v-if="open" class="hb-tab-item-body">
            <!-- What the tab is called -->
            <div class="mb-2">
                <TranslatableInput :label="__('tab_title')" :model-value="item.title"
                    @update:model-value="item.title = $event" :languages="languages" :active-lang="activeLang" />
            </div>

            <!-- The icon above the label, one per platform -->
            <label class="form-label small text-muted mb-1">{{ __('tab_icon') }}</label>
            <div class="row g-2 mb-3">
                <div class="col-4">
                    <HbImageUpload :label="__('app')" :model-value="item.image.app"
                        @update:model-value="item.image.app = $event" />
                </div>
                <div class="col-4">
                    <HbImageUpload :label="__('tablet')" :model-value="item.image.tablet"
                        @update:model-value="item.image.tablet = $event" />
                </div>
                <div class="col-4">
                    <HbImageUpload :label="__('web')" :model-value="item.image.web"
                        @update:model-value="item.image.web = $event" />
                </div>
            </div>

            <!-- What the tab shows: the same source picker a product slider has -->
            <div class="row g-2 mb-2">
                <div class="col-md-6">
                    <label class="form-label small text-muted mb-1">{{ __('data_source') }}</label>
                    <AppSelect class="form-select form-select-sm" v-model="item.config.data_source"
                        :options="dataSourceOptions" :searchable="false" :allow-empty="false" />
                </div>
                <div class="col-md-6">
                    <label class="form-label small text-muted mb-1">
                        {{ __('limit') }}
                        <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('tab_limit_hint')" />
                    </label>
                    <!-- Untouched = inherit the block's limit, shown as the slider's value. -->
                    <DimensionSlider :model-value="item.config.limit ?? inheritedLimit" :min="1" :max="limitMax"
                        suffix="" @update:model-value="item.config.limit = $event" />
                </div>
            </div>

            <div class="mb-2" v-if="item.config.data_source === 'manual'">
                <label class="form-label small text-muted mb-1">{{ __('select_products') }}</label>
                <AppSelect class="form-select form-select-sm" multiple :model-value="item.config.manual_product_ids"
                    @update:model-value="item.config.manual_product_ids = $event"
                    :options="allProducts" :placeholder="__('select_products')" />
            </div>
            <div class="mb-2" v-if="item.config.data_source === 'category'">
                <label class="form-label small text-muted mb-1">{{ __('categories') }}</label>
                <AppSelect class="form-select form-select-sm" multiple :model-value="item.config.slider_category_ids"
                    @update:model-value="item.config.slider_category_ids = $event"
                    :options="allCategories" :placeholder="__('select_categories')" />
            </div>
            <div class="mb-2" v-if="item.config.data_source === 'brand'">
                <label class="form-label small text-muted mb-1">{{ __('brands') }}</label>
                <AppSelect class="form-select form-select-sm" multiple :model-value="item.config.brand_ids"
                    @update:model-value="item.config.brand_ids = $event"
                    :options="allBrands" :placeholder="__('select_brands')" />
            </div>

            <!-- Scope an ordering-only source to part of the catalogue, or away
                 from it. Each tab carries its own, independent of its neighbours. -->
            <div class="mb-2" v-if="isDynamicSource">
                <div class="row g-2">
                    <div class="col-md-6">
                        <label class="form-label small text-muted mb-1">
                            {{ __('filter_products') }}
                            <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('filter_products_hint')" />
                        </label>
                        <AppSelect class="form-select form-select-sm" :model-value="item.config.filter_type"
                            @update:model-value="setFilterType($event)"
                            :options="filterTypeOptions" :searchable="false" :allow-empty="false" />
                    </div>
                    <div class="col-md-6" v-if="item.config.filter_type !== 'none'">
                        <label class="form-label small text-muted mb-1">{{ __('filter_mode') }}</label>
                        <AppSelect class="form-select form-select-sm" v-model="item.config.filter_mode"
                            :options="filterModeOptions" :searchable="false" :allow-empty="false" />
                    </div>
                </div>
                <div class="mt-2" v-if="item.config.filter_type === 'category'">
                    <label class="form-label small text-muted mb-1">{{ __('categories') }}</label>
                    <AppSelect class="form-select form-select-sm" multiple :model-value="item.config.filter_category_ids"
                        @update:model-value="item.config.filter_category_ids = $event"
                        :options="allCategories" :placeholder="__('select_categories')" />
                </div>
                <div class="mt-2" v-if="item.config.filter_type === 'brand'">
                    <label class="form-label small text-muted mb-1">{{ __('brands') }}</label>
                    <AppSelect class="form-select form-select-sm" multiple :model-value="item.config.filter_brand_ids"
                        @update:model-value="item.config.filter_brand_ids = $event"
                        :options="allBrands" :placeholder="__('select_brands')" />
                </div>
            </div>

            <div class="form-check form-switch hb-switch-row">
                <label class="form-check-label small text-muted" :for="'tab-shuffle-' + item.id">
                    {{ __('shuffle_products') }}
                </label>
                <input class="form-check-input" type="checkbox" role="switch" :id="'tab-shuffle-' + item.id"
                    :checked="item.config.shuffle_products === true"
                    @change="item.config.shuffle_products = $event.target.checked">
            </div>
        </div>
    </div>
</template>

<script>
import HbImageUpload from './HbImageUpload.vue';
import TranslatableInput from './TranslatableInput.vue';
import DimensionSlider from './DimensionSlider.vue';
import { TAB_LIMIT_MAX } from '../homeBuilderHelpers.js';
import { ChevronDown, ChevronRight, ArrowUp, ArrowDown, Trash2, Info } from 'lucide-vue-next';

/**
 * One tab of a product_tabs block: a title, an icon, and the same data-source
 * choice a product slider offers. Presentation lives on the block; a tab only
 * decides what it shows.
 */
export default {
    name: 'TabItemRow',
    components: { ChevronDown, ChevronRight, ArrowUp, ArrowDown, Trash2, Info, HbImageUpload, TranslatableInput, DimensionSlider },
    props: {
        item: { type: Object, required: true },
        index: { type: Number, required: true },
        count: { type: Number, required: true },
        // The block's limit — what a tab uses when it sets none of its own.
        inheritedLimit: { type: Number, default: 10 },
        dataSourceOptions: { type: Array, default: () => [] },
        languages: { type: Array, default: () => [] },
        activeLang: { type: [Number, String], default: null },
        allProducts: { type: Array, default: () => [] },
        allCategories: { type: Array, default: () => [] },
        allBrands: { type: Array, default: () => [] },
    },
    emits: ['remove', 'move-up', 'move-down'],
    data() {
        // A freshly added tab opens itself; existing ones start collapsed.
        return { open: this.index === this.count - 1, limitMax: TAB_LIMIT_MAX };
    },
    computed: {
        displayTitle() {
            const t = this.item.title || {};
            return t[this.activeLang] || Object.values(t).find(v => v) || '';
        },
        // manual/category/brand already choose products; the rest only order them.
        isDynamicSource() {
            return !['manual', 'category', 'brand'].includes(this.item.config.data_source);
        },
        // Fixed option set — no search box needed.
        filterTypeOptions() {
            return [
                { id: 'none', name: (__('no_filter')) },
                { id: 'category', name: (__('by_category')) },
                { id: 'brand', name: (__('by_brand')) },
            ];
        },
        // Fixed option set — no search box needed.
        filterModeOptions() {
            return [
                { id: 'include', name: (__('include_only')) },
                { id: 'exclude', name: (__('exclude_these')) },
            ];
        },
    },
    methods: {
        // Drop the other list when the scope changes, so a leftover selection can
        // never filter by something the form is no longer showing.
        setFilterType(v) {
            this.item.config.filter_type = v;
            if (v !== 'category') this.item.config.filter_category_ids = [];
            if (v !== 'brand') this.item.config.filter_brand_ids = [];
            if (v === 'none') this.item.config.filter_mode = 'include';
        },
    },
};
</script>

<style scoped>
/* Same chrome as a banner row — those styles are scoped to BannerItemRow, so
   they are declared here rather than borrowed. */
.hb-tab-item {
    border: 1px solid var(--app-card-border);
    border-radius: .5rem;
    margin-bottom: .5rem;
    background: var(--app-card-bg);
}
.hb-tab-item-head {
    display: flex;
    align-items: center;
    gap: .5rem;
    padding: .5rem .75rem;
    cursor: pointer;
    font-size: .85rem;
    min-width: 0;
}
.hb-tab-item-body {
    padding: .25rem .75rem .75rem;
    border-top: 1px solid #f1f1f1;
}
.btn-xs {
    padding: .1rem .35rem;
    font-size: .7rem;
    line-height: 1.2;
}
</style>
