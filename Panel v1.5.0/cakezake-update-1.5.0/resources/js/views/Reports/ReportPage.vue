<template>
    <div>
        <div class="page-heading">
            <section class="section">

                <!-- ===== Heading card: name + icon | refresh + export ===== -->
                <div class="card rp-card rp-head">
                    <div class="card-body">
                        <div class="rp-head-row">
                            <div class="rp-head-left">
                                <span class="rp-icon" :style="{ background: tint, color: primaryColor }">
                                    <component :is="icon" :size="22" />
                                </span>
                                <div class="min-w-0">
                                    <h4 class="rp-head-title">{{ __(cfg.title) }}</h4>
                                    <div class="rp-head-sub">{{ __(cfg.subtitle) }}</div>
                                </div>
                            </div>

                            <div class="rp-head-actions">
                                <AppSelect v-if="czShowCountry" class="cz-sel" v-model="czCountryId"
                                    :options="czCountryOptions" :searchable="czCountryOptions.length > 6"
                                    :allow-empty="false" label-key="label" track-by="id" :placeholder="__('country')"
                                    @update:model-value="czOnCountry">
                                    <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                                :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                                    <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                                :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                                </AppSelect>
                                <AppSelect v-if="czShowZoneDropdown && data.zone_supported !== false" class="cz-sel"
                                    v-model="czZoneId" :options="czZoneOptions" :searchable="false" :allow-empty="false"
                                    label-key="label" track-by="id" :placeholder="__('zone')" @update:model-value="czOnZone" />

                                <button class="btn btn-sm btn-outline-secondary" @click="load()" :disabled="isLoading"
                                    v-b-tooltip.hover :title="__('refresh')">
                                    <b-spinner v-if="isLoading" small></b-spinner>
                                    <i v-else class="fa fa-refresh"></i>
                                </button>

                                <div class="dropdown">
                                    <button class="btn btn-sm dropdown-toggle text-white" data-bs-toggle="dropdown"
                                        :style="{ background: primaryColor, borderColor: primaryColor }"
                                        :disabled="isLoading || exporting || !rows.length">
                                        <b-spinner v-if="exporting" small></b-spinner>
                                        <i v-else class="fa fa-download me-1"></i>
                                        {{ __('export') }}
                                    </button>
                                    <ul class="dropdown-menu dropdown-menu-end">
                                        <li><a class="dropdown-item" href="#" @click.prevent="download('pdf')">
                                            <i class="fa fa-file-pdf text-danger me-2"></i>PDF</a></li>
                                        <li><a class="dropdown-item" href="#" @click.prevent="download('xlsx')">
                                            <i class="fa fa-file-excel text-success me-2"></i>Excel</a></li>
                                        <li><a class="dropdown-item" href="#" @click.prevent="download('csv')">
                                            <i class="fa fa-file-csv text-primary me-2"></i>CSV</a></li>
                                    </ul>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- ===== Period filter (outside the card). Inventory is a live stock
                          snapshot, so it has no period filter at all. ===== -->
                <div class="rp-filter" v-if="!cfg.pointInTime">
                    <div class="rp-periods">
                        <button v-for="p in periods" :key="p.key" type="button"
                            class="rp-period" :class="{ active: period === p.key }"
                            :style="periodStyle(p.key)"
                            @click="selectPreset(p.key)">
                            {{ __(p.label) }}
                        </button>
                    </div>

                    <!-- Order type: all / quick / ecommerce / self pickup (only where orders drive the report). -->
                    <div class="rp-range" v-if="cfg.orderTypeFilter">
                        <AppSelect class="rp-dt-select" v-model="orderType" :options="orderTypeOptions"
                            :searchable="false" :allow-empty="false" @update:model-value="load()" />
                    </div>

                    <!-- Custom range: picking dates switches the period to `custom`. -->
                    <div class="rp-range">
                        <date-range-picker v-model="dateRange" :config="datePickerConfig"
                            @update="applyCustomRange" />
                        <button v-if="dateRange" class="btn btn-sm btn-outline-danger"
                            @click="clearCustomRange()" v-b-tooltip.hover :title="__('clear')">
                            <i class="fa fa-times"></i>
                        </button>
                    </div>
                </div>

                <!-- ===== KPI cards ===== -->
                <div class="rp-kpis">
                    <!-- Skeleton tiles while the first response loads (no summary yet). -->
                    <template v-if="isLoading && !data.summary.length">
                        <div class="rp-kpi" v-for="n in 4" :key="'kskel-' + n">
                            <div class="skel skel-line" style="width:55%;height:.65rem;margin-bottom:.6rem"></div>
                            <div class="skel skel-line" style="width:75%;height:1.15rem;margin-bottom:0"></div>
                        </div>
                    </template>
                    <div v-else class="rp-kpi" v-for="(k, i) in data.summary" :key="i">
                        <div class="rp-kpi-label">{{ __(k.label) }}</div>
                        <div class="rp-kpi-value" :class="{ 'rp-stale': isLoading }">
                            <RollingNumber :value="fmt(k.value, k.type)" />
                        </div>
                        <div class="rp-kpi-trend" v-if="k.trend && !isLoading"
                            :class="k.trend.up ? 'up' : 'down'">
                            <i :class="k.trend.up ? 'fa fa-arrow-trend-up' : 'fa fa-arrow-trend-down'"></i>
                            {{ k.trend.pct }}% <span class="text-muted">{{ __('vs_previous') }}</span>
                        </div>
                    </div>
                </div>

                <!-- Chart skeleton while loading (real chart is v-if'd on data). -->
                <div v-if="isLoading && cfg.chart" class="card rp-card">
                    <div class="card-body">
                        <div class="skel skel-line" style="width:22%;height:.9rem;margin-bottom:1rem"></div>
                        <div class="skel" style="height:300px;border-radius:.5rem"></div>
                    </div>
                </div>

                <!-- ===== Chart ===== -->
                <div class="card rp-card" v-if="cfg.chart && chartSeries.length">
                    <div class="card-body">
                        <div class="rp-card-title">{{ __(chartTitle) }}</div>
                        <apexchart :type="cfg.chart.type" :height="300"
                            :options="chartOptions" :series="chartSeries" />
                    </div>
                </div>

                <!-- ===== Mode breakdown (sales only) ===== -->
                <div class="row g-3 mb-3" v-if="data.mode_breakdown">
                    <div class="col-md-4" v-for="m in data.mode_breakdown" :key="m.mode">
                        <div class="card rp-card mb-0">
                            <div class="card-body d-flex align-items-center justify-content-between">
                                <div class="d-flex align-items-center gap-2">
                                    <span class="rp-mode-icon" :style="{ background: tint, color: primaryColor }">
                                        <component :is="icons[m.mode] || icons.bag" :size="18" />
                                    </span>
                                    <div>
                                        <div class="rp-kpi-label">{{ __(m.mode === 'pickup' ? 'self_pickup' : m.mode) }}</div>
                                        <div class="rp-kpi-value"><RollingNumber :value="money(m.revenue)" /></div>
                                    </div>
                                </div>
                                <div class="text-end">
                                    <div class="rp-kpi-label">{{ __('orders') }}</div>
                                    <div class="rp-kpi-value"><RollingNumber :value="num(m.orders)" /></div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- ===== Table ===== -->
                <div class="list-surface">
                    <div class="list-toolbar">
                        <div class="list-toolbar-start">
                            <span class="rp-card-title mb-0">{{ __('details') }}</span>
                        </div>
                        <div class="list-search">
                            <Search class="list-search-icon" />
                            <input type="search" class="form-control" v-model="search"
                                :placeholder="__('search')" />
                        </div>
                    </div>

                    <MazerDatatable responsive
                        :items="tableRows"
                        :fields="tableFields"
                        :filter="searchFn"
                        :current-page="currentPage"
                        :per-page="perPage"
                        v-model:sort-by="mzSortBy"
                        v-model:sort-desc="mzSortDesc"
                        :busy="isLoading"
                        stacked="md"
                        show-empty
                        small
                        @filtered="onFiltered">

                        <template v-for="c in columns" :key="c.key" #[`cell(${c.key})`]="{ item }">
                            <!-- product: image + name -->
                            <template v-if="c.format === 'product'">
                                <div class="d-flex align-items-center gap-2">
                                    <img v-if="item.image" :src="item.image" class="rp-thumb" alt="" />
                                    <div v-else class="rp-thumb rp-thumb-ph">{{ initials(display(item[c.key])) }}</div>
                                    <span class="text-truncate rp-linkable" :class="{ 'is-link': linkTo(c, item) }"
                                        @click="openLink(c, item)">{{ display(item[c.key]) }}</span>
                                </div>
                            </template>
                            <!-- linked text (customer / delivery boy / product name) -->
                            <span v-else-if="c.link" class="rp-linkable" :class="{ 'is-link': linkTo(c, item) }"
                                @click="openLink(c, item)">{{ fmt(item[c.key], c.format) }}</span>
                            <!-- badge -->
                            <span v-else-if="c.format === 'badge'"
                                class="badge" :class="'bg-' + (c.map[item[c.key]] || 'secondary')">
                                {{ __(c.text ? c.text[item[c.key]] : item[c.key]) }}
                            </span>
                            <!-- drill-down: a summary row opens the orders behind it -->
                            <span v-else-if="cfg.drill && c.key === cfg.columns[0].key"
                                class="rp-linkable is-link" @click="drillTo(item)">{{ fmt(item[c.key], c.format) }}</span>
                            <span v-else>{{ fmt(item[c.key], c.format) }}</span>
                        </template>
                    </MazerDatatable>

                    <div class="list-footer" v-if="filteredCount > perPage">
                        <div class="list-perpage">
                            <span class="list-range">{{ __('showing') }} {{ Math.min(perPage, filteredCount) }} / {{ filteredCount }}</span>
                        </div>
                        <b-pagination v-model="currentPage" :total-rows="filteredCount"
                            :per-page="perPage" size="sm" class="mb-0 list-pagination"></b-pagination>
                    </div>
                </div>

            </section>
        </div>
    </div>
</template>

<script>
import { markRaw } from 'vue';
import axios from 'axios';
import {
    TrendingUp, ShoppingCart, Package, Users, Warehouse,
    RotateCcw, Truck, CreditCard, Layers, Ticket, Zap, ShoppingBag, Search, ReceiptText, PackageCheck,
} from 'lucide-vue-next';
import DateRangePicker from '../../components/DateRangePicker.vue';
import RollingNumber from '../../components/RollingNumber.vue';
import { buildDateRangeConfig, toApiDate } from '../../utils/dateRange.js';
import { REPORTS, PERIODS } from './reportConfig.js';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';

// reportConfig only stores the icon NAME; resolve it to a component here.
const ICONS = {
    TrendingUp: markRaw(TrendingUp),
    ShoppingCart: markRaw(ShoppingCart),
    Package: markRaw(Package),
    Users: markRaw(Users),
    Warehouse: markRaw(Warehouse),
    RotateCcw: markRaw(RotateCcw),
    Truck: markRaw(Truck),
    CreditCard: markRaw(CreditCard),
    Layers: markRaw(Layers),
    Ticket: markRaw(Ticket),
    ReceiptText: markRaw(ReceiptText),
};

export default {
    name: 'ReportPage',
    mixins: [CountryZoneFilter],
    components: { DateRangePicker, RollingNumber, Search },
    props: {
        // Which report to render — supplied by the router (see router/index.js).
        type: { type: String, required: true },
    },
    data() {
        return {
            themeDark: document.body.classList.contains('theme-dark'),
            periods: PERIODS,
            period: 'this_month',
            // Custom range. Picking one sets period = 'custom'; a preset clears it.
            dateRange: '',
            datePickerConfig: buildDateRangeConfig({ maxDate: new Date() }),
            data: { summary: [], rows: [] },
            isLoading: false,
            exporting: false,
            search: '',
            sortKey: '',
            sortAsc: false,
            // MazerDatatable sort model + filtered row count (for pagination).
            mzSortBy: '',
            mzSortDesc: false,
            filteredCount: 0,
            currentPage: 1,
            perPage: 15,
            // Channel icons for the sales mode breakdown.
            icons: { quick: markRaw(Zap), ecommerce: markRaw(ShoppingBag), pickup: markRaw(PackageCheck) },
            // '' = every order; quick / ecommerce = that channel's home deliveries; pickup = self pickup.
            orderType: '',
        };
    },
    computed: {
        cfg() { return REPORTS[this.type]; },
        orderTypeOptions() {
            return [
                { id: '', name: __('all_orders') },
                { id: 'quick', name: __('quick') },
                { id: 'ecommerce', name: __('ecommerce') },
                { id: 'pickup', name: __('self_pickup') },
            ];
        },
        columns() {
            const base = this.cfg.columns || [];
            const dh = this.cfg.dynamicHeads;
            if (!dh) return base;

            const heads = this.data[dh.label] || [];
            if (!heads.length) return base;

            const extra = heads.map(h => ({ key: dh.prefix + h, label: h, format: 'money' }));
            const at = base.findIndex(c => c.key === dh.after);
            const out = base.slice();
            out.splice(at >= 0 ? at + 1 : out.length, 0, ...extra);
            return out;
        },
        icon() { return ICONS[this.cfg.icon] || ICONS.TrendingUp; },
        currency() { return this.data.currency || this.$currency || ''; },
        rows() { return this.data.rows || []; },
        tableRows() {
            const cols = this.columns;
            return this.rows.map(r => {
                const out = { ...r };
                for (const c of cols) {
                    if (this.isNumeric(c)) {
                        const n = Number(r[c.key]);
                        out[c.key] = isNaN(n) ? r[c.key] : n;
                    } else {
                        out[c.key] = this.display(r[c.key]);
                    }
                }
                return out;
            });
        },
        // Report columns → MazerDatatable fields (numeric cols right-aligned).
        tableFields() {
            return this.columns.map(c => ({
                key: c.key,
                label: __(c.label),
                sortable: true,
                class: this.isNumeric(c) ? 'text-end' : '',
            }));
        },
        primaryColor() { return window.adminThemeColor || '#435ebe'; },
        /** Soft wash of the theme colour behind the report icon. */
        tint() { return this.hexToRgba(this.primaryColor, 0.12); },

        searchFn() {
            const q = (this.search || '').toLowerCase().trim();
            if (!q) return '';
            return (item) => this.columns.some(c =>
                String(this.display(item[c.key]) ?? '').toLowerCase().includes(q));
        },
        filteredRows() {
            const q = (this.search || '').toLowerCase().trim();
            let out = this.rows;
            if (q) {
                out = out.filter(r => this.columns.some(c => {
                    const v = this.display(r[c.key]);
                    return String(v ?? '').toLowerCase().includes(q);
                }));
            }
            if (this.sortKey) {
                const k = this.sortKey;
                out = [...out].sort((a, b) => {
                    const x = a[k], y = b[k];
                    const bothNum = typeof x === 'number' && typeof y === 'number';
                    const cmp = bothNum ? x - y : String(this.display(x)).localeCompare(String(this.display(y)));
                    return this.sortAsc ? cmp : -cmp;
                });
            }
            return out;
        },
        pagedRows() {
            const from = (this.currentPage - 1) * this.perPage;
            return this.filteredRows.slice(from, from + this.perPage);
        },

        chartTitle() {
            if (this.cfg.chart?.from === 'series') return 'revenue_trend';
            if (this.cfg.chart?.from === 'reasons') return 'return_reasons';
            return 'overview';
        },

        // Source rows for the chart: an explicit payload key, else the table rows.
        chartRows() {
            const ch = this.cfg.chart;
            if (!ch) return [];
            if (ch.from === 'reasons') return this.data.reasons || [];
            const src = this.rows;
            return ch.limit ? src.slice(0, ch.limit) : src;
        },

        // Bars coloured like the status badges on the orders list, when the report asks for it.
        chartColors() {
            const ch = this.cfg.chart || {};
            if (ch.colorBy !== 'status_id') return null;
            const tone = (id) => {
                const n = Number(id);
                if (n === 2) return this.primaryColor;
                if (n === 3 || n === 9) return '#2aa9e0';
                if (n === 4 || n === 5 || n === 10 || n === 11) return '#f59e0b';
                if (n === 6) return '#10b981';
                if (n === 7 || n === 8) return '#ef4444';
                return '#94a3b8';
            };
            return this.chartRows.map(r => tone(r.status_id));
        },

        chartSeries() {
            const ch = this.cfg.chart;
            if (!ch || this.isLoading) return [];

            // Sales: a real time series (revenue + orders) from the backend.
            if (ch.from === 'series') {
                const s = this.data.series;
                const key = ch.valueKey || 'revenue';
                if (!s || !s.labels?.length || !s[key]) return [];
                return [{ name: __(key), data: s[key] }];
            }

            const rows = this.chartRows;
            if (!rows.length) return [];
            const values = rows.map(r => Number(r[ch.valueKey]) || 0);
            if (!values.some(v => v > 0)) return [];

            // Donut takes a bare number[]; bar takes a named series.
            return ch.type === 'donut' ? values : [{ name: __(ch.valueKey), data: values }];
        },

        chartLabels() {
            const ch = this.cfg.chart;
            if (ch?.from === 'series') return this.data.series?.labels || [];
            return this.chartRows.map(r => this.display(r[ch.labelKey]));
        },

        chartOptions() {
            const ch = this.cfg.chart || {};
            const money = ch.valueKey !== 'orders' && ch.valueKey !== 'count' && ch.valueKey !== 'delivered'
                && ch.valueKey !== 'uses' && ch.valueKey !== 'users';

            const base = {
                chart: {
                    toolbar: { show: false },
                    fontFamily: 'inherit',
                    background: 'transparent',
                    // No drag-to-zoom / pan, and no selection rectangle on the sales chart.
                    zoom: { enabled: false },
                    selection: { enabled: false },
                    animations: { enabled: true },
                },
                // Kills the focus/active outline Apex draws around a clicked slice or bar.
                states: {
                    active: { allowMultipleDataPointsSelection: false, filter: { type: 'none' } },
                    hover: { filter: { type: 'lighten', value: 0.08 } },
                },

                theme: { mode: this.themeDark ? 'dark' : 'light' },
                colors: this.chartColors || [this.primaryColor, '#2aa9e0', '#f59e0b', '#10b981', '#ef4444', '#8b5cf6', '#ec4899', '#14b8a6'],
                dataLabels: { enabled: false },
                legend: { position: 'bottom', fontSize: '12px' },
                grid: { borderColor: this.themeDark ? 'rgba(255,255,255,0.08)' : '#eef0f4', strokeDashArray: 4 },
                tooltip: {
                    y: { formatter: (v) => (money && ch.from !== 'reasons') ? this.money(v) : this.num(v) },
                },
            };

            if (ch.type === 'donut') {
                return {
                    ...base,
                    labels: this.chartLabels,
                    // expandOnClick off — clicking a slice shouldn't pop it out of the ring.
                    plotOptions: { pie: { expandOnClick: false, donut: { size: '68%' } } },
                    tooltip: { y: { formatter: (v) => this.num(v) } },
                };
            }

            return {
                ...base,
                xaxis: {
                    categories: this.chartLabels,
                    labels: { style: { fontSize: '11px' }, rotate: -35, trim: true, hideOverlappingLabels: true },
                    axisBorder: { show: false }, axisTicks: { show: false },
                },
                yaxis: { labels: { formatter: (v) => money ? this.compact(v) : this.num(v), style: { fontSize: '11px' } } },
                stroke: ch.type === 'area' ? { curve: 'smooth', width: 2 } : { width: 0 },
                fill: ch.type === 'area'
                    ? { type: 'gradient', gradient: { shadeIntensity: 1, opacityFrom: 0.35, opacityTo: 0.02, stops: [0, 100] } }
                    : { opacity: 1 },
                // distributed = one colour per bar (the per-status palette); the legend would
                // then repeat the x-axis, so it goes.
                plotOptions: { bar: { borderRadius: 4, columnWidth: '55%', distributed: !!this.chartColors } },
                legend: { ...base.legend, show: !this.chartColors },
            };
        },
    },
    created() {
        this.czLoad(); // sets default country then load() via czOnFilter

        // Re-theme charts when the header toggles light/dark.
        this._onThemeChanged = () => { this.themeDark = document.body.classList.contains('theme-dark'); };
        window.addEventListener('theme:changed', this._onThemeChanged);
    },
    beforeUnmount() {
        if (this._onThemeChanged) window.removeEventListener('theme:changed', this._onThemeChanged);
    },
    watch: {
        // Same component instance is reused when switching reports via the sidebar.
        type() {
            this.resetView();
            this.load();
        },
        search() { this.currentPage = 1; },
    },
    methods: {
        /**
         * Route for a linkable column, or null when the row carries no id or the
         * viewer lacks the destination's permission (the guard would bounce them).
         */
        linkTo(col, item) {
            if (!col || !col.link) return null;
            const id = Number(item[col.linkId || 'link_id'] || 0);
            if (!id) return null;

            const routes = {
                product:      { path: '/products/view/',      can: 'product_list' },
                customer:     { path: '/users/view/',         can: 'order_list' },
                delivery_boy: { path: '/delivery_boys/view/', can: 'delivery_boy_list' },
            };
            const r = routes[col.link];
            if (!r || !this.$can(r.can)) return null;
            return r.path + id;
        },
        openLink(col, item) {
            const to = this.linkTo(col, item);
            if (to) this.$router.push(to);
        },
        czOnFilter() { this.load(); },
        resetView() {
            this.data = { summary: [], rows: [] };
            this.search = '';
            this.sortKey = '';
            this.currentPage = 1;
            this.period = 'this_month';
            this.dateRange = '';
            this.orderType = '';
        },
        params() {
            const p = {
                period: this.period,
                country_id: this.czCountryParam,
                zone_id: this.czZoneParam,
            };
            if (this.period === 'custom' && this.dateRange) {
                p.start_date = toApiDate(this.dateRange, 'start');
                p.end_date = toApiDate(this.dateRange, 'end');
            }
            if (this.cfg.orderTypeFilter && this.orderType) {
                p.order_type = this.orderType;
            }

            for (const k of ['source', 'head', 'rate', 'channel']) {
                if (this.$route.query[k] !== undefined && this.$route.query[k] !== '') {
                    p[k] = this.$route.query[k];
                }
            }
            return p;
        },
        /** Summary row -> the order-wise report, filtered to exactly that row. */
        drillTo(item) {
            const d = this.cfg.drill;
            if (!d) return;
            const query = { period: this.period };
            if (this.period === 'custom' && this.dateRange) {
                query.start_date = toApiDate(this.dateRange, 'start');
                query.end_date = toApiDate(this.dateRange, 'end');
            }
            for (const key of (d.params || [])) {
                if (item[key] !== undefined && item[key] !== null && item[key] !== '') {
                    query[key] = item[key];
                }
            }
            this.$router.push({ name: d.to, query });
        },
        /** A preset and a custom range are mutually exclusive. */
        selectPreset(key) {
            this.period = key;
            this.dateRange = '';
            this.load();
        },
        applyCustomRange() {
            // flatpickr fires @update mid-selection too; only fetch once BOTH ends are picked.
            if (!this.dateRange || !toApiDate(this.dateRange, 'end')) return;
            this.period = 'custom';
            this.load();
        },
        clearCustomRange() {
            this.dateRange = '';
            this.period = 'this_month';
            this.load();
        },
        load() {
            this.isLoading = true;
            this.currentPage = 1;
            axios.get(this.$apiUrl + '/reports/' + this.type, { params: this.params() })
                .then(res => { this.data = res.data.data || { summary: [], rows: [] }; })
                .catch(() => this.showError(__('something_went_wrong')))
                .finally(() => { this.isLoading = false; });
        },
        download(format) {
            this.exporting = true;
            axios.get(this.$apiUrl + '/reports/' + this.type + '/export', {
                params: { ...this.params(), format },
                responseType: 'blob',
            }).then(res => {
                const url = window.URL.createObjectURL(new Blob([res.data]));
                const a = document.createElement('a');
                a.href = url;
                a.download = `${this.type}_report.${format}`;
                document.body.appendChild(a);
                a.click();
                a.remove();
                window.URL.revokeObjectURL(url);
            }).catch(() => this.showError(__('something_went_wrong')))
                .finally(() => { this.exporting = false; });
        },
        hexToRgba(hex, alpha) {
            const h = String(hex || '').replace('#', '');
            if (h.length !== 6) return `rgba(67, 94, 190, ${alpha})`;
            const n = parseInt(h, 16);
            return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${alpha})`;
        },
        // Active period tab follows the panel's theme colour (not a hardcoded blue).
        periodStyle(key) {
            return this.period === key
                ? { background: this.primaryColor, borderColor: this.primaryColor, color: '#fff' }
                : {};
        },
        sortBy(key) {
            if (this.sortKey === key) this.sortAsc = !this.sortAsc;
            else { this.sortKey = key; this.sortAsc = false; }
        },
        // MazerDatatable reports how many rows survived the search filter.
        onFiltered(_items, count) {
            this.filteredCount = count;
            const pages = Math.max(1, Math.ceil(count / this.perPage));
            if (this.currentPage > pages) this.currentPage = pages;
        },
        isNumeric(c) {
            return ['money', 'number', 'percent'].includes(c.format);
        },

        /* ---------- formatting ---------- */
        // Backend may send a translatable name as { en: '...', ar: '...' }.
        display(v) {
            if (v && typeof v === 'object' && !Array.isArray(v)) {
                const loc = window.appLocale || localStorage.getItem('lang') || 'en';
                return v[loc] || Object.values(v).find(x => x) || '';
            }
            return v;
        },
        num(v) { return new Intl.NumberFormat().format(Number(v || 0)); },
        money(v) {
            return this.currency + new Intl.NumberFormat(undefined, {
                minimumFractionDigits: 2, maximumFractionDigits: 2,
            }).format(Number(v || 0));
        },
        compact(v) {
            const n = Number(v || 0);
            if (Math.abs(n) >= 1000) {
                return this.currency + new Intl.NumberFormat(undefined, {
                    notation: 'compact', maximumFractionDigits: 1,
                }).format(n);
            }
            return this.currency + n;
        },
        fmt(v, type) {
            if (v === null || v === undefined || v === '') return '-';
            if (type === 'money') return this.money(v);
            if (type === 'percent') return `${v}%`;
            if (type === 'number') return this.num(v);
            return this.display(v);
        },
        initials(name) {
            const n = String(this.display(name) || '').trim();
            if (!n) return '?';
            return n.split(/\s+/).slice(0, 2).map(w => w[0]).join('').toUpperCase();
        },
    },
};
</script>

<style scoped>
/* ---- heading card ---- */
/* The theme's .card clips its content, which cut off the Export dropdown. Let this one
   overflow, and lift it above the KPI/chart cards so the menu paints on top. */
.rp-head, .rp-head .card-body { overflow: visible !important; }
.rp-head { margin-bottom: 1rem; position: relative; z-index: 5; }
.rp-head-actions .dropdown-menu { z-index: 1050; }
.rp-head-row {
    display: flex; align-items: center; justify-content: space-between;
    gap: 1rem; flex-wrap: wrap;
}
.rp-head-left { display: flex; align-items: center; gap: .8rem; min-width: 0; }
.rp-icon {
    width: 44px; height: 44px; flex: 0 0 44px; border-radius: .6rem;
    display: flex; align-items: center; justify-content: center;
}
.rp-head-title {
    margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--app-ink);
    text-align: left; line-height: 1.25;
}
.rp-head-sub { color: #8f97a8; font-size: .78rem; text-align: left; }
.rp-head-actions { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }

/* ---- period filter (standalone, sits between the heading card and the KPIs) ---- */
.rp-filter {
    display: flex; align-items: center; gap: .75rem;
    flex-wrap: wrap; margin-bottom: 1rem;
}
.rp-periods {
    display: inline-flex; background: var(--app-card-bg); border: 1px solid var(--app-card-border);
    border-radius: .5rem; padding: 3px; gap: 2px; overflow-x: auto;
    max-width: 100%; scrollbar-width: none;
}
.rp-periods::-webkit-scrollbar { display: none; }
.rp-range { display: flex; align-items: center; gap: .35rem; }
.rp-range :deep(.form-control) { min-width: 210px; }
.rp-dt-select { min-width: 190px; }
.rp-period {
    border: none; background: transparent; color: var(--app-muted);
    font-size: .78rem; font-weight: 600; white-space: nowrap;
    padding: .35rem .75rem; border-radius: .4rem; cursor: pointer;
}
.rp-period:hover { background: #f3f5ff; }
/* .active colours come from :style so they follow the admin theme colour. */

/* ---- KPI cards ---- */
.rp-kpis {
    display: grid; gap: .75rem; margin-bottom: 1rem;
    grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
}
/* Cap the row at 6 so a 7+ KPI report (sales) wraps instead of squeezing into one line. */
@media (min-width: 1200px) {
    .rp-kpis { grid-template-columns: repeat(6, minmax(0, 1fr)); }
}
.rp-kpi {
    background: var(--app-card-bg); border: 1px solid var(--app-card-border); border-radius: .6rem;
    padding: .85rem 1rem;
}
.rp-kpi-label {
    color: #8f97a8; font-size: .7rem; font-weight: 600;
    text-transform: uppercase; letter-spacing: .3px;
}
.rp-kpi-value {
    font-size: 1.3rem; font-weight: 700; color: var(--app-ink);
    margin-top: .15rem; line-height: 1.2;
}
/* Last response's figure, held while the next one is in flight. */
.rp-stale { opacity: .4; transition: opacity .2s ease; }
.rp-kpi-trend { font-size: .7rem; font-weight: 600; margin-top: .2rem; }
.rp-kpi-trend.up { color: #059669; }
.rp-kpi-trend.down { color: #dc2626; }

/* ---- cards ---- */
.rp-card { border: 1px solid var(--app-card-border); border-radius: .6rem; box-shadow: none; margin-bottom: 1rem; }
.rp-card-title { font-weight: 700; font-size: .9rem; color: var(--app-ink); margin-bottom: .6rem; }

/* Apex renders a focusable SVG — the browser then paints a focus ring on click. */
:deep(.apexcharts-canvas),
:deep(.apexcharts-canvas *) { outline: none !important; }
:deep(.apexcharts-canvas svg) { -webkit-tap-highlight-color: transparent; }

/* ---- sales mode breakdown ---- */
.rp-mode-icon {
    width: 36px; height: 36px; flex: 0 0 36px; border-radius: .5rem;
    display: flex; align-items: center; justify-content: center;
}

/* ---- search ---- */
.rp-search { position: relative; }
.rp-search i {
    position: absolute; left: 10px; top: 50%; transform: translateY(-50%);
    color: #b6bdca; font-size: .75rem;
}
.rp-search input { padding-left: 28px; min-width: 200px; }

/* ---- table ---- */
.rp-table thead th {
    background: var(--app-thead-bg); color: #6b7280; font-size: .72rem; font-weight: 700;
    text-transform: uppercase; letter-spacing: .3px;
    border-bottom: 1px solid var(--app-card-border); white-space: nowrap;
}
.rp-table th.sortable { cursor: pointer; user-select: none; }
.rp-table th.sortable:hover { color: #435ebe; }
.rp-table tbody td { font-size: .85rem; border-bottom: 1px solid #f4f6f9; }
.rp-table tbody tr:hover td { background: #f9fbff; }

.rp-thumb {
    width: 32px; height: 32px; border-radius: .35rem; object-fit: cover;
    flex: 0 0 32px; border: 1px solid var(--app-card-border);
}
.rp-linkable.is-link { cursor: pointer; }
.rp-linkable.is-link:hover { color: var(--bs-primary); }
.rp-thumb-ph {
    display: flex; align-items: center; justify-content: center;
    background: #f3f5ff; color: #435ebe; font-size: .65rem; font-weight: 700;
}
</style>
