<template>
    <div class="list-page">
        <!-- Title + primary action outside any card. -->
        <div class="page-head">
            <h3 class="page-head-title">{{ __('manage_products') }}</h3>
            <router-link v-if="$can('product_create')" to="/products/create"
                class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap">
                <Plus :size="16" /><span>{{ __('add_product') }}</span>
            </router-link>
        </div>

        <!-- Everything (toolbar + filters + grid + pager) inside one card. -->
        <div class="list-surface">
        <!-- Toolbar: Published/Drafts on the LEFT, controls on the RIGHT. -->
        <div class="card-toolbar products-toolbar list-panel-toolbar">
            <div class="btn-group product-tabs" role="group">
                <button type="button" class="btn"
                    :class="isDraftTab === 0 ? 'btn-primary' : 'btn-outline-primary'" @click="setTab(0)">
                    {{ __('published') }}
                </button>
                <button type="button" class="btn"
                    :class="isDraftTab === 1 ? 'btn-primary' : 'btn-outline-primary'" @click="setTab(1)">
                    {{ __('drafts') }}
                    <span class="count-pill">{{ counts.draft }}</span>
                </button>
            </div>

            <div class="products-toolbar-right">
                <AppSelect v-if="czShowCountry" class="cz-sel" v-model="czCountryId" :options="czCountryOptions"
                    :searchable="czCountryOptions.length > 6" :allow-empty="false" label-key="label" track-by="id"
                    :placeholder="__('country')" @update:model-value="czOnCountry">
                    <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                    <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                </AppSelect>
                <AppSelect v-if="czShowZoneDropdown" class="cz-sel" v-model="czZoneId" :options="czZoneOptions"
                    :searchable="false" :allow-empty="false" label-key="label" track-by="id"
                    :placeholder="__('zone')" @update:model-value="czOnZone" />
                <button class="btn" :class="showFilters ? 'btn-primary' : 'btn-outline-primary'"
                    @click="showFilters = !showFilters">
                    <SlidersHorizontal :size="15" /> {{ __('filters') }}
                    <span v-if="activeFilterCount" class="badge bg-light text-dark ms-1">{{ activeFilterCount }}</span>
                </button>
                <AppSelect class="form-select list-select" v-model="sort_by" :options="sort_byOptions" :searchable="false" @update:model-value="onFilterChange" />
                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input type="search" class="form-control" v-model="search"
                        :placeholder="__('search_products')" @input="onFilterChange" />
                </div>
                <button class="list-icon-btn" @click="getRecords" :disabled="isLoading"
                    v-b-tooltip.hover :title="__('refresh')">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>
        </div>

        <!-- Collapsible filter panel -->
        <transition name="filter-slide">
        <div v-if="showFilters" class="list-filters">
            <div class="row g-3">
                <div class="col-lg-3 col-md-4 col-6">
                    <label class="flbl">{{ __('categories') }}</label>
                    <AppSelect class="form-select" v-model="category_id" :options="translatedCategories"
                        :placeholder="__('all_categories')" @update:model-value="onFilterChange" />
                </div>
                <div class="col-lg-3 col-md-4 col-6">
                    <label class="flbl">{{ __('brand') }}</label>
                    <AppSelect class="form-select" v-model="brand_id" :options="translatedBrands"
                        :placeholder="__('all_brands')" @update:model-value="onFilterChange" />
                </div>
                <div class="col-lg-3 col-md-4 col-6">
                    <label class="flbl">{{ __('tax_category') }}</label>
                    <AppSelect class="form-select" v-model="tax_category_id" :options="taxCategoryOptions"
                        :searchable="true" @update:model-value="onFilterChange" />
                </div>
                <div class="col-lg-2 col-md-4 col-6">
                    <label class="flbl">{{ __('status') }}</label>
                    <AppSelect class="form-select" v-model="status" :options="statusOptions" :searchable="false" @update:model-value="onFilterChange" />
                </div>
                <div class="col-lg-2 col-md-4 col-6">
                    <label class="flbl">{{ __('sales_channel') }}</label>
                    <AppSelect class="form-select" v-model="sales_channel" :options="sales_channelOptions" :searchable="false" @update:model-value="onFilterChange" />
                </div>
                <div class="col-lg-2 col-md-4 col-6">
                    <!-- Drafts are listed nowhere yet, so the toggle is meaningless there. -->
                    <label class="flbl d-inline-flex align-items-center gap-1" v-if="isDraftTab === 0">
                        {{ __('listed_only') }}
                        <Info :size="13" class="text-muted" style="cursor:help;" v-b-tooltip.hover :title="__('listed_only_hint')" />
                    </label>
                    <label class="flbl" v-else>&nbsp;</label>
                    <div class="d-flex align-items-center justify-content-between gap-3" style="height:38px;">
                        <div class="form-check form-switch d-flex align-items-center gap-2 m-0 ps-0" v-if="isDraftTab === 0">
                            <input class="form-check-input m-0 float-none" type="checkbox" role="switch"
                                id="listedOnlyToggle" v-model="listedOnly" @change="onFilterChange">
                            <label class="form-check-label small mb-0 text-nowrap" for="listedOnlyToggle">{{ listedOnly ? __('yes') : __('no') }}</label>
                        </div>
                        <div v-else></div>
                        <button class="list-icon-btn" @click="resetFilters" :disabled="!activeFilterCount"
                            v-b-tooltip.hover :title="__('clear_filters')">
                            <X :size="15" />
                        </button>
                    </div>
                </div>
            </div>
        </div>
        </transition>

        <!-- Grid -->
            <div class="list-panel-body">
                <div class="card-grid">
                    <!-- Skeleton placeholders while loading (no layout jump). -->
                    <EntityCardSkeleton v-if="isLoading" :count="skeletonCount" />
                    <div v-else-if="products.length === 0" class="card-grid-empty">
                        <Inbox :size="34" />
                        <span>{{ __('no_records_found') }}</span>
                    </div>

            <div v-else v-for="p in translatedProducts" :key="'p-' + p.id" class="entity-card">
                <div class="entity-card-media is-contain">
                    <img :src="p.image_url || placeholderImg" alt="" />
                    <!-- Rating badge, top-left. Drops below the draft pill when both show. -->
                    <span v-if="Number(p.rating_avg) > 0" class="rating-badge"
                        :class="{ 'is-below': p.is_draft, 'is-link': canOpenRatings }"
                        @click.stop="openRatings(p.id)">
                        <span class="rating-badge-star">
                            <Star :size="12" class="rating-badge-star-bg" />
                            <span class="rating-badge-star-fill" :style="{ width: ratingFillPct(p) + '%' }">
                                <Star :size="12" />
                            </span>
                        </span>
                        {{ ratingAvg(p) }}
                    </span>
                    <span v-if="p.is_draft" class="status-pill is-warning is-start">{{ __('draft') }}</span>
                    <span v-else class="status-pill" :class="p.status ? 'is-active' : 'is-inactive'">
                        {{ p.status ? __('active') : __('inactive') }}
                    </span>
                </div>

                <div class="entity-card-body">
                    <h4 class="entity-card-title text-truncate" :title="p.name">{{ p.name }}</h4>
                    <div class="entity-card-meta">
                        <div class="d-flex align-items-center justify-content-between gap-2">
                            <span class="entity-meta-row text-truncate">{{ p.category ? p.category.name : '—' }}</span>
                            <span class="mode-chip flex-shrink-0">
                                <component :is="(p.sales_channel || 'both') === 'quick' ? 'Zap' : ((p.sales_channel || 'both') === 'ecommerce' ? 'ShoppingBag' : 'Layers')" :size="13" />
                                {{ channelLabel(p) }}
                            </span>
                        </div>
                        <span class="entity-meta-row">
                            <b class="text-primary">{{ displayCurrency }}{{ priceLabel(p) }}</b>
                            <button type="button" class="ms-auto variant-count-btn"
                                v-b-tooltip.hover :title="__('view_variants')" @click.stop="openVariants(p)">
                                {{ p.variants_count }} {{ p.variants_count === 1 ? __('variant') : __('variants') }}
                            </button>
                        </span>
                    </div>

                    <div class="entity-card-foot">
                        <div class="list-actions">
                            <router-link :to="viewRoute(p)" class="list-action-btn is-view"
                                v-if="$can('product_list')" v-b-tooltip.hover :title="__('view')">
                                <Eye :size="15" />
                            </router-link>
                            <router-link :to="editRoute(p)" class="list-action-btn is-edit"
                                v-if="$can('product_update')" v-b-tooltip.hover :title="__('edit')">
                                <Pencil :size="15" />
                            </router-link>
                            <router-link :to="cloneRoute(p)" class="list-action-btn is-edit"
                                v-if="$can('product_create')" v-b-tooltip.hover :title="__('clone_product')">
                                <Copy :size="15" />
                            </router-link>
                            <button class="list-action-btn is-edit" @click="openRecommendations(p)"
                                v-if="$can('product_update')" v-b-tooltip.hover :title="__('recommendations')">
                                <Link :size="15" />
                            </button>
                            <!-- Only a food product asks addon questions. -->
                            <router-link :to="'/products/' + p.id + '/addons'" class="list-action-btn is-edit"
                                v-if="$can('product_update') && Number(p.is_food) === 1"
                                v-b-tooltip.hover :title="__('set_addons_for_this_product')">
                                <ListPlus :size="15" />
                            </router-link>
                            <button class="list-action-btn is-delete" @click="deleteRecord(p)"
                                v-if="$can('product_delete')" v-b-tooltip.hover :title="__('delete')">
                                <Trash2 :size="15" />
                            </button>
                        </div>
                    </div>
                </div>
                </div>
            </div>
            </div>

            <!-- Pagination -->
            <div v-if="!isLoading && products.length > 0" class="list-footer">
                <div class="list-perpage">
                    <span>{{ __('per_page') }}</span>
                    <b-form-select v-model="perPage" :options="pageOptions" size="sm"
                        class="form-select" @change="onPerPageChange"></b-form-select>
                    <span class="list-range">{{ __('total_records') }} : {{ totalRows }}</span>
                </div>
                <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage"
                    size="sm" class="my-0"></b-pagination>
            </div>
        </div>

        <!-- Variants quick-look: the listing shows a count, this shows what they are. -->
        <b-modal v-model="variantModal.show" size="lg" centered :no-footer="true">
            <template #title>
                <span class="d-inline-flex align-items-center gap-2">
                    <Layers :size="16" />
                    <span>{{ __('variants') }}<span v-if="variantModal.product"> — {{ variantModal.product.name }}</span></span>
                </span>
            </template>

            <div v-if="variantModal.loading" class="text-center py-4">
                <b-spinner small></b-spinner>
            </div>
            <div v-else-if="!variantModal.rows.length" class="empty-block">{{ __('no_data_found') }}</div>
            <div v-else class="variant-grid">
                <div v-for="v in variantModal.rows" :key="v.id" class="variant-card">
                    <div class="variant-thumb">
                        <img v-if="v.image" :src="v.image" alt="" />
                        <PackageOpen v-else :size="22" />
                    </div>
                    <div class="variant-info min-w-0">
                        <div class="fw-semibold text-truncate" :title="v.name">{{ v.name }}</div>
                        <div class="variant-attrs" v-if="v.attributes.length">
                            <span v-for="(a, ai) in v.attributes" :key="ai" class="variant-attr">
                                {{ a.name }}: <b>{{ a.value }}</b>
                            </span>
                        </div>
                        <div class="variant-sku" v-if="v.sku">{{ __('sku') }}: {{ v.sku }}</div>
                        <div class="variant-foot">
                            <b class="text-primary">{{ displayCurrency }}{{ variantPrice(v) }}</b>
                        </div>
                    </div>
                </div>
            </div>
        </b-modal>

        <!-- Recommendations (cross-sell / up-sell) modal -->
        <b-modal v-model="reco.show" size="lg" centered :no-footer="true">
            <template #title>
                <span class="d-inline-flex align-items-center gap-2">
                    <Link :size="16" />
                    <span>{{ __('recommendations') }}<span v-if="reco.product"> — {{ reco.product.name }}</span></span>
                </span>
            </template>
            <div v-if="reco.product" class="reco-modal">
                <!-- type toggle (solid / outline buttons) -->
                <div class="d-flex gap-2 mb-3">
                    <button type="button" class="btn flex-fill"
                        :class="reco.activeType === 'cross_sell' ? 'btn-primary' : 'btn-outline-primary'"
                        @click="reco.activeType = 'cross_sell'">
                        <ShoppingCart :size="15" /> {{ __('cross_sell') }}
                        <span class="count-pill">{{ reco.cross_sell.length }}</span>
                    </button>
                    <button type="button" class="btn flex-fill"
                        :class="reco.activeType === 'upsell' ? 'btn-primary' : 'btn-outline-primary'"
                        @click="reco.activeType = 'upsell'">
                        <ArrowUp :size="15" /> {{ __('upsell') }}
                        <span class="count-pill">{{ reco.upsell.length }}</span>
                    </button>
                </div>

                <p class="reco-note">
                    <component :is="reco.activeType === 'upsell' ? 'ArrowUp' : 'ShoppingCart'" :size="14" />
                    <span>{{ recoNote }}</span>
                </p>

                <div v-if="reco.loading" class="text-center py-4">
                    <b-spinner></b-spinner>
                </div>

                <template v-else>
                    <!-- currently added -->
                    <div class="reco-section-label">{{ __('currently_added') }}</div>
                    <div v-if="!activeRecoList.length" class="reco-empty">
                        <PackageOpen :size="26" />
                        <span>{{ __('no_products_added_yet') }}</span>
                    </div>
                    <div v-else class="reco-list reco-list--added mb-3">
                        <div v-for="item in activeRecoList" :key="'sel-' + item.id" class="reco-row">
                            <img :src="item.image_url || placeholderImg" class="reco-thumb" alt="" />
                            <div class="reco-info">
                                <div class="reco-name text-truncate">{{ item.name }}</div>
                                <div class="reco-sub">{{ $currency }}{{ item.price }} · {{ item.sku || '—' }}</div>
                            </div>
                            <button class="reco-remove" @click="removeReco(item)"
                                v-b-tooltip.hover :title="__('remove')">
                                <X :size="15" />
                            </button>
                        </div>
                    </div>

                    <!-- search + add -->
                    <div class="reco-section-label">{{ __('add_products') }}</div>
                    <div class="reco-filters mb-2">
                        <div class="reco-filter-col">
                            <label class="flbl">{{ __('search') }}</label>
                            <div class="list-search mb-0">
                                <Search class="list-search-icon" />
                                <input type="search" class="form-control" v-model="reco.search"
                                    :placeholder="__('search_by_name_or_sku')" @input="onRecoSearch" />
                            </div>
                        </div>
                        <!-- Narrow the candidates to one category — pairing is usually within a category. -->
                        <div class="reco-filter-col">
                            <label class="flbl">{{ __('category') }}</label>
                            <AppSelect class="form-select" v-model="reco.category_id"
                                :options="recoCategoryOptions" :allow-empty="false"
                                :searchable="recoCategoryOptions.length > 6"
                                :placeholder="__('all_categories')" @update:model-value="runRecoSearch" />
                        </div>
                    </div>
                    <div v-if="reco.searching" class="text-center py-2">
                        <b-spinner small></b-spinner>
                    </div>
                    <div v-else class="reco-list">
                        <div v-for="item in availableSearchResults" :key="'res-' + item.id" class="reco-row">
                            <img :src="item.image_url || placeholderImg" class="reco-thumb" alt="" />
                            <div class="reco-info">
                                <div class="reco-name text-truncate">{{ item.name }}</div>
                                <div class="reco-sub">{{ $currency }}{{ item.price }} · {{ item.sku || '—' }}</div>
                            </div>
                            <button class="btn btn-sm btn-outline-primary reco-add" @click="addReco(item)">
                                <Plus :size="15" /> {{ __('add') }}
                            </button>
                        </div>
                        <div v-if="(reco.search || reco.category_id) && !availableSearchResults.length" class="reco-empty">
                            <Search :size="24" />
                            <span>{{ __('no_records_found') }}</span>
                        </div>
                        <div v-else-if="!availableSearchResults.length" class="reco-empty">
                            <Search :size="24" />
                            <span>{{ __('search_by_name_or_sku') }}</span>
                        </div>
                    </div>
                </template>

                <div class="reco-foot">
                    <button class="btn btn-outline-secondary" @click="reco.show = false">{{ __('cancel') }}</button>
                    <button class="btn btn-primary" @click="saveReco" :disabled="reco.saving">
                        <b-spinner small v-if="reco.saving"></b-spinner>
                        {{ __('save') }}
                    </button>
                </div>
            </div>
        </b-modal>
    </div>
</template>

<script>
import axios from "axios";
import Auth from '../../Auth.js';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';
import ListState from '../../mixins/ListState.js';
import {
    Plus, Search, SlidersHorizontal, RefreshCw, X, Inbox, Eye, Pencil, Copy,
    Link, Trash2, Zap, ShoppingBag, Layers, PackageOpen, ShoppingCart, ArrowUp, Info, Star, ListPlus,
} from 'lucide-vue-next';

export default {
    mixins: [CountryZoneFilter, ListState],
    // Come back from a product and land where you left, not on page 1.
    listState: ['currentPage', 'perPage', 'search', 'category_id', 'brand_id', 'tax_category_id',
        'status', 'sales_channel', 'sort_by', 'isDraftTab', 'listedOnly'],
    components: {
        Plus, Search, SlidersHorizontal, RefreshCw, X, Inbox, Eye, Pencil, Copy,
        Link, Trash2, Zap, ShoppingBag, Layers, PackageOpen, ShoppingCart, ArrowUp, Info, Star, ListPlus,
    },
    data() {
        return {
            // Products are branch/zone-priced with a single response currency → country-locked.
            login_user: Auth.user,
            products: [],
            categories: [],
            brands: [],
            counts: { published: 0, draft: 0 },

            search: '',
            category_id: '',
            brand_id: '',
            tax_category_id: '',
            taxCategories: [],
            status: '',
            sales_channel: '',
            sort_by: 'latest',
            currency: '',
            listedOnly: true,
            showFilters: false,
            isDraftTab: 0,

            currentPage: 1,
            perPage: 30,
            pageOptions: this.$pageOptions,
            totalRows: 0,

            isLoading: true,
            currentLanguageId: null,
            activeLanguages: [],
            defaultLanguageId: null,
            _searchTimer: null,

            // Null-image placeholder: favicon -> logo -> bundled default (all
            // guaranteed to resolve). Broken/404 image urls are handled by the
            // global fallback in app.js, so no per-img @error needed here.
            placeholderImg: window.appFavicon
                || (window.appLogo ? window.baseUrl + '/storage/' + window.appLogo : '')
                || (window.baseUrl + '/images/logo.png'),

            variantModal: { show: false, product: null, rows: [], loading: false },
            reco: {
                show: false,
                product: null,
                activeType: 'cross_sell',
                cross_sell: [],
                upsell: [],
                search: '',
                category_id: '',
                searchResults: [],
                loading: false,
                searching: false,
                saving: false,
                _searchTimer: null,
            },
        };
    },
    computed: {
        // The ratings page is guarded by product_ratings — don't offer a dead link.
        canOpenRatings() { return this.$can('product_ratings'); },
        // Fixed option set — no search box needed.
        sort_byOptions() {
            return [
                { id: 'latest', name: (__('latest')) },
                { id: 'oldest', name: (__('oldest')) },
                { id: 'name_asc', name: (__('name')) + ' ' + 'A-Z' },
                { id: 'name_desc', name: (__('name')) + ' ' + 'Z-A' },
                { id: 'price_low', name: (__('price_low_to_high')) },
                { id: 'price_high', name: (__('price_high_to_low')) },
            ];
        },
        // Fixed option set — no search box needed.
        statusOptions() {
            return [
                { id: '', name: (__('all_statuses')) },
                { id: '1', name: (__('active')) },
                { id: '0', name: (__('inactive')) },
            ];
        },
        // Fixed option set — no search box needed.
        sales_channelOptions() {
            return [
                { id: '', name: (__('all')) },
                { id: 'quick', name: (__('quick')) },
                { id: 'ecommerce', name: (__('ecommerce')) },
                { id: 'both', name: (__('both')) },
            ];
        },
        activeRecoList() {
            return this.reco[this.reco.activeType] || [];
        },
        availableSearchResults() {
            // Hide products already in the active list.
            const added = new Set(this.activeRecoList.map(p => p.id));
            return this.reco.searchResults.filter(p => !added.has(p.id));
        },
        recoNote() {
            const raw = this.reco.activeType === 'upsell' ? __('upsell_note') : __('cross_sell_note');
            // The translation strings lead with an emoji (🛒 / ⬆️); strip it — a lucide
            // icon is rendered in its place in the template.
            return raw.replace(/^[^\p{L}\p{N}]+/u, '').trim();
        },
        taxCategoryOptions() {
            return [
                { id: '', name: __('all_tax_categories') },
                { id: 0, name: __('not_set') },
            ].concat(this.taxCategories.map(t => ({
                id: t.id,
                name: t.code ? `${t.name} (${t.code})` : t.name,
            })));
        },
        activeFilterCount() {
            return [this.category_id, this.brand_id, this.tax_category_id, this.status, this.sales_channel]
                .filter(v => v !== '' && v !== null).length;
        },
        // How many skeleton cards to show while loading: reuse the last-known row
        // count, capped so we don't paint a huge grid.
        skeletonCount() {
            const known = this.products.length || this.perPage || 10;
            return Math.min(known, 12);
        },
        // Brand filter options, translated to the active language.
        translatedBrands() {
            return this.brands.map(b => {
                const out = { ...b };
                const t = this.pickTranslation(b.translations);
                if (t && t.name && t.name.trim()) out.name = t.name;
                return out;
            });
        },
        // Currency of the header-selected country; falls back to the global currency.
        displayCurrency() {
            return this.currency || this.$currency;
        },
        translatedProducts() {
            if (!this.currentLanguageId || this.products.length === 0) return this.products;
            return this.products.map(p => {
                const out = { ...p };
                const t = this.pickTranslation(p.translations);
                if (t && t.name && t.name.trim()) out.name = t.name;
                if (p.category) {
                    out.category = { ...p.category };
                    const ct = this.pickTranslation(p.category.translations);
                    if (ct && ct.name && ct.name.trim()) out.category.name = ct.name;
                }
                if (p.branch) {
                    out.branch = { ...p.branch };
                    const st = this.pickTranslation(p.branch.translations);
                    if (st && st.name && st.name.trim()) out.branch.name = st.name;
                }
                return out;
            });
        },
        // Same tree as the page filter, with an explicit "all" entry on top.
        recoCategoryOptions() {
            return [{ id: '', name: __('all_categories') }].concat(this.translatedCategories || []);
        },
        translatedCategories() {
            // Translate names, then flatten into an indented tree. Parent categories
            // (those with children) are shown but disabled — only leaf/child categories
            // are selectable in the filter.
            const list = this.categories.map(c => {
                const out = { ...c, parent_id: Number(c.parent_id || 0) };
                const t = this.pickTranslation(c.translations);
                if (t && t.name && t.name.trim()) out.name = t.name;
                return out;
            });
            // Group children by parent. A child whose parent isn't in the list
            // (e.g. an inactive parent the API omitted) is promoted to a root so it
            // never disappears from the tree.
            const idSet = new Set(list.map(c => c.id));
            const byParent = {};
            list.forEach(c => {
                const pid = idSet.has(c.parent_id) ? c.parent_id : 0;
                (byParent[pid] = byParent[pid] || []).push(c);
            });

            const INDENT = '\u00A0\u00A0\u00A0\u00A0'; // nbsp — plain spaces collapse in the dropdown
            const out = [];
            const walk = (parentId, depth) => {
                (byParent[parentId] || []).forEach(c => {
                    const hasChildren = (byParent[c.id] || []).length > 0;
                    out.push({
                        ...c,
                        name: (depth ? INDENT.repeat(depth) + '↳ ' : '') + c.name,
                        $isDisabled: hasChildren, // parents shown but not selectable
                    });
                    walk(c.id, depth + 1);
                });
            };
            walk(0, 0);
            return out;
        },
    },
    created() {
        if (!this.$can('product_list')) {
            this.showError("You do not have permission to view this page.");
            this.$router.back();
            return;
        }
        this.fetchActiveLanguages();
        this.czLoad(); // sets default country then getRecords via czOnFilter
    },
    watch: {
        currentPage() { this.getRecords(); },
    },
    methods: {
        czOnFilter() {
            // A restored visit keeps its page; a real filter change starts over.
            if (!this.consumeListRestore()) this.currentPage = 1;
            this.getRecords();
        },
        fetchActiveLanguages() {
            return axios.get(this.$apiUrl + '/active_languages').then(r => {
                const langs = r.data.data || [];
                this.activeLanguages = langs;
                const def = langs.find(l => l.is_default === 1);
                this.defaultLanguageId = def ? def.id : null;
                const appLocale = window.appLocale || 'en';
                const cur = langs.find(l => l.code === appLocale);
                this.currentLanguageId = cur ? cur.id : (def ? def.id : null);
            }).catch(() => { });
        },
        pickTranslation(translations) {
            if (!Array.isArray(translations)) return null;
            let t = translations.find(x => Number(x.language_id) === Number(this.currentLanguageId));
            if (!t && this.defaultLanguageId) {
                t = translations.find(x => Number(x.language_id) === Number(this.defaultLanguageId));
            }
            return t || null;
        },
        setTab(tab) {
            if (this.isDraftTab === tab) return;
            this.isDraftTab = tab;
            this.currentPage = 1;
            this.getRecords();
        },
        onFilterChange() {
            if (this._searchTimer) clearTimeout(this._searchTimer);
            this._searchTimer = setTimeout(() => {
                this.currentPage = 1;
                this.getRecords();
            }, 300);
        },
        resetFilters() {
            this.category_id = '';
            this.brand_id = '';
            this.tax_category_id = '';
            this.status = '';
            this.sales_channel = '';
            this.currentPage = 1;
            this.getRecords();
        },
        onPerPageChange() {
            this.currentPage = 1;
            this.getRecords();
        },
        getRecords() {
            this.isLoading = true;
            const params = {
                page: this.currentPage,
                per_page: this.perPage,
                search: this.search,
                category_id: this.category_id,
                brand_id: this.brand_id,
                tax_category_id: this.tax_category_id,
                status: this.status,
                sales_channel: this.sales_channel,
                is_draft: this.isDraftTab,
                sort_by: this.sort_by,
                country_id: this.czCountryParam,
                zone_id: this.czZoneParam,
                // Listed-only toggle: only products with a listed branch (in the header region).
                // Drafts have no listing yet, so it is never sent on that tab.
                listed_only: (this.isDraftTab === 0 && this.listedOnly) ? 1 : 0,
            };
            axios.get(this.$apiUrl + '/products', { params }).then(r => {
                const d = r.data.data || {};
                this.products = d.products || [];
                this.categories = d.categories || [];
                this.brands = d.brands || [];
                this.taxCategories = d.tax_categories || [];
                this.counts = d.counts || { published: 0, draft: 0 };
                this.currency = d.currency || '';
                this.totalRows = r.data.total || 0;
            }).catch(() => {
                this.products = [];
            }).finally(() => {
                this.isLoading = false;
            });
        },
        // Rating badge: average to one decimal, star filled proportionally.
        ratingAvg(p) {
            return (Math.round((Number(p.rating_avg) || 0) * 10) / 10).toFixed(1);
        },
        ratingFillPct(p) {
            const avg = Math.max(0, Math.min(5, Number(p.rating_avg) || 0));
            return (avg / 5) * 100;
        },
        openRatings(id) {
            if (!id || !this.canOpenRatings) return;
            this.$router.push('/product_ratings/view/' + id);
        },
        channelLabel(p) {
            const c = p.sales_channel || 'both';
            if (c === 'quick') return __('quick');
            if (c === 'ecommerce') return __('ecommerce');
            return __('both');
        },
        priceLabel(p) {
            if (!p.min_price && !p.max_price) return '0';
            if (p.min_price === p.max_price) return Number(p.min_price).toFixed(2);
            return Number(p.min_price).toFixed(2) + ' – ' + Number(p.max_price).toFixed(2);
        },
        viewRoute(p) {
            return { name: 'ViewProduct', params: { id: p.id } };
        },
        editRoute(p) {
            return { name: 'EditProduct', params: { id: p.id } };
        },
        cloneRoute(p) {
            return { name: 'CloneProduct', params: { id: p.id, clone: true } };
        },
        openVariants(p) {
            this.variantModal.product = p;
            this.variantModal.rows = [];
            this.variantModal.loading = true;
            this.variantModal.show = true;
            axios.get(this.$apiUrl + '/products/variants', { params: { product_id: p.id } })
                .then(r => { this.variantModal.rows = (r.data.data || {}).variants || []; })
                .catch(() => { this.variantModal.rows = []; })
                .finally(() => { this.variantModal.loading = false; });
        },
        // One price when every branch agrees, a range when they don't.
        variantPrice(v) {
            const lo = Number(v.min_price) || 0;
            const hi = Number(v.max_price) || 0;
            if (!lo && !hi) return '—';
            return lo === hi ? this.money(lo) : this.money(lo) + ' – ' + this.money(hi);
        },
        money(n) {
            return Number(n).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
        },
        openRecommendations(p) {
            this.reco.product = p;
            this.reco.activeType = 'cross_sell';
            this.reco.cross_sell = [];
            this.reco.upsell = [];
            this.reco.search = '';
            // Default to the product's own category — pairings are usually within it.
            this.reco.category_id = p.category ? p.category.id : '';
            this.reco.searchResults = [];
            this.reco.show = true;
            this.runRecoSearch();
            this.loadRecommendations(p.id);
        },
        loadRecommendations(productId) {
            this.reco.loading = true;
            axios.get(this.$apiUrl + '/products/recommendations', { params: { product_id: productId } })
                .then(r => {
                    const d = r.data.data || {};
                    this.reco.cross_sell = d.cross_sell || [];
                    this.reco.upsell = d.upsell || [];
                }).catch(() => { })
                .finally(() => { this.reco.loading = false; });
        },
        onRecoSearch() {
            if (this.reco._searchTimer) clearTimeout(this.reco._searchTimer);
            this.reco._searchTimer = setTimeout(() => this.runRecoSearch(), 300);
        },
        runRecoSearch() {
            if (!this.reco.product) return;
            this.reco.searching = true;
            axios.get(this.$apiUrl + '/products/recommendations/search', {
                params: {
                    product_id: this.reco.product.id,
                    search: this.reco.search,
                    category_id: this.reco.category_id || '',
                    limit: 20,
                },
            }).then(r => {
                this.reco.searchResults = r.data.data || [];
            }).catch(() => { this.reco.searchResults = []; })
                .finally(() => { this.reco.searching = false; });
        },
        addReco(item) {
            const list = this.reco[this.reco.activeType];
            if (!list.some(p => p.id === item.id)) list.push(item);
        },
        removeReco(item) {
            const type = this.reco.activeType;
            this.reco[type] = this.reco[type].filter(p => p.id !== item.id);
        },
        saveReco() {
            if (!this.reco.product) return;
            this.reco.saving = true;
            const pid = this.reco.product.id;
            const save = (type) => axios.post(this.$apiUrl + '/products/recommendations/save', {
                product_id: pid,
                type,
                related_product_ids: this.reco[type].map(p => p.id),
            });
            // Sequential (not Promise.all): parallel delete+insert on the same product
            // races on the unique index and can deadlock.
            save('cross_sell')
                .then(() => save('upsell'))
                .then(() => {
                    this.showMessage('success', __('recommendations_saved_successfully'));
                    this.reco.show = false;
                }).catch(() => { this.showError(__('something_went_wrong')); })
                .finally(() => { this.reco.saving = false; });
        },
        deleteRecord(p) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('you_want_be_able_to_revert_this'),
                confirmButtonText: __('yes_sure'),
                cancelButtonText: __('cancel'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (!result.value) return;
                axios.post(this.$apiUrl + '/products/delete', { product_id: p.id }).then(r => {
                    this.showMessage('success', r.data.message);
                    this.getRecords();
                }).catch(() => { });
            });
        },
    },
};
</script>

<style scoped>
/* Filter labels (same as Orders.vue): block display keeps the control below. */
.flbl { font-size: .72rem; color: #6c757d; margin-bottom: .2rem; display: block; }

/* Product-card / grid-column styles removed — the page now uses the shared
   .card-grid / .entity-card system in common.css. Only the recommendations
   modal's own bits remain. */
/* ---- Toolbar: tabs left, controls right ---- */
.products-toolbar {
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 0.75rem;
}
/* When the toolbar/filters live INSIDE the card, they get padding + a divider
   instead of the standalone bottom margin. */
.list-panel-toolbar {
    margin-bottom: 0;
    padding: 0.85rem 1rem;
    border-bottom: 1px solid var(--app-card-border);
}
.list-panel-filters {
    margin-bottom: 0;
    border: 0;
    border-radius: 0;
    border-bottom: 1px solid var(--app-card-border);
}
.product-tabs {
    flex: 0 0 auto;
}
.products-toolbar-right {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex: 1 1 420px;
    justify-content: flex-end;
    flex-wrap: wrap;
}
/* The .list-search input is fixed 220px globally — give it a bounded flex here
   so it never greedily swallows the toolbar's leftover width. */
.products-toolbar-right .list-search {
    flex: 0 1 240px;
    min-width: 160px;
}

/* Small screens: stack the toolbar; search takes its own full row, the other
   controls share one row. */
@media (max-width: 767.98px) {
    .products-toolbar-right {
        flex: 1 1 100%;
        justify-content: flex-start;
    }
    .products-toolbar-right .list-search {
        order: 10;
        flex: 1 1 100%;
        min-width: 0;
        max-width: none;
    }
    .products-toolbar-right .form-select {
        flex: 1 1 auto;
        max-width: none;
    }
    .product-tabs {
        width: 100%;
    }
    .product-tabs .btn {
        flex: 1 1 50%;
    }
}
.products-toolbar-right .list-search .form-control {
    width: 100%;
}

/* Count pill inside a toggle button — readable on BOTH the solid and outline
   states (currentColor adapts: white on active, primary on inactive). */
.count-pill {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 18px;
    height: 18px;
    padding: 0 6px;
    margin-inline-start: 6px;
    border-radius: 999px;
    background-color: rgba(0, 0, 0, 0.16);
    font-size: 0.7rem;
    font-weight: 700;
    line-height: 1;
}
/* Active button = white count on the solid fill; inactive = black (not primary). */
.btn-primary .count-pill {
    color: #fff;
}
.btn-outline-primary .count-pill {
    color: var(--app-ink);
    background-color: rgba(0, 0, 0, 0.1);
}

/* ---- Recommendations modal ---- */
.reco-note {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.8rem;
    color: var(--app-muted);
    margin-bottom: 1rem;
}
.reco-note svg {
    flex-shrink: 0;
    color: var(--bs-primary);
}
/* Search + category filter share one row above the candidate list: the search
   grows, the select keeps a fixed width. .list-search's input is hard-set to
   220px globally, so it has to be released here to actually flex. */
.reco-filters {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex-wrap: wrap;
}
.reco-filters {
    align-items: flex-end;
}
.reco-filter-col {
    flex: 1 1 0;
    min-width: 0;
}
.reco-filters .list-search .form-control {
    width: 100%;
}
@media (max-width: 575.98px) {
    .reco-filter-col {
        flex: 1 1 100%;
    }
}
.reco-section-label {
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.4px;
    color: var(--app-muted);
    margin-bottom: 0.5rem;
}
.reco-list {
    max-height: 260px;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 6px;
}
.reco-row {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    padding: 0.5rem 0.6rem;
    border: 1px solid var(--app-card-border);
    border-radius: 10px;
    background: var(--app-card-bg);
    transition: border-color 0.15s ease, background-color 0.15s ease;
}
.reco-row:hover {
    border-color: rgba(var(--bs-primary-rgb), 0.35);
    background: var(--app-hover);
}
.reco-thumb {
    width: 44px;
    height: 44px;
    object-fit: contain;
    background: var(--app-thead-bg);
    border: 1px solid var(--app-card-border);
    border-radius: 8px;
    flex: none;
    padding: 3px;
}
.reco-info {
    min-width: 0;
    flex: 1;
    text-align: start;
}
.reco-name {
    font-size: 0.85rem;
    font-weight: 600;
    color: var(--app-ink);
}
.reco-sub {
    font-size: 0.75rem;
    color: var(--app-muted);
}
.reco-remove {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 30px;
    height: 30px;
    flex-shrink: 0;
    border: 1px solid var(--app-card-border);
    border-radius: 7px;
    background: transparent;
    color: var(--app-muted);
    transition: all 0.15s ease;
}
.reco-remove:hover {
    border-color: #dc3545;
    background: rgba(220, 53, 69, 0.1);
    color: #dc3545;
}
.reco-add {
    flex-shrink: 0;
    border-radius: 7px;
}
.reco-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.4rem;
    padding: 1.5rem 1rem;
    color: var(--app-muted);
    font-size: 0.8rem;
}
.reco-empty svg {
    opacity: 0.45;
}
.reco-foot {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    margin-top: 1.25rem;
    padding-top: 1rem;
    border-top: 1px solid var(--app-card-border);
}

.min-w-0 {
    min-width: 0;
}

/* Variant count reads as a control, since it opens the quick-look modal. */
.variant-count-btn {
    border: 0; background: transparent; padding: 0; font: inherit; color: inherit;
    cursor: pointer; text-decoration: underline dotted; text-underline-offset: 2px;
    white-space: nowrap; flex-shrink: 0;
}
.variant-count-btn:hover { color: var(--bs-primary); }

.variant-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: .6rem; }
.variant-card {
    display: flex; gap: .6rem; padding: .6rem;
    border: 1px solid var(--app-card-border); border-radius: .5rem; background: var(--app-card-bg);
}
.variant-thumb {
    width: 56px; height: 56px; flex: 0 0 56px; border-radius: .4rem; overflow: hidden;
    background: var(--app-thead-bg); display: flex; align-items: center; justify-content: center;
    color: var(--app-muted);
}
.variant-thumb img { width: 100%; height: 100%; object-fit: contain; }
.variant-info { display: flex; flex-direction: column; gap: 2px; font-size: .8rem; }
.variant-attrs { display: flex; flex-wrap: wrap; gap: .3rem; }
.variant-attr {
    font-size: .68rem; color: var(--app-muted);
    background: var(--app-thead-bg); border-radius: .25rem; padding: 1px 5px;
}
.variant-sku { font-size: .68rem; color: var(--app-muted); }
.variant-foot { display: flex; align-items: center; justify-content: space-between; gap: .4rem; margin-top: 2px; }
.variant-stock { font-size: .68rem; font-weight: 600; }
.variant-stock.is-in { color: #1e7c39; }
.variant-stock.is-out { color: #c0392b; }
</style>
