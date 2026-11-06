<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('brands') }}</h3>

            <button v-if="$can('brand_create')" class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                @click="edit_record=true">
                <Plus :size="16" />
                <span>{{ __('add_brand') }}</span>
            </button>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-toolbar-start">
                    <div class="btn-group" role="group">
                        <button type="button" class="btn btn-sm"
                            :class="viewMode === 'cards' ? 'btn-primary' : 'btn-outline-primary'"
                            @click="viewMode = 'cards'" v-b-tooltip.hover :title="__('card_view') || 'Cards'">
                            <LayoutGrid :size="15" />
                        </button>
                        <button type="button" class="btn btn-sm"
                            :class="viewMode === 'tree' ? 'btn-primary' : 'btn-outline-primary'"
                            @click="viewMode = 'tree'" v-b-tooltip.hover :title="__('tree_view') || 'Tree'">
                            <FolderTree :size="15" />
                        </button>
                    </div>
                </div>
                <AppSelect class="form-select list-select" v-model="statusFilter" :options="statusFilterOptions" :searchable="false" @update:model-value="onStatusChange" />
                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input
                        id="filter-input"
                        v-model="filter"
                        type="search"
                        class="form-control"
                        :placeholder="__('search')"
                        @input="onSearch">
                </div>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getRecords()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <!-- ===== CARD VIEW ===== -->
            <div class="list-panel-body" v-if="viewMode === 'cards'">
                <div class="card-grid">
                    <EntityCardSkeleton v-if="isLoading" :count="perPage" />
                    <div v-else-if="translatedBrands.length === 0" class="card-grid-empty">
                        <Inbox :size="34" />
                        <span>{{ __('no_records_found') }}</span>
                    </div>

                    <div v-else v-for="(b, index) in translatedBrands" :key="'b-' + b.id" class="entity-card">
                        <div class="entity-card-media is-contain">
                            <img :src="b.image ? $storageUrl + b.image : placeholderImg" alt="" />
                            <span class="status-pill" :class="b.status == 1 ? 'is-active' : 'is-inactive'">
                                {{ b.status == 1 ? __('active') : __('deactive') }}
                            </span>
                        </div>
                        <div class="entity-card-body">
                            <h4 class="entity-card-title text-truncate" :title="b.name">{{ b.name }}</h4>
                            <div class="entity-card-meta">
                                <span class="cat-count-badge" :class="{ 'is-muted': !productCount(b) }">
                                    <Package :size="12" /> {{ productCount(b) }} {{ __('products') }}
                                </span>
                            </div>
                            <div class="entity-card-foot">
                                <div class="list-actions">
                                    <span v-if="!$can('brand_update') && !$can('brand_delete')" class="text-muted small">—</span>
                                    <button v-if="$can('brand_update')" class="list-action-btn is-edit" @click="edit_record = b"
                                        v-b-tooltip.hover :title="__('edit')">
                                        <Pencil :size="15" />
                                    </button>
                                    <button v-if="$can('brand_delete')" class="list-action-btn is-delete" @click="deleteRecord(index, b.id)"
                                        v-b-tooltip.hover :title="__('delete')">
                                        <Trash2 :size="15" />
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- ===== TREE VIEW: brand → its products (loaded on expand) ===== -->
            <div class="list-panel-body" v-else>
                <div v-if="isLoading" class="card-grid-empty">
                    <b-spinner small></b-spinner>
                </div>
                <div v-else-if="!translatedBrands.length" class="card-grid-empty">
                    <Inbox :size="34" />
                    <span>{{ __('no_records_found') }}</span>
                </div>
                <div v-else class="cat-tree">
                    <template v-for="b in translatedBrands" :key="'bt-' + b.id">
                        <div class="cat-tree-row">
                            <button class="cat-tree-toggle" :class="{ 'is-leaf': !productCount(b) }"
                                @click="toggleBrand(b.id)">
                                <component :is="isBrandOpen(b.id) ? 'ChevronDown' : 'ChevronRight'" :size="15" />
                            </button>
                            <img v-if="b.image" :src="$storageUrl + b.image" class="cat-tree-thumb" :alt="b.name" />
                            <span v-else class="cat-tree-thumb cat-tree-thumb-ph"><ImageIcon :size="16" /></span>
                            <span class="cat-tree-name">{{ b.name }}</span>
                            <span class="cat-tree-counts">
                                <span v-if="productCount(b)" class="cat-count-badge">
                                    {{ productCount(b) }} {{ __('products') }}
                                </span>
                            </span>
                            <span class="status-pill" :class="b.status == 1 ? 'is-active' : 'is-inactive'">
                                {{ b.status == 1 ? __('active') : __('deactive') }}
                            </span>
                            <div class="list-actions cat-tree-actions">
                                <button v-if="$can('brand_update')" class="list-action-btn is-edit"
                                    @click="edit_record = b" v-b-tooltip.hover :title="__('edit')">
                                    <Pencil :size="15" />
                                </button>
                                <button v-if="$can('brand_delete')" class="list-action-btn is-delete"
                                    @click="deleteRecord(translatedBrands.indexOf(b), b.id)"
                                    v-b-tooltip.hover :title="__('delete')">
                                    <Trash2 :size="15" />
                                </button>
                            </div>
                        </div>

                        <template v-if="isBrandOpen(b.id)">
                            <div v-if="brandProductsLoading[b.id]" class="cat-tree-row brand-child">
                                <span class="cat-tree-indent"></span>
                                <b-spinner small></b-spinner>
                            </div>
                            <div v-else-if="!(brandProducts[b.id] || []).length" class="cat-tree-row brand-child">
                                <span class="cat-tree-indent"></span>
                                <span class="text-muted small">{{ __('no_records_found') }}</span>
                            </div>
                            <div v-else v-for="p in brandProducts[b.id]" :key="'bp-' + p.id"
                                class="cat-tree-row brand-child" :class="{ 'is-link': canOpenProduct }"
                                @click="openProduct(p.id)">
                                <span class="cat-tree-indent"></span>
                                <img v-if="p.image_url" :src="p.image_url" class="cat-tree-thumb" :alt="p.name" />
                                <span v-else class="cat-tree-thumb cat-tree-thumb-ph"><ImageIcon :size="16" /></span>
                                <span class="cat-tree-name">{{ productName(p) }}</span>
                                <span class="cat-tree-counts">
                                    <span v-if="p.is_draft" class="cat-count-badge">{{ __('draft') }}</span>
                                </span>
                                <span class="status-pill" :class="p.status == 1 ? 'is-active' : 'is-inactive'">
                                    {{ p.status == 1 ? __('active') : __('deactive') }}
                                </span>
                            </div>
                        </template>
                    </template>
                </div>

            </div>

            <!-- Both views are server-paginated, so the footer is shared. -->
            <div class="list-footer">
                <div class="list-perpage">
                    <span>{{ __('per_page') }}</span>
                    <b-form-select
                        id="per-page-select"
                        v-model="perPage"
                        :options="pageOptions"
                        size="sm"
                        class="form-select"
                    ></b-form-select>
                    <span class="list-range">{{ __('total_records') }} : {{ totalRows }}</span>
                </div>

                <b-pagination
                    v-model="currentPage"
                    :total-rows="totalRows"
                    :per-page="perPage"
                    size="sm"
                    class="mb-0 list-pagination"
                ></b-pagination>
            </div>
        </div>

        <!-- Add / Edit -->
        <app-edit-record
            v-if="edit_record"
            :record="edit_record"
            @modalClose="edit_record = null"
            @saved="onBrandSaved"
        ></app-edit-record>
    </div>
</template>

<script>
import EditRecord from './Edit.vue';
import axios from 'axios';
import { Search, RefreshCw, Plus, Pencil, Trash2, Inbox, LayoutGrid, FolderTree,
    ChevronRight, ChevronDown, Package, Image as ImageIcon } from 'lucide-vue-next';

export default {
    components: {
        'app-edit-record': EditRecord,
        Search,
        RefreshCw,
        Plus,
        Pencil,
        Trash2,
        Inbox,
        LayoutGrid,
        FolderTree,
        ChevronRight,
        ChevronDown,
        Package,
        ImageIcon,
    },
    data() {
        return {
            fields: [
                { key: 'id', label: __('id'), class: 'text-center', sortable: true, sortDirection: 'desc' },
                { key: 'name', label: __('name'), class: 'text-center', sortable: false },
                { key: 'image', label: __('image'), class: 'text-center', sortable: false },
                { key: 'status', label: __('status'), class: 'text-center', formatter: (value) => {
                    return value == 1 ? __('active') : __('deactive');
                }},
                { key: 'actions', label: __('actions'), sortable: false }
            ],
            totalRows: 0,
            currentPage: 1,
            perPage: 30,
            pageOptions: this.$pageOptions,
            sortBy: '',
            sortDesc: false,
            sortDirection: 'asc',
            filter: null,
            statusFilter: '',
            filterOn: ['id', 'name', 'status'],
            isLoading: true,
            brands: [],
            // Fallback image when a brand has no logo (favicon → logo → bundled default).
            placeholderImg: window.appFavicon
                || (window.appLogo ? window.baseUrl + '/storage/' + window.appLogo : '')
                || (window.baseUrl + '/images/logo.png'),
            edit_record: null,
            // 'cards' (paginated grid) or 'tree' (brand → its products, lazy loaded).
            viewMode: 'cards',
            openBrands: {},
            brandProducts: {},
            brandProductsLoading: {},
             currentLanguageId: null,
            activeLanguages: []
            
        }
    },

    computed: {
        // /products/view/:id is guarded by product_list.
        canOpenProduct() { return this.$can('product_list'); },
        // Fixed option set — no search box needed.
        statusFilterOptions() {
            return [
                { id: '', name: (__('all_statuses') || 'All statuses') },
                { id: '1', name: (__('active')) },
                { id: '0', name: (__('deactive')) },
            ];
        },
    translatedBrands() {
        if (!this.currentLanguageId || this.brands.length === 0) {
            return this.brands;
        }

        return this.brands.map(brand => {
            const translatedBrand = { ...brand };

            if (brand.translations && Array.isArray(brand.translations)) {
               const translation = brand.translations.find(
    t => Number(t.language_id) === Number(this.currentLanguageId)
);
if (translation && translation.name && translation.name.trim() !== '') {
                    translatedBrand.name = translation.name;
                }
            }

            return translatedBrand;
        });
    }
}
,
    created()  {
    this.fetchActiveLanguages().then(() => {
        this.getRecords();
    });
},
    watch: {
         currentPage() {
            this.openBrands = {};
            this.getRecords();
        },
        perPage() {
            this.getRecords();
        },
        viewMode() {
            // Card view is paginated, tree view accumulates — always restart clean.
            this.currentPage = 1;
            this.getRecords();
        }
    },
    methods: {
        productCount(b) {
            return Number((b || {}).products_count || 0);
        },
        isBrandOpen(id) {
            return !!this.openBrands[id];
        },
        // Products load on first expand only — the list page never ships the catalogue.
        toggleBrand(id) {
            if (this.openBrands[id]) {
                this.openBrands[id] = false;
                return;
            }
            this.openBrands[id] = true;
            if (this.brandProducts[id]) return;

            this.brandProductsLoading[id] = true;
            axios.get(this.$apiUrl + '/products/brands/products', { params: { brand_id: id } })
                .then(res => { this.brandProducts[id] = res.data?.data || []; })
                .catch(() => { this.brandProducts[id] = []; })
                .finally(() => { this.brandProductsLoading[id] = false; });
        },
        // Product names are translatable; fall back to the base column.
        productName(p) {
            if (this.currentLanguageId && Array.isArray(p.translations)) {
                const t = p.translations.find(x => Number(x.language_id) === Number(this.currentLanguageId));
                if (t && t.name && t.name.trim() !== '') return t.name;
            }
            return p.name || '';
        },
        openProduct(id) {
            if (!id || !this.canOpenProduct) return;
            this.$router.push('/products/view/' + id);
        },

        fetchActiveLanguages() {
            console.log("data fetch");
            
    return axios.get(this.$apiUrl + '/active_languages')
        .then(response => {
            this.activeLanguages = response.data.data || [];

            const appLocale = window.appLocale || 'en';

            const currentLanguage = this.activeLanguages.find(
                lang => lang.code === appLocale
            );

            if (currentLanguage) {
                this.currentLanguageId = currentLanguage.id;
            } else {
                const defaultLang = this.activeLanguages.find(l => l.is_default === 1);
                if (defaultLang) {
                    this.currentLanguageId = defaultLang.id;
                }
            }
        });
    },

        onStatusChange() {
            this.currentPage = 1;
            this.getRecords();
        },
        // Typing refetches, but from page 1 — searching while on page 3 returned nothing.
        onSearch() {
            clearTimeout(this._searchTimer);
            this._searchTimer = setTimeout(() => {
                this.currentPage = 1;
                this.getRecords();
            }, 350);
        },
        getRecords() {
            this.isLoading = true;
            axios.get(this.$apiUrl + '/products/brands', {
                params: {
                    page: this.currentPage,
                    per_page: this.perPage,
                    filter: this.filter,
                    ...(this.statusFilter !== '' ? { status: this.statusFilter } : {})
                }
            }).then((response) => {
                const data = response.data;
                this.brands = data.data || [];
                this.totalRows = data.total;
            }).finally(() => {
                this.isLoading = false;
            });
        },
        onBrandSaved(message) {
            this.showMessage('success', message);
            this.getRecords();
            this.edit_record = null;
        },
        deleteRecord(index, id) {
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
                if (result.value) {
                    this.isLoading = true;
                    axios.post(this.$apiUrl + '/products/brands/delete', { id })
                        .then((response) => {
                            this.isLoading = false;
                            if (response.data.status === 0 || response.data.status === false) {
                                this.showError(response.data.message || __('something_went_wrong'));
                                return;
                            }
                            this.brands.splice(index, 1);
                            this.showMessage('success', response.data.message);
                        }).catch((err) => {
                            this.isLoading = false;
                            this.showError(err?.response?.data?.message || __('something_went_wrong'));
                        });
                }
            });
        },
    }
};
</script>