<template>
    <div class="list-page">
        <div class="page-head">
            <div>
                <h3 class="page-head-title mb-0">{{ __('stock_alerts') }}</h3>
                <p class="text-muted small mb-0 mt-1">{{ __('stock_alerts_hint') }}</p>
            </div>
        </div>

        <!-- Totals for the current filter, so a country filter answers "what does this market want". -->
        <div class="row g-3 mb-3">
            <div class="col-6 col-sm-4 col-xl" v-for="c in statCards" :key="c.key">
                <div class="stat-card">
                    <span class="stat-icon"><component :is="c.icon" :size="20" /></span>
                    <div class="stat-meta">
                        <div class="stat-label">{{ c.label }}</div>
                        <div class="stat-num">{{ c.value }}</div>
                    </div>
                </div>
            </div>
        </div>

        <div class="row g-3">
            <!-- Most requested: what to reorder first. -->
            <div class="col-xl-4">
                <div class="list-surface h-100">
                    <div class="list-toolbar">
                        <div class="fw-semibold d-flex align-items-center gap-2">
                            <TrendingUp :size="16" /> {{ __('most_requested_products') }}
                        </div>
                    </div>
                    <div class="list-panel-body">
                        <div v-if="!topProducts.length" class="text-muted small text-center py-4">{{ __('no_records_to_show') }}</div>
                        <div v-else class="top-list">
                            <div class="top-row" v-for="(p, i) in topProducts" :key="p.product_id" @click="filterByProduct(p)"
                                :class="{ active: Number(product_id) === Number(p.product_id) }" role="button">
                                <span class="top-rank">{{ i + 1 }}</span>
                                <img v-if="p.image" :src="p.image" class="top-thumb" alt="" />
                                <div class="top-ph" v-else><Package :size="16" /></div>
                                <div class="top-meta">
                                    <div class="top-name text-truncate">{{ p.product_name }}</div>
                                    <small class="text-muted">{{ __('waiting_since') }} {{ $filters.formatDate(p.oldest_request) }}</small>
                                </div>
                                <span class="badge bg-warning text-dark">{{ p.waiting }} {{ __('waiting') }}</span>
                            </div>
                        </div>
                        <small class="text-muted d-block mt-2" v-if="topProducts.length">{{ __('click_a_product_to_filter_the_list') }}</small>
                    </div>
                </div>
            </div>

            <!-- Every request: who is waiting on what. -->
            <div class="col-xl-8">
                <div class="list-surface">
                    <div class="list-toolbar">
                        <div class="list-toolbar-start flex-wrap">
                            <AppSelect v-if="czShowCountry" class="form-select list-select cz-sel" v-model="czCountryId"
                                :options="czCountryOptions" :searchable="czCountryOptions.length > 6" :allow-empty="false"
                                label-key="label" track-by="id" :placeholder="__('country')" @update:model-value="czOnCountry">
                                <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                            :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                                <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                            :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                            </AppSelect>
                            <AppSelect v-if="czShowZoneDropdown" class="form-select list-select" v-model="czZoneId"
                                :options="czZoneOptions" label-key="label" track-by="id" :placeholder="__('all_zones')"
                                @update:model-value="czOnZone" />
                            <AppSelect class="form-select list-select" v-model="status" :options="statusOptions"
                                :searchable="false" @update:model-value="reload" />
                            <div class="cc-daterange">
                                <date-range-picker v-model="dateRange" :config="datePickerConfig" @update="reload"></date-range-picker>
                            </div>
                            <button v-if="dateRange || product_id" class="list-icon-btn" @click="dateRange = ''; product_id = ''; reload()"
                                v-b-tooltip.hover :title="__('clear')"><X :size="16" /></button>
                        </div>

                        <div class="list-search">
                            <Search class="list-search-icon" />
                            <input v-model="search" type="search" class="form-control" :placeholder="__('search_product_or_customer')"
                                @input="debouncedReload" />
                        </div>

                        <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getAlerts()">
                            <RefreshCw :class="{ 'is-spinning': isLoading }" />
                        </button>
                    </div>

                    <MazerDatatable responsive :items="alerts" :fields="fields" :busy="isLoading" stacked="md" show-empty small>
                        <template #cell(product)="row">
                            <div class="d-flex align-items-center gap-2 text-start">
                                <img v-if="row.item.product_image" :src="row.item.product_image" class="row-thumb" alt="" />
                                <div>
                                    <router-link class="db-identity-name" :to="{ name: 'ViewProduct', params: { id: row.item.product_id } }">
                                        {{ row.item.product_name || '—' }}
                                    </router-link>
                                    <small class="text-muted d-block">{{ row.item.variant_name || '' }}</small>
                                </div>
                            </div>
                        </template>
                        <template #cell(customer)="row">
                            <div class="text-start">
                                <router-link class="db-identity-name" v-if="row.item.user_id"
                                    :to="{ name: 'ViewCustomer', params: { id: row.item.user_id } }">{{ row.item.user_name || '—' }}</router-link>
                                <small class="text-muted d-block">{{ $filters.mobileMask(row.item.user_mobile || '') }}</small>
                            </div>
                        </template>
                        <template #cell(zone)="row">
                            <div class="text-start">
                                <div>{{ row.item.zone_name || '—' }}</div>
                                <small class="text-muted">{{ row.item.branch_name || '' }}</small>
                            </div>
                        </template>
                        <template #cell(status)="row">
                            <span class="status-pill" :class="statusClass(row.item.status)">{{ row.item.status_name }}</span>
                        </template>
                        <template #cell(created_at)="row">
                            {{ $filters.formatDateTime(row.item.created_at) }}
                        </template>
                        <template #cell(notified_at)="row">
                            {{ row.item.notified_at ? $filters.formatDateTime(row.item.notified_at) : '—' }}
                        </template>
                    </MazerDatatable>

                    <div class="list-footer">
                        <div class="list-perpage">
                            <span>{{ __('per_page') }}</span>
                            <b-form-select id="per-page-select" v-model="perPage" :options="pageOptions" size="sm" class="form-select"></b-form-select>
                            <span class="list-range">{{ __('total_records') }} : {{ totalRows }}</span>
                        </div>
                        <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage" size="sm" class="mb-0 list-pagination"></b-pagination>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import axios from 'axios';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';
import DateRangePicker from '../../components/DateRangePicker.vue';
import { buildDateRangeConfig, toApiDate } from '../../utils/dateRange.js';
import { Search, RefreshCw, X, TrendingUp, Package, BellRing, CheckCircle2, Users, Boxes } from 'lucide-vue-next';

export default {
    name: 'StockAlerts',
    mixins: [CountryZoneFilter],
    components: { DateRangePicker, Search, RefreshCw, X, TrendingUp, Package },
    data() {
        return {
            czAllowAll: true,
            alerts: [],
            topProducts: [],
            summary: { waiting: 0, notified: 0, cancelled: 0, variants: 0, customers: 0 },
            status: '1',
            product_id: '',
            search: '',
            dateRange: '',
            datePickerConfig: buildDateRangeConfig({ maxDate: new Date() }),
            isLoading: false,
            totalRows: 0,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            fields: [
                { key: 'product', label: __('product'), class: 'text-center col-product' },
                { key: 'customer', label: __('customer'), class: 'text-center col-customer' },
                { key: 'zone', label: __('zone'), class: 'text-center' },
                { key: 'status', label: __('status'), class: 'text-center' },
                { key: 'created_at', label: __('requested_at'), class: 'text-center' },
                { key: 'notified_at', label: __('notified_at'), class: 'text-center' },
            ],
            _debounce: null,
        };
    },
    computed: {
        statusOptions() {
            return [
                { id: '', name: __('all_status') },
                { id: '1', name: __('waiting') },
                { id: '2', name: __('notified') },
                { id: '0', name: __('cancelled') },
            ];
        },
        statCards() {
            return [
                { key: 'waiting', label: __('waiting'), value: this.summary.waiting, icon: BellRing },
                { key: 'notified', label: __('notified'), value: this.summary.notified, icon: CheckCircle2 },
                { key: 'variants', label: __('products_requested'), value: this.summary.variants, icon: Boxes },
                { key: 'customers', label: __('customers_waiting'), value: this.summary.customers, icon: Users },
            ];
        },
    },
    watch: {
        currentPage() { this.getAlerts(); },
        perPage() { this.currentPage = 1; this.getAlerts(); },
    },
    mounted() {
        this.czLoad(); // resolves the country, then calls czOnFilter
    },
    methods: {
        czOnFilter() { this.reload(); },
        debouncedReload() {
            clearTimeout(this._debounce);
            this._debounce = setTimeout(() => this.reload(), 400);
        },
        reload() {
            this.currentPage = 1;
            this.getAlerts();
        },
        filterByProduct(p) {
            this.product_id = Number(this.product_id) === Number(p.product_id) ? '' : p.product_id;
            this.reload();
        },
        getAlerts() {
            this.isLoading = true;
            const params = {
                page: this.currentPage,
                per_page: this.perPage,
                search: this.search || '',
                status: this.status,
                product_id: this.product_id || '',
                country_id: this.czCountryParam,
                zone_id: this.czZoneParam,
            };
            if (this.dateRange) {
                params.startDate = toApiDate(this.dateRange, 'start');
                params.endDate = toApiDate(this.dateRange, 'end');
            }
            axios.get(this.$apiUrl + '/stock_alerts', { params }).then(res => {
                const d = res.data?.data || {};
                this.alerts = d.alerts || [];
                this.summary = d.summary || this.summary;
                this.topProducts = d.top_products || [];
                this.totalRows = res.data?.total || 0;
            }).catch(() => this.showError(__('something_went_wrong')))
                .finally(() => { this.isLoading = false; });
        },
        statusClass(status) {
            const n = Number(status);
            if (n === 1) return 'is-pending';
            if (n === 2) return 'is-active';
            return 'is-inactive';
        },
    },
};
</script>

<style scoped>
.stat-card {
    display: flex; align-items: center; gap: .75rem; height: 100%;
    background: var(--app-card-bg); border: 1px solid var(--app-card-border);
    border-radius: 12px; padding: .9rem 1rem;
}
.stat-icon {
    width: 44px; height: 44px; border-radius: 12px; flex-shrink: 0;
    display: inline-flex; align-items: center; justify-content: center;
    background: rgba(var(--bs-primary-rgb), .1); color: var(--bs-primary);
}
.stat-label { font-size: 12px; color: var(--bs-secondary-color); }
.stat-num { font-size: 18px; font-weight: 700; }
.top-list { display: flex; flex-direction: column; gap: 6px; }
.top-row {
    display: flex; align-items: center; gap: 10px; padding: 8px 10px; border-radius: 8px;
    border: 1px solid var(--app-card-border); cursor: pointer;
}
.top-row:hover, .top-row.active { border-color: var(--bs-primary); background: rgba(var(--bs-primary-rgb), .06); }
.top-rank { width: 22px; font-size: 12px; font-weight: 700; color: var(--bs-secondary-color); text-align: center; }
.top-thumb, .top-ph { width: 36px; height: 36px; border-radius: 6px; object-fit: cover; flex-shrink: 0; }
.top-ph { display: inline-flex; align-items: center; justify-content: center; background: rgba(var(--bs-primary-rgb), .08); color: var(--bs-primary); }
.top-meta { min-width: 0; flex: 1; }
.top-name { font-size: 13px; font-weight: 600; }
.row-thumb { width: 36px; height: 36px; border-radius: 6px; object-fit: cover; flex-shrink: 0; }
:deep(.col-product) { min-width: 260px; }
:deep(.col-customer) { min-width: 160px; }
.db-identity-name { white-space: normal; }
.status-pill.is-pending { color: #92400e; background: rgba(245, 158, 11, .16); }
.cc-daterange { width: 220px; flex-shrink: 0; }
.cc-daterange :deep(.date-range-picker), .cc-daterange :deep(.form-control) { width: 100%; height: 36px; border-radius: 8px; }
.cz-flag { width: 18px; height: 12px; object-fit: cover; border-radius: 2px; margin-right: 4px; }
</style>
