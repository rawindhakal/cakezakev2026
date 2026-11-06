<template>
    <div>
        <div class="list-page">
            <div class="page-head">
                <div>
                    <h3 class="page-head-title">
                        {{ __('regions') }}
                        <span class="text-muted fw-normal" v-if="country"> — {{ country.name }}</span>
                    </h3>
                    <p class="text-muted small mb-0">{{ __('regions_hint') }}</p>
                </div>

                <div class="page-head-actions">
                    <button class="btn btn-outline-secondary list-add-btn" @click="$router.push('/countries')">
                        <ArrowLeft :size="16" />
                        <span>{{ __('back') }}</span>
                    </button>
                    <button class="btn btn-outline-primary list-add-btn" v-if="$can('country_update')" @click="openImport">
                        <Download :size="16" />
                        <span>{{ __('import') }}</span>
                    </button>
                    <button class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                        v-if="$can('country_update')" @click="openForm()">
                        <Plus :size="16" />
                        <span>{{ __('add') }}</span>
                    </button>
                </div>
            </div>

            <div class="list-surface">
                <div class="list-toolbar">
                    <div class="list-search">
                        <Search class="list-search-icon" />
                        <input v-model="filter" type="search" class="form-control" :placeholder="__('search')">
                    </div>
                    <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getRecords()">
                        <RefreshCw :class="{ 'is-spinning': isLoading }" />
                    </button>
                </div>

                <MazerDatatable responsive :items="records" :fields="fields" :current-page="currentPage"
                    :per-page="perPage" :filter="filter" :busy="isLoading" stacked="md" show-empty small>
                    <template #cell(code)="row">
                        <code class="region-code">{{ row.item.code || '—' }}</code>
                    </template>

                    <!-- The jurisdiction's own code, where it has one. India's GST state
                         code prints on every invoice as the place of supply. -->
                    <template #cell(tax_code)="row">
                        <span v-if="row.item.tax_code">{{ row.item.tax_code }}</span>
                        <span v-else class="text-muted">—</span>
                    </template>

                    <template #cell(type)="row">
                        <span class="text-capitalize">{{ String(row.item.type || '').replace('_', ' ') }}</span>
                    </template>

                    <template #cell(status)="row">
                        <span v-if="row.item.status == 1" class="status-pill is-active">{{ __('active') }}</span>
                        <span v-else class="status-pill is-inactive">{{ __('deactive') }}</span>
                    </template>

                    <template #cell(actions)="row">
                        <div class="list-actions">
                            <button v-if="$can('country_update')" class="list-action-btn is-edit" @click="openForm(row.item)"
                                v-b-tooltip.hover :title="__('edit')"><Pencil :size="15" /></button>
                            <button v-if="$can('country_delete')" class="list-action-btn is-delete"
                                @click="deleteRecord(row.item.id)" v-b-tooltip.hover :title="__('delete')"><Trash2 :size="15" /></button>
                        </div>
                    </template>
                </MazerDatatable>

                <div class="list-footer">
                    <div class="list-perpage">
                        <span>{{ __('per_page') }}</span>
                        <b-form-select v-model="perPage" :options="pageOptions" size="sm" class="form-select"></b-form-select>
                        <span class="list-range">{{ __('total_records') }} : {{ records.length }}</span>
                    </div>
                    <b-pagination v-model="currentPage" :total-rows="records.length" :per-page="perPage" size="sm"
                        class="mb-0 list-pagination"></b-pagination>
                </div>
            </div>
        </div>

        <!-- Import from the shipped dataset, same flow as the country import. -->
        <b-modal v-model="showImportModal" :title="__('import_regions')" scrollable centered size="lg">
            <div class="d-flex align-items-center gap-2 mb-2">
                <b-form-input v-model="importSearch" type="search" :placeholder="__('search')"></b-form-input>
                <button class="btn btn-outline-primary text-nowrap" @click="toggleSelectAll" :disabled="!selectableCodes.length">
                    {{ allSelected ? __('clear_all') : __('select_all') }}
                </button>
            </div>

            <div v-if="importLoading" class="text-center p-4"><b-spinner></b-spinner></div>
            <div v-else-if="!importList.length" class="text-muted text-center p-4">
                {{ __('no_region_dataset_for_country') }}
            </div>
            <div v-else style="max-height:55vh; overflow:auto;">
                <div class="row g-0">
                    <div v-for="r in filteredImportList" :key="r.code" class="col-md-6">
                        <div class="form-check py-1 border-bottom d-flex align-items-center gap-2">
                            <input class="form-check-input mt-0" type="checkbox" :value="r.code" v-model="selectedCodes"
                                :id="'reg-' + r.code" :disabled="r.imported">
                            <label class="form-check-label flex-grow-1" :class="{ 'text-muted': r.imported }" :for="'reg-' + r.code">
                                {{ r.name }}
                                <small class="text-muted">
                                    ({{ r.code }}<template v-if="r.tax_code"> · {{ __('tax_code') }} {{ r.tax_code }}</template>)
                                </small>
                                <span v-if="r.imported" class="badge bg-light-secondary ms-1">{{ __('imported') }}</span>
                            </label>
                        </div>
                    </div>
                </div>
                <div v-if="!filteredImportList.length" class="text-muted text-center p-3">{{ __('no_records_found') }}</div>
            </div>

            <template #footer>
                <button class="btn btn-secondary me-2" @click="showImportModal = false">{{ __('cancel') }}</button>
                <button class="btn btn-primary" :disabled="!selectedCodes.length || importing" @click="doImport">
                    <b-spinner small v-if="importing"></b-spinner> {{ __('import') }} ({{ selectedCodes.length }})
                </button>
            </template>
        </b-modal>

        <!-- Manual add / edit, for anything the dataset doesn't carry. -->
        <b-modal v-model="showFormModal" :title="form.id ? __('edit') : __('add')" centered no-close-on-backdrop>
            <div class="row">
                <div class="col-md-12 form-group">
                    <label>{{ __('name') }}<i class="text-danger">*</i></label>
                    <input type="text" class="form-control" v-model="form.name">
                </div>
                <div class="col-md-6 form-group">
                    <label>{{ __('subdivision_code') }}</label>
                    <input type="text" class="form-control" v-model="form.code" placeholder="IN-MH">
                </div>
                <div class="col-md-6 form-group">
                    <label>{{ __('tax_code') }}</label>
                    <input type="text" class="form-control" v-model="form.tax_code" placeholder="27">
                    <small class="text-muted">{{ __('tax_code_hint') }}</small>
                </div>
                <div class="col-md-6 form-group">
                    <label>{{ __('type') }}</label>
                    <input type="text" class="form-control" v-model="form.type" placeholder="state">
                </div>
                <div class="col-md-6 form-group" v-if="form.id">
                    <label>{{ __('status') }}</label>
                    <div class="btn-group btn-group-toggle d-block mt-1" role="group">
                        <label class="btn btn-outline-primary" :class="{ active: form.status == 0 }">
                            <input type="radio" :value="0" v-model.number="form.status"> {{ __('deactivate') }}
                        </label>
                        <label class="btn btn-outline-primary" :class="{ active: form.status == 1 }">
                            <input type="radio" :value="1" v-model.number="form.status"> {{ __('activate') }}
                        </label>
                    </div>
                </div>
            </div>
            <template #footer>
                <button class="btn btn-secondary me-2" @click="showFormModal = false">{{ __('cancel') }}</button>
                <button class="btn btn-primary" :disabled="saving" @click="saveRecord">
                    <b-spinner small v-if="saving"></b-spinner> {{ __('save') }}
                </button>
            </template>
        </b-modal>
    </div>
</template>

<script>
import axios from 'axios';
import { Search, RefreshCw, Plus, Pencil, Trash2, Download, ArrowLeft } from 'lucide-vue-next';

export default {
    components: { Search, RefreshCw, Plus, Pencil, Trash2, Download, ArrowLeft },
    data() {
        return {
            fields: [
                { key: 'id', label: __('id'), class: 'text-center', sortable: true },
                { key: 'name', label: __('name'), class: 'text-center', sortable: true },
                { key: 'code', label: __('subdivision_code'), class: 'text-center' },
                { key: 'tax_code', label: __('tax_code'), class: 'text-center' },
                { key: 'type', label: __('type'), class: 'text-center' },
                { key: 'status', label: __('status'), class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false },
            ],
            country: null,
            records: [],
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            filter: null,
            isLoading: false,

            showImportModal: false,
            importList: [],
            importLoading: false,
            importSearch: '',
            selectedCodes: [],
            importing: false,

            showFormModal: false,
            saving: false,
            form: { id: null, name: '', code: '', tax_code: '', type: 'state', status: 1 },
            defaultLanguageId: null,
        };
    },
    computed: {
        countryId() {
            return this.$route.params.id;
        },
        filteredImportList() {
            const term = (this.importSearch || '').toLowerCase().trim();
            if (!term) return this.importList;
            return this.importList.filter(r =>
                (r.name || '').toLowerCase().includes(term) ||
                (r.code || '').toLowerCase().includes(term) ||
                (r.tax_code || '').toLowerCase().includes(term)
            );
        },
        // Only rows that are actually importable — already-imported ones are inert.
        selectableCodes() {
            return this.filteredImportList.filter(r => !r.imported).map(r => r.code);
        },
        allSelected() {
            return this.selectableCodes.length > 0 &&
                this.selectableCodes.every(code => this.selectedCodes.includes(code));
        },
    },
    created() {
        this.loadCountry();
        this.loadDefaultLanguage().then(() => this.getRecords());
    },
    methods: {
        loadDefaultLanguage() {
            return axios.get(this.$apiUrl + '/active_languages').then(res => {
                const languages = res.data.data || [];
                const def = languages.find(l => l.is_default == 1);
                this.defaultLanguageId = def ? def.id : (languages[0] && languages[0].id);
            }).catch(() => {});
        },
        loadCountry() {
            axios.get(this.$apiUrl + '/countries', { params: { id: this.countryId } }).then(res => {
                const data = res.data.data;
                this.country = Array.isArray(data) ? data[0] : data;
            }).catch(() => {});
        },
        getRecords() {
            this.isLoading = true;
            axios.get(this.$apiUrl + '/countries/regions', { params: { country_id: this.countryId } })
                .then(res => { this.records = res.data.data || []; })
                .catch(err => this.showError(err.response?.data?.message || err.message))
                .finally(() => { this.isLoading = false; });
        },

        openImport() {
            this.showImportModal = true;
            this.selectedCodes = [];
            this.importSearch = '';
            this.importLoading = true;
            axios.get(this.$apiUrl + '/countries/regions/import_list', { params: { country_id: this.countryId } })
                .then(res => { this.importList = res.data.data || []; })
                .catch(() => { this.importList = []; })
                .finally(() => { this.importLoading = false; });
        },
        toggleSelectAll() {
            if (this.allSelected) {
                this.selectedCodes = this.selectedCodes.filter(c => !this.selectableCodes.includes(c));
            } else {
                const merged = new Set(this.selectedCodes.concat(this.selectableCodes));
                this.selectedCodes = Array.from(merged);
            }
        },
        doImport() {
            this.importing = true;
            const fd = new FormData();
            fd.append('country_id', this.countryId);
            fd.append('codes', JSON.stringify(this.selectedCodes));
            axios.post(this.$apiUrl + '/countries/regions/import', fd).then(res => {
                if (res.data.error) throw new Error(res.data.message);
                this.showMessage('success', res.data.message);
                this.showImportModal = false;
                this.getRecords();
            }).catch(err => {
                this.showError(err.response?.data?.message || err.message);
            }).finally(() => { this.importing = false; });
        },

        openForm(record) {
            this.form = record
                ? { id: record.id, name: record.name, code: record.code, tax_code: record.tax_code, type: record.type, status: record.status }
                : { id: null, name: '', code: '', tax_code: '', type: 'state', status: 1 };
            this.showFormModal = true;
        },
        saveRecord() {
            if (!this.form.name || !this.form.name.trim()) {
                this.showError(__('please_fill_default_language_required_fields'));
                return;
            }
            this.saving = true;
            const fd = new FormData();
            if (this.form.id) fd.append('id', this.form.id);
            fd.append('country_id', this.countryId);
            fd.append('language_id', this.defaultLanguageId);
            fd.append('name', this.form.name);
            fd.append('code', this.form.code || '');
            fd.append('tax_code', this.form.tax_code || '');
            fd.append('type', this.form.type || 'state');
            fd.append('status', this.form.status != null ? this.form.status : 1);

            axios.post(this.$apiUrl + '/countries/regions/save', fd).then(res => {
                if (res.data.error) throw new Error(res.data.message);
                this.showMessage('success', res.data.message);
                this.showFormModal = false;
                this.getRecords();
            }).catch(err => {
                this.showError(err.response?.data?.message || err.message);
            }).finally(() => { this.saving = false; });
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
                axios.post(this.$apiUrl + '/countries/regions/delete', fd).then(res => {
                    if (res.data.error) { this.showError(res.data.message); return; }
                    this.showMessage('success', res.data.message);
                    this.getRecords();
                }).catch(err => this.showError(err.response?.data?.message || err.message));
            });
        },
    },
};
</script>

<style scoped>
.region-code {
    font-size: 12px;
    padding: 2px 6px;
    border-radius: 4px;
    background: rgba(128, 128, 128, .12);
}
</style>
