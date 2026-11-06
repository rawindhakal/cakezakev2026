<template>
    <div class="hb-redirect-filters">
        <div class="hb-rf-head">
            <Filter :size="13" />
            <span>{{ __('listing_filters') }}</span>
            <Info :size="13" class="hb-info ms-1" v-b-tooltip.hover :title="__('listing_filters_hint')" />
        </div>

        <!-- Default language only: the other languages are typed on the section's
             own language tabs, beside its title, like every translatable field. -->
        <TranslatableInput v-if="languages.length" :model-value="filters.title"
            @update:model-value="filters.title = $event" :languages="languages" :active-lang="activeLang"
            :label="__('listing_heading')" :placeholder="__('listing_heading_placeholder')" />
        <template v-else>
            <label class="hb-lbl">{{ __('listing_heading') }}</label>
            <input type="text" class="form-control form-control-sm" :value="plainTitle"
                @input="filters.title = $event.target.value"
                :placeholder="__('listing_heading_placeholder')">
        </template>

        <div class="row g-2 mt-1">
            <div class="col-md-6">
                <label class="hb-lbl">{{ __('category') }}</label>
                <AppSelect class="form-select form-select-sm" :model-value="filters.category_id"
                    @update:model-value="filters.category_id = $event"
                    :options="allCategories" :placeholder="__('select_category')" />
            </div>
            <div class="col-md-6">
                <label class="hb-lbl">{{ __('brands') }}</label>
                <AppSelect class="form-select form-select-sm" multiple :model-value="filters.brand_ids"
                    @update:model-value="filters.brand_ids = $event"
                    :options="allBrands" :placeholder="__('select_brands')" />
            </div>
        </div>

        <div class="mt-2">
            <label class="hb-lbl">
                {{ __('attributes') }}
                <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('listing_attributes_hint')" />
            </label>
            <AppSelect class="form-select form-select-sm" multiple :model-value="filters.attribute_value_ids"
                @update:model-value="filters.attribute_value_ids = $event"
                :options="attributeOptions" :placeholder="__('select_attribute_values')"
                :loading="attributesLoading" />
            <small v-if="filters.category_id && !attributesLoading && !attributeOptions.length"
                class="text-muted d-block mt-1">{{ __('no_attributes_for_category') }}</small>
            <small v-else-if="filters.category_id" class="text-muted d-block mt-1">
                {{ __('attributes_scoped_to_category') }}
            </small>
        </div>

        <div class="row g-2 mt-1">
            <div class="col-6 col-md-3">
                <label class="hb-lbl">{{ __('min_price') }}</label>
                <input type="number" min="0" step="any" class="form-control form-control-sm"
                    v-model="filters.min_price" placeholder="0">
            </div>
            <div class="col-6 col-md-3">
                <label class="hb-lbl">{{ __('max_price') }}</label>
                <input type="number" min="0" step="any" class="form-control form-control-sm"
                    :class="{ 'is-invalid': priceRangeInvalid }"
                    v-model="filters.max_price" :placeholder="__('no_limit')">
            </div>
            <div class="col-6 col-md-3">
                <label class="hb-lbl">{{ __('min_discount_percent') }}</label>
                <input type="number" min="0" max="100" step="1" class="form-control form-control-sm"
                    v-model="filters.min_discount_percent" placeholder="0">
            </div>
            <div class="col-6 col-md-3">
                <label class="hb-lbl">{{ __('max_discount_percent') }}</label>
                <input type="number" min="0" max="100" step="1" class="form-control form-control-sm"
                    :class="{ 'is-invalid': discountRangeInvalid }"
                    v-model="filters.max_discount_percent" :placeholder="__('no_limit')">
            </div>
        </div>

        <small v-if="priceRangeInvalid" class="text-danger d-block mt-1">{{ __('max_price_below_min') }}</small>
        <small v-if="discountRangeInvalid" class="text-danger d-block mt-1">{{ __('max_discount_below_min') }}</small>
        <small v-if="hasDiscountBound" class="text-muted d-block mt-1">{{ __('discount_filter_note') }}</small>

        <div class="mt-2">
            <label class="hb-lbl">{{ __('sort_products_by') }}</label>
            <AppSelect class="form-select form-select-sm" v-model="filters.sort"
                :options="sortOptions" :searchable="false" :allow-empty="false" />
        </div>
    </div>
</template>

<script>
import TranslatableInput from './TranslatableInput.vue';
import { attributeValueOptions, redirectSortOptions, toRedirectFilters } from '../homeBuilderHelpers.js';
import { Filter, Info } from 'lucide-vue-next';

export default {
    name: 'RedirectFilterPicker',
    components: { TranslatableInput, Filter, Info },
    props: {
        // The object holding the redirect — a banner item, or a block config.
        // `redirect_filters` is read and written in place.
        target: { type: Object, required: true },
        allCategories: { type: Array, default: () => [] },
        allBrands: { type: Array, default: () => [] },
        languages: { type: Array, default: () => [] },
        activeLang: { type: [Number, String], default: null },
    },
    data() {
        return { attributeOptions: [], attributesLoading: false };
    },
    computed: {
        // A layout saved before this feature has no filter object at all.
        filters() {
            if (!this.target.redirect_filters || typeof this.target.redirect_filters !== 'object') {
                this.target.redirect_filters = toRedirectFilters(null);
            }
            return this.target.redirect_filters;
        },
        plainTitle() {
            const t = this.filters.title;
            return typeof t === 'string' ? t : '';
        },
        sortOptions() {
            return redirectSortOptions();
        },
        hasDiscountBound() {
            return Number(this.filters.min_discount_percent) > 0 || Number(this.filters.max_discount_percent) > 0;
        },
        priceRangeInvalid() {
            const min = this.filters.min_price;
            const max = this.filters.max_price;
            return min !== '' && max !== '' && Number(max) < Number(min);
        },
        discountRangeInvalid() {
            const min = this.filters.min_discount_percent;
            const max = this.filters.max_discount_percent;
            return min !== '' && max !== '' && Number(max) < Number(min);
        },
    },
    watch: {
        // A narrower category means a narrower attribute list, and a value picked
        // under the old category may not exist under the new one — left in place it
        // would quietly filter the listing down to nothing.
        'filters.category_id'() {
            this.loadAttributes(true);
        },
    },
    methods: {
        async loadAttributes(prune = false) {
            const cat = this.filters.category_id;
            this.attributesLoading = true;
            try {
                const rows = await attributeValueOptions(cat);
                // The admin may have changed the category while this was in flight.
                if (String(this.filters.category_id) !== String(cat)) {
                    return;
                }
                this.attributeOptions = rows;
                if (prune) {
                    const allowed = new Set(rows.map((r) => String(r.id)));
                    this.filters.attribute_value_ids = this.filters.attribute_value_ids
                        .filter((id) => allowed.has(String(id)));
                }
            } catch (e) {
                // A failed load must not break the editor or drop what is selected;
                // the list stays as it was and reloads on the next category change.
            } finally {
                if (String(this.filters.category_id) === String(cat)) {
                    this.attributesLoading = false;
                }
            }
        },
    },
    mounted() {
        this.loadAttributes();
    },
};
</script>

<style scoped>
.hb-redirect-filters {
    margin-top: .5rem;
    padding: .6rem;
    border: 1px dashed var(--bs-border-color);
    border-radius: 6px;
}
.hb-rf-head {
    display: flex;
    align-items: center;
    gap: .35rem;
    font-size: .78rem;
    font-weight: 600;
    margin-bottom: .5rem;
}
.hb-lbl {
    font-size: .75rem;
    color: var(--app-muted);
    margin-bottom: .15rem;
    display: block;
}
.hb-info {
    cursor: help;
    opacity: .6;
}</style>
