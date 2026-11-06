<template>
    <div>
        <div class="list-page">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('orders') }}</h3>

                <div class="page-head-actions">
                    <!-- Channel tabs -->
                    <div class="btn-group" role="group">
                        <button class="btn" :class="tab === 'quick' ? 'btn-primary' : 'btn-outline-primary'" @click="switchTab('quick')">
                            <Zap :size="15" class="me-1" /> {{ __('quick') }}
                        </button>
                        <button class="btn" :class="tab === 'ecom' ? 'btn-primary' : 'btn-outline-primary'" @click="switchTab('ecom')">
                            <ShoppingBag :size="15" class="me-1" /> {{ __('ecommerce') }}
                        </button>
                    </div>
                </div>
            </div>

            <div class="list-surface">
                <div class="list-toolbar">
                    <div class="list-toolbar-start">
                        <button class="btn" :class="showFilters ? 'btn-primary' : 'btn-outline-primary'"
                            @click="showFilters = !showFilters">
                            <SlidersHorizontal :size="15" /> {{ __('filters') }}
                        </button>
                    </div>

                    <div class="list-search">
                        <Search class="list-search-icon" />
                        <input type="search" v-model="search" @input="debouncedFetch"
                            class="form-control" :placeholder="__('search_orders_placeholder')" />
                    </div>

                    <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="fetch()">
                        <RefreshCw :class="{ 'is-spinning': isLoading }" />
                    </button>
                </div>

                <!-- Filters -->
                <transition name="filter-slide">
                <div v-if="showFilters" class="list-filters">
                    <div class="row">
                        <div class="col-md-4 col-6">
                            <label class="flbl">{{ __('from_to_date') }}</label>
                            <div class="d-flex gap-2">
                                <date-range-picker class="flex-grow-1" v-model="dateRange" :config="datePickerConfig" @update="fetch" />
                                <button v-if="dateRange" class="btn btn-danger" @click="dateRange = ''; fetch()">
                                    {{ __('clear') }}
                                </button>
                            </div>
                        </div>
                        <div class="col-md-4 col-6">
                            <label class="flbl">{{ __('status') }}</label>
                            <AppSelect class="form-select" v-model="status" :options="statusFilterOptions"
                                :searchable="false" @update:model-value="fetch()" />
                        </div>
                    </div>
                </div>
                </transition>

                <!-- QUICK: order-wise -->
                <MazerDatatable v-if="tab === 'quick'" responsive="sm" :items="orders" :fields="quickFields"
                    :striped="true" :head-variant="'light'" :busy="isLoading" stacked="md" show-empty small>
                    <template #cell(id)="row">
                        <div class="fw-bold">{{ row.item.order_number || ('#' + String(row.item.id).padStart(5, '0')) }}</div>
                        <small class="text-muted">{{ $filters.formatDateTime(row.item.date) }}</small>
                    </template>
                    <template #cell(user_name)="row">
                        <div class="fw-bold">{{ row.item.user_name }}</div>
                        <small class="text-muted d-block">{{ $filters.mobileMask(row.item.user_mobile || row.item.mobile) }}</small>
                    </template>
                    <template #cell(items_preview)="row">
                        <div class="text-truncate" style="max-width:220px">{{ itemsPreview(row.item) }}</div>
                        <small class="text-muted">{{ row.item.branch_name || '' }}</small>
                    </template>
                    <template #cell(payment_method)="row">
                        <span class="badge bg-light text-dark border">{{ row.item.payment_method }}</span>
                    </template>
                    <template #cell(final_total)="row">
                        <span class="fw-bold">{{ row.item.currency || $currency }}{{ row.item.final_total }}</span>
                    </template>
                    <template #cell(active_status)="row">
                        <span class="badge" :class="getStatusBadgeClass(row.item.active_status)">{{ statusLabel(row.item.active_status) }}</span>
                    </template>
                    <template #cell(actions)="row">
                        <div class="list-actions">
                            <button class="list-action-btn is-view" v-b-tooltip.hover :title="__('view')" @click="openOrder(row.item.id)">
                                <Eye :size="15" />
                            </button>
                        </div>
                    </template>
                </MazerDatatable>

                <!-- ECOMMERCE: item-wise (same columns as quick) -->
                <MazerDatatable v-else responsive="sm" :items="items" :fields="quickFields"
                    :striped="true" :head-variant="'light'" :busy="isLoading" stacked="md" show-empty small>
                    <template #cell(id)="row">
                        <div class="fw-bold">{{ row.item.order_number || ('#' + String(row.item.order_id).padStart(5, '0')) }}</div>
                        <small class="text-muted">{{ __('item') }} #{{ row.item.id }}</small>
                    </template>
                    <template #cell(user_name)="row">
                        <div class="fw-bold">{{ row.item.user_name }}</div>
                        <small class="text-muted d-block">{{ $filters.mobileMask(row.item.user_mobile || row.item.order_mobile) }}</small>
                    </template>
                    <template #cell(items_preview)="row">
                        <div class="d-flex gap-2 align-items-center">
                            <img v-if="row.item.image" :src="row.item.image" class="list-thumb" alt="" />
                            <div>
                                <div class="text-truncate fw-bold" style="max-width:200px">{{ row.item.product_name }}</div>
                                <small class="text-muted">{{ __('qty') }}: {{ row.item.quantity }}</small>
                            </div>
                        </div>
                    </template>
                    <template #cell(payment_method)="row">
                        <span class="badge bg-light text-dark border">{{ row.item.payment_method }}</span>
                    </template>
                    <template #cell(final_total)="row">
                        <span class="fw-bold">{{ row.item.currency || $currency }}{{ row.item.final_total }}</span>
                    </template>
                    <template #cell(active_status)="row">
                        <span class="badge" :class="getStatusBadgeClass(row.item.active_status)">{{ statusLabel(row.item.active_status) }}</span>
                    </template>
                    <template #cell(actions)="row">
                        <div class="list-actions">
                            <button class="list-action-btn is-view" v-b-tooltip.hover :title="__('view')" @click="openOrder(row.item.order_id, row.item.id)">
                                <Eye :size="15" />
                            </button>
                        </div>
                    </template>
                </MazerDatatable>

                <div class="list-footer">
                    <div class="list-perpage">
                        <span>{{ __('per_page') }}</span>
                        <b-form-select id="per-page-select" v-model="perPage" :options="pageOptions"
                            size="sm" class="form-select"></b-form-select>
                    </div>

                    <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage"
                        size="sm" class="mb-0 list-pagination"></b-pagination>
                </div>
            </div>
        </div>

        <OrderDetailSlider v-model="sliderShow" :order-id="activeOrderId" :order-item-id="activeItemId" :nav-list="navList" mode="delivery_boy" @navigate="onNavigate" @updated="fetch" />
    </div>
</template>

<script>
import axios from "axios";
import OrderDetailSlider from '../Orders/OrderDetailSlider.vue';
import DateRangePicker from '../../components/DateRangePicker.vue';
import { buildDateRangeConfig, toApiDate } from '../../utils/dateRange.js';
import { Search, Eye, SlidersHorizontal, Zap, ShoppingBag, RefreshCw } from 'lucide-vue-next';

export default {
    name: "DeliveryBoyOrdersList",
    components: { OrderDetailSlider, DateRangePicker, Search, Eye, SlidersHorizontal, Zap, ShoppingBag, RefreshCw },
    data() {
        return {
            tab: 'quick',
            search: "",
            status: "",
            dateRange: "",
            datePickerConfig: buildDateRangeConfig({ maxDate: new Date() }),
            showFilters: false,

            orders: [],   // quick (order-wise)
            items: [],    // ecommerce (item-wise)
            statuses: [],

            quickFields: [
                { key: 'id', label: __('order_no'), class: 'text-center' },
                { key: 'user_name', label: __('customer') },
                { key: 'items_preview', label: __('items') },
                { key: 'payment_method', label: __('payment'), class: 'text-center' },
                { key: 'final_total', label: __('amount'), class: 'text-center' },
                { key: 'active_status', label: __('status'), class: 'text-center' },
                { key: 'actions', label: __('actions'), class: 'text-center' },
            ],

            totalRows: 0,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            isLoading: false,

            sliderShow: false,
            activeOrderId: null,
            activeItemId: null,
            _debounce: null,
        };
    },
    computed: {
        statusFilterOptions() {
            return [{ id: '', name: __('all_statuses') }]
                .concat((this.statuses || []).map(s => ({ id: s.id, name: this.getStatusDisplayName(s) })));
        },
        primaryColor() { return window.adminThemeColor || '#435ebe'; },
        navList() {
            return this.tab === 'ecom'
                ? this.items.map(it => ({ id: it.order_id, itemId: it.id }))
                : this.orders.map(o => ({ id: o.id }));
        },
    },
    created() {
        this.getOrderStatus();
        this.fetch();
    },
    watch: {
        currentPage() { this.fetch(); },
        perPage() { this.fetch(); },
    },
    methods: {
        switchTab(t) {
            if (this.tab === t) return;
            this.tab = t;
            this.currentPage = 1;
            this.orders = [];
            this.items = [];
            this.totalRows = 0;
            this.fetch();
        },
        debouncedFetch() {
            clearTimeout(this._debounce);
            this._debounce = setTimeout(() => { this.currentPage = 1; this.fetch(); }, 400);
        },
        getOrderStatus() {
            axios.get(this.$deliveryBoyApiUrl + '/order_statuses').then((res) => {
                this.statuses = res.data.data || [];
            }).catch(() => {});
        },
        fetch() {
            this.isLoading = true;
            const params = {
                search: this.search,
                status: this.status,
                limit: this.perPage,
                offset: (this.currentPage - 1) * this.perPage,
            };
            if (this.dateRange) {
                params.start_date = toApiDate(this.dateRange, 'start');
                params.end_date = toApiDate(this.dateRange, 'end');
            }
            const url = this.tab === 'ecom' ? '/ecom_orders' : '/orders';
            axios.get(this.$deliveryBoyApiUrl + url, { params }).then((res) => {
                const data = res.data.data || [];
                if (this.tab === 'ecom') this.items = data; else this.orders = data;
                this.totalRows = res.data.total || 0;
                this.isLoading = false;
            }).catch((error) => {
                this.isLoading = false;
                this.showError(error?.message || __('something_went_wrong'));
            });
        },
        openOrder(orderId, itemId = null) {
            this.activeOrderId = orderId;
            this.activeItemId = itemId;
            this.sliderShow = true;
        },
        onNavigate(entry) {
            this.activeOrderId = entry.id;
            this.activeItemId = entry.itemId ?? null;
        },
        itemsPreview(order) {
            const items = order.items || [];
            if (!items.length) return '-';
            return items.map(i => (i.name || i.product_name || '')).filter(Boolean).join(', ');
        },
        formatDate(dt) {
            if (!dt) return '';
            const d = new Date(dt);
            return d.toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' });
        },
        getStatusDisplayName(status) {
            if (!status) return '';
            const sn = status.status_name;
            if (sn == null) return status.status || '';
            if (typeof sn === 'string') return sn.trim() || status.status || '';
            if (typeof sn === 'object') {
                const loc = window.appLocale || window.localStorage.getItem('lang') || 'en';
                const v = sn[loc] || Object.values(sn).find(x => x && String(x).trim() !== '');
                return v ? String(v).trim() : (status.status || '');
            }
            return status.status || '';
        },
        statusLabel(id) {
            const s = this.statuses.find(x => Number(x.id) === Number(id));
            if (s) return this.getStatusDisplayName(s);
            const all = { 1: 'payment_pending', 2: 'received', 3: 'processed', 4: 'shipped', 5: 'outForDelivery', 6: 'delivered', 7: 'cancelled', 8: 'returned', 9: 'preparing', 10: 'ready_for_pickup', 11: 'picked_up' };
            return all[Number(id)] ? this.__(all[Number(id)]) : String(id ?? '');
        },
        getStatusBadgeClass(id) {
            const n = Number(id);
            if (n === 1) return 'bg-secondary';
            if (n === 2) return 'bg-primary';
            if (n === 3 || n === 9) return 'bg-info';
            if (n === 4 || n === 5 || n === 10 || n === 11) return 'bg-warning';
            if (n === 6) return 'bg-success';
            if (n === 7 || n === 8) return 'bg-danger';
            return 'bg-secondary';
        },
    },
};
</script>

<style scoped>
.flbl { font-size: .72rem; color: var(--app-muted); margin-bottom: .2rem; display: block; }
.gap-2 { gap: .5rem; }
</style>
