<template>
    <div class="page-heading">
        <div class="page-title">
            <div class="row align-items-center">
                <div class="col-12 d-flex align-items-center gap-2 justify-content-end flex-wrap">
                    <button class="btn btn-sm btn-outline-secondary d-inline-flex align-items-center gap-1" @click="$router.back()">
                        <ArrowLeft :size="14" /> {{ __('back') }}
                    </button>
                </div>
            </div>
        </div>

        <div v-if="isLoading" class="text-center py-5"><b-spinner></b-spinner></div>

        <template v-else-if="user">
            <!-- Header -->
            <div class="card cust-header mb-3">
                <div class="card-body">
                    <div class="d-flex flex-wrap align-items-start gap-3">
                        <div class="cust-avatar">
                            <img v-if="user.profile" :src="user.profile_url" :alt="user.name" />
                            <template v-else>{{ initials }}</template>
                        </div>
                        <div class="flex-grow-1">
                            <div class="d-flex align-items-center gap-2 flex-wrap">
                                <h4 class="mb-0 fw-bold">{{ user.name || '—' }}</h4>
                                <span class="status-pill" :class="user.status === 1 ? 'is-active' : 'is-inactive'">
                                    {{ user.status === 1 ? __('active') : __('inactive') }}
                                </span>
                            </div>
                            <!-- Contact details below the name -->
                            <div class="small mt-2 d-flex flex-wrap align-items-center gap-2">
                                <span v-if="user.mobile" class="d-inline-flex align-items-center gap-1"><Smartphone :size="14" /> {{ user.country_code }} {{ $filters.mobileMask(user.mobile) }}</span>
                                <span v-if="user.email" class="d-inline-flex align-items-center gap-1"><Mail :size="14" /> {{ $filters.emailMask(user.email) }}</span>
                            </div>
                            <div class="small">{{ __('customer_since') }} {{ $filters.formatDateTime(user.created_at) }} · ID #{{ user.id }}</div>
                        </div>
                        <!-- Country / zone filters sit just left of the status toggle. -->
                        <div class="cz-filters d-flex align-items-center gap-2 flex-wrap ms-auto align-self-center"
                            v-if="czShowCountry || czShowZoneDropdown">
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
                        </div>
                        <div class="d-flex flex-column align-items-start align-self-center" v-if="$can('order_list')">
                            <div class="status-toggle" :class="user.status === 1 ? 'on' : 'off'">
                                <div class="form-check form-switch m-0 p-0 d-flex align-items-center gap-2">
                                    <input class="form-check-input m-0" type="checkbox" role="switch"
                                        :checked="user.status === 1" :disabled="isSavingStatus" @change="toggleStatus">
                                    <b-spinner v-if="isSavingStatus" small></b-spinner>
                                    <span v-else class="status-text">{{ user.status === 1 ? __('active') : __('deactive') }}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Stat cards -->
            <div class="row g-3 mb-3 justify-content-start">
                <!-- Gradual wrap: 2/row (xs) → 3/row (sm) → 4/row (lg) → 6/row (xl+). -->
                <div class="col-6 col-sm-4 col-lg-3 col-xl-2" v-for="c in statCards" :key="c.key">
                    <div class="stat-card">
                        <span class="stat-icon" :class="'tone-' + c.key"><component :is="c.icon" :size="20" /></span>
                        <div class="stat-meta">
                            <div class="stat-label">{{ c.label }}</div>
                            <div class="stat-num" :class="{ 'stat-num-sm': c.key === 'last' }">{{ c.value }}</div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Tabs -->
            <ul class="nav nav-tabs cust-tabs mb-3">
                <li class="nav-item" v-for="t in tabs" :key="t.key">
                    <a class="nav-link d-inline-flex align-items-center gap-1" :class="{ active: tab === t.key }" href="#" @click.prevent="tab = t.key">
                        <component :is="t.icon" :size="15" /> {{ t.label }}
                    </a>
                </li>
            </ul>

            <!-- Orders -->
            <div v-if="tab === 'orders'" class="list-surface">
                <div class="table-responsive">
                    <table class="table align-middle mb-0">
                        <thead>
                            <tr>
                                <th>{{ __('order_no') }}</th>
                                <th>{{ __('items') }}</th>
                                <th>{{ __('mode') }}</th>
                                <th>{{ __('amount') }}</th>
                                <th>{{ __('payment') }}</th>
                                <th>{{ __('status') }}</th>
                                <th>{{ __('date') }}</th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-if="!orders.length"><td colspan="8" class="text-center py-4 text-muted">{{ __('no_records_found') }}</td></tr>
                            <tr v-for="o in pagedOrders" :key="o.id">
                                <td class="fw-bold">{{ o.order_number || ('#' + String(o.id).padStart(5, '0')) }}</td>
                                <td style="max-width:260px">
                                    <span v-for="(it, i) in itemChips(o.items_preview)" :key="i" class="item-chip">{{ it }}</span>
                                    <span v-if="extraCount(o.items_preview) > 0" class="text-muted small"> +{{ extraCount(o.items_preview) }}</span>
                                </td>
                                <td>
                                    <span class="mode-chip">
                                        <component :is="o.channel === 'quick' ? 'Zap' : 'ShoppingBag'" :size="14" :color="primaryColor" />
                                        {{ o.channel === 'quick' ? __('quick') : __('ecommerce') }}
                                    </span>
                                </td>
                                <td class="fw-bold">{{ o.currency || cur }}{{ o.final_total }}</td>
                                <td><span class="badge bg-light text-dark border">{{ o.payment_method }}</span></td>
                                <td><span class="badge" :class="getStatusBadgeClass(o.active_status)">{{ statusLabel(o.active_status) }}</span></td>
                                <td class="small">{{ formatDate(o.created_at) }}</td>
                                <td>
                                    <button class="list-action-btn is-view" v-b-tooltip.hover :title="__('view')" @click="openOrder(o.id)">
                                        <Eye :size="15" />
                                    </button>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
                <div v-if="orders.length > perPage" class="d-flex justify-content-end p-2">
                    <b-pagination v-model="ordersPage" :total-rows="orders.length" :per-page="perPage" size="sm" class="mb-0"></b-pagination>
                </div>
            </div>

            <!-- Addresses -->
            <div v-else-if="tab === 'addresses'" class="card"><div class="card-body">
                <div class="row g-3 justify-content-start">
                    <div class="col-md-4 col-sm-6" v-for="a in addresses" :key="a.id">
                        <div class="addr-card" :style="a.is_default == 1 ? { borderColor: primaryColor, background: primaryColor + '14' } : {}">
                            <div class="d-flex justify-content-between align-items-start">
                                <span class="addr-type">{{ a.type }}</span>
                                <span class="d-flex align-items-center gap-1">
                                    <span v-if="a.is_default == 1" class="badge bg-primary">{{ __('default') }}</span>
                                    <a :href="a.latitude && a.longitude ? `https://www.google.com/maps?q=${a.latitude},${a.longitude}` : null"
                                        :class="{ disabled: !(a.latitude && a.longitude) }" target="_blank" class="addr-pin d-inline-flex" :title="__('delivery_location')"><MapPin :size="16" /></a>
                                </span>
                            </div>
                            <div class="fw-bold mt-1">{{ a.name }}</div>
                            <div class="addr-mobile">{{ a.country_code }} {{ $filters.mobileMask(a.mobile) }}</div>
                            <div class="addr-mobile" v-if="a.alternate_mobile">{{ a.alternate_country_code || a.country_code }} {{ a.alternate_mobile }}</div>
                            <div class="addr-text">{{ a.address }}<template v-if="a.landmark">, {{ a.landmark }}</template>, {{ a.area }}, {{ a.city }}, {{ a.state }}, {{ a.country }} - {{ a.pincode }}</div>
                            <!-- Business buyer: the name it is billed in and the registration
                                 number that makes its invoice claimable. -->
                        </div>
                    </div>
                    <div v-if="!addresses.length" class="col-12 text-center text-muted py-4">{{ __('no_records_found') }}</div>
                </div>
            </div></div>

            <!-- Analytics -->
            <div v-else-if="tab === 'analytics'">
                <!-- Status breakdown -->
                <div class="card mb-3"><div class="card-body">
                    <h6 class="fw-bold mb-3">{{ __('order_status_breakdown') }}</h6>
                    <div class="row g-3 justify-content-start">
                        <div class="col-md-6" v-for="s in (analytics.status_breakdown || [])" :key="s.id">
                            <div class="sb-row">
                                <div class="d-flex justify-content-between">
                                    <span class="small">{{ s.name }}</span>
                                    <b class="small">{{ s.count }}</b>
                                </div>
                                <div class="sb-bar"><div class="sb-fill" :style="{ width: barPct(s.count) + '%', background: statusColor(s.id) }"></div></div>
                            </div>
                        </div>
                    </div>
                </div></div>

                <!-- Quick vs eCommerce order counts -->
                <div class="row g-3 mb-3 justify-content-start">
                    <div class="col-md-6">
                        <div class="card"><div class="card-body d-flex align-items-center justify-content-between">
                            <span class="mode-chip"><Zap :size="14" :color="primaryColor" /> {{ __('quick') }}</span>
                            <h3 class="mb-0 fw-bold">{{ analytics.quick_orders || 0 }} <span class="fs-6 fw-semibold text-muted">{{ __('orders') }}</span></h3>
                        </div></div>
                    </div>
                    <div class="col-md-6">
                        <div class="card"><div class="card-body d-flex align-items-center justify-content-between">
                            <span class="mode-chip"><ShoppingBag :size="14" :color="primaryColor" /> {{ __('ecommerce') }}</span>
                            <h3 class="mb-0 fw-bold">{{ analytics.ecommerce_orders || 0 }} <span class="fs-6 fw-semibold text-muted">{{ __('orders') }}</span></h3>
                        </div></div>
                    </div>
                </div>

                <!-- Monthly orders (current year) -->
                <div class="card"><div class="card-body">
                    <h6 class="fw-bold mb-2">{{ __('orders') }} — {{ analytics.year }}</h6>
                    <apexchart type="bar" height="300" :options="ordersChartOptions" :series="ordersSeries"></apexchart>
                </div></div>
            </div>

            <!-- Transactions -->
            <div v-else-if="tab === 'transactions'" class="list-surface">
                <div class="table-responsive">
                    <table class="table align-middle mb-0">
                        <thead><tr>
                            <th>{{ __('order_no') }}</th><th>{{ __('type') }}</th><th>{{ __('amount') }}</th>
                            <th>{{ __('status') }}</th><th>{{ __('message') }}</th><th>{{ __('date') }}</th>
                        </tr></thead>
                        <tbody>
                            <tr v-if="!transactions.length"><td colspan="6" class="text-center py-4 text-muted">{{ __('no_records_found') }}</td></tr>
                            <tr v-for="t in pagedTransactions" :key="t.id">
                                <td>{{ t.order_number || (t.order_id ? '#' + t.order_id : '—') }}</td>
                                <td>{{ t.type }}</td>
                                <td class="fw-bold">{{ cur }}{{ t.amount }}</td>
                                <td><span class="badge" :class="t.status === 'success' ? 'bg-success' : (t.status === 'failed' ? 'bg-danger' : 'bg-secondary')">{{ t.status }}</span></td>
                                <td class="small">{{ t.message }}</td>
                                <td class="small">{{ $filters.formatDateTime(t.date) }}</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
                <div v-if="transactions.length > perPage" class="d-flex justify-content-end p-2">
                    <b-pagination v-model="txnPage" :total-rows="transactions.length" :per-page="perPage" size="sm" class="mb-0"></b-pagination>
                </div>
            </div>

            <!-- Wallet Transactions -->
            <div v-else-if="tab === 'wallet_transactions'" class="list-surface">
                <div class="table-responsive">
                    <table class="table align-middle mb-0">
                        <thead><tr>
                            <th>{{ __('order_no') }}</th><th>{{ __('type') }}</th><th>{{ __('amount') }}</th>
                            <th>{{ __('message') }}</th><th>{{ __('date') }}</th>
                        </tr></thead>
                        <tbody>
                            <tr v-if="!walletTransactions.length"><td colspan="5" class="text-center py-4 text-muted">{{ __('no_records_found') }}</td></tr>
                            <tr v-for="t in pagedWalletTransactions" :key="t.id">
                                <td>{{ t.order_number || (t.order_id ? '#' + t.order_id : '—') }}</td>
                                <td><span class="badge" :class="t.type === 'credit' ? 'bg-success' : 'bg-danger'">{{ t.type }}</span></td>
                                <td class="fw-bold" :class="t.type === 'credit' ? 'text-success' : 'text-danger'">{{ t.type === 'credit' ? '+' : '-' }}{{ cur }}{{ t.amount }}</td>
                                <td class="small">{{ t.message }}</td>
                                <td class="small">{{ $filters.formatDateTime(t.date) }}</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
                <div v-if="walletTransactions.length > perPage" class="d-flex justify-content-end p-2">
                    <b-pagination v-model="walletTxnPage" :total-rows="walletTransactions.length" :per-page="perPage" size="sm" class="mb-0"></b-pagination>
                </div>
            </div>
        </template>

        <OrderDetailSlider v-model="sliderShow" :order-id="activeOrderId" @updated="getCustomer" />
    </div>
</template>

<script>
import axios from "axios";
import { markRaw } from 'vue';
import VueApexCharts from 'vue3-apexcharts';
import OrderDetailSlider from '../Orders/OrderDetailSlider.vue';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';
import {
    ArrowLeft, Smartphone, Mail, MapPin, Zap, ShoppingBag, Eye,
    ShoppingCart, CircleCheck, DollarSign, Calculator, Wallet, Clock, BarChart3, Receipt,
} from 'lucide-vue-next';

export default {
    name: 'ViewCustomer',
    mixins: [CountryZoneFilter],
    components: {
        OrderDetailSlider, apexchart: VueApexCharts,
        ArrowLeft, Smartphone, Mail, MapPin, Zap, ShoppingBag, Eye,
    },
    data() {
        return {
            id: this.$route.params.id,
            isLoading: false,
            isSavingStatus: false,
            user: null,
            stats: {},
            orders: [],
            addresses: [],
            transactions: [],
            walletTransactions: [],
            analytics: {},
            statusModel: 1,
            tab: 'orders',
            sliderShow: false,
            activeOrderId: null,
            // Client-side pagination for the orders / transactions tabs.
            perPage: 10,
            ordersPage: 1,
            txnPage: 1,
            walletTxnPage: 1,
        };
    },
    computed: {
        primaryColor() { return window.adminThemeColor || '#435ebe'; },
        pagedOrders() {
            const start = (this.ordersPage - 1) * this.perPage;
            return this.orders.slice(start, start + this.perPage);
        },
        pagedTransactions() {
            const start = (this.txnPage - 1) * this.perPage;
            return this.transactions.slice(start, start + this.perPage);
        },
        pagedWalletTransactions() {
            const start = (this.walletTxnPage - 1) * this.perPage;
            return this.walletTransactions.slice(start, start + this.perPage);
        },
        cur() { return this.stats.currency || this.$currency; },
        initials() {
            const n = (this.user && this.user.name) ? this.user.name.trim() : '';
            if (!n) return '?';
            return n.split(/\s+/).slice(0, 2).map(w => w[0]).join('').toUpperCase();
        },
        statCards() {
            return [
                { key: 'orders', icon: markRaw(ShoppingCart), value: this.stats.total_orders || 0, label: __('total_orders') },
                { key: 'delivered', icon: markRaw(CircleCheck), value: this.stats.delivered || 0, label: __('delivered') },
                { key: 'spent', icon: markRaw(DollarSign), value: this.cur + (this.stats.total_spent || 0), label: __('total_spent') },
                { key: 'avg', icon: markRaw(Calculator), value: this.cur + (this.stats.avg_order_value || 0), label: __('avg_order_value') },
                { key: 'wallet', icon: markRaw(Wallet), value: this.cur + (this.stats.wallet_balance || 0), label: __('wallet_balance') },
                { key: 'last', icon: markRaw(Clock), value: this.stats.last_order_date || '—', label: __('last_order') },
            ];
        },
        tabs() {
            return [
                { key: 'orders', icon: markRaw(ShoppingCart), label: __('orders') + ' (' + (this.stats.total_orders || 0) + ')' },
                { key: 'addresses', icon: markRaw(MapPin), label: __('addresses') + ' (' + this.addresses.length + ')' },
                { key: 'analytics', icon: markRaw(BarChart3), label: __('analytics') },
                { key: 'transactions', icon: markRaw(Receipt), label: __('order_transactions') },
                { key: 'wallet_transactions', icon: markRaw(Wallet), label: __('wallet_transactions') },
            ];
        },
        ordersSeries() {
            return [{ name: __('orders'), data: this.analytics.monthly_orders || [] }];
        },
        ordersChartOptions() {
            const revenue = this.analytics.monthly_revenue || [];
            const cur = this.cur;
            return {
                chart: { toolbar: { show: false } },
                colors: [this.primaryColor],
                plotOptions: { bar: { borderRadius: 4, columnWidth: '55%' } },
                dataLabels: { enabled: false },
                xaxis: { categories: this.analytics.months || [] },
                grid: { borderColor: '#eef0f4' },
                tooltip: {
                    // Show order count + amount for the hovered month.
                    y: {
                        formatter: (val, opts) => {
                            const amt = revenue[opts.dataPointIndex] ?? 0;
                            return `${val} ${__('orders_count')} · ${cur}${amt}`;
                        },
                        title: { formatter: () => '' },
                    },
                },
            };
        },
    },
    created() {
        this.czLoad();
    },
    methods: {
        czOnFilter() { this.getCustomer(); },
        getCustomer() {
            this.isLoading = !this.user;
            const params = {
                country_id: this.czCountryParam,
                zone_id: this.czZoneParam,
            };
            axios.get(this.$apiUrl + '/customers/' + this.id, { params }).then((res) => {
                this.isLoading = false;
                const d = res.data;
                if (d.status === 1) {
                    this.user = d.data.user;
                    this.stats = d.data.stats || {};
                    this.orders = d.data.orders || [];
                    this.addresses = d.data.addresses || [];
                    this.transactions = d.data.transactions || [];
                    this.walletTransactions = d.data.wallet_transactions || [];
                    this.ordersPage = 1;
                    this.txnPage = 1;
                    this.walletTxnPage = 1;
                    this.analytics = d.data.analytics || {};
                    this.statusModel = this.user.status;
                } else {
                    this.showError(d.message);
                    this.$router.back();
                }
            }).catch(() => {
                this.isLoading = false;
                this.showError(__('something_went_wrong'));
            });
        },
        // Toggle switch in the header — flips status and persists immediately.
        toggleStatus(e) {
            const newStatus = e.target.checked ? 1 : 0;
            // Confirm before changing — the switch flipped optimistically, so revert
            // it if the admin backs out.
            this.$swal.fire({
                title: __('are_you_sure'),
                text: newStatus === 1 ? __('activate_this_customer') : __('deactivate_this_customer'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: __('yes'),
                cancelButtonText: __('cancel'),
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (!result.value) {
                    e.target.checked = this.user.status === 1;
                    return;
                }
                this.statusModel = newStatus;
                this.isSavingStatus = true;
                axios.post(this.$apiUrl + '/customers/set_status', { id: this.id, status: newStatus }).then((res) => {
                    this.isSavingStatus = false;
                    if (res.data.status === 1) { this.showMessage('success', res.data.message); this.user.status = newStatus; }
                    else { this.showError(res.data.message); e.target.checked = this.user.status === 1; }
                }).catch(() => {
                    this.isSavingStatus = false;
                    e.target.checked = this.user.status === 1;
                    this.showError(__('something_went_wrong'));
                });
            });
        },
        openOrder(id) { this.activeOrderId = id; this.sliderShow = true; },
        barPct(count) {
            const max = Math.max(1, ...((this.analytics.status_breakdown || []).map(s => s.count)));
            return Math.round((count / max) * 100);
        },
        itemChips(preview) {
            if (!preview) return [];
            return preview.split(',').map(s => s.trim()).filter(Boolean).slice(0, 2);
        },
        extraCount(preview) {
            if (!preview) return 0;
            return Math.max(0, preview.split(',').filter(s => s.trim()).length - 2);
        },
        formatDate(dt) {
            if (!dt) return '';
            const d = new Date(dt);
            return d.toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' });
        },
        statusLabel(id) {
            const all = { 1: 'payment_pending', 2: 'received', 3: 'processed', 4: 'shipped', 5: 'outForDelivery', 6: 'delivered', 7: 'cancelled', 8: 'returned', 9: 'preparing', 10: 'ready_for_pickup', 11: 'picked_up' };
            return all[Number(id)] ? this.__(all[Number(id)]) : String(id ?? '');
        },
        // Same per-status palette as the dashboard status bars.
        statusColor(id) {
            const map = { 1: '#f59e0b', 2: this.primaryColor, 3: '#6366f1', 4: '#3b82f6', 5: '#14b8a6', 6: '#10b981', 7: '#ef4444', 8: '#8b5cf6', 9: '#f97316', 10: '#06b6d4', 11: '#a855f7' };
            return map[Number(id)] || '#94a3b8';
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
.cust-header .cust-avatar {
    width: 64px; height: 64px; border-radius: 50%; background: var(--bs-primary); color: #fff;
    display: flex; align-items: center; justify-content: center; font-size: 1.4rem; font-weight: 700;
    overflow: hidden; flex-shrink: 0;
}
.cust-header .cust-avatar img { width: 100%; height: 100%; object-fit: cover; }
/* Horizontal stat card — icon chip left, label + big number right (matches delivery-boy view). */
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
.stat-icon.tone-delivered { background: rgba(22, 163, 74, .12); color: #16a34a; }
.stat-icon.tone-spent { background: rgba(245, 158, 11, .14); color: #d97706; }
.stat-icon.tone-avg { background: rgba(124, 58, 237, .12); color: #7c3aed; }
.stat-icon.tone-wallet { background: rgba(6, 182, 212, .12); color: #0891b2; }
.stat-icon.tone-last { background: rgba(100, 116, 139, .14); color: #64748b; }
.stat-meta { min-width: 0; }
.stat-num { font-size: 1.3rem; font-weight: 800; line-height: 1.15; color: var(--app-ink); }
.stat-num-sm { font-size: .9rem; font-weight: 700; }
.stat-label { font-size: .68rem; letter-spacing: .04em; text-transform: uppercase; color: var(--app-muted); }
.cust-tabs .nav-link { color: var(--app-muted); font-weight: 600; }
.cust-tabs .nav-link.active { color: var(--bs-primary); }
.item-chip {
    display: inline-block; background: var(--app-thead-bg); border: 1px solid var(--app-card-border); border-radius: 1rem;
    padding: .1rem .6rem; font-size: .75rem; margin: .1rem .2rem .1rem 0; color: var(--app-ink);
}
.addr-card { border: 1px solid var(--app-card-border); border-radius: .6rem; padding: .9rem 1rem; height: 100%; background: var(--app-card-bg); text-align: left; }
.addr-type { font-size: .72rem; letter-spacing: .05em; text-transform: uppercase; color: var(--app-muted); font-weight: 700; }
.addr-mobile { font-size: .8rem; color: var(--app-muted); }
.addr-text { font-size: .82rem; color: var(--app-muted); margin-top: .35rem; }
.addr-pin { text-decoration: none; color: var(--bs-primary); }
.addr-pin.disabled { opacity: .35; pointer-events: none; }
.sb-row { padding: .15rem 0; }
.sb-bar { height: 8px; background: var(--app-thead-bg); border-radius: 4px; margin-top: .25rem; overflow: hidden; }
.sb-fill { height: 100%; background: var(--bs-primary); border-radius: 4px; transition: width .3s; }
.gap-1 { gap: .25rem; } .gap-2 { gap: .5rem; } .gap-3 { gap: 1rem; }

/* Pill status toggle — same as the delivery-boy dashboard. */
.status-toggle { display: inline-flex; align-items: center; padding: 6px 14px; border-radius: 20px; }
.status-toggle.on { background: rgba(16, 185, 129, .12); color: #059669; }
.status-toggle.off { background: rgba(239, 68, 68, .12); color: #dc2626; }
.status-toggle .status-text { font-size: .78rem; font-weight: 600; }
.status-toggle .form-check-input { cursor: pointer; margin-left: 0 !important; }
.status-toggle.on .form-check-input:checked { background-color: #059669; border-color: #059669; }
.status-toggle .form-check-input:focus { box-shadow: none; }

/* Phones: same treatment as the dashboard tiles — smaller icon, 17px figure, lighter weight. */
@media (max-width: 575.98px) {
    .stat-card { padding: .65rem .7rem; gap: .55rem; }
    .stat-icon { width: 34px; height: 34px; border-radius: 9px; }
    .stat-icon svg { width: 16px; height: 16px; }
    .stat-label { font-size: .62rem; }
    .stat-num { font-size: 17px; font-weight: 600; }
    .stat-num-sm { font-size: .8rem; font-weight: 600; }
}
</style>
