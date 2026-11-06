<template>
    <div>
        <div class="list-page">
            <div class="page-head" v-if="!embedded">
                <div>
                    <h3 class="page-head-title">{{ __('tax_rules') }}</h3>
                    <p class="text-muted small mb-0">{{ __('tax_rule_hint') }}</p>
                </div>
                <button v-if="$can('tax_create')"
                    class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                    @click="edit_record = true">
                    <Plus :size="16" />
                    <span>{{ __('add') }}</span>
                </button>
            </div>

            <div v-if="coverageGaps.length" class="alert alert-warning tax-coverage-alert">
                <strong>{{ __('tax_not_configured') }}</strong>
                <ul class="mb-0 mt-1">
                    <li v-for="gap in coverageGaps" :key="gap.country_id">
                        {{ gap.country_name }} — {{ gap.categories.join(', ') }}
                        <span v-if="gap.product_count" class="text-muted">
                            ({{ gap.product_count }} {{ __('products').toLowerCase() }})
                        </span>
                    </li>
                </ul>
            </div>

            <div class="list-surface">
                <div class="list-toolbar">
                    <div class="list-toolbar-start d-flex flex-wrap gap-2">
                        <AppSelect class="form-select list-select" v-model="countryFilter"
                            :options="countryOptions" :searchable="true" />
                        <AppSelect class="form-select list-select" v-model="categoryFilter"
                            :options="categoryOptions" :searchable="true" />
                    </div>
                    <div class="list-search">
                        <Search class="list-search-icon" />
                        <input v-model="filter" type="search" class="form-control" :placeholder="__('search')">
                    </div>
                    <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getRecords()">
                        <RefreshCw :class="{ 'is-spinning': isLoading }" />
                    </button>
                </div>

                <MazerDatatable responsive :items="filteredRecords" :fields="fields" :current-page="currentPage"
                    :per-page="perPage" :filter="filter" :busy="isLoading" stacked="md" show-empty small>
                    <template #cell(jurisdiction)="row">
                        <div class="rule-jurisdiction">
                            <span class="fw-semibold">{{ row.item.country?.name || '—' }}</span>
                            <span v-if="row.item.region" class="text-muted small">{{ row.item.region.name }}</span>
                            <span v-else class="text-muted small">{{ __('whole_country') }}</span>
                        </div>
                    </template>

                    <template #cell(tax_category)="row">
                        <span v-if="row.item.tax_category">{{ row.item.tax_category.name }}</span>
                        <!-- Pre-existing rule from when the category was optional. Every rule
                             names a category now, so this one taxes nothing. -->
                        <span v-else class="status-pill is-warning" v-b-tooltip.hover
                            :title="__('rule_without_category_inactive_hint')">
                            {{ __('no_tax_category') }}
                        </span>
                    </template>

                    <template #cell(place_of_supply)="row">
                        <span class="status-pill" :class="supplyClass(row.item.place_of_supply)">
                            {{ supplyLabel(row.item.place_of_supply) }}
                        </span>
                    </template>

                    <!-- The components ARE the rate. Showing them inline is the whole point:
                         one glance tells you CGST 9 + SGST 9 lands on the same 18 as IGST 18. -->
                    <template #cell(components)="row">
                        <div class="rule-components">
                            <span v-for="c in (row.item.components || [])" :key="c.id" class="component-chip">
                                {{ c.name }} {{ trimRate(c.rate) }}%
                            </span>
                        </div>
                    </template>

                    <template #cell(total_rate)="row">
                        <strong>{{ trimRate(row.item.total_rate) }}%</strong>
                    </template>


                    <template #cell(status)="row">
                        <span v-if="row.item.status == 1" class="status-pill is-active">{{ __('active') }}</span>
                        <span v-else class="status-pill is-inactive">{{ __('deactive') }}</span>
                    </template>

                    <template #cell(actions)="row">
                        <div class="list-actions">
                            <span v-if="!$can('tax_update') && !$can('tax_delete')" class="text-muted small">—</span>
                            <button v-if="$can('tax_update')" class="list-action-btn is-edit" @click="edit_record = row.item"
                                v-b-tooltip.hover :title="__('edit')"><Pencil :size="15" /></button>
                            <button v-if="$can('tax_delete')" class="list-action-btn is-delete"
                                @click="deleteRecord(row.item.id)" v-b-tooltip.hover :title="__('delete')"><Trash2 :size="15" /></button>
                        </div>
                    </template>
                </MazerDatatable>

                <div class="list-footer">
                    <div class="list-perpage">
                        <span>{{ __('per_page') }}</span>
                        <b-form-select v-model="perPage" :options="pageOptions" size="sm" class="form-select"></b-form-select>
                        <span class="list-range">{{ __('total_records') }} : {{ filteredRecords.length }}</span>
                    </div>
                    <b-pagination v-model="currentPage" :total-rows="filteredRecords.length" :per-page="perPage" size="sm"
                        class="mb-0 list-pagination"></b-pagination>
                </div>
            </div>
        </div>

        <app-edit-record v-if="edit_record" :record="edit_record" @modalClose="edit_record = null"></app-edit-record>
    </div>
</template>

<script>
import EditRecord from './Edit.vue';
import { Search, RefreshCw, Plus, Pencil, Trash2 } from 'lucide-vue-next';

export default {
    components: { 'app-edit-record': EditRecord, Search, RefreshCw, Plus, Pencil, Trash2 },
    props: {
        // Rendered inside the Tax Settings tabs: the wrapper owns the heading and the
        // Add button (which calls openCreate() through a ref).
        embedded: { type: Boolean, default: false },
    },
    data() {
        return {
            fields: [
                { key: 'jurisdiction', label: __('jurisdiction'), class: 'text-center' },
                { key: 'tax_category', label: __('tax_category'), class: 'text-center' },
                { key: 'place_of_supply', label: __('place_of_supply'), class: 'text-center' },
                { key: 'components', label: __('tax_components'), class: 'text-center' },
                { key: 'total_rate', label: __('total_rate'), class: 'text-center' },
                { key: 'status', label: __('status'), class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false },
            ],
            records: [],
            countries: [],
            categories: [],
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            filter: null,
            countryFilter: '',
            categoryFilter: '',
            isLoading: false,
            edit_record: null,
            coverageGaps: [],
        };
    },
    computed: {
        countryOptions() {
            return [{ id: '', name: __('all_countries') }].concat(
                this.countries.map(c => ({ id: String(c.id), name: c.name }))
            );
        },
        categoryOptions() {
            return [{ id: '', name: __('all_tax_categories') }].concat(
                this.categories.map(c => ({ id: String(c.id), name: c.name }))
            );
        },
        filteredRecords() {
            return this.records.filter(r => {
                if (this.countryFilter !== '' && String(r.country_id) !== String(this.countryFilter)) return false;
                if (this.categoryFilter !== '' && String(r.tax_category_id) !== String(this.categoryFilter)) return false;
                return true;
            });
        },
    },
    created() {
        this._recordSavedHandler = (message) => {
            this.showMessage('success', message);
            this.getRecords();
            this.loadCoverage();
        };
        this.$eventBus.off('recordSaved', this._recordSavedHandler);
        this.$eventBus.on('recordSaved', this._recordSavedHandler);
        this.loadLookups();
        this.getRecords();
        this.loadCoverage();
    },
    beforeUnmount() {
        this.$eventBus.off('recordSaved', this._recordSavedHandler);
    },
    methods: {
        /** Open the create form — used by the Tax Settings tab bar's Add button. */
        openCreate() {
            this.edit_record = true;
        },
        trimRate(rate) {
            const n = Number(rate || 0);
            return Number.isInteger(n) ? String(n) : String(parseFloat(n.toFixed(3)));
        },
        supplyLabel(value) {
            if (value === 'intra') return __('supply_intra');
            if (value === 'inter') return __('supply_inter');
            return __('supply_any');
        },
        supplyClass(value) {
            if (value === 'intra') return 'is-active';
            if (value === 'inter') return 'is-warning';
            return 'is-inactive';
        },
        loadCoverage() {
            axios.get(this.$apiUrl + '/products/tax_rules/coverage')
                .then(res => { this.coverageGaps = res.data.data || []; })
                .catch(() => { this.coverageGaps = []; });
        },
        loadLookups() {
            axios.get(this.$apiUrl + '/countries').then(res => { this.countries = res.data.data || []; }).catch(() => {});
            axios.get(this.$apiUrl + '/products/tax_categories', { params: { status: 1 } })
                .then(res => { this.categories = res.data.data || []; }).catch(() => {});
        },
        getRecords() {
            this.isLoading = true;
            axios.get(this.$apiUrl + '/products/tax_rules')
                .then(res => { this.records = res.data.data || []; })
                .catch(err => this.showError(err.response?.data?.message || err.message))
                .finally(() => { this.isLoading = false; });
        },
        deleteRecord(id) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('tax_rule_delete_note'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: __('yes_sure'),
                cancelButtonText: __('cancel'),
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (!result.isConfirmed) return;
                const fd = new FormData();
                fd.append('id', id);
                axios.post(this.$apiUrl + '/products/tax_rules/delete', fd).then(res => {
                    if (res.data.status !== 1) { this.showError(res.data.message || __('something_went_wrong')); return; }
                    this.showMessage('success', res.data.message);
                    this.getRecords();
                }).catch(err => this.showError(err.response?.data?.message || err.message));
            });
        },
    },
};
</script>

<style scoped>
.rule-jurisdiction { display: flex; flex-direction: column; align-items: center; line-height: 1.3; }
.rule-components { display: flex; flex-wrap: wrap; gap: 4px; justify-content: center; }
.component-chip {
    font-size: 12px;
    padding: 2px 8px;
    border-radius: 999px;
    background: rgba(var(--bs-primary-rgb, 66 99 235), .1);
    white-space: nowrap;
}
.status-pill.is-warning { background: rgba(255, 171, 0, .15); color: #b26a00; }
.tax-coverage-alert { font-size: 13px; }
.tax-coverage-alert ul { padding-left: 18px; }
</style>
