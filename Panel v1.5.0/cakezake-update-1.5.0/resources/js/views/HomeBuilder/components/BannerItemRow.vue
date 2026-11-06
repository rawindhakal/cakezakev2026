<template>
    <div class="hb-banner-item">
        <div class="hb-banner-item-head" @click="open = !open">
            <component :is="open ? 'ChevronDown' : 'ChevronRight'" :size="15" />
            <span class="fw-bold">{{ __('banner') }} {{ index + 1 }}</span>
            <div class="ms-auto d-flex gap-1" @click.stop>
                <button type="button" class="btn btn-xs btn-light" :disabled="index === 0"
                    @click="$emit('move-up')"><ArrowUp :size="14" /></button>
                <button type="button" class="btn btn-xs btn-light" :disabled="index === count - 1"
                    @click="$emit('move-down')"><ArrowDown :size="14" /></button>
                <button type="button" class="btn btn-xs btn-light text-danger"
                    @click="$emit('remove')"><Trash2 :size="14" /></button>
            </div>
        </div>

        <div v-if="open" class="hb-banner-item-body">
            <div class="row g-2 mb-2">
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

            <div class="row g-2">
                <div class="col-md-5">
                    <label class="form-label small text-muted mb-1">{{ __('redirect_type') }}</label>
                    <AppSelect class="form-select form-select-sm" v-model="item.redirect_type"
                        :options="redirectTypeOptions" :searchable="false" :allow-empty="false" />
                </div>

                <div class="col-md-7" v-if="hasRedirectTarget">
                    <label class="form-label small text-muted mb-1">{{ __('redirect_target') }}</label>
                    <AppSelect class="form-select form-select-sm" v-if="item.redirect_type === 'product'"
                        :model-value="item.redirect_id"
                        @update:model-value="item.redirect_id = $event"
                        :options="allProducts" :placeholder="__('select_product')" />
                    <AppSelect class="form-select form-select-sm" v-else-if="item.redirect_type === 'category'"
                        :model-value="item.redirect_id"
                        @update:model-value="item.redirect_id = $event"
                        :options="allCategories" :placeholder="__('select_category')" />
                    <AppSelect class="form-select form-select-sm" v-else-if="item.redirect_type === 'brand'"
                        :model-value="item.redirect_id"
                        @update:model-value="item.redirect_id = $event"
                        :options="allBrands" :placeholder="__('select_brand')" />
                    <AppSelect class="form-select form-select-sm" v-else-if="item.redirect_type === 'page'"
                        :model-value="item.redirect_id"
                        @update:model-value="item.redirect_id = $event"
                        :options="allPages" :placeholder="__('select_page')" />
                    <input v-else type="text" class="form-control form-control-sm" v-model="item.redirect_url"
                        placeholder="https://">
                </div>
            </div>

            <RedirectFilterPicker v-if="item.redirect_type === 'products'" :target="item"
                :all-categories="allCategories" :all-brands="allBrands"
                :languages="languages" :active-lang="activeLang" />
        </div>
    </div>
</template>

<script>
import HbImageUpload from './HbImageUpload.vue';
import RedirectFilterPicker from './RedirectFilterPicker.vue';
import { redirectTypeOptions } from '../homeBuilderHelpers.js';
import { ChevronDown, ChevronRight, ArrowUp, ArrowDown, Trash2 } from 'lucide-vue-next';

export default {
    name: 'BannerItemRow',
    components: { ChevronDown, ChevronRight, ArrowUp, ArrowDown, Trash2, HbImageUpload, RedirectFilterPicker },
    props: {
        item: { type: Object, required: true },
        index: { type: Number, required: true },
        count: { type: Number, required: true },
        allProducts: { type: Array, default: () => [] },
        allCategories: { type: Array, default: () => [] },
        allBrands: { type: Array, default: () => [] },
        allPages: { type: Array, default: () => [] },
        languages: { type: Array, default: () => [] },
        activeLang: { type: [Number, String], default: null },
    },
    emits: ['remove', 'move-up', 'move-down'],
    computed: {
        // Everything except 'none' and 'products' points at one record the admin picks.
        hasRedirectTarget() {
            return !!this.item.redirect_type && !['none', 'products'].includes(this.item.redirect_type);
        },
        // Fixed option set — no search box needed.
        redirectTypeOptions() {
            return redirectTypeOptions();
        },
    },
    data() {
        return { open: false };
    },
};
</script>

<style scoped>
.hb-banner-item {
    border: 1px solid var(--app-card-border);
    border-radius: .5rem;
    margin-bottom: .5rem;
    background: var(--app-card-bg);
}
.hb-banner-item-head {
    display: flex;
    align-items: center;
    gap: .5rem;
    padding: .5rem .75rem;
    cursor: pointer;
    font-size: .85rem;
}
.hb-banner-item-body {
    padding: .25rem .75rem .75rem;
    border-top: 1px solid #f1f1f1;
}
.btn-xs {
    padding: .1rem .35rem;
    font-size: .7rem;
    line-height: 1.2;
}
</style>
