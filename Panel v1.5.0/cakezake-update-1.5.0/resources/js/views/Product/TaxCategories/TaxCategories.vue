<template>
    <div>
        <div class="list-page">
            <div class="page-head" v-if="!embedded">
                <div>
                    <h3 class="page-head-title">{{ __('tax_categories') }}</h3>
                    <p class="text-muted small mb-0">{{ __('tax_category_hint') }}</p>
                </div>
                <button v-if="$can('tax_create')"
                    class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                    @click="edit_record = true">
                    <Plus :size="16" />
                    <span>{{ __('add') }}</span>
                </button>
            </div>

            <div class="list-surface">
                <div class="list-toolbar">
                    <AppSelect class="form-select list-select list-toolbar-start" v-model="statusFilter"
                        :options="statusFilterOptions" :searchable="false" />
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
                    <template #cell(code)="row">
                        <code class="tax-code">{{ row.item.code }}</code>
                    </template>

                    <template #cell(rule_count)="row">
                        <!-- A category no jurisdiction prices taxes nothing. Worth flagging. -->
                        <span v-if="row.item.rule_count > 0" class="tax-rule-count">{{ row.item.rule_count }}</span>
                        <span v-else class="status-pill is-inactive" v-b-tooltip.hover :title="__('tax_category_no_rules_hint')">
                            {{ __('no_rules') }}
                        </span>
                    </template>

                    <template #cell(product_count)="row">
                        <span v-if="row.item.product_count > 0">{{ row.item.product_count }}</span>
                        <span v-else class="text-muted">—</span>
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
                { key: 'id', label: __('id'), class: 'text-center', sortable: true },
                { key: 'name', label: __('name'), class: 'text-center', sortable: true },
                { key: 'code', label: __('code'), class: 'text-center' },
                { key: 'rule_count', label: __('tax_rules'), class: 'text-center' },
                { key: 'product_count', label: __('products'), class: 'text-center' },
                { key: 'status', label: __('status'), class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false },
            ],
            records: [],
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            filter: null,
            statusFilter: '',
            isLoading: false,
            edit_record: null,
        };
    },
    computed: {
        statusFilterOptions() {
            return [
                { id: '', name: __('all_statuses') },
                { id: '1', name: __('active') },
                { id: '0', name: __('deactive') },
            ];
        },
        filteredRecords() {
            if (this.statusFilter === '') return this.records;
            return this.records.filter(r => String(r.status) === String(this.statusFilter));
        },
    },
    created() {
        this._recordSavedHandler = (message) => {
            this.showMessage('success', message);
            this.getRecords();
        };
        this.$eventBus.off('recordSaved', this._recordSavedHandler);
        this.$eventBus.on('recordSaved', this._recordSavedHandler);
        this.getRecords();
    },
    beforeUnmount() {
        this.$eventBus.off('recordSaved', this._recordSavedHandler);
    },
    methods: {
        /** Open the create form — used by the Tax Settings tab bar's Add button. */
        openCreate() {
            this.edit_record = true;
        },
        getRecords() {
            this.isLoading = true;
            axios.get(this.$apiUrl + '/products/tax_categories')
                .then(res => { this.records = res.data.data || []; })
                .catch(err => this.showError(err.response?.data?.message || err.message))
                .finally(() => { this.isLoading = false; });
        },
        deleteRecord(id) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('you_want_be_able_to_revert_this'),
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
                axios.post(this.$apiUrl + '/products/tax_categories/delete', fd).then(res => {
                    if (res.data.status !== 1) {
                        this.showError(res.data.message || __('something_went_wrong'));
                        return;
                    }
                    this.showMessage('success', res.data.message);
                    this.getRecords();
                }).catch(err => this.showError(err.response?.data?.message || err.message));
            });
        },
    },
};
</script>

<style scoped>
.tax-code {
    font-size: 12px;
    padding: 2px 6px;
    border-radius: 4px;
    background: rgba(128, 128, 128, .12);
}
/* bg-light-secondary paints light-on-light here, so the count was unreadable. */
.tax-rule-count {
    display: inline-block;
    min-width: 26px;
    padding: 2px 8px;
    border: 1px solid var(--app-card-border);
    border-radius: 999px;
    background: var(--app-thead-bg);
    color: var(--app-ink);
    font-size: .78rem;
    font-weight: 600;
}
</style>
