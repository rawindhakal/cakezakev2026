<template>
    <div>
        <div class="list-page">
            <div class="page-head">
                <h3 class="page-head-title">{{ fixedDeliveryType === 'pickup' ? __('self_pickup_orders') : __('orders') }}</h3>
            </div>

            <!-- Stat cards -->
            <div class="row g-3 mb-3">
                <div class="col-6 col-md" v-for="card in statCards" :key="card.key">
                    <div class="stat-card" :class="'tone-' + card.tone">
                        <span class="stat-icon">
                            <component :is="card.icon" :size="20" />
                        </span>
                        <div class="stat-meta">
                            <div class="stat-label">{{ card.label }}</div>
                            <div class="stat-num"><RollingNumber :value="counts[card.key] || 0" /></div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="list-surface">
                <div class="list-toolbar">
                    <div class="list-toolbar-start">
                        <!-- Country / zone (per-row currency → All Countries allowed), left of the Modes dropdown. -->
                        <AppSelect v-if="czShowCountry" class="cz-sel" v-model="czCountryId" :options="czCountryOptions"
                            :searchable="czCountryOptions.length > 6" :allow-empty="false" label-key="label"
                            track-by="id" :placeholder="__('country')" @update:model-value="czOnCountry">
                            <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                        :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                            <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                        :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                        </AppSelect>
                        <AppSelect v-if="czShowZoneDropdown" class="cz-sel" v-model="czZoneId" :options="czZoneOptions"
                            :searchable="false" :allow-empty="false" label-key="label" track-by="id"
                            :placeholder="__('zone')" @update:model-value="czOnZone" />
                        <AppSelect class="form-select list-select" v-model="channel" :options="channelOptions"
                            :searchable="false" @update:model-value="onChannelChange" />
                        <AppSelect class="form-select list-select list-select-lg" v-model="status"
                            :options="statusFilterOptions" :searchable="false"
                            @update:model-value="getOrders()" />
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

                    <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getOrders()">
                        <RefreshCw :class="{ 'is-spinning': isLoading }" />
                    </button>
                </div>

                <!-- Filters -->
                <transition name="filter-slide">
                <div v-if="showFilters" class="list-filters">
                    <div class="row g-3">
                        <div class="col-md-3 col-6">
                            <label class="flbl">{{ __('from_to_date') }}</label>
                            <div class="d-flex gap-2">
                                <date-range-picker class="flex-grow-1" v-model="dateRange" :config="datePickerConfig" @update="getOrders" />
                                <button v-if="dateRange" class="btn btn-danger" @click="dateRange = ''; getOrders()">
                                    {{ __('clear') }}
                                </button>
                            </div>
                        </div>
                        <div class="col-md-3 col-6">
                            <label class="flbl">{{ __('sort_by') }}</label>
                            <AppSelect class="form-select" v-model="sort" :options="sortOptions"
                                :searchable="false" @update:model-value="getOrders()" />
                        </div>
                        <div class="col-md-3 col-6">
                            <label class="flbl">{{ __('payment_method') }}</label>
                            <AppSelect class="form-select" v-model="payment_method"
                                :options="paymentMethodOptions" :searchable="false"
                                @update:model-value="getOrders()" />
                        </div>
                        <div class="col-md-3 col-6">
                            <label class="flbl">{{ __('branch') }}</label>
                            <AppSelect class="form-select" v-model="branch" :options="branchOptions"
                                :placeholder="__('all_branches')" @update:model-value="getOrders()" />
                        </div>
                    </div>
                </div>
                </transition>

                <div class="table-responsive">
                    <MazerDatatable responsive="sm" :items="orders" :fields="orderFields"
                        :striped="true" :head-variant="'light'" :busy="isLoading" stacked="md" show-empty small>

                        <template #cell(id)="row">
                            <div class="fw-bold">{{ row.item.order_number || ('#' + String(row.item.id).padStart(5, '0')) }}</div>
                            <small class="text-muted">{{ $filters.formatDateTime(row.item.date) }}</small>
                        </template>

                        <template #cell(user_name)="row">
                            <router-link v-if="row.item.user_id" :to="{ name: 'ViewCustomer', params: { id: row.item.user_id } }"
                                class="text-primary text-decoration-none">{{ row.item.user_name }}</router-link>
                            <div v-else>{{ row.item.user_name }}</div>
                            <small class="text-muted d-block">{{ $filters.mobileMask(row.item.mobile) }}</small>
                        </template>

                        <template #cell(items_preview)="row">
                            <div class="text-truncate" style="max-width:220px">{{ row.item.items_preview || '-' }}</div>
                            <!-- A pickup order is collected at the branch, so that is the place that matters. -->
                            <small class="text-muted">{{ row.item.delivery_type === 'pickup' ? (row.item.branch_name || '') : (row.item.customer_city || '') }}</small>
                        </template>

                        <template #cell(channel)="row">
                            <span class="mode-chip" v-if="row.item.delivery_type === 'pickup'">
                                <PackageCheck :size="14" :color="primaryColor" /> {{ __('self_pickup') }}
                            </span>
                            <span class="mode-chip" v-else>
                                <component :is="row.item.channel === 'quick' ? 'Zap' : 'ShoppingBag'" :size="14" :color="primaryColor" />
                                {{ row.item.channel === 'quick' ? __('quick') : __('ecommerce') }}
                            </span>
                        </template>

                        <template #cell(payment_method)="row">
                            <span class="badge bg-light text-dark border">{{ row.item.payment_method }}</span>
                        </template>

                        <template #cell(final_total)="row">
                            <span>{{ row.item.currency || $currency }}{{ totalPaid(row.item) }}</span>
                        </template>

                        <template #cell(active_status)="row">
                            <span class="badge" :class="getStatusBadgeClass(row.item.active_status)">{{ statusLabel(row.item.active_status, row.item) }}</span>
                        </template>

                        <template #cell(actions)="row">
                            <div class="list-actions">
                                <button class="list-action-btn is-view" v-b-tooltip.hover :title="__('view')" @click="openOrder(row.item.id)">
                                    <Eye :size="15" />
                                </button>
                                <button v-if="$can(row.item.delivery_type === 'pickup' ? 'self_pickup_order_delete' : 'order_delete')" class="list-action-btn is-delete" v-b-tooltip.hover :title="__('delete')" @click="deleteOrder(row.item.id)">
                                    <Trash2 :size="15" />
                                </button>
                            </div>
                        </template>
                    </MazerDatatable>
                </div>

                <div class="list-footer">
                    <div class="list-perpage">
                        <span>{{ __('per_page') }}</span>
                        <b-form-select id="per-page-select" v-model="perPage" :options="pageOptions"
                            size="sm" class="form-select"></b-form-select>
                    </div>

                    <b-pagination v-model="currentPage" :total-rows="totalOrderRows" :per-page="perPage"
                        size="sm" class="mb-0 list-pagination"></b-pagination>
                </div>
            </div>
        </div>

        <OrderDetailSlider v-model="sliderShow" :order-id="activeOrderId" :nav-list="navList" @navigate="onNavigate" @updated="getOrders" />
    </div>
</template>

<script>
import axios from "axios";
import { initEcho, getEcho } from '../../echo.js';
import OrderDetailSlider from './OrderDetailSlider.vue';
import DateRangePicker from '../../components/DateRangePicker.vue';
import RollingNumber from '../../components/RollingNumber.vue';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';
import { buildDateRangeConfig, toApiDate } from '../../utils/dateRange.js';
import { markRaw } from 'vue';
import {
    Search, RefreshCw, SlidersHorizontal, Eye, Trash2, Zap, ShoppingBag, PackageCheck,
    Receipt, Clock, Loader, CircleCheck, CircleX,
} from 'lucide-vue-next';

export default {
    name: "OrdersList",
    mixins: [CountryZoneFilter],
    components: { OrderDetailSlider, DateRangePicker, RollingNumber, Search, RefreshCw, SlidersHorizontal, Eye, Trash2, Zap, ShoppingBag, PackageCheck },
    props: {
        // Each page lists one delivery type: /orders = home delivery, /orders/pickup = self pickup.
        fixedDeliveryType: { type: String, default: 'delivery' },
    },
    data() {
        return {
            czAllowAll: true, // orders show per-row currency → All Countries allowed
            search: "",
            status: "",
            channel: "",
            payment_method: "",
            branch: "",
            dateRange: "",
            datePickerConfig: buildDateRangeConfig({ maxDate: new Date() }),
            sort: "newest",
            showFilters: false,

            orders: [],
            counts: {},
            statuses: [],
            branches: [],
            // Core gateways; an installed payment plugin's gateway is appended at load.
            paymentMethods: ['COD', 'Wallet', 'Razorpay', 'Stripe', 'PayPal', 'PhonePe', 'Cashfree', 'Paystack', 'Midtrans'],
            pluginPaymentMethods: [],

            orderFields: [
                // MazerDatatable treats a missing `sortable` as true, so the columns
                // that shouldn't sort have to opt out explicitly.
                { key: 'id', label: __('order_no'), class: 'text-center' },
                { key: 'user_name', label: __('customer'), sortable: false },
                { key: 'items_preview', label: __('items') + ' / ' + __('address'), sortable: false },
                { key: 'channel', label: __('mode'), class: 'text-center' },
                { key: 'payment_method', label: __('payment'), class: 'text-center', sortable: false },
                { key: 'final_total', label: __('amount'), class: 'text-center' },
                { key: 'active_status', label: __('status'), class: 'text-center' },
                { key: 'actions', label: __('actions'), class: 'text-center', sortable: false },
            ],

            totalOrderRows: 0,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            isLoading: false,

            sliderShow: false,
            activeOrderId: null,
            _debounce: null,
        };
    },
    computed: {
        // Fixed option set — no search box needed.
        channelOptions() {
            return [
                { id: '', name: (__('all_modes')) },
                { id: 'quick', name: (__('quick')) },
                { id: 'ecommerce', name: (__('ecommerce')) },
            ];
        },
        // Fixed option set — no search box needed.
        sortOptions() {
            return [
                { id: 'newest', name: (__('newest_first')) },
                { id: 'oldest', name: (__('oldest_first')) },
                { id: 'amount_high', name: (__('amount_high_to_low')) },
                { id: 'amount_low', name: (__('amount_low_to_high')) },
            ];
        },
        statusFilterOptions() {
            return [{ id: '', name: __('all_statuses') }]
                .concat((this.statuses || []).map(st => ({ id: st.id, name: this.getStatusDisplayName(st) })));
        },
        // Core payment methods are plain strings; AppSelect needs { id, name }. A
        // plugin's gateway already carries both, because what an order records (the
        // gateway code) is not what the filter should read.
        paymentMethodOptions() {
            return [{ id: '', name: __('all_methods') }]
                .concat((this.paymentMethods || []).map(m => ({ id: m, name: m })))
                .concat(this.pluginPaymentMethods || []);
        },
        // AppSelect renders `name`; branch names are translated objects.
        branchOptions() {
            return (this.branches || []).map(s => ({ id: s.id, name: this.getDisplayName(s.name) }));
        },
        primaryColor() { return window.adminThemeColor || '#435ebe'; },
        navList() { return this.orders.map(o => ({ id: o.id })); },
        statCards() {
            return [
                { key: 'total', label: __('total'), icon: markRaw(Receipt), tone: 'total' },
                { key: 'pending', label: __('pending'), icon: markRaw(Clock), tone: 'pending' },
                { key: 'processing', label: __('processing'), icon: markRaw(Loader), tone: 'processing' },
                { key: 'delivered', label: __('delivered'), icon: markRaw(CircleCheck), tone: 'delivered' },
                { key: 'cancelled', label: __('cancelled'), icon: markRaw(CircleX), tone: 'cancelled' },
            ];
        },
    },
    created() {
        this.channel = this.channelFromRoute();
        this.loadStatuses();
        this.getBranches();
        this.loadPluginPaymentMethods();
        this.czLoad(); // sets default country (All) then fetches orders via czOnFilter
    },
    mounted() {
        const oid = this.$route.query.order_id;
        if (oid) this.$nextTick(() => this.openOrder(parseInt(oid, 10)));
        this.subscribeRealtimeOrders();
    },
    beforeUnmount() {
        // Leave the realtime orders channel.
        try { getEcho()?.leave('admin.orders'); } catch (e) { /* noop */ }
    },
    watch: {
        currentPage() { this.getOrders(); },
        perPage() { this.getOrders(); },
        // /orders and /orders/pickup share this instance, so a route change is not a
        // remount — reload the list and the status set for the new page.
        fixedDeliveryType() {
            this.status = "";
            this.currentPage = 1;
            this.loadStatuses();
            this.getOrders();
        },
        // Dashboard links land here with ?channel=quick|ecommerce; same instance, so watch it.
        '$route.query.channel'() {
            const ch = this.channelFromRoute();
            if (ch === this.channel) return;
            this.channel = ch;
            this.currentPage = 1;
            this.loadStatuses();
            this.getOrders();
        },
    },
    methods: {
        channelFromRoute() {
            const ch = this.$route.query.channel;
            return ch === 'quick' || ch === 'ecommerce' ? ch : '';
        },
        totalPaid(o) {
            if (!o) return '0.00';
            const num = v => Number(v || 0);
            const parseList = v => {
                if (Array.isArray(v)) return v;
                if (typeof v === 'string') { try { return JSON.parse(v) || []; } catch (e) { return []; } }
                return [];
            };
            const sub = num(o.sub_total != null ? o.sub_total : o.total);
            const delivery = num(o.delivery_charge);
            const addl = parseList(o.additional_charges).reduce((s, c) => s + num(c.amount != null ? c.amount : c.charge), 0);
            const surge = parseList(o.surge_charges).reduce((s, c) => s + num(c.charge != null ? c.charge : c.amount), 0);
            const promo = num(o.promo_discount);
            return Math.max(0, sub + delivery + addl + surge - promo).toFixed(2);
        },
        // Live new-order updates via Echo (falls back to manual refresh if realtime off).
        subscribeRealtimeOrders() {
            initEcho();
            const echo = getEcho();
            if (!echo) return;
            echo.private('admin.orders').listen('.order.placed', () => {
                if (this.currentPage === 1) {
                    this.getOrders();
                }
            });
        },
        debouncedFetch() {
            clearTimeout(this._debounce);
            this._debounce = setTimeout(() => { this.currentPage = 1; this.getOrders(); }, 400);
        },
        onChannelChange() {
            this.status = "";
            this.loadStatuses();
            this.getOrders();
        },
        loadStatuses() {
            const params = {};
            if (this.channel) params.channel = this.channel;
            params.delivery_type = this.fixedDeliveryType;
            axios.get(this.$apiUrl + '/order_statuses', { params }).then((res) => {
                this.statuses = res.data.data || [];
            }).catch(() => {});
        },
        /**
         * Payment filter: append every installed payment plugin's gateway.
         *
         * The filter matches `orders.payment_method`, and an order records the gateway
         * code the apps send ("payu"), not the plugin's name ("PayU India"), so the code
         * is the option's value and the short payment label is what an admin reads.
         */
        loadPluginPaymentMethods() {
            axios.get(this.$apiUrl + '/countries/plugin_payment_schemas')
                .then(res => {
                    if (res.data.status !== 1) return;
                    (res.data.data.gateways || []).forEach(gw => {
                        if (!gw.code) return;
                        if (this.pluginPaymentMethods.some(m => m.id === gw.code)) return;
                        this.pluginPaymentMethods.push({
                            id: gw.code,
                            name: gw.payment_label || gw.label || gw.code,
                        });
                    });
                })
                .catch(() => { /* filter keeps the core list */ });
        },
        getBranches() {
            axios.get(this.$apiUrl + '/orders', { params: { per_page: 1, page: 1 } }).then((res) => {
                this.branches = res.data.data.branches || [];
            }).catch(() => {});
        },
        // Called by the country/zone mixin (on load + on every change).
        czOnFilter() {
            this.currentPage = 1;
            this.getOrders();
        },
        getOrders() {
            this.isLoading = true;
            const params = {
                search: this.search,
                status: this.status,
                channel: this.channel,
                delivery_type: this.fixedDeliveryType,
                payment_method: this.payment_method,
                branch: this.branch,
                country_id: this.czCountryParam,
                zone_id: this.czZoneParam,
                sort: this.sort,
                page: this.currentPage,
                per_page: this.perPage,
            };
            if (this.dateRange) {
                params.startDate = toApiDate(this.dateRange, 'start');
                params.endDate = toApiDate(this.dateRange, 'end');
            }
            axios.get(this.$apiUrl + '/orders', { params }).then((res) => {
                const d = res.data.data;
                this.orders = d.orders || [];
                this.totalOrderRows = d.orders_total || 0;
                this.counts = d.counts || {};
                if (d.branches && !this.branches.length) this.branches = d.branches;
                this.isLoading = false;
            }).catch((error) => {
                this.isLoading = false;
                this.showError(error?.message || __('something_went_wrong'));
            });
        },
        openOrder(id) {
            this.activeOrderId = id;
            this.sliderShow = true;
        },
        onNavigate(entry) {
            this.activeOrderId = entry.id;
        },
        deleteOrder(id) {
            this.$swal.fire({
                title: __('are_you_sure'), text: __('you_want_be_able_to_revert_this'), icon: 'warning',
                showCancelButton: true, confirmButtonText: __('yes_sure'), cancelButtonText: __('cancel'),
                confirmButtonColor: window.adminThemeColor || '#435ebe', cancelButtonColor: '#d33',
            }).then(result => {
                if (!result.value) return;
                axios.post(this.$apiUrl + '/orders/delete', { id }).then((res) => {
                    this.showSuccess(res.data.message);
                    this.getOrders();
                });
            });
        },
        formatDate(dt) {
            if (!dt) return '';
            const d = new Date(dt);
            return d.toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' });
        },
        getDisplayName(name) {
            if (name == null) return '';
            if (typeof name === 'string') return name;
            if (typeof name === 'object' && !Array.isArray(name)) {
                const loc = window.appLocale || window.localStorage.getItem('lang') || 'en';
                const v = name[loc] || Object.values(name).find(x => x && String(x).trim() !== '');
                return v ? String(v).trim() : '';
            }
            return '';
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
        statusLabel(id, order = null) {
            // Nobody "delivers" a pickup order; the customer collected it.
            if (order && order.delivery_type === 'pickup' && Number(id) === 6) return this.__('collected');
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
/* Tinted card + solid icon tile, label above the count. Each tone sets a single
   --tone colour; the card washes it, the tile uses it solid. */
.stat-card {
    display: flex;
    align-items: center;
    gap: .75rem;
    height: 100%;
    padding: .9rem 1rem;
    border: 0;
    border-radius: 12px;
    background: color-mix(in srgb, var(--tone) 10%, transparent);
}
.stat-icon {
    width: 42px;
    height: 42px;
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 10px;
    background: var(--tone);
    color: #fff;
}
.stat-meta { min-width: 0; }
.stat-label {
    font-size: .78rem;
    font-weight: 500;
    line-height: 1.2;
    color: var(--app-muted);
}
.stat-num {
    font-size: 1.25rem;
    font-weight: 700;
    line-height: 1.3;
    color: var(--app-ink);
}

.stat-card.tone-total { --tone: #3b82f6; }
.stat-card.tone-pending { --tone: #f59e0b; }
.stat-card.tone-processing { --tone: #06b6d4; }
.stat-card.tone-delivered { --tone: #22c55e; }
.stat-card.tone-cancelled { --tone: #ef4444; }

/* color-mix is unsupported on older Safari/Firefox — fall back to a flat surface
   so the cards never render transparent. */
@supports not (background: color-mix(in srgb, red 10%, transparent)) {
    .stat-card {
        background: var(--app-card-bg);
        border: 1px solid var(--app-card-border);
    }
}
.sort-select { width: auto; min-width: 160px; }
.flbl { font-size: .72rem; color: #6c757d; margin-bottom: .2rem; display: block; }
/* .mode-chip now lives in common.css — shared with the dashboard's recent orders. */
.gap-2 { gap: .5rem; }
</style>