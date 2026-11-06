<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('wishlists') }}</h3>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <button class="btn" :class="showFilters ? 'btn-primary' : 'btn-outline-primary'"
                    @click="showFilters = !showFilters">
                    <SlidersHorizontal :size="15" /> {{ __('filters') }}
                    <span v-if="activeFilterCount" class="badge bg-light text-dark ms-1">{{ activeFilterCount }}</span>
                </button>

                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input
                        id="filter-input"
                        v-model="filter"
                        type="search"
                        class="form-control"
                        :placeholder="__('search')">
                </div>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getWishlists()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <!-- Collapsible filter panel -->
            <transition name="filter-slide">
            <div v-if="showFilters" class="list-filters">
                <div class="row g-3">
                    <div class="col-lg-3 col-md-4 col-6">
                        <label class="flbl">{{ __('categories') }}</label>
                        <AppSelect class="form-select" v-model="category_id" :options="categoryOptions"
                            :placeholder="__('all_categories')" @update:model-value="getWishlists" />
                    </div>
                    <div class="col-lg-3 col-md-4 col-6">
                        <label class="flbl">{{ __('brand') }}</label>
                        <AppSelect class="form-select" v-model="brand_id" :options="brandOptions"
                            :placeholder="__('all_brands')" @update:model-value="getWishlists" />
                    </div>
                    <div class="col-lg-2 col-md-4 col-6">
                        <label class="flbl">{{ __('channel') }}</label>
                        <AppSelect class="form-select" v-model="channel" :options="channelOptions"
                            :searchable="false" @update:model-value="getWishlists" />
                    </div>
                    <div class="col-lg-3 col-md-6 col-12">
                        <label class="flbl">{{ __('from_to_date') }}</label>
                        <div class="d-flex gap-2">
                            <date-range-picker class="flex-grow-1" v-model="dateRange"
                                :config="datePickerConfig" @update="getWishlists" />
                            <button class="list-icon-btn" @click="resetFilters" :disabled="!activeFilterCount"
                                v-b-tooltip.hover :title="__('clear_filters')">
                                <X :size="15" />
                            </button>
                        </div>
                    </div>
                </div>
            </div>
            </transition>

            <MazerDatatable responsive
                :items="wishlists"
                :fields="fields"
                :current-page="currentPage"
                :per-page="perPage"
                :filter="filter"
                :filter-included-fields="filterOn"
                v-model:sort-by="sortBy"
                v-model:sort-desc="sortDesc"
                :sort-direction="sortDirection"

                :busy="isLoading"
                stacked="md"
                show-empty
                small>
                    <template #cell(user_name)="row">
                        <router-link class="db-identity-name" v-if="row.item.user_id"
                            :to="{ name: 'ViewCustomer', params: { id: row.item.user_id } }">
                            {{ row.item.user_name || '—' }}
                        </router-link>
                        <template v-else>{{ row.item.user_name || '—' }}</template>
                    </template>

                    <template #cell(product_name)="row">
                        <router-link class="db-identity-name" v-if="row.item.product_id"
                            :to="{ name: 'ViewProduct', params: { id: row.item.product_id } }">
                            {{ row.item.product_name || '—' }}
                        </router-link>
                        <template v-else>{{ row.item.product_name || '—' }}</template>
                    </template>

                <template #cell(created_at)="row">
                    {{ $filters.formatDateTime(row.item.created_at) }}
                </template>
                <template #cell(actions)="row">
                    <div class="list-actions">
                        <router-link :to="'products/view/' + row.item.product_id" class="list-action-btn is-view" v-b-tooltip.hover :title="__('view')">
                            <Eye :size="15" />
                        </router-link>
                    </div>
                </template>

            </MazerDatatable>

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
    </div>
</template>
<script>
import { Search, RefreshCw, Eye, SlidersHorizontal, X } from 'lucide-vue-next';
import DateRangePicker from '../../components/DateRangePicker.vue';
import { buildDateRangeConfig, toApiDate } from '../../utils/dateRange.js';

export default {
    components: { Search, RefreshCw, Eye, SlidersHorizontal, X, DateRangePicker },
    data: function() {
        return {
            fields: [
                { key: 'id', label: __('id'), sortable: true, sortDirection: 'desc', class: 'text-center' },
                { key: 'user_name', label: __('user'), sortable: false, class: 'text-center' },
                { key: 'product_name', label: __('product'), sortable: false, class: 'text-center' },
                { key: 'total_qty', label: __('quantity'), sortable: false, class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false, class: 'text-center' }
            ],
            totalRows: 1,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            sortBy: '',
            sortDesc: false,
            sortDirection: 'asc',
            filter: null,
            filterOn: [],
            page: 1,

            isLoading: false,
            wishlists: [],

            // Filters
            showFilters: false,
            category_id: '',
            brand_id: '',
            channel: '',
            dateRange: '',
            datePickerConfig: buildDateRangeConfig({ maxDate: new Date() }),
            categories: [],
            brands: [],
        }
    },
    computed: {
        sortOptions() {
            return this.fields
                .filter(f => f.sortable)
                .map(f => {
                    return { text: f.label, value: f.key }
                })
        },
        activeFilterCount() {
            return [this.category_id, this.brand_id, this.channel, this.dateRange]
                .filter(v => v !== '' && v !== null).length;
        },
        categoryOptions() {
            return this.categories.map(c => ({ id: c.id, name: c.name }));
        },
        brandOptions() {
            return this.brands.map(b => ({ id: b.id, name: b.name }));
        },
        // Fixed option set — no search box needed.
        channelOptions() {
            return [
                { id: '', name: (__('all')) },
                { id: 'quick', name: (__('quick')) },
                { id: 'ecommerce', name: (__('ecommerce')) },
            ];
        },
    },
    mounted() {
        this.totalRows = this.wishlists.length
    },
    created: function() {
        this.getWishlists();
        this.loadFilterData();
    },
    methods: {
        getWishlists(){
            this.isLoading = true
            const params = {};
            if (this.category_id) params.category_id = this.category_id;
            if (this.brand_id) params.brand_id = this.brand_id;
            if (this.channel) params.channel = this.channel;
            if (this.dateRange) {
                params.startDate = toApiDate(this.dateRange, 'start');
                params.endDate = toApiDate(this.dateRange, 'end');
            }
            axios.get(this.$apiUrl + '/wishlists', { params })
                .then((response) => {
                    this.isLoading = false
                    this.wishlists = response.data.data;
                    this.totalRows = this.wishlists.length
                    this.currentPage = 1
                })
                .catch(() => { this.isLoading = false });
        },
        // Category + brand dropdown options for the filters.
        loadFilterData() {
            axios.get(this.$apiUrl + '/categories').then(r => {
                this.categories = r.data.data || [];
            });
            axios.get(this.$apiUrl + '/products/brands/get').then(r => {
                this.brands = r.data.data || [];
            });
        },
        resetFilters() {
            this.category_id = '';
            this.brand_id = '';
            this.channel = '';
            this.dateRange = '';
            this.getWishlists();
        },
    }
};
</script>
