<template>
    <div class="hb-redirect">
        <div class="row g-2">
            <div class="col-md-4">
                <label class="form-label small text-muted mb-1">{{ __('redirect_type') }}</label>
                <AppSelect class="form-select form-select-sm" v-model="config.redirect_type"
                    :options="redirectTypeOptions" :searchable="false" :allow-empty="false" />
            </div>
            <!-- A filtered listing has no single target to pick: its whole target is
                 the filter panel below, so the column is left out entirely. -->
            <div class="col-md-8" v-if="hasRedirectTarget">
                <label class="form-label small text-muted mb-1">{{ __('redirect_target') }}</label>
                <AppSelect class="form-select form-select-sm" v-if="config.redirect_type === 'product'"
                    :model-value="config.redirect_id"
                    @update:model-value="config.redirect_id = $event"
                    :options="allProducts" :placeholder="__('select_product')" />
                <AppSelect v-else-if="config.redirect_type === 'category'"
                    :model-value="config.redirect_id"
                    @update:model-value="config.redirect_id = $event"
                    :options="allCategories" :placeholder="__('select_category')" />
                <AppSelect v-else-if="config.redirect_type === 'brand'"
                    :model-value="config.redirect_id"
                    @update:model-value="config.redirect_id = $event"
                    :options="allBrands" :placeholder="__('select_brand')" />
                <AppSelect v-else-if="config.redirect_type === 'page'"
                    :model-value="config.redirect_id"
                    @update:model-value="config.redirect_id = $event"
                    :options="allPages" :placeholder="__('select_page')" />
                <input v-else type="text" class="form-control form-control-sm" v-model="config.redirect_url"
                    placeholder="https://">
            </div>
        </div>

        <RedirectFilterPicker v-if="config.redirect_type === 'products'" :target="config"
            :all-categories="allCategories" :all-brands="allBrands"
            :languages="languages" :active-lang="activeLang" />
    </div>
</template>

<script>
import { redirectTypeOptions } from '../homeBuilderHelpers.js';
import RedirectFilterPicker from './RedirectFilterPicker.vue';

export default {
    name: 'RedirectPicker',
    components: { RedirectFilterPicker },
    props: {
        config: { type: Object, required: true },
        allProducts: { type: Array, default: () => [] },
        allCategories: { type: Array, default: () => [] },
        allBrands: { type: Array, default: () => [] },
        allPages: { type: Array, default: () => [] },
        languages: { type: Array, default: () => [] },
        activeLang: { type: [Number, String], default: null },
    },
    computed: {
        // Everything except 'none' and 'products' points at one record the admin picks.
        hasRedirectTarget() {
            return !!this.config.redirect_type && !['none', 'products'].includes(this.config.redirect_type);
        },
        // Fixed option set — no search box needed.
        redirectTypeOptions() {
            return redirectTypeOptions();
        },
    },
};
</script>

<style scoped>
.hb-redirect {
    margin-top: .25rem;
}
.hb-lbl {
    font-size: .75rem;
    color: var(--app-muted);
    margin-bottom: .15rem;
    display: block;
}
</style>
