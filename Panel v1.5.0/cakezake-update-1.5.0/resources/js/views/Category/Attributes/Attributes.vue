<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('attributes') }}</h3>

            <button v-if="$can('attribute_create')" class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                @click="edit_record = true">
                <Plus :size="16" />
                <span>{{ __('add_attribute') }}</span>
            </button>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input v-model="filter" type="search" class="form-control"
                        :placeholder="__('search_name_or_value')" @input="getRecords()">
                </div>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getRecords()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive :items="translatedRows" :fields="fields" v-model:sort-by="sortBy" v-model:sort-desc="sortDesc"
                :sort-direction="sortDirection" :busy="isLoading" stacked="md" show-empty small>
                <template #cell(id)="row">{{ row.item.id }}</template>
                <template #cell(values)="row">
                    <span v-for="v in row.item.values" :key="v.id" class="badge me-1"
                        :class="isMatch(valueLabel(v)) ? 'bg-primary' : 'bg-light text-dark'">
                        {{ valueLabel(v) }}
                    </span>
                </template>
                <template #cell(status)="row">
                    <span v-if="row.item.status == 1" class="status-pill is-active">{{ __('active') }}</span>
                    <span v-else class="status-pill is-inactive">{{ __('deactive') }}</span>
                </template>
                <template #cell(actions)="row">
                    <div class="list-actions">
                        <span v-if="!$can('attribute_update') && !$can('attribute_delete')" class="text-muted small">—</span>
                        <button v-if="$can('attribute_update')" class="list-action-btn is-edit" @click="edit_record = row.item" v-b-tooltip.hover :title="__('edit')">
                            <Pencil :size="15" />
                        </button>
                        <button v-if="$can('attribute_delete')" class="list-action-btn is-delete" @click="deleteRecord(row.index, row.item.id)" v-b-tooltip.hover :title="__('delete')">
                            <Trash2 :size="15" />
                        </button>
                    </div>
                </template>
            </MazerDatatable>

            <div class="list-footer">
                <div class="list-perpage">
                    <span>{{ __('per_page') }}</span>
                    <b-form-select v-model="perPage" :options="pageOptions" size="sm" class="form-select"></b-form-select>
                    <span class="list-range">{{ __('total_records') }} - {{ totalRows }}</span>
                </div>

                <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage" size="sm" class="mb-0 list-pagination"></b-pagination>
            </div>
        </div>

        <app-edit-record v-if="edit_record" :record="edit_record" @modalClose="edit_record = null" @saved="onSaved"></app-edit-record>
    </div>
</template>

<script>
import EditRecord from './Edit.vue';
import { Search, RefreshCw, Plus, Pencil, Trash2 } from 'lucide-vue-next';

export default {
    components: { 'app-edit-record': EditRecord, Search, RefreshCw, Plus, Pencil, Trash2 },
    data() {
        return {
            fields: [
                { key: 'id', label: __('id'), class: 'text-center', sortable: true },
                { key: 'name', label: __('name'), class: 'text-center' },
                { key: 'values', label: __('values'), class: 'text-center' },
                { key: 'status', label: __('status'), class: 'text-center' },
                { key: 'actions', label: __('actions') },
            ],
            totalRows: 0,
            currentPage: 1,
            perPage: 10,
            pageOptions: this.$pageOptions,
            sortBy: '',
            sortDesc: false,
            sortDirection: 'asc',
            filter: null,
            isLoading: false,
            rows: [],
            edit_record: null,
            currentLanguageId: null,
            activeLanguages: [],
        };
    },
    computed: {
        translatedRows() {
            if (!this.currentLanguageId || this.rows.length === 0) return this.rows;
            return this.rows.map(r => {
                const out = { ...r };
                if (Array.isArray(r.translations)) {
                    const t = r.translations.find(x => Number(x.language_id) === Number(this.currentLanguageId));
                    if (t && t.name && t.name.trim() !== '') out.name = t.name;
                }
                return out;
            });
        },
    },
    created() {
        this.fetchActiveLanguages().then(() => this.getRecords());
    },
    watch: {
        currentPage() { this.getRecords(); },
        perPage() { this.getRecords(); },
    },
    methods: {
        fetchActiveLanguages() {
            return axios.get(this.$apiUrl + '/active_languages').then(res => {
                this.activeLanguages = res.data.data || [];
                const code = window.appLocale || 'en';
                const cur = this.activeLanguages.find(l => l.code === code);
                if (cur) this.currentLanguageId = cur.id;
                else {
                    const def = this.activeLanguages.find(l => l.is_default === 1);
                    if (def) this.currentLanguageId = def.id;
                }
            });
        },
        /** Does this text contain what is being searched for? */
        isMatch(text) {
            const term = String(this.filter || '').trim().toLowerCase();
            return term !== '' && String(text || '').toLowerCase().includes(term);
        },
        valueLabel(v) {
            if (!this.currentLanguageId) return v.value;
            if (Array.isArray(v.translations)) {
                const t = v.translations.find(x => Number(x.language_id) === Number(this.currentLanguageId));
                if (t && t.value && t.value.trim() !== '') return t.value;
            }
            return v.value;
        },
        getRecords() {
            this.isLoading = true;
            axios.get(this.$apiUrl + '/attributes', {
                params: { page: this.currentPage, per_page: this.perPage, filter: this.filter },
            }).then(res => {
                this.isLoading = false;
                this.rows = res.data.data || [];
                this.totalRows = res.data.total || 0;
            }).catch(() => { this.isLoading = false; });
        },
        onSaved(message) {
            this.showMessage('success', message);
            this.getRecords();
            this.edit_record = null;
        },
        deleteRecord(index, id) {
            // Warn when the attribute is already used by live products.
            axios.get(this.$apiUrl + '/attributes/usage', { params: { id } })
                .then(res => res.data.data || {})
                .catch(() => ({}))
                .then(u => {
                    const products = Number(u.product_count || 0);
                    const variants = Number(u.variant_count || 0);
                    if (products > 0) {
                        const tpl = __('attribute_delete_in_use_blocked') || 'This attribute is used by :products product(s) across :variants variant(s) and cannot be deleted. Remove it from those products first.';
                        this.showError(tpl.replace(':products', products).replace(':variants', variants));
                        return;
                    }
                    this.confirmAttributeDelete(index, id, __('you_want_be_able_to_revert_this'), false);
                });
        },
        confirmAttributeDelete(index, id, text, inUse) {
            this.$swal.fire({
                title: __('are_you_sure'),
                html: text,
                confirmButtonText: __('yes_sure'),
                cancelButtonText: __('cancel'),
                icon: inUse ? 'warning' : 'warning',
                showCancelButton: true,
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (result.value) {
                    this.isLoading = true;
                    axios.post(this.$apiUrl + '/attributes/delete', { id }).then(res => {
                        this.isLoading = false;
                        this.rows.splice(index, 1);
                        this.showMessage('success', res.data.message);
                    }).catch(() => { this.isLoading = false; });
                }
            });
        },
    },
};
</script>
