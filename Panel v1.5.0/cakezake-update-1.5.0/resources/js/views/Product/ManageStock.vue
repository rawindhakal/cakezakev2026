<template>
    <div class="stock-mgmt">
        <!-- Header banner -->
        <div class="stock-hero d-flex justify-content-between align-items-center flex-wrap gap-2">
            <div class="d-flex align-items-center gap-3">
                <div class="stock-hero-icon"><BarChart3 :size="22" /></div>
                <div>
                    <h3 class="mb-0 fw-bold">{{ __('stock_management') }}</h3>
                    <small class="text-muted">{{ __('realtime_inventory_levels') }}</small>
                </div>
            </div>
            <div class="d-flex align-items-center gap-2 flex-wrap">
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
                <div v-if="alertTotal > 0" class="stock-attention" @click="activeTab = 'alerts'">
                    <AlertTriangle :size="16" class="text-warning" />
                    {{ alertTotal }} {{ __('items_need_attention') }}
                </div>
            </div>
        </div>

        <!-- Tabs (theme btn-group) -->
        <div class="btn-group my-3" role="group">
            <button type="button" class="btn" :class="activeTab === 'overview' ? 'btn-primary' : 'btn-outline-primary'"
                @click="activeTab = 'overview'"><BarChart3 :size="15" /> {{ __('overview') }}</button>
            <button type="button" class="btn" :class="activeTab === 'inventory' ? 'btn-primary' : 'btn-outline-primary'"
                @click="activeTab = 'inventory'"><Package :size="15" /> {{ __('inventory') }}</button>
            <button type="button" class="btn" :class="activeTab === 'alerts' ? 'btn-primary' : 'btn-outline-primary'"
                @click="activeTab = 'alerts'">
                <Bell :size="15" /> {{ __('alerts') }}
                <span v-if="alertTotal > 0" class="badge bg-danger rounded-pill ms-1">{{ alertTotal }}</span>
            </button>
        </div>

        <!-- ============ OVERVIEW ============ -->
        <div v-show="activeTab === 'overview'">
            <div v-if="overviewLoading" class="text-center py-5"><b-spinner></b-spinner></div>
            <template v-else>
                <div class="row g-2 mb-3">
                    <div class="col-6 col-md-4 col-lg-2" v-for="t in overviewTiles" :key="t.key">
                        <div class="card kpi-card h-100">
                            <div class="card-body py-3 d-flex align-items-center justify-content-center gap-2">
                                <span class="kpi-ic" :class="'tone-' + t.key"><component :is="t.icon" :size="20" /></span>
                                <div>
                                    <div class="kpi-val">{{ t.value }}</div>
                                    <div class="kpi-lbl">{{ t.label }}</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <h6 class="fw-bold mb-2">{{ __('branch_wise_snapshot') }}</h6>
                <div class="row g-2">
                    <div class="col-stock5" v-for="s in overview.branches" :key="s.id">
                        <div class="card branch-card mb-0">
                            <div class="card-body p-3">
                                <div class="d-flex align-items-center gap-2 mb-3 text-start">
                                    <BranchIcon :size="20" class="text-primary" />
                                    <div>
                                        <div class="branch-name">{{ s.name }}</div>
                                        <div class="branch-city">{{ s.city }}</div>
                                    </div>
                                </div>
                                <div class="d-flex justify-content-between text-center branch-stats">
                                    <div><div class="stat-num text-success">{{ s.in_stock }}</div><div class="stat-lbl">{{ __('in_stock') }}</div></div>
                                    <div><div class="stat-num text-danger">{{ s.out }}</div><div class="stat-lbl">{{ __('out') }}</div></div>
                                    <div><div class="stat-num text-warning">{{ s.low }}</div><div class="stat-lbl">{{ __('low') }}</div></div>
                                    <div><div class="stat-num text-primary">{{ fmt(s.units) }}</div><div class="stat-lbl">{{ __('units') }}</div></div>
                                </div>
                                <hr class="my-2">
                                <div class="branch-value"><b>{{ displayCurrency }}{{ fmt(s.value) }}</b> <span>{{ __('value') }}</span></div>
                            </div>
                        </div>
                    </div>
                </div>
            </template>
        </div>

        <!-- ============ INVENTORY ============ -->
        <div v-show="activeTab === 'inventory'">
            <div class="card mb-3">
                <div class="card-body card-filter-row d-flex flex-wrap align-items-center gap-2">
                    <input type="search" class="form-control" style="flex:0 1 280px; min-width:180px"
                        v-model="inv.search" :placeholder="__('search_product_sku_variant')" @input="onInvFilter" />
                    <AppSelect class="form-select inline-select" v-model="inv.branch_id"
                        :options="branchFilterOptions" @update:model-value="loadInventory(1, true)" />
                    <AppSelect class="form-select inline-select" v-model="inv.status" :options="statusOptions"
                        :searchable="false" @update:model-value="loadInventory(1, true)" />
                    <div class="btn-group ms-auto">
                        <button class="btn" :class="inv.view === 'branch' ? 'btn-primary' : 'btn-outline-primary'"
                            @click="setView('branch')">{{ __('branch_view') }}</button>
                        <button class="btn" :class="inv.view === 'product' ? 'btn-primary' : 'btn-outline-primary'"
                            @click="setView('product')">{{ __('product_view') }}</button>
                    </div>
                </div>
            </div>

            <div v-if="invLoading" class="text-center py-5"><b-spinner></b-spinner></div>

            <!-- branch view -->
            <div v-else-if="inv.view === 'branch'" class="list-surface">
                    <MazerDatatable responsive :items="inv.rows" :fields="branchFields" :per-page="0" :busy="false"
                        small show-empty primary-key="pvss_key">
                        <template #cell(product)="row">
                            <div class="d-flex align-items-center gap-2">
                                <img v-if="row.item.image_url" :src="row.item.image_url" class="stock-thumb" @error="onImgErr" />
                                <div>
                                    <div class="fw-semibold small" :class="{ 'stock-link': canOpenProduct }"
                                        @click="openProduct(row.item.product_id)">{{ row.item.product_name }}</div>
                                    <div class="text-muted xs">SKU: {{ row.item.sku || '—' }}</div>
                                </div>
                            </div>
                        </template>
                        <template #cell(variant)="row">{{ row.item.variant_text || '—' }}</template>
                        <template #cell(branch)="row">{{ row.item.branch_name }}</template>
                        <template #cell(available)="row"><span class="badge" :class="availBadge(row.item)">{{ availText(row.item) }}</span></template>
                        <template #cell(in_stock)="row"><span class="badge" :class="row.item.in_stock ? 'bg-success-subtle text-success' : 'bg-danger-subtle text-danger'">{{ Number(row.item.is_unlimited_stock) === 1 ? __('unlimited') : (row.item.in_stock ? __('yes') : __('no')) }}</span></template>
                        <template #cell(listed)="row"><span class="badge" :class="row.item.is_listed ? 'bg-success-subtle text-success' : 'bg-secondary-subtle text-secondary'">{{ row.item.is_listed ? __('listed') : __('unlisted') }}</span></template>
                        <template #cell(adjust)="row"><button v-if="Number(row.item.is_unlimited_stock) !== 1" class="btn btn-sm btn-outline-primary" @click="openAdjust(row.item)">± {{ __('adjust') }}</button><span v-else class="text-muted small">—</span></template>
                    </MazerDatatable>
                    <div class="list-footer">
                        <div class="list-perpage">
                            <span>{{ __('per_page') }}</span>
                            <b-form-select id="per-page-select" v-model="inv.per_page" :options="$pageOptions"
                                size="sm" class="form-select" @change="loadInventory(1)"></b-form-select>
                            <span class="list-range">{{ __('total_records') }} : {{ inv.total }}</span>
                        </div>

                        <b-pagination v-model="inv.page" :total-rows="inv.total" :per-page="inv.per_page" size="sm"
                            class="mb-0 list-pagination" @update:model-value="loadInventory"></b-pagination>
                    </div>
            </div>

            <!-- product view -->
            <div v-else>
                <div class="card mb-2" v-for="g in inv.groups" :key="g.product_id">
                    <div class="card-body py-2 d-flex justify-content-between align-items-center" role="button" @click="toggleGroup(g.product_id)">
                        <div class="d-flex align-items-center gap-2 text-start">
                            <component :is="expanded[g.product_id] ? 'ChevronDown' : 'ChevronRight'" :size="16" />
                            <img v-if="g.image_url" :src="g.image_url" class="stock-thumb" @error="onImgErr" />
                            <div>
                                <div class="fw-bold small" :class="{ 'stock-link': canOpenProduct }"
                                    @click.stop="openProduct(g.product_id)">{{ g.name }}</div>
                                <div class="text-muted xs">SKU: {{ g.sku || '—' }} · {{ g.brand || '—' }} · {{ g.branch_variants }} {{ __('branch_variants') }}</div>
                            </div>
                        </div>
                        <span class="badge bg-light text-dark">{{ fmt(g.units_total) }} {{ __('units_total') }}</span>
                    </div>
                    <div v-if="expanded[g.product_id]" class="card-body pt-0">
                        <MazerDatatable responsive :items="g.variants" :fields="variantFields" :per-page="0" :busy="false"
                            small primary-key="pvss_key">
                            <template #cell(variant)="row">
                                <div class="d-flex align-items-center gap-2">
                                    <img v-if="row.item.image_url" :src="row.item.image_url" class="stock-thumb" @error="onImgErr" />
                                    <span>{{ row.item.variant_text || __('no_variant') }}</span>
                                </div>
                            </template>
                            <template #cell(branch)="row"><BranchIcon :size="14" class="text-primary" /> {{ row.item.branch_name }}<span v-if="row.item.branch_city" class="text-muted"> · {{ row.item.branch_city }}</span></template>
                            <template #cell(available)="row"><span class="badge" :class="availBadge(row.item)">{{ availText(row.item) }}</span></template>
                            <template #cell(in_stock)="row"><span class="badge" :class="row.item.in_stock ? 'bg-success-subtle text-success' : 'bg-danger-subtle text-danger'">{{ Number(row.item.is_unlimited_stock) === 1 ? __('unlimited') : (row.item.in_stock ? __('yes') : __('no')) }}</span></template>
                            <template #cell(listed)="row"><span class="badge" :class="row.item.is_listed ? 'bg-success-subtle text-success' : 'bg-secondary-subtle text-secondary'">{{ row.item.is_listed ? __('listed') : __('unlisted') }}</span></template>
                            <template #cell(adjust)="row"><button v-if="Number(row.item.is_unlimited_stock) !== 1" class="btn btn-sm btn-outline-primary" @click="openAdjust(row.item)">± {{ __('adjust') }}</button><span v-else class="text-muted small">—</span></template>
                        </MazerDatatable>
                    </div>
                </div>
                <p v-if="!inv.groups.length" class="text-center text-muted py-4">{{ __('no_records_found') }}</p>
                <div class="list-surface">
                    <div class="list-footer">
                        <div class="list-perpage">
                            <span>{{ __('per_page') }}</span>
                            <b-form-select v-model="inv.per_page" :options="$pageOptions" size="sm"
                                class="form-select" @change="loadInventory(1)"></b-form-select>
                            <span class="list-range">{{ __('total_records') }} : {{ inv.total }}</span>
                        </div>

                        <b-pagination v-model="inv.page" :total-rows="inv.total" :per-page="inv.per_page" size="sm"
                            class="mb-0 list-pagination" @update:model-value="loadInventory"></b-pagination>
                    </div>
                </div>
            </div>
        </div>

        <!-- ============ ALERTS ============ -->
        <div v-show="activeTab === 'alerts'">
            <div v-if="alertsLoading" class="text-center py-5"><b-spinner></b-spinner></div>
            <template v-else>
                <div class="d-flex gap-2 mb-3">
                    <span class="alert-chip out"><XCircle :size="14" /> {{ alerts.out_count }} {{ __('out_of_stock') }}</span>
                    <span class="alert-chip low"><AlertTriangle :size="14" /> {{ alerts.low_count }} {{ __('low_stock') }}</span>
                </div>
                <p v-if="!alertTotal" class="text-center text-muted py-4">{{ __('no_records_found') }}</p>
                <div class="alert-row out mb-2" v-for="r in alerts.out_of_stock" :key="'o-' + r.branch_id + '-' + r.product_variant_id">
                    <XCircle :size="22" class="text-danger" />
                    <div class="flex-grow-1">
                        <div class="fw-bold small"><span :class="{ 'stock-link': canOpenProduct }"
                            @click="openProduct(r.product_id)">{{ r.product_name }}</span><span v-if="r.variant_text" class="text-muted"> · {{ r.variant_text }}</span></div>
                        <div class="text-muted xs"><MapPin :size="12" /> {{ r.branch_name }}</div>
                    </div>
                    <div class="text-end me-2"><span class="badge bg-danger-subtle text-danger">{{ r.available }} {{ __('units') }}</span><div class="text-muted xs">{{ __('min') }}: {{ r.min_alert }}</div></div>
                    <button class="btn btn-sm btn-outline-success" @click="openAdjust(r)">{{ __('restock') }} →</button>
                </div>
                <div class="alert-row low mb-2" v-for="r in alerts.low_stock" :key="'l-' + r.branch_id + '-' + r.product_variant_id">
                    <AlertTriangle :size="22" class="text-warning" />
                    <div class="flex-grow-1">
                        <div class="fw-bold small"><span :class="{ 'stock-link': canOpenProduct }"
                            @click="openProduct(r.product_id)">{{ r.product_name }}</span><span v-if="r.variant_text" class="text-muted"> · {{ r.variant_text }}</span></div>
                        <div class="text-muted xs"><MapPin :size="12" /> {{ r.branch_name }}</div>
                    </div>
                    <div class="text-end me-2"><span class="badge bg-warning-subtle text-warning">{{ r.available }} {{ __('units') }}</span><div class="text-muted xs">{{ __('min') }}: {{ r.min_alert }}</div></div>
                    <button class="btn btn-sm btn-outline-success" @click="openAdjust(r)">{{ __('restock') }} →</button>
                </div>
            </template>
        </div>

        <!-- Adjust modal -->
        <b-modal v-model="adjust.show" :title="__('adjust_stock')" :no-footer="true" centered>
            <div v-if="adjust.row">
                <div class="border rounded p-3 mb-3 bg-light">
                    <div class="fw-bold">{{ adjust.row.product_name }}<span v-if="adjust.row.variant_text" class="text-muted small"> · {{ adjust.row.variant_text }}</span></div>
                    <div class="small text-muted"><MapPin :size="13" /> {{ adjust.row.branch_name }}</div>
                    <div class="small mt-1">{{ __('current_stock') }}: <span class="badge" :class="availBadge(adjust.row)">{{ adjust.row.available }}</span></div>
                </div>
                <label class="form-label small text-uppercase text-muted">{{ __('action') }}</label>
                <div class="d-flex gap-2 mb-3">
                    <button class="btn flex-fill" :class="adjust.action === 'add' ? 'btn-primary' : 'btn-outline-secondary'" @click="adjust.action = 'add'"><Plus :size="15" /> {{ __('add') }}</button>
                    <button class="btn flex-fill" :class="adjust.action === 'remove' ? 'btn-primary' : 'btn-outline-secondary'" :disabled="removeDisabled" @click="adjust.action = 'remove'"
                        v-b-tooltip.hover :title="removeDisabled ? __('no_stock_available_to_remove') : ''"><Minus :size="15" /> {{ __('remove') }}</button>
                    <button class="btn flex-fill" :class="adjust.action === 'set' ? 'btn-primary' : 'btn-outline-secondary'" @click="adjust.action = 'set'"><Pin :size="15" /> {{ __('set_to') }}</button>
                </div>
                <label class="form-label small text-uppercase text-muted">{{ __('quantity') }}</label>
                <input type="number" min="0" class="form-control" v-model.number="adjust.qty" :placeholder="__('amount')" />
                <div v-if="hasQty" class="border rounded p-2 mt-3 small bg-light">
                    {{ __('result') }}: <b>{{ resultUnits }} {{ __('units') }}</b>
                    <span v-if="resultHint" class="text-warning">— {{ resultHint }}</span>
                </div>
                <div class="text-end mt-3">
                    <button class="btn btn-secondary me-2" @click="adjust.show = false">{{ __('cancel') }}</button>
                    <button class="btn btn-primary" :disabled="adjust.saving" @click="applyAdjust">
                        <b-spinner small v-if="adjust.saving"></b-spinner>
                        {{ adjust.saving ? __('saving') : __('apply') }}
                    </button>
                </div>
            </div>
        </b-modal>
    </div>
</template>

<script>
import { markRaw } from "vue";
import axios from "axios";
import {
    BarChart3, AlertTriangle, Package, Bell, Store as BranchIcon, ChevronDown, ChevronRight,
    XCircle, CheckCircle2, Tag, DollarSign, MapPin, Plus, Minus, Pin,
} from 'lucide-vue-next';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';

export default {
    mixins: [CountryZoneFilter],
    components: {
        BarChart3, AlertTriangle, Package, Bell, BranchIcon, ChevronDown, ChevronRight,
        XCircle, CheckCircle2, Tag, DollarSign, MapPin, Plus, Minus, Pin,
    },
    data() {
        return {
            activeTab: 'overview',
            branches: [],

            overview: { totals: {}, branches: [] },
            overviewLoading: false,

            inv: { view: 'branch', search: '', branch_id: 0, status: 'all', page: 1, per_page: 20, total: 0, rows: [], groups: [] },
            invLoading: false,
            expanded: {},
            _searchTimer: null,
            branchFields: [
                { key: 'product', label: __('product'), sortable: false, class: 'text-start' },
                { key: 'variant', label: __('variant'), sortable: false, class: 'text-start' },
                { key: 'branch', label: __('branch'), sortable: false, class: 'text-start' },
                { key: 'available', label: __('available'), sortable: false, class: 'text-start' },
                { key: 'reserved', label: __('reserved'), sortable: false, class: 'text-start' },
                { key: 'min_alert', label: __('min_alert'), sortable: false, class: 'text-start' },
                { key: 'in_stock', label: __('in_stock'), sortable: false, class: 'text-start' },
                { key: 'listed', label: __('listed'), sortable: false, class: 'text-start' },
                { key: 'adjust', label: __('adjust'), sortable: false, class: 'text-start' },
            ],
            variantFields: [
                { key: 'variant', label: __('variant'), sortable: false, class: 'text-start' },
                { key: 'branch', label: __('branch'), sortable: false, class: 'text-start' },
                { key: 'available', label: __('available'), sortable: false, class: 'text-start' },
                { key: 'reserved', label: __('reserved'), sortable: false, class: 'text-start' },
                { key: 'min_alert', label: __('min_alert'), sortable: false, class: 'text-start' },
                { key: 'in_stock', label: __('in_stock'), sortable: false, class: 'text-start' },
                { key: 'listed', label: __('listed'), sortable: false, class: 'text-start' },
                { key: 'adjust', label: __('adjust'), sortable: false, class: 'text-start' },
            ],

            alerts: { out_of_stock: [], low_stock: [], out_count: 0, low_count: 0, total: 0 },
            alertsLoading: false,

            adjust: { show: false, row: null, action: 'add', qty: null, saving: false },
        };
    },
    computed: {
        // /products/view/:id is guarded by product_list — don't offer the link without it.
        canOpenProduct() { return this.$can('product_list'); },
        branchFilterOptions() {
            return [{ id: 0, name: __('all_branches') }].concat(this.branches || []);
        },
        // Fixed option set — no search box needed.
        statusOptions() {
            return [
                { id: 'all', name: (__('all_statuses')) },
                { id: 'in_stock', name: (__('in_stock')) },
                { id: 'out_of_stock', name: (__('out_of_stock')) },
                { id: 'unlimited', name: (__('unlimited')) },
                { id: 'low_stock', name: (__('low_stock')) },
                { id: 'unlisted', name: (__('unlisted')) },
            ];
        },
        alertTotal() { return this.alerts.total || 0; },
        hasQty() { return this.adjust.qty !== null && this.adjust.qty !== ''; },
        // Header-selected currency, falling back to the global default.
        displayCurrency() { return this.czCurrency || this.$currency; },
        overviewTiles() {
            const t = this.overview.totals || {};
            return [
                { key: 'total', icon: markRaw(Package), label: __('total_skus'), value: this.fmt(t.total_skus) },
                { key: 'in', icon: markRaw(CheckCircle2), label: __('in_stock'), value: this.fmt(t.in_stock) },
                { key: 'out', icon: markRaw(XCircle), label: __('out_of_stock'), value: this.fmt(t.out_of_stock) },
                { key: 'low', icon: markRaw(AlertTriangle), label: __('low_stock'), value: this.fmt(t.low_stock) },
                { key: 'listed', icon: markRaw(Tag), label: __('listed_skus'), value: this.fmt(t.listed_skus) },
                { key: 'units', icon: markRaw(BarChart3), label: __('total_units'), value: this.fmt(t.total_units) },
                { key: 'value', icon: markRaw(DollarSign), label: __('inventory_value'), value: this.displayCurrency + this.fmt(t.inventory_value) },
                { key: 'branches', icon: markRaw(BranchIcon), label: __('active_branches'), value: this.fmt(t.active_branches) },
            ];
        },
        // Nothing to remove when current stock is 0 (and it isn't unlimited).
        removeDisabled() {
            if (!this.adjust.row) return true;
            if (Number(this.adjust.row.is_unlimited_stock) === 1) return false;
            return Number(this.adjust.row.available) <= 0;
        },
        resultUnits() {
            const cur = this.adjust.row ? Number(this.adjust.row.available) : 0;
            const q = Number(this.adjust.qty) || 0;
            if (this.adjust.action === 'add') return cur + q;
            if (this.adjust.action === 'remove') return Math.max(0, cur - q);
            return q;
        },
        resultHint() {
            const r = this.resultUnits;
            const min = this.adjust.row ? Number(this.adjust.row.min_alert) : 0;
            if (r <= 0) return __('will_be_marked_out_of_stock');
            if (min > 0 && r <= min) return __('still_below_min_alert') + ' (' + min + ')';
            return '';
        },
    },
    created() {
        this.czLoad(); // sets default country then czOnFilter (loads overview/alerts)
    },
    watch: {
        activeTab(tab) {
            if (tab === 'inventory' && !this.inv.rows.length && !this.inv.groups.length) this.loadInventory(1);
            if (tab === 'alerts') this.loadAlerts();
            if (tab === 'overview') this.loadOverview();
        },
    },
    methods: {
        openProduct(id) {
            if (!id || !this.canOpenProduct) return;
            this.$router.push('/products/view/' + id);
        },
        czOnFilter() {
            this.branches = [];
            this.loadOverview();
            this.loadAlerts();
            if (this.activeTab === 'inventory') this.loadInventory(1, true);
        },
        fmt(n) { return (Number(n) || 0).toLocaleString(); },
        globalFilter() {
            return {
                country_id: this.czCountryParam,
                zone_id: this.czZoneParam,
            };
        },
        onImgErr(e) { e.target.style.display = 'none'; },
        availBadge(r) {
            // Unlimited branches don't track stock — never show them as low/out.
            if (Number(r.is_unlimited_stock) === 1) return 'bg-info-subtle text-info';
            if (!r.in_stock || r.available <= 0) return 'bg-danger-subtle text-danger';
            if (r.min_alert > 0 && r.available <= r.min_alert) return 'bg-warning-subtle text-warning';
            return 'bg-success-subtle text-success';
        },
        /** Displayed quantity: unlimited rows have no meaningful number. */
        availText(r) {
            return Number(r.is_unlimited_stock) === 1 ? '\u221E' : r.available;
        },
        withKeys(rows) {
            return (rows || []).map(r => ({ ...r, pvss_key: r.branch_id + '-' + r.product_variant_id }));
        },
        loadOverview() {
            this.overviewLoading = true;
            axios.get(this.$apiUrl + '/products/stock/overview', { params: this.globalFilter() }).then(r => {
                this.overview = r.data.data || { totals: {}, branches: [] };
                if (!this.branches.length) this.branches = this.overview.branches.map(s => ({ id: s.id, name: s.name }));
            }).catch(() => { }).finally(() => { this.overviewLoading = false; });
        },
        onInvFilter() {
            if (this._searchTimer) clearTimeout(this._searchTimer);
            this._searchTimer = setTimeout(() => this.loadInventory(1, true), 350);
        },
        setView(v) {
            if (this.inv.view === v) return;
            this.inv.view = v;
            this.loadInventory(1, true);
        },
        toggleGroup(id) {
            this.expanded = { ...this.expanded, [id]: !this.expanded[id] };
        },
        loadInventory(page, resetExpand) {
            this.inv.page = page || this.inv.page;
            if (resetExpand) this.expanded = {}; // collapse on filter/view change
            this.invLoading = true;
            axios.get(this.$apiUrl + '/products/stock/inventory', {
                params: {
                    view: this.inv.view, search: this.inv.search, branch_id: this.inv.branch_id,
                    status: this.inv.status, page: this.inv.page, per_page: this.inv.per_page,
                    ...this.globalFilter(),
                },
            }).then(r => {
                const d = r.data.data || {};
                this.inv.total = r.data.total || 0;
                if (this.inv.view === 'product') {
                    this.inv.groups = (d.groups || []).map(g => ({ ...g, variants: this.withKeys(g.variants) }));
                    this.inv.rows = [];
                } else {
                    this.inv.rows = this.withKeys(d.rows || []);
                    this.inv.groups = [];
                }
            }).catch(() => { this.inv.rows = []; this.inv.groups = []; this.inv.total = 0; })
                .finally(() => { this.invLoading = false; });
        },
        loadAlerts() {
            this.alertsLoading = true;
            axios.get(this.$apiUrl + '/products/stock/alerts', { params: this.globalFilter() }).then(r => {
                this.alerts = r.data.data || { out_of_stock: [], low_stock: [], out_count: 0, low_count: 0, total: 0 };
            }).catch(() => { }).finally(() => { this.alertsLoading = false; });
        },
        openAdjust(row) {
            this.adjust.row = { ...row };
            this.adjust.action = 'add';
            this.adjust.qty = null;
            this.adjust.show = true;
        },
        applyAdjust() {
            if (this.adjust.qty === null || this.adjust.qty === '' || Number(this.adjust.qty) < 0) {
                this.showError(__('please_enter_quantity'));
                return;
            }
            // Can't remove stock that isn't there.
            if (this.adjust.action === 'remove' && this.removeDisabled) {
                this.showError(__('no_stock_available_to_remove'));
                return;
            }
            this.adjust.saving = true;
            axios.post(this.$apiUrl + '/products/stock/adjust', {
                product_variant_id: this.adjust.row.product_variant_id,
                branch_id: this.adjust.row.branch_id,
                action: this.adjust.action,
                quantity: Number(this.adjust.qty),
            }).then(r => {
                this.showMessage('success', r.data.message);
                this.adjust.show = false;
                this.loadOverview();
                this.loadAlerts();
                if (this.activeTab === 'inventory') this.loadInventory(this.inv.page);
            }).catch(e => {
                this.showError(e.response?.data?.message || __('something_went_wrong'));
            }).finally(() => { this.adjust.saving = false; });
        },
    },
};
</script>

<style scoped>
.stock-hero {
    background: var(--app-card-bg);
    border: 1px solid var(--app-card-border);
    border-radius: 1rem;
    padding: 1.25rem 1.5rem;
}
.stock-hero-icon {
    width: 44px; height: 44px; border-radius: .6rem;
    background: var(--app-thead-bg); color: var(--app-muted);
    display: flex; align-items: center; justify-content: center; font-size: 1.2rem;
}
/* Branch-wise snapshot: 4 per row on large screens. */
.col-stock5 { flex: 0 0 auto; width: 25%; }
@media (max-width: 991.98px) { .col-stock5 { width: 33.333%; } }
@media (max-width: 767.98px) { .col-stock5 { width: 50%; } }
@media (max-width: 479.98px) { .col-stock5 { width: 100%; } }
.stock-attention {
    display: inline-flex; align-items: center; gap: .4rem;
    background: rgba(245, 158, 11, .14); color: #b45309; font-weight: 600; font-size: .85rem;
    padding: .5rem .9rem; border-radius: .6rem; cursor: pointer;
}
.stock-attention svg { flex-shrink: 0; }
.kpi-card { border: 1px solid var(--app-card-border); }
/* KPI icon: lucide SVG in a tinted chip, one semantic tone per tile. */
.kpi-ic {
    width: 38px; height: 38px; flex: none;
    display: inline-flex; align-items: center; justify-content: center;
    border-radius: 10px;
    background: rgba(var(--bs-primary-rgb), .1);
    color: var(--bs-primary);
}
.kpi-ic.tone-total { background: rgba(59,130,246,.12); color: #3b82f6; }
.kpi-ic.tone-in { background: rgba(34,197,94,.12); color: #16a34a; }
.kpi-ic.tone-out { background: rgba(239,68,68,.12); color: #dc2626; }
.kpi-ic.tone-low { background: rgba(245,158,11,.14); color: #d97706; }
.kpi-ic.tone-listed { background: rgba(139,92,246,.12); color: #8b5cf6; }
.kpi-ic.tone-units { background: rgba(6,182,212,.12); color: #0891b2; }
.kpi-ic.tone-value { background: rgba(16,185,129,.12); color: #059669; }
.kpi-ic.tone-branches { background: rgba(var(--bs-primary-rgb),.12); color: var(--bs-primary); }
.stock-hero-icon svg { color: var(--bs-primary); }
.alert-chip { display: inline-flex; align-items: center; gap: .35rem; }
/* Inline lucide icons next to text. No `.stock-mgmt` ancestor — the adjust modal
   is portaled to <body>, so an ancestor selector would miss it; the scoped
   data-attribute alone still targets this component's markup. */
.text-muted svg,
td svg,
th svg {
    display: inline-block;
    vertical-align: -2px;
}
/* Keep icon + text on one row wherever a line actually contains an icon. */
.text-muted:has(> svg),
td:has(> svg) {
    display: inline-flex;
    align-items: center;
    gap: .3rem;
}
.kpi-val { font-size: 1.3rem; font-weight: 800; line-height: 1; }
.kpi-lbl { font-size: 12.16px; color: var(--app-muted); }
.branch-card { border: 1px solid var(--app-card-border); }
.branch-name { font-weight: 700; font-size: .95rem; color: var(--app-ink); }

/* Product names link through to the product page; colour is inherited so the
   rows keep their existing look, only the cursor marks them as clickable. */
.stock-link { cursor: pointer; }
.stock-link:hover { color: var(--bs-primary); }
.branch-city { font-size: .78rem; color: var(--app-muted); }
/* Match the KPI card numbers (.kpi-val). */
.branch-stats .stat-num { font-weight: 800; font-size: 1.2rem; line-height: 1; }
.branch-stats .stat-lbl { font-size: .78rem; color: var(--app-muted); margin-top: 2px; }
.branch-value { font-size: .9rem; color: var(--app-ink); }
.branch-value b { font-weight: 700; }
.branch-value span { color: var(--app-muted); }
.xs { font-size: .68rem; }
.stock-thumb {
    width: 34px; height: 34px; object-fit: contain;
    background: var(--app-thead-bg); border-radius: 6px; flex: none;
}
.alert-chip {
    font-weight: 600; font-size: .8rem; padding: .35rem .8rem; border-radius: 2rem;
}
.alert-chip.out { background: rgba(239, 68, 68, .12); color: #dc2626; }
.alert-chip.low { background: rgba(245, 158, 11, .14); color: #b45309; }

/* The amber ink is tuned for a light tint; on the dark sheet it goes muddy, so
   lift it (and the same pairing on the header chip) a couple of steps. */
body.theme-dark .stock-attention,
body.theme-dark .alert-chip.low {
    color: #fbbf24;
}
.alert-row {
    display: flex; align-items: center; gap: .75rem;
    border: 1px solid var(--app-card-border); border-radius: .6rem; padding: .75rem 1rem; background: var(--app-card-bg);
}
.alert-row.out { border-color: rgba(239, 68, 68, .35); background: rgba(239, 68, 68, .07); }
.alert-row.low { border-color: rgba(245, 158, 11, .4); background: rgba(245, 158, 11, .08); }
</style>
