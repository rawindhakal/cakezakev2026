<template>
    <div class="db-dash">
        <!-- ===== Welcome ===== -->
        <div class="d-flex align-items-start justify-content-between flex-wrap gap-2 mb-3">
            <div>
                <h3 class="mb-0 fw-bold welcome-h">{{ __('welcome') }}, {{ d.profile.name || '—' }}</h3>
                <div class="welcome-sub">{{ greeting }} • {{ today }}</div>
            </div>

            <!-- Own status toggle (moved out of the header). 1 = active, 3 = deactivated. -->
            <div class="status-toggle" :class="isActive ? 'on' : 'off'">
                <div class="form-check form-switch m-0 p-0 d-flex align-items-center gap-2">
                    <input class="form-check-input m-0" type="checkbox" role="switch"
                        :true-value="1" :false-value="3"
                        v-model="boyStatus" :disabled="statusLoading" @change="toggleStatus">
                    <b-spinner v-if="statusLoading" small></b-spinner>
                    <span v-else class="status-text">{{ isActive ? __('active') : __('deactive') }}</span>
                </div>
            </div>
        </div>

        <!-- ===== Today ===== -->
        <div class="row g-3 mb-1">
            <div class="col-6 col-lg-3" v-for="t in todayCards" :key="t.key">
                <div class="card today-card h-100">
                    <div class="card-body d-flex align-items-center gap-3">
                        <span class="today-ic" :style="{ background: t.color }"><component :is="t.icon" /></span>
                        <div class="min-w-0">
                            <div class="today-label">{{ t.label }}</div>
                            <div class="today-value"><RollingNumber :value="t.value" /></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- ===== Wallet + Cash ===== -->
        <div class="row g-3 mt-1">
            <div class="col-12 col-lg-6">
                <div class="card h-100 wallet-card">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-start">
                            <div>
                                <div class="wallet-label">{{ __('wallet_balance') }}</div>
                                <div class="wallet-value"><RollingNumber :value="money(d.wallet.balance)" /></div>
                                <div class="wallet-sub">{{ __('available_to_withdraw') }}: <b>{{ money(d.wallet.available) }}</b></div>
                            </div>
                            <span class="wallet-ic"><component :is="icon.wallet" /></span>
                        </div>
                        <div class="wallet-grid mt-3">
                            <div v-for="w in walletRows" :key="w.key">
                                <div class="tiny text-muted">{{ w.label }}</div>
                                <strong :style="{ color: w.color }">{{ money(w.value) }}</strong>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12 col-lg-6">
                <div class="card h-100">
                    <div class="card-body d-flex flex-column">
                        <div class="dash-card-title">{{ __('cash_collection') }}</div>
                        <div class="dash-card-sub">{{ __('cod_cash_lifecycle') }}</div>
                        <div class="cash-hero my-2">
                            <span class="cash-ic" :style="tint('#f59e0b')"><component :is="icon.cash" /></span>
                            <div>
                                <div class="cash-num"><RollingNumber :value="money(d.cash.in_hand)" /></div>
                                <div class="tiny text-muted">{{ __('cash_in_hand') }}</div>
                            </div>
                        </div>
                        <div class="mt-auto">
                            <div class="d-flex justify-content-between small mb-1">
                                <span class="text-muted">{{ __('deposited') }}</span>
                                <strong>{{ money(d.cash.total_deposited) }} / {{ money(d.cash.total_collected) }}</strong>
                            </div>
                            <div class="track"><span :style="{ width: pct(d.cash.total_deposited, d.cash.total_collected) + '%', background: '#10b981' }"></span></div>
                            <div class="tiny text-muted mt-1">{{ __('total_collected') }} {{ money(d.cash.total_collected) }}</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- ===== Earnings trend + Order status ===== -->
        <div class="row g-3 mt-1">
            <div class="col-12 col-xl-8">
                <div class="card h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-start flex-wrap gap-2">
                            <div>
                                <div class="dash-card-title">{{ __('earnings_trend') }}</div>
                                <div class="dash-card-sub">
                                    {{ trendLabel }} · <b>{{ money(d.earnings_trend.total) }}</b>
                                </div>
                            </div>
                            <AppSelect class="form-select form-select-sm trend-select" v-model="trend" :options="trendOptions" :searchable="false" @update:model-value="load" />
                        </div>
                        <apexchart type="area" height="300" :options="trendOptions" :series="trendSeries"></apexchart>
                    </div>
                </div>
            </div>
            <div class="col-12 col-xl-4">
                <div class="card h-100">
                    <div class="card-body d-flex flex-column">
                        <div class="dash-card-title">{{ __('order_status') }}</div>
                        <div class="dash-card-sub">{{ __('assigned_to_you') }}</div>
                        <div class="status-bars mt-2">
                            <div class="status-bar" v-for="s in d.status_breakdown" :key="s.status_id">
                                <span class="status-ic" :style="tint(statusColor(s.status_id))"><component :is="statusIcon(s.status_id)" /></span>
                                <div class="flex-grow-1">
                                    <div class="d-flex justify-content-between">
                                        <span class="small">{{ s.name }}</span>
                                        <strong class="small">{{ num(s.count) }}</strong>
                                    </div>
                                    <div class="track"><span :style="{ width: barW(s.count) + '%', background: statusColor(s.status_id) }"></span></div>
                                </div>
                            </div>
                        </div>

                        <!-- Channel split of the assigned orders. Sits directly under the bars
                             (no mt-auto) so it isn't pushed to the bottom of the stretched card. -->
                        <div class="mt-3 pt-2 split-row">
                            <div class="split-title">{{ __('commerce_mode') }}</div>
                            <div class="d-flex justify-content-between small">
                                <span><span class="dot" :style="{ background: primary }"></span> {{ __('quick') }}</span>
                                <strong>{{ num(d.orders.quick) }}</strong>
                            </div>
                            <div class="track mt-1"><span :style="{ width: pct(d.orders.quick, d.orders.total) + '%', background: primary }"></span></div>
                            <div class="d-flex justify-content-between small mt-2">
                                <span><span class="dot" style="background:#10b981"></span> {{ __('ecommerce') }}</span>
                                <strong>{{ num(d.orders.ecommerce) }}</strong>
                            </div>
                            <div class="track mt-1"><span :style="{ width: pct(d.orders.ecommerce, d.orders.total) + '%', background: '#10b981' }"></span></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- ===== Orders / Returns / Salary ===== -->
        <div class="row g-3 mt-1">
            <div class="col-12 col-md-6 col-xl-4">
                <div class="card h-100">
                    <div class="card-body d-flex flex-column">
                        <div class="dash-card-title">{{ __('orders') }}</div>
                        <div class="dash-card-sub">{{ __('all_time') }}</div>
                        <div class="stat-grid mt-2">
                            <div v-for="o in orderRows" :key="o.key">
                                <strong :style="{ color: o.color }">{{ num(o.value) }}</strong>
                                <div class="tiny text-muted">{{ o.label }}</div>
                            </div>
                        </div>

                        <!-- Fills the card: performance rates derived from the same counts. -->
                        <div class="rate-block mt-3">
                            <div class="d-flex justify-content-between small">
                                <span class="text-muted">{{ __('delivery_success_rate') }}</span>
                                <strong style="color:#10b981">{{ successRate }}%</strong>
                            </div>
                            <div class="track mt-1"><span :style="{ width: successRate + '%', background: '#10b981' }"></span></div>

                            <div class="d-flex justify-content-between small mt-3">
                                <span class="text-muted">{{ __('cancellation_rate') }}</span>
                                <strong style="color:#ef4444">{{ cancelRate }}%</strong>
                            </div>
                            <div class="track mt-1"><span :style="{ width: cancelRate + '%', background: '#ef4444' }"></span></div>

                            <div class="d-flex justify-content-between small mt-3">
                                <span class="text-muted">{{ __('in_progress') }}</span>
                                <strong style="color:#3b82f6">{{ activeRate }}%</strong>
                            </div>
                            <div class="track mt-1"><span :style="{ width: activeRate + '%', background: '#3b82f6' }"></span></div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12 col-md-6 col-xl-4">
                <div class="card h-100">
                    <div class="card-body d-flex flex-column">
                        <div class="dash-card-title">{{ __('return_requests') }}</div>
                        <div class="dash-card-sub">{{ __('assigned_to_you') }}</div>
                        <div class="cash-hero my-2">
                            <span class="cash-ic" :style="tint('#8b5cf6')"><component :is="icon.ret" /></span>
                            <div>
                                <div class="cash-num"><RollingNumber :value="num(d.returns.total)" /></div>
                                <div class="tiny text-muted">{{ __('total') }}</div>
                            </div>
                        </div>
                        <!-- Only the return statuses a delivery boy handles. -->
                        <div class="status-bars status-bars--sm">
                            <div class="status-bar" v-for="r in d.returns.breakdown" :key="r.status_id">
                                <span class="status-ic" :style="tint(returnColor(r.status_id))"><component :is="returnIcon(r.status_id)" /></span>
                                <div class="flex-grow-1">
                                    <div class="d-flex justify-content-between">
                                        <span class="small">{{ r.name }}</span>
                                        <strong class="small">{{ num(r.count) }}</strong>
                                    </div>
                                    <div class="track"><span :style="{ width: retBarW(r.count) + '%', background: returnColor(r.status_id) }"></span></div>
                                </div>
                            </div>
                        </div>
                        <div class="mt-auto pt-3 split-row stat-grid stat-grid--2">
                            <div>
                                <strong style="color:#10b981">{{ num(d.returns.completed) }}</strong>
                                <div class="tiny text-muted">{{ __('completed') }}</div>
                            </div>
                            <div>
                                <strong style="color:#f59e0b">{{ num(d.returns.pending) }}</strong>
                                <div class="tiny text-muted">{{ __('pending') }}</div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12 col-xl-4">
                <div class="card h-100">
                    <div class="card-body d-flex flex-column">
                        <div class="dash-card-title">{{ __('salary') }}</div>
                        <div class="dash-card-sub">{{ __('paid_by_admin') }}</div>
                        <div class="cash-hero my-3">
                            <span class="cash-ic" :style="tint(primary)"><component :is="icon.salary" /></span>
                            <div>
                                <div class="cash-num"><RollingNumber :value="money(d.salary.total_paid)" /></div>
                                <div class="tiny text-muted">{{ __('total_paid') }}</div>
                            </div>
                        </div>
                        <div class="mt-auto pt-2 split-row d-flex justify-content-between small">
                            <span class="text-muted">{{ __('last_payment') }}</span>
                            <strong>{{ d.salary.last_paid_on ? money(d.salary.last_amount) + ' · ' + fmtDate(d.salary.last_paid_on) : '—' }}</strong>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- ===== Recent ledgers ===== -->
        <div class="row g-3 mt-1 mb-4">
            <div class="col-12 col-xl-4">
                <div class="card h-100">
                    <div class="card-body">
                        <div class="dash-card-title mb-3">{{ __('settlement_history') }}</div>
                        <div class="led-row" v-for="f in d.recent_settlements" :key="f.id">
                            <span class="led-ic" :style="tint(f.type === 'credit' ? '#10b981' : '#ef4444')">
                                <component :is="f.type === 'credit' ? icon.up : icon.down" />
                            </span>
                            <div class="flex-grow-1 min-w-0">
                                <div class="fw-semibold text-truncate">{{ f.message || __(f.type) }}</div>
                                <div class="tiny text-muted">{{ fmtDate(f.date) }}</div>
                            </div>
                            <strong class="small" :class="f.type === 'credit' ? 'text-success' : 'text-danger'">
                                {{ f.type === 'credit' ? '+' : '−' }}{{ money(f.amount) }}
                            </strong>
                        </div>
                        <div v-if="!d.recent_settlements.length" class="empty-block">{{ __('no_data_found') }}</div>
                    </div>
                </div>
            </div>

            <div class="col-12 col-xl-4">
                <div class="card h-100">
                    <div class="card-body">
                        <div class="dash-card-title mb-3">{{ __('cash_collection') }}</div>
                        <div class="led-row" v-for="c in d.recent_cash" :key="c.id">
                            <span class="led-ic" :style="tint(c.type === 'COD' ? '#f59e0b' : '#10b981')"><component :is="icon.cash" /></span>
                            <div class="flex-grow-1 min-w-0">
                                <div class="fw-semibold text-truncate">
                                    {{ c.type === 'COD' ? __('collected') : __('deposited') }}
                                    <span v-if="c.order_number || c.order_id" class="tiny text-muted">{{ c.order_number || ('#' + c.order_id) }}</span>
                                </div>
                                <div class="tiny text-muted">{{ fmtDate(c.date) }}</div>
                            </div>
                            <strong class="small">{{ money(c.amount) }}</strong>
                        </div>
                        <div v-if="!d.recent_cash.length" class="empty-block">{{ __('no_data_found') }}</div>
                    </div>
                </div>
            </div>

            <div class="col-12 col-xl-4">
                <div class="card h-100">
                    <div class="card-body">
                        <div class="dash-card-title mb-3">{{ __('withdrawal_requests') }}</div>
                        <div class="led-row" v-for="w in d.recent_withdrawals" :key="w.id">
                            <span class="led-ic" :style="tint(wdColor(w.status))"><component :is="icon.wallet" /></span>
                            <div class="flex-grow-1 min-w-0">
                                <div class="fw-semibold">#{{ w.id }}</div>
                                <div class="tiny text-muted">{{ fmtDate(w.date) }}</div>
                            </div>
                            <div class="text-end">
                                <div class="small fw-semibold">{{ money(w.amount) }}</div>
                                <span class="badge" :class="wdBadge(w.status)">{{ wdLabel(w.status) }}</span>
                            </div>
                        </div>
                        <div v-if="!d.recent_withdrawals.length" class="empty-block">{{ __('no_data_found') }}</div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import { markRaw } from 'vue';
import axios from 'axios';
import Auth from '../../Auth.js';
import VueApexCharts from 'vue3-apexcharts';
import {
    Wallet, Banknote, DollarSign, Package, Truck, CircleCheck, ArrowUp, ArrowDown,
    RotateCcw, MapPin, Store as BranchIcon, Inbox, ShoppingBag,
} from 'lucide-vue-next';
import dayjs from '../../utils/dayjs';
import RollingNumber from '../../components/RollingNumber.vue';

// Lucide icon components; markRaw keeps Vue from proxying them when stored in data().
const ICON = {
    wallet: markRaw(Wallet),
    cash: markRaw(Banknote),
    salary: markRaw(DollarSign),
    box: markRaw(Package),
    truck: markRaw(Truck),
    check: markRaw(CircleCheck),
    up: markRaw(ArrowUp),
    down: markRaw(ArrowDown),
    ret: markRaw(RotateCcw),
    pin: markRaw(MapPin),
    branch: markRaw(BranchIcon),
    inbox: markRaw(Inbox),
    handbag: markRaw(ShoppingBag),
};

export default {
    name: 'DeliveryBoyDashboard',
    components: { apexchart: VueApexCharts, RollingNumber },
    data() {
        return {
            icon: ICON,
            isLoading: false,
            trend: '30',
            boyStatus: 1,
            statusLoading: false,
            primary: window.adminThemeColor || '#435ebe',
            d: this.emptyData(),
        };
    },
    computed: {
        // Fixed option set — no search box needed.
        trendOptions() {
            return [
                { id: '7', name: (__('last_7_days')) },
                { id: '30', name: (__('last_30_days')) },
                { id: '90', name: (__('last_90_days')) },
                { id: '12m', name: (__('last_12_months')) },
            ];
        },
        today() { return dayjs().format('DD MMM YYYY'); },
        greeting() {
            const h = new Date().getHours();
            return h < 12 ? this.__('good_morning') : (h < 17 ? this.__('good_afternoon') : this.__('good_evening'));
        },
        curr() { return this.d.profile.currency || this.$currency || ''; },
        isActive() { return Number(this.boyStatus) === 1; },
        trendLabel() {
            return {
                7: this.__('last_7_days'), 30: this.__('last_30_days'),
                90: this.__('last_90_days'), '12m': this.__('last_12_months'),
            }[this.trend];
        },

        todayCards() {
            const t = this.d.today;
            return [
                { key: 'e', label: this.__('today_earnings'), value: this.money(t.earnings), color: '#10b981', icon: ICON.salary },
                { key: 'd', label: this.__('delivered_today'), value: this.num(t.delivered), color: '#3b82f6', icon: ICON.check },
                { key: 'c', label: this.__('cash_collected_today'), value: this.money(t.cash), color: '#f59e0b', icon: ICON.cash },
                { key: 'o', label: this.__('today_orders'), value: this.num(t.orders), color: this.primary, icon: ICON.box },
            ];
        },
        walletRows() {
            const w = this.d.wallet;
            return [
                { key: 'earned', label: this.__('total_earned'), value: w.total_earned, color: '#10b981' },
                { key: 'withdrawn', label: this.__('total_withdrawn'), value: w.total_withdrawn, color: '#ef4444' },
                { key: 'pending', label: this.__('pending_withdrawal'), value: w.pending_withdrawal, color: '#f59e0b' },
            ];
        },
        orderRows() {
            const o = this.d.orders;
            return [
                { key: 't', label: this.__('total'), value: o.total, color: '#1d2939' },
                { key: 'a', label: this.__('active'), value: o.active, color: '#3b82f6' },
                { key: 'd', label: this.__('delivered'), value: o.delivered, color: '#10b981' },
                { key: 'c', label: this.__('cancelled'), value: o.cancelled, color: '#ef4444' },
            ];
        },
        statusMax() { return Math.max(1, ...this.d.status_breakdown.map((s) => s.count)); },
        returnMax() { return Math.max(1, ...(this.d.returns.breakdown || []).map((r) => r.count)); },
        successRate() { return this.pct(this.d.orders.delivered, this.d.orders.total); },
        cancelRate() { return this.pct(this.d.orders.cancelled, this.d.orders.total); },
        activeRate() { return this.pct(this.d.orders.active, this.d.orders.total); },

        trendSeries() { return [{ name: this.__('earnings'), data: this.d.earnings_trend.data }]; },
        trendOptions() {
            return {
                chart: { toolbar: { show: false }, fontFamily: 'inherit', zoom: { enabled: false }, selection: { enabled: false } },
                colors: [this.primary],
                dataLabels: { enabled: false },
                stroke: { curve: 'smooth', width: 2.5 },
                fill: { type: 'gradient', gradient: { opacityFrom: 0.35, opacityTo: 0.02 } },
                grid: { borderColor: '#eef0f4', strokeDashArray: 4 },
                // Cap tick count so 30/90-day ranges don't crowd the axis.
                xaxis: {
                    categories: this.d.earnings_trend.labels,
                    tickAmount: Math.min(8, Math.max(1, this.d.earnings_trend.labels.length)),
                    labels: { rotate: 0, hideOverlappingLabels: true, style: { colors: '#98a2b3', fontSize: '10px' } },
                    axisBorder: { show: false }, axisTicks: { show: false },
                },
                yaxis: { labels: { formatter: (v) => this.curr + this.compact(v), style: { colors: '#98a2b3' } } },
                tooltip: { y: { formatter: (v) => this.money(v) } },
            };
        },
    },
    created() { this.load(); },
    methods: {
        emptyData() {
            return {
                profile: { name: '', status: 1, country: '', currency: '', bonus_type: 0 },
                today: { earnings: 0, delivered: 0, cash: 0, orders: 0 },
                wallet: { balance: 0, total_earned: 0, total_debited: 0, pending_withdrawal: 0, total_withdrawn: 0, available: 0 },
                cash: { in_hand: 0, total_collected: 0, total_deposited: 0 },
                salary: { total_paid: 0, last_paid_on: null, last_amount: 0 },
                orders: { total: 0, active: 0, delivered: 0, cancelled: 0, quick: 0, ecommerce: 0 },
                status_breakdown: [], returns: { total: 0, completed: 0, pending: 0, breakdown: [] },
                earnings_trend: { labels: [], data: [], trend: '30', total: 0 },
                recent_settlements: [], recent_cash: [], recent_withdrawals: [],
            };
        },
        load() {
            this.isLoading = true;
            axios.get(this.$deliveryBoyApiUrl + '/dashboard', { params: { trend: this.trend } }).then((res) => {
                if (res.data.status === 1) {
                    this.d = res.data.data;
                    this.boyStatus = Number(this.d.profile.status) === 1 ? 1 : 3;
                }
            }).catch(() => this.showError(this.__('something_went_wrong')))
                .finally(() => { this.isLoading = false; });
        },

        // Own availability: 1 = active, 3 = deactivated. Revert the switch if the API rejects it.
        toggleStatus() {
            if (this.statusLoading) return;
            const previous = Number(this.boyStatus) === 1 ? 3 : 1;
            this.statusLoading = true;

            // Shared endpoint with the admin panel: `id` + `status`. For a delivery boy the
            // server ignores the id and resolves the boy from the token, so this is safe.
            const id = (Auth.user && Auth.user.delivery_boy) ? Auth.user.delivery_boy.id : null;
            axios.post(this.$deliveryBoyApiUrl + '/update_delivery_boy_status', { id, status: this.boyStatus }).then((res) => {
                if (res.data.status === 1) {
                    // Trust the server's resulting status over the optimistic switch value.
                    if (res.data.data && res.data.data.status) this.boyStatus = Number(res.data.data.status);
                    this.showMessage('success', res.data.message);
                } else {
                    this.boyStatus = previous;
                    this.showError(res.data.message || this.__('something_went_wrong'));
                }
            }).catch(() => {
                this.boyStatus = previous;
                this.showError(this.__('something_went_wrong'));
            }).finally(() => { this.statusLoading = false; });
        },

        num(n) { return new Intl.NumberFormat().format(Number(n || 0)); },
        money(n) {
            const s = new Intl.NumberFormat(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 }).format(Number(n || 0));
            return (this.curr || '') + s;
        },
        compact(n) {
            n = Number(n || 0);
            if (Math.abs(n) >= 1e7) return (n / 1e7).toFixed(1).replace(/\.0$/, '') + 'Cr';
            if (Math.abs(n) >= 1e5) return (n / 1e5).toFixed(1).replace(/\.0$/, '') + 'L';
            if (Math.abs(n) >= 1e3) return (n / 1e3).toFixed(1).replace(/\.0$/, '') + 'K';
            return String(Math.round(n));
        },
        pct(part, total) { return total ? Math.round((part / total) * 100) : 0; },
        barW(c) { return Math.max(c > 0 ? 4 : 0, Math.round((c / this.statusMax) * 100)); },
        retBarW(c) { return Math.max(c > 0 ? 4 : 0, Math.round((c / this.returnMax) * 100)); },
        // Order statuses the boy handles: 5 out-for-delivery, 6 delivered, 11 picked-up.
        statusIcon(id) {
            const map = { 5: ICON.truck, 6: ICON.pin, 11: ICON.handbag };
            return map[Number(id)] || ICON.box;
        },
        // Return statuses the boy handles: 5 out-for-pickup, 6 received, 7 return-to-branch.
        returnColor(id) {
            const map = { 5: '#f59e0b', 6: '#3b82f6', 7: '#10b981' };
            return map[Number(id)] || '#94a3b8';
        },
        returnIcon(id) {
            const map = { 5: ICON.truck, 6: ICON.inbox, 7: ICON.branch };
            return map[Number(id)] || ICON.ret;
        },
        // API sends UTC (ISO-8601 Zulu); render in the viewer's local timezone.
        // Date-only values (e.g. salary paid_on) carry no time — never shift those.
        fmtDate(dt) {
            if (!dt) return '';
            if (/^\d{4}-\d{2}-\d{2}$/.test(dt)) return dayjs(dt).format('DD MMM YYYY');
            return dayjs.utc(dt).local().format('DD MMM YYYY');
        },
        fmtDateTime(dt) { return dt ? dayjs.utc(dt).local().format('DD MMM YYYY, hh:mm A') : ''; },

        hexToRgb(hex) {
            const m = String(hex || '').match(/^#?([0-9a-fA-F]{6})$/);
            if (!m) return '67,94,190';
            const v = parseInt(m[1], 16);
            return `${(v >> 16) & 255},${(v >> 8) & 255},${v & 255}`;
        },
        tint(color) { return { background: `rgba(${this.hexToRgb(color)}, .12)`, color }; },
        statusColor(id) {
            const map = { 1: '#f59e0b', 2: this.primary, 3: '#6366f1', 4: '#3b82f6', 5: '#14b8a6', 6: '#10b981', 7: '#ef4444', 8: '#8b5cf6', 9: '#f97316', 10: '#06b6d4', 11: '#a855f7' };
            return map[Number(id)] || '#94a3b8';
        },
        wdColor(s) { return Number(s) === 1 ? '#10b981' : (Number(s) === 2 ? '#ef4444' : '#f59e0b'); },
        wdBadge(s) { return Number(s) === 1 ? 'badge-soft-success' : (Number(s) === 2 ? 'badge-soft-danger' : 'badge-soft-warning'); },
        wdLabel(s) { return Number(s) === 1 ? this.__('approved') : (Number(s) === 2 ? this.__('rejected') : this.__('pending')); },
    },
};
</script>

<style scoped>
.db-dash { padding-bottom: 1rem; }
.welcome-h { color: var(--app-ink); }
.welcome-sub { color: var(--bs-primary); font-size: .84rem; font-weight: 500; }

/* own status toggle (1 = active, 3 = deactivated) */
.status-toggle { display: inline-flex; align-items: center; padding: 6px 14px; border-radius: 20px; }
.status-toggle.on { background: rgba(16, 185, 129, .12); color: #059669; }
.status-toggle.off { background: rgba(239, 68, 68, .12); color: #dc2626; }
.status-toggle .status-text { font-size: .78rem; font-weight: 600; }
.status-toggle .form-check-input { cursor: pointer; margin-left: 0 !important; }
.status-toggle.on .form-check-input:checked { background-color: #059669; border-color: #059669; }
.status-toggle .form-check-input:focus { box-shadow: none; }


/* Theme sets .card { margin-bottom: 2.2rem } — with h-100 that margin inflates the column,
   so every card stretches with dead space at the bottom. Kill it here; rows use g-3 gutters. */
.card { border: 1px solid var(--app-card-border); border-radius: 14px; box-shadow: 0 2px 10px rgba(16, 24, 40, .04); margin-bottom: 0; }
.dash-card-title { font-weight: 700; font-size: .98rem; color: var(--app-ink); }
.dash-card-sub { font-size: .78rem; color: var(--app-muted); margin-bottom: .5rem; }
.dash-card-sub b { color: var(--app-ink); }
.trend-select { width: auto; min-width: 140px; border-radius: 9px; }
.min-w-0 { min-width: 0; }
.tiny { font-size: .68rem; }
.empty-block { text-align: center; color: var(--app-muted); padding: 2.2rem 0; }
.dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 5px; }

/* lucide defaults — per-context svg rules below override the size */
svg.lucide { width: 22px; height: 22px; stroke-width: 1.7px; }

/* apexcharts: browser/theme draws a focus outline around the svg on click — drop it */
.db-dash :deep(.apexcharts-canvas),
.db-dash :deep(.apexcharts-svg),
.db-dash :deep(.apexcharts-canvas *:focus) { outline: none !important; }

/* today */
.today-card .card-body { padding: 12px 14px; }
.today-ic { width: 40px; height: 40px; border-radius: 11px; display: flex; align-items: center; justify-content: center; color: var(--app-card-bg); flex-shrink: 0; }
.today-ic svg { width: 19px; height: 19px; }
.today-label { font-size: .76rem; color: var(--app-muted); }
.today-value { font-size: 1.2rem; font-weight: 800; color: var(--app-ink); line-height: 1.15; }

/* wallet */
.wallet-card .wallet-label { color: var(--app-muted); font-size: .76rem; text-transform: uppercase; letter-spacing: .4px; font-weight: 600; }
.wallet-value { font-size: 1.9rem; font-weight: 800; color: var(--app-ink); line-height: 1.15; }
.wallet-sub { color: var(--app-muted); font-size: .8rem; }
.wallet-sub b { color: var(--app-ink); }
.wallet-ic { width: 44px; height: 44px; border-radius: 12px; background: var(--app-thead-bg); color: var(--app-muted); display: flex; align-items: center; justify-content: center; }
.wallet-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.wallet-grid > div { background: var(--app-thead-bg); border: 1px solid var(--app-thead-bg); border-radius: 10px; padding: 8px 10px; }
.wallet-grid strong { font-size: .92rem; }

/* cash / salary hero */
.cash-hero { display: flex; align-items: center; gap: 12px; }
.cash-ic { width: 46px; height: 46px; border-radius: 12px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.cash-num { font-size: 1.4rem; font-weight: 800; color: var(--app-ink); line-height: 1.1; }

/* progress */
.track { height: 7px; border-radius: 6px; background: var(--app-thead-bg); overflow: hidden; }
.track span { display: block; height: 100%; border-radius: 6px; transform-origin: left center; animation: barGrow .85s cubic-bezier(.22, 1, .36, 1) both; }
@keyframes barGrow { from { transform: scaleX(0); } to { transform: scaleX(1); } }

/* status bars */
/* Don't grow — the channel split is pinned under it with mt-auto. */
.status-bars { display: flex; flex-direction: column; gap: 12px; flex: 0 1 auto; min-height: 0; max-height: 300px; overflow-y: auto; padding-right: 6px; }
.status-bars::-webkit-scrollbar { width: 5px; }
.status-bars::-webkit-scrollbar-thumb { background: var(--app-card-border); border-radius: 6px; }
.status-bars--sm { flex: 0 0 auto; max-height: none; overflow: visible; padding-right: 0; }
.status-bar { display: flex; align-items: center; gap: 10px; }
.status-ic { width: 32px; height: 32px; border-radius: 9px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.status-ic svg { width: 16px; height: 16px; }

/* stat grids */
.stat-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; text-align: center; }
.stat-grid--2 { grid-template-columns: repeat(2, 1fr); }
.stat-grid strong { font-size: 1.15rem; display: block; }
.split-row { border-top: 1px solid var(--app-thead-bg); }
.split-title { font-weight: 700; font-size: .84rem; color: var(--app-ink); margin-bottom: .5rem; }
.ret-num { font-size: 2.2rem; font-weight: 800; color: var(--app-ink); }

/* ledger rows */
.led-row { display: flex; align-items: center; gap: 10px; padding: 9px 0; border-bottom: 1px solid var(--app-card-border); }
.led-row:last-child { border-bottom: 0; }
.led-ic { width: 36px; height: 36px; border-radius: 10px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.led-ic svg { width: 17px; height: 17px; }

.badge-soft-success { background: rgba(16, 185, 129, .12); color: #059669; }
.badge-soft-danger { background: rgba(239, 68, 68, .12); color: #dc2626; }
.badge-soft-warning { background: rgba(245, 158, 11, .14); color: #d97706; }
</style>
