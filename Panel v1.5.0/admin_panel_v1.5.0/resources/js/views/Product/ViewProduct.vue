<template>
    <div>
        <div class="page-heading">

            <!-- Country / zone filters and the page actions share one row. -->
            <div class="d-flex align-items-center justify-content-between gap-2 flex-wrap mb-3">
                <div class="d-flex align-items-center gap-2 flex-wrap">
                    <template v-if="czShowCountry">
                        <AppSelect class="cz-sel" v-model="czCountryId" :options="czCountryOptions"
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
                    </template>
                </div>

                <div class="d-flex align-items-center gap-2 flex-wrap ms-auto">
                    <router-link v-if="record && $can('product_update')"
                        :to="'/products/edit/' + record.id" class="btn btn-primary btn-sm mb-0">
                        <i class="fa fa-pencil me-1"></i>{{ __('edit_product') }}
                    </router-link>
                    <router-link to="/products"
                        class="btn btn-outline-secondary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap">
                        <ArrowLeft :size="16" /> {{ __('back_to_products') }}
                    </router-link>
                </div>
            </div>

            <template v-if="record">
                <!-- HERO -->
                <div class="card vp-hero">
                    <div class="card-body d-flex flex-wrap">
                        <div class="vp-hero-img">
                            <img v-if="heroImage" :src="heroImage" alt="" />
                            <div v-else class="vp-noimg"><i class="fa fa-image"></i></div>
                        </div>
                        <div class="vp-hero-info flex-grow-1">
                            <div>
                                <p class="text-muted small mb-1">{{ categoryPathLabel }}</p>
                                <h4 class="fw-bold mb-1">{{ headerProductName }}</h4>
                                <p class="text-muted mb-2">{{ __('product_id') }}: #{{ record.id }}</p>
                            </div>
                            <div class="d-flex flex-wrap gap-2 mb-3">
                                <span class="badge" :class="record.status == 1 ? 'bg-success' : 'bg-danger'">
                                    {{ record.status == 1 ? __('active') : __('deactive') }}
                                </span>
                                <span class="badge bg-info">{{ salesChannelLabel }}</span>
                                <span v-if="Number(record.product_type) === 1" class="badge bg-success">{{ __('veg') }}</span>
                                <span v-else-if="Number(record.product_type) === 2" class="badge bg-danger">{{ __('non_veg') }}</span>
                            </div>
                            <div class="vp-facts">
                                <div class="vp-fact">
                                    <span class="vp-fact-label">{{ __('brand') }}</span>
                                    <span class="vp-fact-value">{{ record.brand ? record.brand.name : '—' }}</span>
                                </div>
                                <div class="vp-fact">
                                    <span class="vp-fact-label">{{ __('tax_category') }}</span>
                                    <span class="vp-fact-value">
                                        <template v-if="record.tax_category">{{ record.tax_category.name }}</template>
                                        <template v-else>—</template>
                                    </span>
                                </div>
                                <div class="vp-fact">
                                    <span class="vp-fact-label">{{ __('made_in') }}</span>
                                    <span class="vp-fact-value">{{ record.made_in || '—' }}</span>
                                </div>
                                <div class="vp-fact">
                                    <span class="vp-fact-label">{{ __('manufacturer') }}</span>
                                    <span class="vp-fact-value">{{ (translatedRecord && translatedRecord.manufacturer) ? translatedRecord.manufacturer : '—' }}</span>
                                </div>
                                <div class="vp-fact">
                                    <span class="vp-fact-label">{{ __('return') }}</span>
                                    <span class="vp-fact-value">
                                        {{ record.return_status == 1 ? __('allowed') : __('not_allowed') }}
                                        <template v-if="record.return_status == 1 && record.return_days"> ({{ record.return_days }}d)</template>
                                    </span>
                                </div>
                                <div class="vp-fact">
                                    <span class="vp-fact-label">{{ __('cancellation') }}</span>
                                    <span class="vp-fact-value">{{ record.cancelable_status == 1 ? __('allowed') : __('not_allowed') }}</span>
                                </div>
                                <div class="vp-fact">
                                    <span class="vp-fact-label">{{ __('cod') }}</span>
                                    <span class="vp-fact-value">{{ record.cod_allowed == 1 ? __('allowed') : __('not_allowed') }}</span>
                                </div>
                                <!-- Stock limit is per branch now — shown in each variant's branch table. -->
                                <div class="vp-fact">
                                    <span class="vp-fact-label">{{ __('total_allowed_quantity') }}</span>
                                    <span class="vp-fact-value">{{ record.total_allowed_quantity || '—' }}</span>
                                </div>
                                <!-- Live demand: distinct customers holding this product right now.
                                     No tooltip directive here — it injects a sibling node, which in
                                     this CSS grid eats a cell and pushes the next fact to a new row. -->
                                <div class="vp-fact">
                                    <span class="vp-fact-label">{{ __('in_wishlists') }}</span>
                                    <span class="vp-fact-value vp-fact-icon-value">
                                        <Heart :size="14" class="vp-fact-icon is-wishlist" />
                                        {{ demandLoading ? '…' : demand.wishlist_users }}
                                    </span>
                                </div>
                                <div class="vp-fact">
                                    <span class="vp-fact-label">{{ __('in_carts') }}</span>
                                    <span class="vp-fact-value vp-fact-icon-value">
                                        <ShoppingCart :size="14" class="vp-fact-icon is-cart" />
                                        {{ demandLoading ? '…' : demand.cart_users }}
                                    </span>
                                </div>
                            </div>
                            <div v-if="otherImages.length" class="mt-3">
                                <span class="vp-fact-label d-block mb-2">{{ __('other_images') }}</span>
                                <div class="d-flex flex-wrap gap-2">
                                    <template v-for="(img, i) in otherImages" :key="'oi-' + i">
                                        <video v-if="isVideoUrl(img.image)" :src="$storageUrl + img.image"
                                            class="vp-thumb vp-thumb-video" controls muted playsinline></video>
                                        <img v-else :src="$storageUrl + img.image" class="vp-thumb" alt="" />
                                    </template>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- DESCRIPTION -->
                <div class="card">
                    <div class="card-header">
                        <h4>{{ __('product_request_description') }}</h4>
                    </div>
                    <div class="card-body">
                        <!-- Read-only: render the description HTML, no editor / toolbar. -->
                        <div v-if="viewerDescription" class="vp-desc" v-html="viewerDescription"></div>
                        <p v-else class="text-muted mb-0">—</p>
                    </div>
                </div>

                <!-- VARIANTS -->
                <div class="card">
                    <div class="card-header">
                        <h4>{{ __('product_variants') }} ({{ (record.variants || []).length }})</h4>
                    </div>
                    <div class="card-body">
                        <div class="row">
                            <div class="col-lg-6 mb-3" v-for="(v, idx) in (record.variants || [])" :key="'vc-' + (v.id || idx)">
                                <div class="card vp-variant-card h-100">
                                    <div class="card-body d-flex">
                                        <div class="vp-variant-media">
                                            <div class="vp-vm-main">
                                                <img v-if="v.image" :src="v.image" alt="" />
                                                <div v-else class="vp-noimg"><i class="fa fa-image"></i></div>
                                            </div>
                                            <div v-for="(g, gi) in (v.gallery || [])" :key="'vg-' + idx + '-' + gi" class="vp-vm-thumb">
                                                <video v-if="isVideoUrl(g.url)" :src="g.url" controls muted
                                                    playsinline preload="metadata"></video>
                                                <img v-else :src="g.url" alt="" />
                                            </div>
                                        </div>
                                        <div class="vp-variant-info flex-grow-1">
                                            <div class="d-flex mb-2 align-items-baseline">
                                                <span class="text-muted me-2 flex-shrink-0">{{ __('variant') }} #{{ idx + 1 }}</span>
                                                <h6 class="mb-0 fw-bold vp-name">{{ variantName(v) }}</h6>
                                            </div>
                                            <table class="vp-kv">
                                                <tbody>
                                                    <tr>
                                                        <td>{{ __('variant_id') }}</td>
                                                        <td>{{ v.id || '—' }}</td>
                                                    </tr>
                                                    <tr>
                                                        <td>{{ __('sku') }}</td>
                                                        <td>{{ v.sku || '—' }}</td>
                                                    </tr>
                                                </tbody>
                                            </table>

                                            <div v-if="variantAttrChips(v).length" class="d-flex flex-wrap gap-2 mt-2">
                                                <span class="vp-attr-chip" v-for="(c, ci) in variantAttrChips(v)" :key="'vac-' + idx + '-' + ci">
                                                    <strong>{{ c.label }}:</strong> {{ c.value }}
                                                </span>
                                            </div>

                                            <!-- Price and stock are per branch. Scoped to the header
                                                 country/zone filter, like the product list. -->
                                            <div class="vp-stock-block mt-3">
                                                <div class="vp-block-title">{{ __('branch_wise_price_and_stock') }}</div>
                                                <div v-if="!visibleBranchStocks(v).length" class="text-muted small">
                                                    {{ __('no_branches_for_selected_filter') }}
                                                </div>
                                                <div class="table-responsive" v-else>
                                                    <table class="table table-sm vp-stock-table mb-0">
                                                        <thead>
                                                            <tr>
                                                                <th>{{ __('branch') }}</th>
                                                                <th class="text-end">{{ __('selling') }}</th>
                                                                <th class="text-end">{{ __('purchase') }}</th>
                                                                <th>{{ __('stock_limit_type') }}</th>
                                                                <th>{{ __('status') }}</th>
                                                                <th class="text-end">{{ __('available') }}</th>
                                                                <th class="text-end">{{ __('reserved') }}</th>
                                                                <th class="text-end">{{ __('min_alert') }}</th>
                                                            </tr>
                                                        </thead>
                                                        <tbody>
                                                            <tr v-for="(s, si) in visibleBranchStocks(v)" :key="'ss-' + idx + '-' + si">
                                                                <td>
                                                                    {{ branchName(s.branch_id) }}
                                                                </td>
                                                                <td class="text-end">
                                                                    {{ branchCurrency(s.branch_id) }}{{ Number(s.discounted_price) > 0 ? s.discounted_price : (s.price || 0) }}
                                                                    <span v-if="Number(s.discounted_price) > 0"
                                                                        class="text-muted text-decoration-line-through ms-1">{{ branchCurrency(s.branch_id) }}{{ s.price }}</span>
                                                                </td>
                                                                <td class="text-end">{{ branchCurrency(s.branch_id) }}{{ s.purchase_price || 0 }}</td>
                                                                <td>
                                                                    <span class="badge" :class="Number(s.is_unlimited_stock) === 1 ? 'bg-info' : 'bg-light text-dark'">
                                                                        {{ Number(s.is_unlimited_stock) === 1 ? __('unlimited') : __('limited') }}
                                                                    </span>
                                                                </td>
                                                                <td>
                                                                    <span v-if="Number(s.is_unlimited_stock) === 1" class="badge bg-success">{{ __('in_stock') }}</span>
                                                                    <span v-else class="badge" :class="s.stock_status == 1 ? 'bg-success' : 'bg-danger'">
                                                                        {{ s.stock_status == 1 ? __('in_stock') : __('out_of_stock') }}
                                                                    </span>
                                                                </td>
                                                                <td class="text-end">{{ Number(s.is_unlimited_stock) === 1 ? '∞' : s.available }}</td>
                                                                <td class="text-end">{{ Number(s.is_unlimited_stock) === 1 ? '—' : s.reserved }}</td>
                                                                <td class="text-end">{{ Number(s.is_unlimited_stock) === 1 ? '—' : s.min_alert }}</td>
                                                            </tr>
                                                        </tbody>
                                                    </table>
                                                </div>
                                            </div>

                                            <div v-for="(sec, si) in variantCustomSections(v)" :key="'vcs-' + idx + '-' + si"
                                                class="vp-custom-section mt-3">
                                                <div class="vp-block-title">{{ sec.name }}</div>
                                                <table class="vp-kv">
                                                    <tbody>
                                                        <tr v-for="(it, ii) in sec.items" :key="'vci-' + idx + '-' + si + '-' + ii">
                                                            <td>{{ it.label }}</td>
                                                            <td>{{ it.value }}</td>
                                                        </tr>
                                                    </tbody>
                                                </table>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </template>
        </div>
    </div>
</template>
<script>
import axios from "axios";
import Editor from '@tinymce/tinymce-vue';
// Without this the wrapper falls back to cdn.tiny.cloud with `no-api-key`,
// which renders Tiny's "Finish setting up" panel instead of the editor.
import { TINYMCE_SCRIPT_SRC } from '../../utils/tinymce.js';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';
import { Heart, ShoppingCart, ArrowLeft } from 'lucide-vue-next';
export default {
    mixins: [CountryZoneFilter],
    components: { 'editor': Editor, Heart, ShoppingCart, ArrowLeft },
    // Exposed so the template can bind it.
    setup() {
        return { TINYMCE_SCRIPT_SRC };
    },
    data: function () {
        return {
            id: null,
            record: null,
            // Distinct customers currently holding this product (wishlist / cart).
            demand: { wishlist_users: 0, cart_users: 0 },
            demandLoading: false,
            otherImages: [],
            languages: [],
            activeLanguages: [],
            currentLanguageId: null,
            defaultLanguageId: null,
            viewerDescription: '',
            categoryAttributes: [],
            categoryCustomSections: [],
            channelBranches: [],
        }
    },
    computed: {
        // The product's own (translated) name. Falls back to the first variant's name
        // for legacy rows saved before products had a name of their own.
        headerProductName() {
            const name = this.translatedRecord && this.translatedRecord.name;
            if (name && String(name).trim()) return name;
            const variants = (this.record && this.record.variants) || [];
            return variants.length ? (this.variantName(variants[0]) || '') : '';
        },
        categoryPathLabel() {
            const c = this.translatedRecord && this.translatedRecord.category;
            return c && c.name ? c.name : '—';
        },
        salesChannelLabel() {
            const c = (this.record && this.record.sales_channel) || 'both';
            if (c === 'quick') return __('quick_commerce_only');
            if (c === 'ecommerce') return __('ecommerce_only');
            return __('quick_and_ecommerce');
        },
        heroImage() {
            if (!this.record) return null;
            if (this.record.image_url) return this.record.image_url;
            return this.record.image ? this.$storageUrl + this.record.image : null;
        },
        translatedRecord() {
            if (!this.record || !this.currentLanguageId || !this.activeLanguages.length) {
                return this.record;
            }
            const defaultLang = this.activeLanguages.find(lang => lang.is_default === 1);
            const defaultLanguageId = defaultLang ? defaultLang.id : null;
            const translated = { ...this.record };

            const pickTranslation = (translations) => {
                if (!translations) return null;
                if (!Array.isArray(translations) && typeof translations === 'object') return translations;
                if (Array.isArray(translations)) {
                    let t = translations.find(tr => tr.language_id === this.currentLanguageId);
                    if (!t && defaultLanguageId) t = translations.find(tr => tr.language_id === defaultLanguageId);
                    return t || null;
                }
                return null;
            };

            const productTr = pickTranslation(this.record.translations);
            if (productTr) {
                if (productTr.name && productTr.name.trim() !== '') translated.name = productTr.name;
                if (productTr.description && productTr.description.trim() !== '') translated.description = productTr.description;
                if (productTr.manufacturer && productTr.manufacturer.trim() !== '') translated.manufacturer = productTr.manufacturer;
            }
            if (this.record.branch) {
                translated.branch = { ...this.record.branch };
                const branchTr = pickTranslation(this.record.branch.translations);
                if (branchTr && branchTr.name && branchTr.name.trim() !== '') translated.branch.name = branchTr.name;
            }
            if (this.record.tax) {
                translated.tax = { ...this.record.tax };
                const taxTr = pickTranslation(this.record.tax.translations);
                if (taxTr && taxTr.title && taxTr.title.trim() !== '') translated.tax.title = taxTr.title;
            }
            if (this.record.category) {
                translated.category = { ...this.record.category };
                const catTr = pickTranslation(this.record.category.translations);
                if (catTr && catTr.name && catTr.name.trim() !== '') translated.category.name = catTr.name;
            }
            return translated;
        }
    },
    created: function () {
        this.id = this.$route.params.id;
        this.fetchActiveLanguages().then(() => {
            if (this.id) this.getProduct();
        }).catch(() => {
            if (this.id) this.getProduct();
        });
        this.czLoad();
    },
    watch: {
        translatedRecord: {
            immediate: true,
            deep: true,
            handler(newRecord) {
                this.viewerDescription = newRecord ? (newRecord.description || '') : '';
                this.$nextTick(() => this.syncDescriptionViewerUi());
            }
        }
    },
    methods: {
        /** Gallery rows carry a stored path, so the extension is all there is to go on. */
        isVideoUrl(url) {
            return /\.(mp4|m4v|mov|webm)(\?|#|$)/i.test(String(url || ''));
        },
        czOnFilter() { this.fetchChannelBranches(); },
        syncDescriptionViewerUi() {
            const editorCmp = this.$refs && this.$refs.descriptionViewer;
            const viewer = Array.isArray(editorCmp) ? editorCmp[0] : editorCmp;
            if (!viewer || typeof viewer.getEditor !== 'function') return;
            const tinymceEditor = viewer.getEditor();
            if (!tinymceEditor || typeof tinymceEditor.setContent !== 'function') return;
            tinymceEditor.setContent(this.viewerDescription || '');
        },
        onDescriptionViewerInit(_evt, editor) {
            try {
                if (editor && typeof editor.setContent === 'function') {
                    editor.setContent(this.viewerDescription || '');
                }
            } catch (e) {
                console.error('TinyMCE view description init sync failed', e);
            }
        },
        fetchActiveLanguages() {
            return axios.get(this.$apiUrl + '/active_languages')
                .then(response => {
                    if (response.data.data) {
                        this.languages = response.data.data;
                        this.activeLanguages = response.data.data;
                        const defaultLang = this.languages.find(lang => lang.is_default === 1);
                        if (defaultLang) this.defaultLanguageId = defaultLang.id;
                        const appLocale = window.appLocale || 'en';
                        const currentLang = this.languages.find(lang => lang.code === appLocale);
                        this.currentLanguageId = currentLang ? currentLang.id : (defaultLang ? defaultLang.id : null);
                    }
                })
                .catch(() => { });
        },
        loadDemandStats() {
            this.demandLoading = true;
            axios.get(this.$apiUrl + '/products/demand_stats', { params: { product_id: this.id } })
                .then(res => { this.demand = res.data?.data || { wishlist_users: 0, cart_users: 0 }; })
                .catch(() => { this.demand = { wishlist_users: 0, cart_users: 0 }; })
                .finally(() => { this.demandLoading = false; });
        },
        getProduct() {
            axios.get(this.$apiUrl + '/products/edit/' + this.id)
                .then((response) => {
                    let data = response.data;
                    if (data.status === 1) {
                        this.record = data.data;
                        this.otherImages = this.record.images || [];
                        this.viewerDescription = this.translatedRecord ? (this.translatedRecord.description || '') : '';
                        this.$nextTick(() => this.syncDescriptionViewerUi());
                        this.loadCategorySchema();
                        this.fetchChannelBranches();
                        this.loadDemandStats();
                    } else {
                        this.showError(data.message);
                        setTimeout(() => this.$router.back(), 1000);
                    }
                }).catch(error => {
                    if (error.request && error.request.statusText) this.showError(error.request.statusText);
                    else if (error.message) this.showError(error.message);
                    else this.showError("Something went wrong!");
                });
        },
        loadCategorySchema() {
            const catId = this.record && this.record.category_id;
            if (!catId) return;
            axios.get(this.$apiUrl + '/categories/schema', { params: { id: catId } }).then(r => {
                const d = r.data.data || {};
                this.categoryAttributes = d.attributes || [];
                this.categoryCustomSections = d.custom_sections || [];
            }).catch(() => { });
        },
        fetchChannelBranches() {
            const ch = (this.record && this.record.sales_channel) || 'both';
            // Scoped to the header country/zone filter, like the product list.
            axios.get(this.$apiUrl + '/branches/for_channel', {
                params: {
                    sales_channel: ch,
                    country_id: this.czCountryParam,
                    zone_id: this.czZoneParam,
                },
            })
                .then(r => { this.channelBranches = r.data?.data?.branches || []; })
                .catch(() => { this.channelBranches = []; });
        },
        branchName(id) {
            const s = (this.channelBranches || []).find(x => Number(x.id) === Number(id));
            return s ? s.name : ('#' + id);
        },
        /** Branch's own currency — branches can sit in different countries. */
        branchCurrency(id) {
            const s = (this.channelBranches || []).find(x => Number(x.id) === Number(id));
            return (s && s.currency) || this.czCurrency || this.$currency;
        },
        /**
         * Branch rows for this variant, limited to the branches the header filter allows.
         * With no filter set, `channelBranches` is the full list so nothing is hidden.
         * Only listed branches are shown — unlisted rows are inventory bookkeeping.
         */
        visibleBranchStocks(v) {
            const rows = v.branch_stocks || [];
            const ids = (this.channelBranches || []).map(x => Number(x.id));
            if (!ids.length) return [];
            return rows.filter(r => ids.includes(Number(r.branch_id)) && Number(r.is_listed) === 1);
        },
        variantName(v) {
            const t = Array.isArray(v.translations)
                ? v.translations.find(x => Number(x.language_id) === Number(this.currentLanguageId))
                : null;
            if (t && t.name && t.name.trim()) return t.name;
            if (v.name && String(v.name).trim()) return v.name;
            return this.variantAttrSummary(v) || ('#' + v.id);
        },
        attrLabel(a) {
            const t = Array.isArray(a.translations)
                ? a.translations.find(x => Number(x.language_id) === Number(this.defaultLanguageId)) : null;
            return (t && t.name && t.name.trim()) ? t.name : (a.name || '');
        },
        valueLabel(v) {
            const t = Array.isArray(v.translations)
                ? v.translations.find(x => Number(x.language_id) === Number(this.defaultLanguageId)) : null;
            return (t && t.value && t.value.trim()) ? t.value : (v.value || '');
        },
        sectionLabelForLang(s) {
            const t = Array.isArray(s.translations)
                ? s.translations.find(x => Number(x.language_id) === Number(this.defaultLanguageId)) : null;
            if (t && t.name && String(t.name).trim()) return t.name;
            return s && (s.name || s.title || s.section_name) || __('custom_section');
        },
        fieldLabelForLang(f) {
            const t = Array.isArray(f.translations)
                ? f.translations.find(x => Number(x.language_id) === Number(this.defaultLanguageId)) : null;
            return (t && t.field_label) ? t.field_label : (f.field_label || '');
        },
        variantAttrSummary(v) {
            return (v.attribute_values || []).map(av => {
                const attr = (this.categoryAttributes || []).find(a => a.id === av.attribute_id);
                const val = attr ? (attr.values || []).find(x => x.id === av.value_id) : null;
                return val ? this.valueLabel(val) : '';
            }).filter(Boolean).join(' / ');
        },
        variantAttrChips(v) {
            return (v.attribute_values || []).map(av => {
                const attr = (this.categoryAttributes || []).find(a => a.id === av.attribute_id);
                const val = attr ? (attr.values || []).find(x => x.id === av.value_id) : null;
                if (!attr || !val) return null;
                return { label: this.attrLabel(attr), value: this.valueLabel(val) };
            }).filter(Boolean);
        },
        variantCustomSections(v) {
            const out = [];
            const cvMap = {};
            (v.custom_values || []).forEach(cv => { cvMap[cv.field_id] = cv; });
            for (const section of (this.categoryCustomSections || [])) {
                const items = [];
                for (const f of (section.fields || [])) {
                    const cv = cvMap[f.id];
                    if (!cv) continue;
                    let val = '';
                    if (f.field_type === 'number') val = cv.value_number;
                    else if (f.field_type === 'date') val = cv.value_date;
                    else val = cv.value_text;
                    if (val === '' || val === null || val === undefined) continue;
                    if (f.field_type === 'number') {
                        val = Number(val);
                    } else if (f.field_type === 'date') {
                        // Show only the date, formatted to the country date format.
                        val = (this.$filters && this.$filters.formatDate) ? this.$filters.formatDate(val) : String(val).slice(0, 10);
                    } else if (f.field_type === 'checkbox' || f.field_type === 'boolean') {
                        // 1/0/true/false -> Yes/No.
                        const s = String(val).toLowerCase();
                        val = (s === '1' || s === 'true' || s === 'yes') ? __('yes') : __('no');
                    }
                    items.push({ label: this.fieldLabelForLang(f), value: val });
                }
                if (items.length) out.push({ name: this.sectionLabelForLang(section), items });
            }
            return out;
        },
    }
};
</script>
<style scoped>
.vp-hero-img {
    width: 180px;
    height: 180px;
    margin-right: 22px;
    flex-shrink: 0;
    background: #f7f8fa;
    border: 1px solid #e4e7ea;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
}
.vp-hero-img img {
    max-width: 100%;
    max-height: 100%;
    object-fit: contain;
}
.vp-hero-info {
    min-width: 0;
}
.vp-noimg {
    color: #c2c7cf;
    font-size: 2.5rem;
}
.vp-facts {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(190px, 1fr));
    gap: 10px 18px;
}
.vp-fact {
    display: flex;
    flex-direction: column;
    min-width: 0;
}
.vp-fact-icon-value {
    display: inline-flex;
    align-items: center;
    gap: 6px;
}
.vp-fact-icon { flex-shrink: 0; }
.vp-fact-icon.is-wishlist { color: #ec4899; }
.vp-fact-icon.is-cart { color: #3b82f6; }
.vp-fact-label {
    font-size: .68rem;
    letter-spacing: .04em;
    text-transform: uppercase;
    color: #9aa1ab;
}
.vp-fact-value {
    font-weight: 600;
    color: var(--app-ink);
}
.vp-thumb {
    width: 60px;
    height: 60px;
    object-fit: cover;
    border: 1px solid #e4e7ea;
    border-radius: 6px;
}
/* Wider than a still: at 60px the player's own controls have nowhere to sit. */
.vp-thumb-video {
    width: 110px;
    object-fit: contain;
    background: #000;
}
.vp-variant-card {
    border: 1px solid #e4e7ea;
}
.vp-variant-media {
    width: 110px;
    margin-right: 18px;
    flex-shrink: 0;
}
.vp-vm-main {
    width: 110px;
    height: 110px;
    background: #f7f8fa;
    border: 1px solid #e4e7ea;
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    margin-bottom: 8px;
}
.vp-vm-main img {
    max-width: 100%;
    max-height: 100%;
    object-fit: contain;
}
.vp-vm-thumb {
    width: 110px;
    height: 70px;
    background: #f7f8fa;
    border: 1px solid #e4e7ea;
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    margin-bottom: 8px;
}
.vp-vm-thumb img,
.vp-vm-thumb video {
    max-width: 100%;
    max-height: 100%;
    object-fit: contain;
}
/* A player needs its controls; the phone-width rule squares this box down to 60px. */
.vp-vm-thumb video {
    background: #000;
}
.vp-variant-info {
    min-width: 0;
    max-width: 100%;
}
.vp-stock-block .table-responsive {
    max-width: 100%;
}
@media (max-width: 575.98px) {
    /* Phones: media above the details, both full width; the stock table scrolls on its own. */
    .vp-variant-card .card-body { flex-wrap: wrap; }
    .vp-variant-media { width: 100%; margin-right: 0; margin-bottom: 10px; display: flex; gap: 8px; flex-wrap: wrap; }
    .vp-vm-main { width: 90px; height: 90px; margin-bottom: 0; }
    .vp-vm-thumb { width: 60px; height: 60px; margin-bottom: 0; }
    .vp-variant-info { width: 100%; }
    .vp-hero-img { width: 120px; height: 120px; margin-right: 14px; }
}
.vp-name {
    word-break: break-word;
    overflow-wrap: anywhere;
    line-height: 1.3;
}
.vp-kv {
    width: 100%;
    font-size: .85rem;
    table-layout: fixed;
}
.vp-kv td:last-child {
    overflow-wrap: anywhere;
}
.vp-kv td {
    padding: 2px 0;
}
.vp-kv td:first-child {
    color: #9aa1ab;
    width: 110px;
}
.vp-kv td:last-child {
    color: var(--app-ink);
    font-weight: 500;
}
.vp-attr-chip {
    background: var(--app-thead-bg, #eef0f3);
    color: var(--bs-body-color, #3a3f47);
    border: 1px solid var(--app-control-border, transparent);
    border-radius: 4px;
    padding: 3px 8px;
    font-size: .78rem;
}
/* Label + value both follow the chip's (theme-aware) text colour so the label
   isn't bleached to near-white in dark mode. */
.vp-attr-chip strong {
    color: inherit;
    font-weight: 600;
}
.vp-block-title {
    font-size: .72rem;
    letter-spacing: .03em;
    text-transform: uppercase;
    color: #9aa1ab;
    font-weight: 600;
    margin-bottom: 4px;
    border-top: 1px dashed #e4e7ea;
    padding-top: 8px;
}
.vp-stock-table th {
    font-size: .72rem;
    text-transform: uppercase;
    color: #9aa1ab;
    font-weight: 600;
}
.vp-stock-table td {
    font-size: .82rem;
    vertical-align: middle;
}
</style>
