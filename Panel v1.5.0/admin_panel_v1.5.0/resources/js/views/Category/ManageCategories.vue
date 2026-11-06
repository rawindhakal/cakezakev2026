<template>
    <div class="list-page">
        <!-- Page title and the primary action share one flex row — no card chrome. -->
        <div class="page-head">
            <h3 class="page-head-title">{{ __('categories') }}</h3>

            <!-- Bootstrap utilities carry the layout as well, so the button still
                 reads correctly if the custom sheet hasn't loaded. -->
            <router-link
                to="/manage_categories/create"
                class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                v-if="$can('category_create')">
                <Plus :size="16" />
                <span>{{ __('add_category') }}</span>
            </router-link>
        </div>

        <!-- Everything sits inside one card panel. -->
        <div class="list-surface">
            <!-- Toolbar: view toggle on the left, search + refresh on the right. -->
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
                            @click="switchToTree" v-b-tooltip.hover :title="__('tree_view') || 'Tree'">
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
                        :placeholder="__('search')">
                    <!-- The `filter` watcher already refetches server-side on change. -->
                </div>
                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="refreshCurrent">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <!-- ===== CARD VIEW ===== -->
            <template v-if="viewMode === 'cards'">
                <div class="list-panel-body">
                    <div class="card-grid">
                        <EntityCardSkeleton v-if="isLoading" :count="perPage" />
                        <div v-else-if="!translatedCategories.length" class="card-grid-empty">
                            <LayoutGrid :size="34" />
                            <span>{{ __('no_records_to_show') }}</span>
                        </div>

                        <div v-else v-for="cat in translatedCategories" :key="cat.id" class="entity-card">
                            <div class="entity-card-media is-contain">
                                <img v-if="cat.image_url" :src="cat.image_url" :alt="cat.name" />
                                <div v-else class="entity-card-ph"><ImageIcon :size="30" /></div>
                                <span class="status-pill" :class="cat.status == 1 ? 'is-active' : 'is-inactive'">
                                    {{ cat.status == 1 ? __('activate') : __('deactivate') }}
                                </span>
                            </div>

                            <div class="entity-card-body">
                                <h4 class="entity-card-title">{{ cat.name }}</h4>
                                <div class="entity-card-meta">
                                    <span class="entity-meta-row">
                                        <FolderTree :size="14" />
                                        {{ Number(cat.parent_id) > 0 ? __('subcategory') : __('parent_category') }}
                                    </span>

                                    <span class="cat-count-row" v-if="hasAnyCount(cat)">
                                        <span v-if="count(cat, 'childs')" class="cat-count-badge"
                                            v-b-tooltip.hover :title="namesTip(cat, 'childs')">
                                            <FolderTree :size="12" /> {{ count(cat, 'childs') }} {{ __('subcategories') }}
                                        </span>
                                        <span v-if="count(cat, 'attributes')" class="cat-count-badge"
                                            v-b-tooltip.hover :title="namesTip(cat, 'attributes')">
                                            <SlidersHorizontal :size="12" /> {{ count(cat, 'attributes') }} {{ __('attributes') }}
                                        </span>
                                        <span v-if="count(cat, 'sections')" class="cat-count-badge"
                                            v-b-tooltip.hover :title="namesTip(cat, 'sections')">
                                            <ListChecks :size="12" /> {{ count(cat, 'sections') }} {{ __('custom_sections') }}
                                        </span>
                                        <span v-if="count(cat, 'products')" class="cat-count-badge">
                                            <Package :size="12" /> {{ count(cat, 'products') }} {{ __('products') }}
                                        </span>
                                    </span>
                                </div>

                                <div class="entity-card-foot">
                                    <div class="list-actions">
                                        <router-link
                                            :to="'/manage_categories/edit/' + cat.id"
                                            class="list-action-btn is-edit"
                                            v-if="$can('category_update')"
                                            v-b-tooltip.hover :title="__('edit')">
                                            <Pencil :size="15" />
                                        </router-link>
                                        <button
                                            class="list-action-btn is-delete"
                                            @click="deleteCategory(cat.id)"
                                            v-if="$can('category_delete')"
                                            v-b-tooltip.hover :title="__('delete')">
                                            <Trash2 :size="15" />
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Pagination (card view is server-paginated) -->
                <div class="list-footer" v-if="totalRows > 0">
                    <div class="list-perpage">
                        <span>{{ __('per_page') }}</span>
                        <b-form-select
                            id="per-page-select"
                            v-model="perPage"
                            :options="pageOptions"
                            size="sm"
                            class="form-select"
                        ></b-form-select>
                        <span class="list-range">{{ rangeLabel }}</span>
                    </div>

                    <b-pagination
                        v-model="currentPage"
                        :total-rows="totalRows"
                        :per-page="perPage"
                        size="sm"
                        class="mb-0"
                        @change="getCategories"
                    ></b-pagination>
                </div>
            </template>

            <!-- ===== TREE VIEW ===== -->
            <template v-else>
                <div class="list-panel-body">
                    <div v-if="treeLoading" class="card-grid-empty">
                        <b-spinner></b-spinner>
                    </div>
                    <div v-else-if="!visibleTreeRows.length" class="card-grid-empty">
                        <FolderTree :size="34" />
                        <span>{{ __('no_records_to_show') }}</span>
                    </div>
                    <div v-else class="cat-tree">
                        <div v-for="row in visibleTreeRows" :key="'t-' + row.id" class="cat-tree-row">
                            <span class="cat-tree-indent" :style="{ width: (row.depth * 22) + 'px' }"></span>
                            <button class="cat-tree-toggle" :class="{ 'is-leaf': !row.hasChildren }"
                                @click="toggleTreeNode(row.id)">
                                <component :is="isTreeExpanded(row.id) ? 'ChevronDown' : 'ChevronRight'" :size="15" />
                            </button>
                            <img v-if="row.image_url" :src="row.image_url" class="cat-tree-thumb" :alt="row.name" />
                            <span v-else class="cat-tree-thumb cat-tree-thumb-ph"><ImageIcon :size="16" /></span>
                            <span class="cat-tree-name">{{ row.name }}</span>
                            <span class="cat-tree-counts">
                                <span v-if="row.childCount" class="cat-count-badge"
                                    v-b-tooltip.hover :title="row.childNames">
                                    {{ row.childCount }} {{ __('subcategories') }}
                                </span>
                                <span v-if="row.sectionCount" class="cat-count-badge"
                                    v-b-tooltip.hover :title="row.sectionNames">
                                    {{ row.sectionCount }} {{ __('custom_sections') }}
                                </span>
                                <span v-if="row.attrCount" class="cat-count-badge"
                                    v-b-tooltip.hover :title="row.attrNames">
                                    {{ row.attrCount }} {{ __('attributes') }}
                                </span>
                                <span v-if="row.productCount" class="cat-count-badge">
                                    {{ row.productCount }} {{ __('products') }}
                                </span>
                            </span>
                            <span class="status-pill" :class="row.status == 1 ? 'is-active' : 'is-inactive'">
                                {{ row.status == 1 ? __('activate') : __('deactivate') }}
                            </span>
                            <div class="list-actions cat-tree-actions">
                                <router-link :to="'/manage_categories/edit/' + row.id"
                                    class="list-action-btn is-edit" v-if="$can('category_update')"
                                    v-b-tooltip.hover :title="__('edit')">
                                    <Pencil :size="15" />
                                </router-link>
                                <button class="list-action-btn is-delete" @click="deleteCategory(row.id)"
                                    v-if="$can('category_delete')" v-b-tooltip.hover :title="__('delete')">
                                    <Trash2 :size="15" />
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </template>
        </div>
    </div>

</template>
<script>
import axios from 'axios';
import {
    Search, RefreshCw, Plus, Pencil, Trash2,
    LayoutGrid, FolderTree, Image as ImageIcon, ChevronRight, ChevronDown,
    SlidersHorizontal, ListChecks, Package,
} from 'lucide-vue-next';
import ListState from '../../mixins/ListState.js';

export default {
    mixins: [ListState],
    // Come back from a category and land where you left, not on page 1.
    listState: ['currentPage', 'perPage', 'filter', 'statusFilter', 'sortBy', 'sortDesc'],
    components: {
        Search, RefreshCw, Plus, Pencil, Trash2,
        LayoutGrid, FolderTree, ImageIcon, ChevronRight, ChevronDown,
        SlidersHorizontal, ListChecks, Package,
    },
    data: function() {
        return {
            // 'cards' (server-paginated grid) or 'tree' (full hierarchy).
            viewMode: 'cards',
            allCategories: [],
            treeLoading: false,
            treeExpanded: {},
            statusFilter: '',

            fields: [
                // Only id and parent_id are sortable; the rest opt out explicitly
                // (MazerDatatable treats a missing `sortable` as true).
                { key: 'id', label: __('id'), class: 'text-center', sortable: true, sortDirection: 'asc' },
                { key: 'parent_id', label: __('parent_id'), class: 'text-center', sortable: true, sortDirection: 'desc' },
                { key: 'name', label: __('name'), class: 'text-center', sortable: false },
                { key: 'image', label: __('image'), class: 'text-center', sortable: false },
                { key: 'status', label: __('status'), class: 'text-center', sortable: false },
                { key: 'actions', label: __('actions'), class: 'text-center', sortable: false }
            ],
            totalRows: 1,
            currentPage: 1,
            perPage: 30,
            pageOptions: this.$pageOptions,
            sortBy: 'id',
            sortDesc: true,
            sortDirection: 'asc',
            filter: null,
            filterOn: [],
            page: 1,

            categories: [],
            isLoading: true,
            sectionStyle : 'style_1',
            max_visible_categories : 12,
            max_col_in_single_row : 3,
            currentLanguageId: null,
            activeLanguages: []
        }
    },
    computed: {
        // Fixed option set — no search box needed.
        statusFilterOptions() {
            return [
                { id: '', name: (__('all_statuses') || 'All statuses') },
                { id: '1', name: (__('activate')) },
                { id: '0', name: (__('deactivate')) },
            ];
        },
        // "1 - 10 of 42" — the page is server-paginated, so this is derived from
        // the current page rather than from the rows actually rendered.
        rangeLabel() {
            if (!this.totalRows) return '';
            const from = (this.currentPage - 1) * this.perPage + 1;
            const to = Math.min(this.currentPage * this.perPage, this.totalRows);
            return `${from} - ${to} ${__('of') || 'of'} ${this.totalRows}`;
        },
        // --- Tree view (built from the full flat list via parent_id) ---
        translatedAll() {
            return (Array.isArray(this.allCategories) ? this.allCategories : [])
                .map(c => ({ ...c, name: this.translateName(c) }));
        },
        treeChildren() {
            const map = {};
            this.translatedAll.forEach(c => {
                const p = Number(c.parent_id) || 0;
                (map[p] = map[p] || []).push(c);
            });
            return map;
        },
        treeRoots() {
            const ids = new Set(this.translatedAll.map(c => c.id));
            return this.translatedAll.filter(c => {
                const p = Number(c.parent_id) || 0;
                return p === 0 || !ids.has(p);
            });
        },
        visibleTreeRows() {
            const kids = this.treeChildren;
            const q = (this.filter || '').toLowerCase().trim();
            const rows = [];
            const row = (c, depth) => {
                const children = kids[c.id] || [];
                return {
                    id: c.id, name: c.name, image_url: c.image_url, status: c.status,
                    depth, hasChildren: children.length > 0, childCount: children.length,
                    sectionCount: Number(c.custom_sections_count || 0),
                    attrCount: Number(c.category_attributes_count || 0),
                    productCount: Number(c.products_count || 0),
                    childNames: this.namesTip(c, 'childs'),
                    sectionNames: this.namesTip(c, 'sections'),
                    attrNames: this.namesTip(c, 'attributes'),
                };
            };
            if (q) {
                // Search collapses to a flat list of matches (depth 0).
                this.translatedAll
                    .filter(c => (c.name || '').toLowerCase().includes(q))
                    .forEach(c => rows.push(row(c, 0)));
                return rows;
            }
            const walk = (node, depth) => {
                rows.push(row(node, depth));
                if (this.isTreeExpanded(node.id)) {
                    (kids[node.id] || []).forEach(ch => walk(ch, depth + 1));
                }
            };
            this.treeRoots.forEach(r => walk(r, 0));
            return rows;
        },
        sortOptions() {
            // Create an options list from our fields
            return this.fields
                .filter(f => f.sortable)
                .map(f => {
                    return { text: f.label, value: f.key }
                })
        },
        filteredCategories: function() {
            const list = Array.isArray(this.categories) ? this.categories : [];
            const query = this.filter ? this.filter.toLowerCase() : '';
            return list.filter(category => {
                const name = (category.name || '').toString().toLowerCase();
                return name.includes(query);
            });
        },
        // Computed property to transform categories with translated fields based on current app_locale
        translatedCategories: function() {
            // Guard: ensure categories is an array to avoid "Cannot read properties of undefined (reading 'length')"
            const list = Array.isArray(this.categories) ? this.categories : [];
            if (!this.currentLanguageId || list.length === 0) {
                return list;
            }

            // Transform each category to use translated fields
            return list.map(category => {
                const translatedCategory = { ...category };

                if (category.translations && Array.isArray(category.translations)) {
                    const translation = category.translations.find(
                        t => t.language_id === this.currentLanguageId
                    );

                    // Use translated name if available and not empty, otherwise fallback to main table name
                    if (translation && translation.name && translation.name.trim() !== '') {
                        translatedCategory.name = translation.name;
                    }

                }
                return translatedCategory;
            });
        },
    },
    mounted() {
    },
    watch: {
        currentPage(newPage) {
            this.getCategories();
        },
        perPage(newPerPage) {
            this.getCategories();
        },
        filter(newFilter, oldFilter) {
            this.currentPage = 1;
            this.getCategories();
        }
    },
    created: function() {
        this.fetchActiveLanguages().then(() => {
            this.getCategories();
        });
    },
    methods: {
        // Translate one category's name to the active panel language (mirrors the
        // translatedCategories computed, but works on a single row for the tree).
        // Count + hover-list helpers. `kind` maps to the relation the API eager-loads.
        _relFor(kind) {
            return {
                childs:     { list: 'childs',             count: 'childs_count' },
                attributes: { list: 'category_attributes', count: 'category_attributes_count' },
                sections:   { list: 'custom_sections',    count: 'custom_sections_count' },
                products:   { list: null,                 count: 'products_count' },
            }[kind];
        },
        hasAnyCount(cat) {
            return ['childs', 'attributes', 'sections', 'products'].some(k => this.count(cat, k) > 0);
        },
        count(cat, kind) {
            const rel = this._relFor(kind);
            return Number((cat || {})[rel.count] || 0);
        },
     
        namesTip(cat, kind) {
            const rel = this._relFor(kind);
            if (!rel.list) return '';
            const rows = Array.isArray((cat || {})[rel.list]) ? cat[rel.list] : [];
            if (!rows.length) {
                return { childs: __('no_subcategories'), attributes: __('no_attributes'), sections: __('no_custom_sections') }[kind] || '';
            }
            const names = rows.map(r => this.translateName(r)).filter(Boolean);
            const shown = names.slice(0, 15);
            const rest = names.length - shown.length;
            return shown.join(', ') + (rest > 0 ? ` +${rest}` : '');
        },
        translateName(category) {
            if (!this.currentLanguageId || !category) return category ? category.name : '';
            if (Array.isArray(category.translations)) {
                const t = category.translations.find(x => x.language_id === this.currentLanguageId);
                if (t && t.name && t.name.trim() !== '') return t.name;
            }
            return category.name;
        },
        switchToTree() {
            this.viewMode = 'tree';
            if (!this.allCategories.length) this.loadTree();
        },
        // Refresh whichever view is active.
        refreshCurrent() {
            if (this.viewMode === 'tree') this.loadTree();
            else this.getCategories();
        },
        // Tree needs the FULL hierarchy, so it fetches every category (no limit).
        loadTree() {
            this.treeLoading = true;
            const params = { filter: '' };
            if (this.statusFilter !== '') params.status = this.statusFilter;
            axios.get(this.$apiUrl + '/categories', { params })
                .then(r => {
                    const d = r.data || {};
                    if (Number(d.status) === 0) {
                        this.allCategories = [];
                        this.showError(d.message || __('something_went_wrong'));
                        return;
                    }
                    this.allCategories = Array.isArray(d.data) ? d.data : [];
                })
                .catch(() => { this.allCategories = []; })
                .finally(() => { this.treeLoading = false; });
        },
        onStatusChange() {
            this.currentPage = 1;
            this.refreshCurrent();
        },
        isTreeExpanded(id) {
            return !!this.treeExpanded[id];
        },
        toggleTreeNode(id) {
            this.treeExpanded = { ...this.treeExpanded, [id]: !this.treeExpanded[id] };
        },
        fetchActiveLanguages() {
            return axios.get(this.$apiUrl + '/active_languages')
                .then(response => {
                    if (response.data.data && Array.isArray(response.data.data)) {
                        this.activeLanguages = response.data.data;
                        
                        const appLocale = window.appLocale || 'en';
                        
                        // Find language ID for current app_locale code
                        const currentLanguage = this.activeLanguages.find(
                            lang => lang.code === appLocale
                        );
                        
                        if (currentLanguage) {
                            this.currentLanguageId = currentLanguage.id;
                        } else {
                            const defaultLanguage = this.activeLanguages.find(
                                lang => lang.is_default === 1
                            );
                            if (defaultLanguage) {
                                this.currentLanguageId = defaultLanguage.id;
                            }
                        }
                    }
                })
                .catch(error => {
                    console.error('Error loading languages:', error);
                });
        },

        getCategories(){

            this.isLoading = true
            const params = {
                offset: this.currentPage,
                limit: this.perPage,
                filter: this.filter
            };
            if (this.statusFilter !== '') params.status = this.statusFilter;
            axios.get(this.$apiUrl + '/categories', { params })
                .then((response) => {
                    this.isLoading = false;
                    const data = response.data || {};
                    // The API answers 200 even when it refuses (status 0); surface
                    // that as an alert instead of a silent empty list.
                    if (Number(data.status) === 0) {
                        this.categories = [];
                        this.totalRows = 0;
                        this.showError(data.message || __('something_went_wrong'));
                        return;
                    }
                    // Always set to array so .length and table empty state work; avoid undefined
                    this.categories = Array.isArray(data.data) ? data.data : [];
                    this.totalRows = typeof data.total === 'number' ? data.total : 0;
                })
                .catch(() => {
                    this.isLoading = false;
                    this.categories = [];
                    this.totalRows = 0;
                });
        },


        deleteCategory(id){
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
                    this.isLoading = true
                    let postData = {
                        id : id
                    }
                    axios.post(this.$apiUrl + '/categories/delete',postData)
                        .then((response) => {
                            // The API answers 200 even when it refuses (status 0), e.g. a
                            // category still holding products — check the flag, not the
                            // HTTP code, or a refusal shows as a success toast.
                            const data = response.data || {};
                            if (Number(data.status) === 0) {
                                this.isLoading = false;
                                this.showError(data.message || __('something_went_wrong'));
                                return;
                            }
                            this.showMessage('success', data.message);
                            // Refresh whichever view is showing.
                            this.refreshCurrent();
                        })
                        .catch(() => { this.isLoading = false; });
                }
            });
        },
    }
};
</script>
