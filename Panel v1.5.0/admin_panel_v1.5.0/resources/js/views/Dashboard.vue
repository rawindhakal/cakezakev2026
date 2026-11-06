<template>
    <div class="ecom-dash">
        <!-- ===== Welcome header ===== -->
        <div class="d-flex align-items-start justify-content-between flex-wrap gap-2 mb-3">
            <div>
                <h3 class="mb-0 fw-bold welcome-h">{{ __('welcome') }}, {{ userName }}</h3>
                <div class="welcome-sub">{{ greeting }} • {{ today }}</div>
            </div>
            <div class="d-flex align-items-center gap-2 flex-wrap dash-pickers">
                <!-- Country-locked: revenue is a single-currency aggregate, so no All Countries.
                     Dropdowns only appear when there's more than one country / zone to pick. -->
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
                    :placeholder="__('zone')" @update:model-value="czOnZone">
                    <template #singleLabel="{ option }"><span class="cz-opt"><component :is="icon.pin" :size="14" class="cz-ic" />{{ option.label }}</span></template>
                </AppSelect>
                <AppSelect class="cz-sel" v-model="period" :options="periodOptions" :searchable="false" @update:model-value="load">
                    <template #singleLabel="{ option }"><span class="cz-opt"><component :is="icon.calendar" :size="14" class="cz-ic" />{{ option.name }}</span></template>
                </AppSelect>
            </div>
        </div>

        <!-- ===== Today cards ===== -->
        <div class="row g-3 mb-1">
            <div class="col-6 col-lg-3" v-for="t in todayCards" :key="t.key">
                <div class="card today-card h-100">
                    <div class="card-body d-flex align-items-center gap-3">
                        <span class="today-ic" :style="{ background: t.color }"><component :is="t.icon" /></span>
                        <div class="min-w-0">
                            <div class="today-label">{{ t.label }}</div>
                            <div class="today-value"><RollingNumber :value="rollValue(t.value)" /></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- ===== Trend + Order status ===== -->
        <div class="row g-3 mt-1">
            <div class="col-12 col-xl-8">
                <div class="card h-100">
                    <div class="card-body">
                        <div class="dash-card-title">{{ __('revenue_and_orders_trend') }}</div>
                        <div class="dash-card-sub">{{ periodLabel }}</div>
                        <apexchart type="area" height="340" :options="trendOptions" :series="trendSeries"></apexchart>
                    </div>
                </div>
            </div>
            <div class="col-12 col-xl-4">
                <div class="card h-100">
                    <div class="card-body d-flex flex-column">
                        <div class="dash-card-title">{{ __('order_status') }}</div>
                        <div class="dash-card-sub">{{ periodLabel }}</div>
                        <div class="status-bars mt-2">
                            <div class="status-bar" v-for="s in statusBars" :key="s.status_id">
                                <span class="status-ic" :style="tintStyle(statusColor(s.status_id))"><component :is="statusIcon(s.status_id)" /></span>
                                <div class="flex-grow-1">
                                    <div class="d-flex justify-content-between">
                                        <span class="small">{{ statusLabel(s.status_id, s.name) }}</span>
                                        <strong class="small">{{ num(s.count) }}</strong>
                                    </div>
                                    <div class="track"><span :style="{ width: barW(s.count) + '%', background: statusColor(s.status_id) }"></span></div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- ===== KPI cards ===== -->
        <div class="row g-3 mt-1">
            <div class="col-6 col-md-4 kpi-col" v-for="k in kpiCards" :key="k.key">
                <div class="card kpi-card h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-start">
                            <span class="kpi-icon" :style="tintStyle(k.color)"><component :is="k.icon" /></span>
                            <span v-if="k.trend" class="kpi-trend" :class="k.trend.up ? 'up' : 'down'">
                                <component :is="k.trend.up ? icon.trendUp : icon.trendDown" class="d-inline-flex" />
                                {{ k.trend.pct }}%
                            </span>
                        </div>
                        <div class="kpi-label">{{ k.label }}</div>
                        <div class="kpi-value">
                            <RollingNumber :value="rollValue(k.value)" /><span class="kpi-sub" v-if="k.sub">{{ k.sub }}</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- ===== Category donut + Brand bar + Top products ===== -->
        <div class="row g-3 mt-1">
            <div class="col-12 col-xl-4">
                <div class="card h-100">
                    <div class="card-body">
                        <div class="dash-card-title">{{ __('sales_by_category') }}</div>
                        <div class="dash-card-sub">{{ periodLabel }}</div>
                        <div v-if="data.category_sales.length" class="d-flex justify-content-center">
                            <apexchart type="donut" height="280" :options="categoryOptions" :series="categorySeries"></apexchart>
                        </div>
                        <div v-else class="empty-block">{{ __('no_data_found') }}</div>
                    </div>
                </div>
            </div>
            <div class="col-12 col-md-6 col-xl-4">
                <div class="card h-100">
                    <div class="card-body">
                        <div class="dash-card-title">{{ __('products_by_brand') }}</div>
                        <div class="dash-card-sub">{{ __('distribution') }}</div>
                        <div v-if="data.brand_products.length">
                            <apexchart type="bar" height="250" :options="brandOptions" :series="brandSeries"></apexchart>
                        </div>
                        <div v-else class="empty-block">{{ __('no_data_found') }}</div>
                    </div>
                </div>
            </div>
            <!-- Top Selling / Top Rated share one card; the segmented control swaps the list. -->
            <div class="col-12 col-md-6 col-xl-4">
                <div class="card h-100">
                    <div class="card-body d-flex flex-column">
                        <div class="dash-seg-head">
                            <div class="min-w-0">
                                <div class="dash-card-title text-truncate">{{ salesTab.title }}</div>
                                <div class="dash-card-sub">{{ salesTab.sub }}</div>
                            </div>
                            <div class="dash-seg">
                                <button type="button" v-for="t in salesTabs" :key="t.key" class="dash-seg-btn"
                                    :class="{ 'is-active': salesView === t.key }" @click="salesView = t.key">
                                    {{ t.short }}
                                </button>
                            </div>
                        </div>
                        <div class="rank-list">
                            <div class="rank-row" v-for="(p, i) in salesTab.rows" :key="p.id || i"
                                :class="{ 'dash-row-link': canViewProduct }" @click="openProduct(p.id)">
                                <span class="rank-badge">{{ i + 1 }}</span>
                                <img v-if="p.image" :src="p.image" class="avatar avatar--sq" />
                                <span v-else class="avatar avatar--sq avatar--ph"><component :is="icon.box" /></span>
                                <div class="flex-grow-1 min-w-0">
                                    <div class="fw-semibold text-truncate">{{ name(p.name) }}</div>
                                    <div class="tiny text-muted" v-if="salesView === 'selling'">{{ num(p.units) }} {{ __('units') }}</div>
                                    <div class="tiny text-muted" v-else>{{ num(p.count) }} {{ __('reviews') }}</div>
                                </div>
                                <strong class="small" v-if="salesView === 'selling'">{{ money(p.revenue) }}</strong>
                                <span class="rating-chip" v-else><component :is="icon.star" class="d-inline-flex" /> {{ p.rating }}</span>
                            </div>
                        </div>
                        <div v-if="!salesTab.rows.length" class="empty-block">{{ __('no_data_found') }}</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- ===== Commerce + Inventory + Returns ===== -->
        <div class="row g-3 mt-1">
            <div class="col-12 col-md-6 col-xl-4">
                <div class="card h-100" :class="{ 'dash-card-link': canViewOrders }" @click="goToOrders">
                    <div class="card-body d-flex flex-column">
                        <div class="dash-card-title">{{ __('commerce_mode') }}</div>
                        <div class="dash-card-sub">{{ __('quick_vs_ecommerce') }}</div>
                        <div class="mode-row" v-for="m in commerceRows" :key="m.key"
                            :class="{ 'mode-row-link': m.to }" @click.stop="goToMode(m)">
                            <span class="mode-ic" :style="tintStyle(m.color)"><component :is="m.icon" /></span>
                            <div class="flex-grow-1">
                                <div class="d-flex justify-content-between">
                                    <span class="fw-semibold">{{ m.label }}</span>
                                    <span class="text-muted small">{{ m.share }}%</span>
                                </div>
                                <div class="track mt-1"><span :style="{ width: m.share + '%', background: m.color }"></span></div>
                                <div class="small text-muted mt-1">{{ num(m.orders) }} {{ __('orders') }} · {{ money(m.revenue) }}</div>
                            </div>
                        </div>
                        <div class="mt-auto pt-3 mode-total d-flex justify-content-between">
                            <span class="text-muted small">{{ __('total') }}</span>
                            <strong>{{ money(commerceTotalRevenue) }}</strong>
                        </div>
                    </div>
                </div>
            </div>


            <div class="col-12 col-xl-4">
                <div class="card h-100">
                    <div class="card-body d-flex flex-column">
                        <div class="dash-card-title">{{ __('platform_usage') }}</div>
                        <div class="dash-card-sub">{{ periodLabel }}</div>
                        <template v-if="platformTotal">
                            <!-- Total rendered in HTML: Apex's donut total label overlaps in a half-donut. -->
                            <div class="gauge-wrap">
                                <apexchart type="donut" height="230" :options="platformOptions" :series="platformSeries"></apexchart>
                                <div class="gauge-center">
                                    <div class="gauge-num">{{ num(platformTotal) }}</div>
                                    <div class="tiny text-muted">{{ __('total_users') }}</div>
                                </div>
                            </div>
                            <div class="plat-pills mt-auto">
                                <div class="plat-pill" v-for="(p, i) in data.platform_usage" :key="i">
                                    <span class="plat-count" :style="{ color: palette[i % palette.length] }">{{ num(p.count) }}</span>
                                    <span class="tiny text-muted">{{ deviceLabel(p.device) }}</span>
                                </div>
                            </div>
                        </template>
                        <div v-else class="empty-block">{{ __('no_data_found') }}</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- ===== Top branches + customers + rated ===== -->
        <div class="row g-3 mt-1">
            <div class="col-12 col-md-6 col-xl-4">
                <div class="card h-100">
                    <div class="card-body d-flex flex-column">
                        <div class="dash-card-title mb-3">{{ __('highest_revenue_branches') }}</div>
                        <div class="rank-list">
                            <div class="rank-row" v-for="(s, i) in data.top_branches" :key="s.id">
                                <span class="rank-badge">{{ i + 1 }}</span>
                                <span class="rank-ic" :style="tintStyle(primary)"><component :is="icon.branch" /></span>
                                <div class="flex-grow-1 min-w-0">
                                    <div class="fw-semibold text-truncate">{{ name(s.name) }}</div>
                                    <div class="tiny text-muted">{{ num(s.orders) }} {{ __('orders') }}</div>
                                </div>
                                <strong class="small">{{ money(s.revenue) }}</strong>
                            </div>
                        </div>
                        <div v-if="!data.top_branches.length" class="empty-block">{{ __('no_data_found') }}</div>
                    </div>
                </div>
            </div>

            <div class="col-12 col-md-6 col-xl-4">
                <div class="card h-100">
                    <div class="card-body d-flex flex-column">
                        <div class="dash-card-title mb-3">{{ __('top_customers') }}</div>
                        <div class="rank-list">
                        <div class="rank-row" v-for="(cst, i) in data.top_customers" :key="i"
                            :class="{ 'dash-row-link': canViewCustomer }" @click="openCustomer(cst.id)">
                            <span class="rank-badge">{{ i + 1 }}</span>
                            <img v-if="cst.image" :src="cst.image" class="avatar" />
                            <span v-else class="avatar avatar--ph"><component :is="icon.user" /></span>
                            <div class="flex-grow-1 min-w-0">
                                <div class="fw-semibold text-truncate">{{ cst.name }}</div>
                                <div class="tiny text-muted text-truncate">{{ customerContact(cst) }}</div>
                            </div>
                            <div class="text-end">
                                <div class="small fw-semibold">{{ num(cst.orders) }} {{ __('orders') }}</div>
                                <div class="tiny text-muted">{{ money(cst.spent) }}</div>
                            </div>
                        </div>
                        </div>
                        <div v-if="!data.top_customers.length" class="empty-block">{{ __('no_data_found') }}</div>
                    </div>
                </div>
            </div>

            <!-- Demand signals: what shoppers are holding right now (wishlists / carts). -->
            <div class="col-12 col-xl-4">
                <div class="card h-100">
                    <div class="card-body d-flex flex-column">
                        <div class="dash-seg-head">
                            <div class="min-w-0">
                                <div class="dash-card-title text-truncate">{{ demandTab.title }}</div>
                                <div class="dash-card-sub">{{ demandTab.sub }}</div>
                            </div>
                            <div class="dash-seg">
                                <button type="button" v-for="t in demandTabs" :key="t.key" class="dash-seg-btn"
                                    :class="{ 'is-active': demandView === t.key }" @click="demandView = t.key">
                                    <component :is="t.icon" class="d-inline-flex" />
                                    <span>{{ t.short }}</span>
                                </button>
                            </div>
                        </div>
                        <div class="rank-list">
                            <div class="rank-row" v-for="(p, i) in demandTab.rows" :key="p.id || i"
                                :class="{ 'dash-row-link': canViewProduct }" @click="openProduct(p.id)">
                                <span class="rank-badge">{{ i + 1 }}</span>
                                <img v-if="p.image" :src="p.image" class="avatar avatar--sq" />
                                <span v-else class="avatar avatar--sq avatar--ph"><component :is="icon.box" /></span>
                                <div class="flex-grow-1 min-w-0">
                                    <!-- Units sit beside the name, not under it: one short row per product. -->
                                    <div class="d-flex align-items-center gap-2 min-w-0">
                                        <span class="fw-semibold text-truncate">{{ name(p.name) }}</span>
                                        <span class="tiny text-muted d-inline-flex align-items-center gap-1 flex-shrink-0"
                                            v-if="demandView === 'carted'">
                                            <component :is="icon.box" class="d-inline-flex" /> {{ num(p.units) }}
                                        </span>
                                    </div>
                                </div>
                                <span class="demand-chip" :style="tintStyle(demandTab.color)"
                                    v-b-tooltip.hover :title="demandTab.unit">
                                    <component :is="demandTab.icon" class="d-inline-flex" /> {{ num(p.count) }}
                                </span>
                            </div>
                        </div>
                        <div v-if="!demandTab.rows.length" class="empty-block">{{ __('no_data_found') }}</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- ===== Recent orders (last) ===== -->
        <div class="row g-3 mt-1 mb-4" v-if="$can('order_list')">
            <div class="col-12">
                <!-- Same surface + table treatment as the Orders list page. -->
                <div class="list-surface">
                    <div class="list-toolbar">
                        <div class="list-toolbar-start">
                            <span class="dash-card-title">{{ __('recent_orders') }}</span>
                        </div>
                    </div>
                    <div class="table-responsive">
                            <table class="table align-middle mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('order') }}</th>
                                        <th>{{ __('customer') }}</th>
                                        <th>{{ __('mode') }}</th>
                                        <th>{{ __('p_method') }}</th>
                                        <th>{{ __('status') }}</th>
                                        <th class="text-end">{{ __('amount') }}</th>
                                        <th class="text-end">{{ __('date') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr v-for="o in data.recent_orders" :key="o.id" @click="openOrder(o.id)" class="cursor-pointer">
                                        <td class="fw-semibold">{{ o.order_number || ('#' + o.id) }}</td>
                                        <td>
                                            <div class="fw-semibold">{{ o.customer || '—' }}</div>
                                            <div class="tiny text-muted">{{ $filters.mobileMask(o.mobile) }}</div>
                                        </td>
                                        <td>
                                            <!-- Same mode chip as the Orders list (common.css). -->
                                            <span class="mode-chip" v-if="o.delivery_type === 'pickup'">
                                                <component :is="icon.pickup" :size="14" :color="primaryColor" /> {{ __('self_pickup') }}
                                            </span>
                                            <span class="mode-chip" v-else>
                                                <component :is="o.channel === 'quick' ? icon.bolt : icon.bag"
                                                    :size="14" :color="primaryColor" />
                                                {{ o.channel === 'quick' ? __('quick') : __('ecommerce') }}
                                            </span>
                                        </td>
                                        <td class="small text-uppercase">{{ o.payment }}</td>
                                        <td><span class="badge" :class="statusBadge(o.status_id)">{{ o.delivery_type === 'pickup' && Number(o.status_id) === 6 ? __('collected') : statusLabel(o.status_id, o.status_name) }}</span></td>
                                        <td class="text-end fw-semibold">{{ money(o.amount) }}</td>
                                        <td class="text-end small text-muted">{{ o.date }}</td>
                                    </tr>
                                    <tr v-if="!data.recent_orders.length"><td colspan="7" class="text-center text-muted py-4">{{ __('no_data_found') }}</td></tr>
                                </tbody>
                            </table>
                    </div>
                </div>
            </div>
        </div>

        <OrderDetailSlider v-model="sliderShow" :order-id="activeOrderId" @updated="load" />
    </div>
</template>

<script>
import { markRaw } from 'vue';
import axios from 'axios';
import VueApexCharts from 'vue3-apexcharts';
import {
    Calendar, DollarSign, ShoppingBag, ChartLine, Users, Package, Store as BranchIcon, Ticket,
    Truck, Zap, CircleCheck, TriangleAlert, CircleX, RotateCcw, Star, User,
    TrendingUp, TrendingDown, Clock, MapPin, Settings, Heart, ShoppingCart, PackageCheck,
} from 'lucide-vue-next';
import OrderDetailSlider from './Orders/OrderDetailSlider.vue';
import RollingNumber from '../components/RollingNumber.vue';
import dayjs from '../utils/dayjs';
import Auth from '../Auth.js';
import CountryZoneFilter from '../mixins/CountryZoneFilter.js';

// Lucide icon components; markRaw keeps Vue from proxying them when stored in data().
const ICON = {
    calendar: markRaw(Calendar),
    revenue: markRaw(DollarSign),
    orders: markRaw(ShoppingBag),
    aov: markRaw(ChartLine),
    users: markRaw(Users),
    box: markRaw(Package),
    branch: markRaw(BranchIcon),
    coupon: markRaw(Ticket),
    delivery: markRaw(Truck),
    bolt: markRaw(Zap),
    bag: markRaw(ShoppingBag),
    pickup: markRaw(PackageCheck),
    check: markRaw(CircleCheck),
    warn: markRaw(TriangleAlert),
    cross: markRaw(CircleX),
    ret: markRaw(RotateCcw),
    star: markRaw(Star),
    user: markRaw(User),
    trendUp: markRaw(TrendingUp),
    trendDown: markRaw(TrendingDown),
    clock: markRaw(Clock),
    truck: markRaw(Truck),
    pin: markRaw(MapPin),
    gear: markRaw(Settings),
    heart: markRaw(Heart),
    cart: markRaw(ShoppingCart),
};

export default {
    name: 'Dashboard',
    mixins: [CountryZoneFilter],
    components: { apexchart: VueApexCharts, OrderDetailSlider, RollingNumber },
    data() {
        return {
            rolled: true,
            icon: ICON,
            isLoading: false,
            sliderShow: false,
            activeOrderId: null,
            period: 'this_year',
            // Which list each of the two filtered product cards is showing.
            salesView: 'selling',
            demandView: 'wishlisted',
            primary: window.adminThemeColor || '#435ebe',
            palette: ['#f5a623', '#8b5cf6', '#10b981', '#3b82f6', '#14b8a6', '#ec4899'],
            currency: this.$currency || '',
            // czAllowAll defaults false → country-locked (revenue is a single-currency aggregate).
            data: this.emptyData(),
        };
    },
    computed: {
        // Fixed option set — no search box needed.
        periodOptions() {
            return [
                { id: 'today', name: (__('today')) },
                { id: 'this_week', name: (__('this_week')) },
                { id: 'this_month', name: (__('this_month')) },
                { id: 'this_year', name: (__('this_year')) },
                { id: 'all', name: (__('all_time')) },
            ];
        },
        // Matches Orders.vue so the shared .mode-chip tints identically on both pages.
        primaryColor() { return window.adminThemeColor || '#435ebe'; },
        userName() { return (Auth && Auth.user && (Auth.user.username || Auth.user.name)) || this.__('admin'); },
        today() { return dayjs().format('DD MMM YYYY'); },
        greeting() {
            const h = new Date().getHours();
            return h < 12 ? this.__('good_morning') : (h < 17 ? this.__('good_afternoon') : this.__('good_evening'));
        },
        periodLabel() {
            return { today: this.__('today'), this_week: this.__('this_week'), this_month: this.__('this_month'), this_year: this.__('this_year'), all: this.__('all_time') }[this.period];
        },

        todayCards() {
            const t = this.data.today;
            return [
                { key: 'o', label: this.__('today_orders'), value: this.num(t.orders), color: '#3b82f6', icon: ICON.box },
                { key: 'r', label: this.__('today_revenue'), value: this.money(t.revenue), color: '#10b981', icon: ICON.revenue },
                { key: 'rt', label: this.__('today_returns'), value: this.num(t.returned), color: '#f59e0b', icon: ICON.ret },
                { key: 'c', label: this.__('today_cancelled'), value: this.num(t.cancelled), color: '#ef4444', icon: ICON.cross },
            ];
        },
        kpiCards() {
            const k = this.data.kpis;
            return [
                { key: 'rev', label: this.__('total_revenue'), value: this.money(k.total_revenue?.value), trend: k.total_revenue?.trend, color: this.primary, icon: ICON.revenue },
                { key: 'ord', label: this.__('total_orders'), value: this.num(k.total_orders?.value), trend: k.total_orders?.trend, color: '#3b82f6', icon: ICON.orders },
                { key: 'del', label: this.__('delivery_charges'), value: this.money(k.delivery_earned?.value), trend: k.delivery_earned?.trend, color: '#0ea5e9', icon: ICON.truck },
                { key: 'tax', label: this.__('tax_collected'), value: this.money(k.tax_collected?.value), sub: this.__('from_orders'), color: '#10b981', icon: ICON.aov },
                { key: 'units', label: this.__('units_sold'), value: this.num(k.units_sold?.value), trend: k.units_sold?.trend, color: '#6366f1', icon: ICON.box },
                { key: 'cust', label: this.__('active_customers'), value: this.num(k.active_customers?.value), trend: k.active_customers?.trend, color: '#8b5cf6', icon: ICON.users },
                { key: 'prd', label: this.__('active_products'), value: this.num(k.active_products?.value), sub: this.__('listed'), color: '#ec4899', icon: ICON.box },
                { key: 'str', label: this.__('active_branches'), value: this.num(k.active_branches?.value), sub: (k.active_branches?.sub || 0) + ' ' + this.__('zones'), color: '#14b8a6', icon: ICON.branch },
                { key: 'cpn', label: this.__('active_coupons'), value: this.num(k.active_coupons?.value), sub: this.__('active'), color: '#f97316', icon: ICON.coupon },
                { key: 'dlv', label: this.__('delivery_staff'), value: this.num(k.delivery_staff?.value), sub: this.__('active'), color: '#0ea5e9', icon: ICON.delivery },
            ];
        },

        trendSeries() {
            return [
                { name: this.__('revenue'), type: 'area', data: this.data.revenue_trend.revenue },
                { name: this.__('orders'), type: 'line', data: this.data.revenue_trend.orders },
            ];
        },
        trendOptions() {
            return {
                chart: {
                    toolbar: { show: false }, fontFamily: 'inherit',
                    // No drag-to-zoom / drag-to-select on the trend chart.
                    zoom: { enabled: false }, selection: { enabled: false },
                },
                colors: [this.primary, '#10b981'],
                dataLabels: { enabled: false },
                stroke: { curve: 'smooth', width: [2.5, 2.5] },
                fill: { type: ['gradient', 'solid'], gradient: { opacityFrom: 0.35, opacityTo: 0.02 } },
                grid: { borderColor: '#eef0f4', strokeDashArray: 4 },
                xaxis: { categories: this.data.revenue_trend.labels, labels: { style: { colors: '#98a2b3', fontSize: '10px' } }, axisBorder: { show: false }, axisTicks: { show: false }, tickAmount: 8 },
                // seriesName must match the series' name for per-axis formatters to apply.
                yaxis: [
                    { seriesName: this.__('revenue'), decimalsInFloat: 0, labels: { formatter: (v) => this.currency + this.compact(v), style: { colors: '#98a2b3' } } },
                    { seriesName: this.__('orders'), opposite: true, decimalsInFloat: 0, labels: { formatter: (v) => Math.round(v), style: { colors: '#98a2b3' } } },
                ],
                legend: { position: 'top', horizontalAlign: 'right', markers: { radius: 12 } },
                tooltip: {
                    shared: true, intersect: false,
                    y: { formatter: (v, o) => (o?.seriesIndex === 0 ? this.money(v) : Math.round(v) + ' ' + this.__('orders')) },
                },
            };
        },

        statusBars() {
            return this.data.order_status.filter((s) => s.count > 0 || [1, 2, 3, 4, 5, 6, 7, 8].includes(s.status_id));
        },
        statusMax() { return Math.max(1, ...this.data.order_status.map((s) => s.count)); },

        categorySeries() { return this.data.category_sales.map((c) => c.revenue); },
        categoryOptions() {
            return {
                chart: { fontFamily: 'inherit' },
                labels: this.data.category_sales.map((c) => this.name(c.name)),
                colors: this.palette,
                legend: { position: 'bottom', fontSize: '12px', markers: { radius: 12 } },
                dataLabels: { enabled: false },
                stroke: { width: 2 },
                plotOptions: { pie: { donut: { size: '62%' } } },
                tooltip: { y: { formatter: (v) => this.money(v) } },
            };
        },

        brandSeries() { return [{ name: this.__('products'), data: this.data.brand_products.map((b) => b.count) }]; },
        brandOptions() {
            const colors = ['#6366f1', '#10b981', '#f59e0b', '#ec4899', '#14b8a6', '#8b5cf6'];
            return {
                chart: { toolbar: { show: false }, fontFamily: 'inherit' },
                colors,
                plotOptions: { bar: { horizontal: true, borderRadius: 4, distributed: true, barHeight: '62%' } },
                dataLabels: { enabled: true, style: { colors: ['#fff'], fontSize: '11px' } },
                legend: { show: false },
                grid: { borderColor: '#eef0f4', strokeDashArray: 4 },
                xaxis: { categories: this.data.brand_products.map((b) => this.name(b.name)), labels: { style: { colors: '#98a2b3' } } },
                yaxis: { labels: { style: { colors: '#667085', fontSize: '12px' } } },
                tooltip: { y: { formatter: (v) => v + ' ' + this.__('products') } },
            };
        },

        platformSeries() { return this.data.platform_usage.map((p) => p.count); },
        platformTotal() { return this.data.platform_usage.reduce((a, p) => a + p.count, 0); },
        platformOptions() {
            return {
                chart: { fontFamily: 'inherit' },
                labels: this.data.platform_usage.map((p) => this.deviceLabel(p.device)),
                colors: this.palette,
                legend: { position: 'bottom', fontSize: '12px', markers: { radius: 12 }, offsetY: -10 },
                dataLabels: { enabled: false },
                stroke: { width: 2 },
                // Half-donut gauge; total drawn in HTML (Apex's total label overlaps here).
                plotOptions: {
                    pie: { startAngle: -90, endAngle: 90, offsetY: 10, donut: { size: '72%', labels: { show: false } } },
                },
                tooltip: { y: { formatter: (v) => this.num(v) } },
                grid: { padding: { bottom: -90 } },
            };
        },

        commerceRows() {
            const c = this.data.commerce_mode;
            const total = (c.quick?.orders || 0) + (c.ecommerce?.orders || 0) + (c.pickup?.orders || 0) || 1;
            const row = (key, label, icon, color, b) => ({
                key, label, icon, color,
                orders: b?.orders || 0, revenue: b?.revenue || 0,
                share: Math.round(((b?.orders || 0) / total) * 100),
            });
            // Each row opens its own list: channel rows the Orders page pre-filtered,
            // pickup the Self Pickup page (own permission).
            const orders = this.canViewOrders;
            const pickup = this.$can('self_pickup_order_list');
            return [
                { ...row('q', this.__('quick'), ICON.bolt, this.primary, c.quick), to: orders ? { path: '/orders', query: { channel: 'quick' } } : null },
                { ...row('e', this.__('ecommerce'), ICON.bag, '#10b981', c.ecommerce), to: orders ? { path: '/orders', query: { channel: 'ecommerce' } } : null },
                { ...row('p', this.__('self_pickup'), ICON.pickup, '#f59e0b', c.pickup), to: pickup ? { path: '/orders/pickup' } : null },
            ];
        },
        commerceTotalRevenue() {
            const c = this.data.commerce_mode;
            return (c.quick?.revenue || 0) + (c.ecommerce?.revenue || 0) + (c.pickup?.revenue || 0);
        },
        // --- Filtered product cards -------------------------------------
        // Top Selling is period-scoped; the other three are live snapshots.
        salesTabs() {
            return [
                { key: 'selling', short: this.__('top_selling'), title: this.__('top_selling_products'), sub: this.periodLabel },
                { key: 'rated', short: this.__('top_rated'), title: this.__('top_rated_products'), sub: this.__('all_time') },
            ];
        },
        salesTab() {
            const t = this.salesTabs.find((x) => x.key === this.salesView) || this.salesTabs[0];
            return { ...t, rows: this.salesView === 'rated' ? this.data.top_rated : this.data.top_products };
        },
        demandTabs() {
            return [
                { key: 'wishlisted', short: this.__('wishlists'), icon: ICON.heart, color: '#ec4899', unit: this.__('wishlists'), title: this.__('most_wishlisted_products'), sub: this.__('all_time') },
                { key: 'carted', short: this.__('carts'), icon: ICON.cart, color: '#3b82f6', unit: this.__('carts'), title: this.__('most_added_to_cart_products'), sub: this.__('all_time') },
            ];
        },
        demandTab() {
            const t = this.demandTabs.find((x) => x.key === this.demandView) || this.demandTabs[0];
            return { ...t, rows: this.demandView === 'carted' ? this.data.most_carted : this.data.most_wishlisted };
        },

        // Cards only act as links when the viewer may open the destination —
        // otherwise the router guard would bounce them to /unauthorized.
        canViewProduct() { return this.$can('product_list'); },
        canViewOrders() { return this.$can('order_list'); },
        canViewStock() { return this.$can('stock_management'); },
        canViewCustomer() { return this.$can('customer_list'); },

        inventoryRows() {
            const i = this.data.inventory_health;
            return [
                { key: 'in', label: this.__('in_stock'), value: i.in_stock, color: '#10b981', icon: ICON.check },
                { key: 'low', label: this.__('low_stock'), value: i.low_stock, color: '#f59e0b', icon: ICON.warn },
                { key: 'out', label: this.__('out_of_stock'), value: i.out_of_stock, color: '#ef4444', icon: ICON.cross },
            ];
        },
    },
    created() {
        this.czLoad();
    },
    beforeUnmount() {
        if (this._rollRaf) cancelAnimationFrame(this._rollRaf);
    },
    methods: {
        // Called by the country/zone mixin (on load + on every change).
        czOnFilter() {
            this.currency = this.czCurrency || this.$currency || '';
            this.load();
        },
        emptyData() {
            return {
                currency: '', period: 'this_month',
                today: { orders: 0, revenue: 0, returned: 0, cancelled: 0 },
                kpis: {}, revenue_trend: { labels: [], revenue: [], orders: [] },
                order_status: [], category_sales: [], top_products: [], brand_products: [],
                commerce_mode: { quick: {}, ecommerce: {}, pickup: {} },
                inventory_health: { in_stock: 0, low_stock: 0, out_of_stock: 0, total: 0 },
                top_branches: [], top_customers: [], top_rated: [], platform_usage: [],
                most_wishlisted: [], most_carted: [],
                returns: { total: 0, pending: 0, refunded: 0, rejected: 0 }, recent_orders: [],
            };
        },
        startCountUp() {
            if (this._rollRaf) cancelAnimationFrame(this._rollRaf);
            this.rolled = false;
            this._rollRaf = requestAnimationFrame(() => {
                this._rollRaf = requestAnimationFrame(() => {
                    this.rolled = true;
                    this._rollRaf = null;
                });
            });
        },
        /** Before the roll, every digit of a card's figure reads 0, so widths never jump. */
        rollValue(v) {
            const s = String(v ?? '');
            return this.rolled ? s : s.replace(/\d/g, '0');
        },
        load() {
            this.isLoading = true;
            const params = {
                country_id: this.czCountryParam,
                zone_id: this.czZoneParam,
                period: this.period,
            };
            axios.get(this.$apiUrl + '/dashboard', { params }).then((res) => {
                if (res.data.status === 1) {
                    this.data = res.data.data;
                    if (res.data.data.currency) this.currency = res.data.data.currency;
                    this.startCountUp();
                }
            }).catch(() => this.showError(this.__('something_went_wrong')))
                .finally(() => { this.isLoading = false; });
        },
        openOrder(id) { this.activeOrderId = id; this.sliderShow = true; },

        openProduct(id) {
            if (id && this.canViewProduct) this.$router.push('/products/view/' + id);
        },
        goToOrders() {
            if (this.canViewOrders) this.$router.push('/orders');
        },
        goToMode(m) {
            if (m.to) this.$router.push(m.to);
            else this.goToOrders();
        },
        goToStock() {
            if (this.canViewStock) this.$router.push('/manage_stock');
        },
        openCustomer(id) {
            if (id && this.canViewCustomer) this.$router.push('/users/view/' + id);
        },
        // Mobile first (masked in demo mode), then email, then a dash.
        customerContact(c) {
            if (c.mobile) return ((c.country_code ? c.country_code + ' ' : '') + this.$filters.mobileMask(c.mobile)).trim();
            if (c.email) return this.$filters.emailMask(c.email);
            return '-';
        },

        name(val) {
            if (val == null) return '';
            if (typeof val === 'string') return val;
            if (typeof val === 'object' && !Array.isArray(val)) {
                const locale = window.appLocale || window.localStorage.getItem('lang') || 'en';
                if (val[locale] && String(val[locale]).trim()) return String(val[locale]).trim();
                const first = Object.values(val).find((v) => v != null && String(v).trim() !== '');
                return first != null ? String(first).trim() : '';
            }
            return '';
        },

        deviceLabel(d) {
            const k = String(d || '').toLowerCase();
            if (k === 'web') return this.__('web');
            if (k === 'android') return 'Android (App)';
            if (k === 'ios') return 'iOS (App)';
            return d || this.__('unknown');
        },
        // Plain formatters. The load animation lives in the cards (rollValue + the
        // RollingNumber component), not in every figure on the page.
        num(n) { return new Intl.NumberFormat().format(Math.round(Number(n || 0))); },
        // Full amount with the header country's currency symbol (no K/L truncation).
        money(n) {
            n = Number(n || 0);
            const s = new Intl.NumberFormat(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 }).format(n);
            return (this.currency || '') + s;
        },
        // Compact only used inside chart axes to keep them readable.
        compact(n) {
            n = Number(n || 0);
            if (Math.abs(n) >= 1e7) return (n / 1e7).toFixed(1).replace(/\.0$/, '') + 'Cr';
            if (Math.abs(n) >= 1e5) return (n / 1e5).toFixed(1).replace(/\.0$/, '') + 'L';
            if (Math.abs(n) >= 1e3) return (n / 1e3).toFixed(1).replace(/\.0$/, '') + 'K';
            return String(Math.round(n));
        },
        pct(part, total) { return total ? Math.round((part / total) * 100) : 0; },
        barW(count) { return Math.max(count > 0 ? 4 : 0, Math.round((count / this.statusMax) * 100)); },

        hexToRgb(hex) {
            const m = String(hex || '').match(/^#?([0-9a-fA-F]{6})$/);
            if (!m) return '67,94,190';
            const v = parseInt(m[1], 16);
            return `${(v >> 16) & 255},${(v >> 8) & 255},${v & 255}`;
        },
        tintStyle(color) {
            const rgb = color.startsWith('#') ? this.hexToRgb(color) : color;
            return { background: `rgba(${rgb}, .12)`, color };
        },
        statusColor(id) {
            const map = { 1: '#f59e0b', 2: this.primary, 3: '#6366f1', 4: '#3b82f6', 5: '#14b8a6', 6: '#10b981', 7: '#ef4444', 8: '#8b5cf6', 9: '#f97316', 10: '#06b6d4', 11: '#a855f7' };
            return map[Number(id)] || '#94a3b8';
        },
        statusIcon(id) {
            const map = { 1: ICON.clock, 2: ICON.check, 3: ICON.gear, 4: ICON.box, 5: ICON.truck, 6: ICON.pin, 7: ICON.cross, 8: ICON.ret, 9: ICON.gear, 10: ICON.box, 11: ICON.truck };
            return map[Number(id)] || ICON.box;
        },
        statusBadge(id) {
            const n = Number(id);
            if (n === 6) return 'badge-soft-success';
            if (n === 7 || n === 8) return 'badge-soft-danger';
            if (n === 1) return 'badge-soft-warning';
            return 'badge-soft-primary';
        },
        // Translate the order status by id via the admin's selected language,
        // instead of the English name the API sends (fallback = that name).
        statusLabel(id, fallback = '') {
            const map = {
                1: 'payment_pending', 2: 'received', 3: 'processed', 4: 'shipped',
                5: 'outForDelivery', 6: 'delivered', 7: 'cancelled', 8: 'returned',
                9: 'preparing', 10: 'ready_for_pickup', 11: 'picked_up',
            };
            const key = map[Number(id)];
            if (!key) return fallback;
            const t = __(key);
            return (t && t !== key) ? t : (fallback || t);
        },
    },
};
</script>

<style scoped>
.ecom-dash { padding-bottom: 1rem; }
.welcome-h { color: var(--app-ink); }
.welcome-sub { color: var(--bs-primary); font-size: .84rem; font-weight: 500; }

.period-select { display: flex; align-items: center; gap: 6px; color: var(--bs-primary); }
.period-select .form-select { border-radius: 9px; min-width: 130px; }

/* Theme sets .card { margin-bottom: 2.2rem } — with h-100 that margin inflates the column,
   so every card stretches with dead space at the bottom. Kill it here; rows use g-3 gutters. */
.card { border: 1px solid var(--app-card-border); border-radius: 14px; box-shadow: 0 2px 10px rgba(16, 24, 40, .04); margin-bottom: 0; }
.dash-card-title { font-weight: 700; font-size: .98rem; color: var(--app-ink); }
.dash-card-sub { font-size: .78rem; color: var(--app-muted); margin-bottom: .5rem; }
.min-w-0 { min-width: 0; }
.tiny { font-size: .68rem; }
.empty-block { text-align: center; color: var(--app-muted); padding: 2.5rem 0; }

/* lucide defaults — match the old hand-drawn set; the per-context svg rules below override size */
svg.lucide { width: 22px; height: 22px; stroke-width: 1.7px; }

/* today cards — compact */

.today-card .card-body { padding: 12px 14px; }
.today-ic { width: 40px; height: 40px; border-radius: 11px; display: flex; align-items: center; justify-content: center; color: var(--app-card-bg); flex-shrink: 0; }
.today-ic svg { width: 19px; height: 19px; }
.today-label { font-size: .76rem; color: var(--app-muted); line-height: 1.2; }
.today-value { font-size: 1.2rem; font-weight: 800; color: var(--app-ink); line-height: 1.15; }
/* The rolling figure is inline-flex; keep it on the text baseline next to a sub label. */
.today-value :deep(.rolling-number),
.kpi-value :deep(.rolling-number) { vertical-align: baseline; }

/* KPI — 5 per row on large screens, tight padding */
.kpi-col { flex: 0 0 auto; width: 50%; }
@media (min-width: 768px) { .kpi-col { width: 33.3333%; } }
@media (min-width: 1200px) { .kpi-col { width: 20%; } }
.kpi-card .card-body { padding: 14px; }
.kpi-icon { width: 40px; height: 40px; border-radius: 11px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.kpi-icon svg { width: 19px; height: 19px; }
.kpi-trend { display: inline-flex; align-items: center; gap: 3px; font-size: .72rem; font-weight: 700; padding: 3px 8px; border-radius: 20px; }
.kpi-trend svg { width: 13px; height: 13px; }
.kpi-trend.up { background: rgba(16, 185, 129, .12); color: #059669; }
.kpi-trend.down { background: rgba(239, 68, 68, .12); color: #dc2626; }
.kpi-label { font-size: .68rem; text-transform: uppercase; letter-spacing: .3px; color: var(--app-muted); font-weight: 600; margin-top: .85rem; }
.kpi-value { font-size: 1.25rem; font-weight: 800; color: var(--app-ink); line-height: 1.25; }
/* Sub sits inline after the number, not on its own line. */
.kpi-sub { font-size: .7rem; font-weight: 500; color: var(--app-muted); margin-left: 6px; }

/* Phones: pickers take the full row under the greeting and split it between them. */
@media (max-width: 575.98px) {
    .dash-pickers { width: 100%; }
    .today-card .card-body { padding: 10px 12px; gap: 10px !important; }
    .today-ic { width: 34px; height: 34px; border-radius: 9px; }
    .today-ic svg { width: 16px; height: 16px; }
    .today-label { font-size: .7rem; }
    .today-value { font-size: 17px; font-weight: 600; }
    /* KPI tiles: two per row is narrow — smaller figure, never split a number mid-way. */
    .kpi-card .card-body { padding: 12px; }
    .kpi-icon { width: 34px; height: 34px; border-radius: 9px; }
    .kpi-icon svg { width: 16px; height: 16px; }
    .kpi-trend { font-size: .64rem; padding: 2px 6px; }
    .kpi-label { font-size: .62rem; margin-top: .6rem; }
    .kpi-value { font-size: 17px; font-weight: 600; word-break: normal; overflow-wrap: normal; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .kpi-sub { display: block; margin-left: 0; font-size: .62rem; }
}

/* status bars — fill the full card height (matched to the trend card via h-100), scroll past it */
.status-bars {
    display: flex; flex-direction: column; gap: 12px;
    /* height:0 basis + grow = exactly the leftover card space; min-height keeps it usable when stacked */
    flex: 1 1 auto; height: 0; min-height: 280px;
    overflow-y: auto; padding-right: 6px;
}
.status-bars::-webkit-scrollbar { width: 5px; }
.status-bars::-webkit-scrollbar-thumb { background: var(--app-card-border); border-radius: 6px; }
.status-bar { display: flex; align-items: center; gap: 10px; }
.status-ic { width: 34px; height: 34px; border-radius: 9px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.status-ic svg { width: 17px; height: 17px; }

/* apexcharts: browser/theme draws a focus outline around the svg on click — purely decorative chart, drop it */
.ecom-dash :deep(.apexcharts-canvas),
.ecom-dash :deep(.apexcharts-svg),
.ecom-dash :deep(.apexcharts-canvas *:focus) { outline: none !important; }

/* generic track/progress — slides in on first paint (like the brand bar chart) */
.track { height: 7px; border-radius: 6px; background: var(--app-thead-bg); overflow: hidden; }
.track span {
    display: block; height: 100%; border-radius: 6px;
    transform-origin: left center;
    animation: barGrow .85s cubic-bezier(.22, 1, .36, 1) both;
}
@keyframes barGrow { from { transform: scaleX(0); } to { transform: scaleX(1); } }

/* commerce / inventory */
.mode-row, .inv-row { display: flex; gap: 12px; align-items: flex-start; margin-top: 14px; }
.mode-row-link { cursor: pointer; border-radius: .5rem; padding: 4px; margin-left: -4px; margin-right: -4px; transition: background .15s; }
.mode-row-link:hover { background: rgba(0, 0, 0, .04); }
.inv-row { align-items: center; }
.mode-ic { width: 40px; height: 40px; border-radius: 11px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.inv-ic { flex-shrink: 0; display: inline-flex; }
.mode-total, .inv-donut { border-top: 1px solid var(--app-thead-bg); }

/* platform usage gauge */
.gauge-wrap { position: relative; display: flex; justify-content: center; }
.gauge-center { position: absolute; left: 50%; top: 58%; transform: translate(-50%, -50%); text-align: center; pointer-events: none; }
.gauge-num { font-size: 1.5rem; font-weight: 800; color: var(--app-ink); line-height: 1; }
.plat-pills { display: grid; grid-template-columns: repeat(auto-fit, minmax(0, 1fr)); gap: 8px; margin-top: .25rem; }
.plat-pill {
    background: rgba(var(--bs-primary-rgb), .06);
    border: 1px solid rgba(var(--bs-primary-rgb), .14);
    border-radius: 10px; padding: 8px; text-align: center;
}
.plat-count { display: inline-block; background: var(--app-card-bg); border-radius: 20px; padding: 1px 12px; font-weight: 700; font-size: .84rem; }

/* rank rows (branches / customers / rated / top products) — list from the top; short lists just end. */
.rank-list { display: flex; flex-direction: column; flex: 1 1 auto; }
.rank-row { display: flex; align-items: center; gap: 10px; padding: 9px 0; border-bottom: 1px solid var(--app-thead-bg); }
.rank-row:last-child { border-bottom: 0; }
.rank-badge { width: 22px; height: 22px; border-radius: 7px; background: rgba(var(--bs-primary-rgb), .1); color: var(--bs-primary); font-size: .74rem; font-weight: 700; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.rank-ic { width: 34px; height: 34px; border-radius: 9px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.avatar { width: 36px; height: 36px; border-radius: 50%; object-fit: cover; flex-shrink: 0; }
.avatar--sq { border-radius: 9px; }
.avatar--ph { display: flex; align-items: center; justify-content: center; background: var(--app-thead-bg); color: var(--app-muted); }
.rating-chip { display: inline-flex; align-items: center; gap: 4px; font-size: .78rem; font-weight: 700; color: #d97706; background: rgba(245, 158, 11, .12); padding: 3px 9px; border-radius: 20px; }
.rating-chip svg { width: 13px; height: 13px; }

/* table */
/* Recent-orders table now inherits .list-surface's table styling (common.css),
   so the old .dash-table rules are gone. */
.cursor-pointer { cursor: pointer; }
/* .chip replaced by the shared .mode-chip in common.css. */

/* Cards that navigate on click (Commerce Mode, Inventory Health). */
.dash-card-link { cursor: pointer; transition: transform .15s ease, box-shadow .15s ease; }
.dash-card-link:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(16, 24, 40, .10); }

/* Header + segmented control for the two filtered product cards. */
.dash-seg-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 10px; margin-bottom: 10px; }
.dash-seg { display: inline-flex; flex: 0 0 auto; background: var(--app-thead-bg); border-radius: 8px; padding: 2px; }
.dash-seg-btn {
    display: inline-flex; align-items: center; gap: 4px;
    border: 0; background: transparent; color: var(--app-muted, #667085);
    font-size: .72rem; font-weight: 600; white-space: nowrap;
    padding: 4px 9px; border-radius: 6px; transition: background .15s ease, color .15s ease;
}
.dash-seg-btn svg { width: 13px; height: 13px; }
.dash-seg-btn:hover { color: var(--app-ink); }
.dash-seg-btn.is-active { background: var(--app-card-bg); color: var(--bs-primary); box-shadow: 0 1px 3px rgba(16, 24, 40, .10); }

/* Count chip in the wishlist / cart lists — the icon carries the meaning. */
.demand-chip { display: inline-flex; align-items: center; gap: 4px; font-size: .78rem; font-weight: 700; padding: 3px 9px; border-radius: 20px; }
.demand-chip svg { width: 13px; height: 13px; }

/* Rows that navigate on click (Top Customers). */
.dash-row-link { cursor: pointer; border-radius: 8px; transition: background .15s ease; }
.dash-row-link:hover { background: rgba(16, 24, 40, .04); }


.badge-soft-success { background: rgba(16, 185, 129, .12); color: #059669; }
.badge-soft-danger { background: rgba(239, 68, 68, .12); color: #dc2626; }
.badge-soft-warning { background: rgba(245, 158, 11, .14); color: #d97706; }
.badge-soft-primary { background: rgba(var(--bs-primary-rgb), .12); color: var(--bs-primary); }
</style>