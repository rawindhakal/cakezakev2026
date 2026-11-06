<template>
    <div>
        <div class="list-page">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('countries') }}</h3>

                <div class="page-head-actions">
                    <button class="btn btn-outline-primary list-add-btn" v-if="$can('country_create')"
                        @click="openImport" v-b-tooltip.hover :title="__('import')">
                        <Download :size="16" />
                        <span>{{ __('import') }}</span>
                    </button>
                </div>
            </div>

            <div class="list-surface">
                <div class="list-toolbar">
                    <div class="list-search">
                        <Search class="list-search-icon" />
                        <input id="filter-input" v-model="filter" type="search" class="form-control"
                            :placeholder="__('search')">
                    </div>

                    <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getRecords()">
                        <RefreshCw :class="{ 'is-spinning': isLoading }" />
                    </button>
                </div>

                <MazerDatatable responsive :items="translatedCountries" :fields="fields" :current-page="currentPage"
                    :per-page="perPage" :filter="filter" :filter-included-fields="filterOn"
                    v-model:sort-by="sortBy" v-model:sort-desc="sortDesc" :sort-direction="sortDirection"
                    :busy="isLoading" stacked="md" show-empty small>

                    <template #cell(id)="row">
                        {{ row.item.id }}
                    </template>
                    <template #cell(logo)="row">
                        <p v-if="row.item.logo === ''"> {{ __('no_image') }}</p>
                        <img :src="$storageUrl + row.item.logo" class="list-thumb" v-else />
                    </template>
                    <template #cell(is_default)="row">
                        <!-- Toggle to make this the default country. The current default is
                             ON + disabled — you switch the default by turning ON another one,
                             never by turning the current one off. Only active countries qualify. -->
                        <div class="form-check form-switch d-flex justify-content-center mb-0">
                            <input class="form-check-input" type="checkbox" role="switch"
                                :checked="row.item.is_default == 1"
                                :disabled="row.item.is_default == 1 || row.item.status != 1 || settingDefaultId === row.item.id"
                                @change="setDefault(row.item)" />
                        </div>
                    </template>

                    <template #cell(status)="row">
                        <span class="status-pill is-active" v-if="row.item.status == 1">{{ __('active') }}</span>
                        <span class="status-pill is-inactive" v-if="row.item.status == 0">{{ __('deactive') }}</span>
                    </template>

                    <template #cell(actions)="row">
                        <div class="list-actions">
                            <button v-if="$can('country_update')" class="list-action-btn is-edit"
                                @click="$router.push('/countries/edit/' + row.item.id)" v-b-tooltip.hover
                                :title="__('edit')">
                                <Pencil :size="15" />
                            </button>

                            <button v-if="$can('country_update')" class="list-action-btn"
                                @click="$router.push('/countries/' + row.item.id + '/regions')" v-b-tooltip.hover
                                :title="__('regions')">
                                <Map :size="15" />
                            </button>
                            <!-- The default country can't be deleted (backend enforces it too). -->
                            <button v-if="$can('country_delete') && row.item.is_default != 1"
                                class="list-action-btn is-delete"
                                @click="deleteRecord(row.index, row.item.id)" v-b-tooltip.hover :title="__('delete')">
                                <Trash2 :size="15" />
                            </button>
                        </div>
                    </template>
                </MazerDatatable>

                <div class="list-footer">
                    <div class="list-perpage">
                        <span>{{ __('per_page') }}</span>
                        <b-form-select id="per-page-select" v-model="perPage" :options="pageOptions" size="sm"
                            class="form-select"></b-form-select>
                        <span class="list-range">{{ __('total_records') }} : {{ totalRows }}</span>
                    </div>

                    <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage" size="sm"
                        class="mb-0 list-pagination"></b-pagination>
                </div>
            </div>
        </div>

        <!-- Import countries -->
        <b-modal v-model="showImportModal" :title="__('import_countries')" scrollable centered size="lg">
            <div class="mb-2">
                <b-form-input v-model="importSearch" type="search" :placeholder="__('search')"></b-form-input>
                <small class="text-muted d-block mt-1">{{ __('country_import_includes_regions') }}</small>
            </div>
            <div v-if="importLoading" class="text-center p-4"><b-spinner></b-spinner></div>
            <div v-else style="max-height:55vh; overflow:auto;">
                <div class="row g-0">
                    <div v-for="c in filteredImportList" :key="c.code" class="col-md-6">
                        <div class="form-check py-1 border-bottom d-flex align-items-center gap-2">
                            <input class="form-check-input mt-0" type="checkbox" :value="c.code" v-model="selectedCodes"
                                :id="'imp-' + c.code" :disabled="c.imported">
                            <img :src="c.flag_url" height="16" alt="" onerror="this.style.display='none'">
                            <label class="form-check-label flex-grow-1" :class="{ 'text-muted': c.imported }" :for="'imp-' + c.code">
                                {{ c.name }} <small class="text-muted">({{ c.dial_code }} · {{ c.code }})</small>
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
    </div>

</template>
<script>

import axios from "axios";
import { Search, RefreshCw, Plus, Pencil, Trash2, Download, Map } from 'lucide-vue-next';


export default {
    components: { Search, RefreshCw, Plus, Pencil, Trash2, Download, Map },
    data: function () {
        return {
            fields: [
                { key: 'id', label: __('id'), class: 'text-center', sortable: true, sortDirection: 'asc' },
                { key: 'name', label: __('name'), class: 'text-center', sortable: false, sortDirection: 'asc' },
                { key: 'dial_code', label: __('dial_code'), sortable: false, class: 'text-center' },
                { key: 'code', label: __('code'),sortable: false, class: 'text-center' },
                { key: 'logo', label: __('flag'), sortable: false, class: 'text-center' },
                { key: 'status', label: __('status'), class: 'text-center', sortable: true, sortDirection: 'asc' },
                { key: 'is_default', label: __('default'), sortable: false, class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false }
            ],
            totalRows: 1,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            sortBy: 'id',
            sortDesc: false,
            sortDirection: 'asc',
            filter: null,
            filterOn: [],
            page: 1,
            isLoading: false,
            sectionStyle: 'style_1',
            max_visible_units: 12,
            max_col_in_single_row: 3,
            countries: [],
            settingDefaultId: null,
            sortBySL: 'id',
            sortDescSL: false,
            sortDirectionSL: 'asc',
            isSystemRefreshing: false,
            currentLanguageId: null,
            activeLanguages: [],

            showImportModal: false,
            importList: [],
            importLoading: false,
            selectedCodes: [],
            importSearch: '',
            importing: false,
        }
    },
    computed: {
        translatedCountries() {
            const list = Array.isArray(this.countries) ? this.countries : [];

            if (!this.currentLanguageId || list.length === 0) {
                return list;
            }

            return list.map(country => {
                const translatedCountry = { ...country };

                if (country.translations && Array.isArray(country.translations)) {
                    const translation = country.translations.find(
                        t => t.language_id === this.currentLanguageId
                    );

                    if (translation && translation.name && translation.name.trim() !== '') {
                        translatedCountry.name = translation.name;
                    }
                }

                return translatedCountry;
            });
        },

        sortOptions() {
            // Create an options list from our fields
            return this.fields
                .filter(f => f.sortable)
                .map(f => {
                    return { text: f.label, value: f.key }
                })
        },
        filteredImportList() {
            const q = (this.importSearch || '').toLowerCase().trim();
            if (!q) return this.importList;
            return this.importList.filter(c =>
                (c.name || '').toLowerCase().includes(q) ||
                (c.code || '').toLowerCase().includes(q) ||
                (c.dial_code || '').toLowerCase().includes(q));
        },
    },

    created() {
        this.fetchActiveLanguages().then(() => {
            this.getRecords();
        });
    },

    methods: {

        openImport() {
            this.showImportModal = true;
            this.selectedCodes = [];
            this.importSearch = '';
            this.importLoading = true;
            axios.get(this.$apiUrl + '/countries/import_list').then(res => {
                this.importList = res.data.data || [];
                this.importLoading = false;
            }).catch(() => { this.importLoading = false; });
        },
        doImport() {
            this.importing = true;
            axios.post(this.$apiUrl + '/countries/import', { codes: this.selectedCodes }).then(res => {
                this.importing = false;
                const regions = res.data?.data?.regions_imported || 0;
                this.showMessage('success', regions
                    ? `${res.data.message} (${regions} ${__('regions').toLowerCase()})`
                    : res.data.message);
                this.showImportModal = false;
                this.getRecords();
            }).catch(err => {
                this.importing = false;
                this.showError(err?.response?.data?.message || __('something_went_wrong'));
            });
        },


        fetchActiveLanguages() {
            return axios.get(this.$apiUrl + '/active_languages')
                .then(response => {
                    if (response.data.data && Array.isArray(response.data.data)) {
                        this.activeLanguages = response.data.data;

                        const appLocale = window.appLocale || 'en';

                        const currentLanguage = this.activeLanguages.find(
                            lang => lang.code === appLocale
                        );

                        if (currentLanguage) {
                            this.currentLanguageId = currentLanguage.id;
                        } else {
                            const defaultLanguage = this.activeLanguages.find(
                                lang => lang.is_default === 1
                            );
                            if (defaultLanguage) {
                                this.currentLanguageId = defaultLanguage.id;
                            }
                        }
                    }
                })
                .catch(error => {
                    console.error('Error loading languages:', error);
                });
        },

        getRecords() {
            this.isLoading = true
            axios.get(this.$apiUrl + '/countries', {
            }).then((response) => {
                this.isLoading = false
                let data = response.data;
                this.countries = data.data;
                this.totalRows = this.countries.length
            }).catch(error => {
                this.isLoading = false;

                if (error?.request?.statusText) {
                    this.showError(error.request.statusText);
                } else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError("Something went wrong!");
                }
            });
        },
        // Make a country the default. The backend unsets the previous default in one txn;
        // we confirm first, then refetch so every row's toggle reflects the new state.
        setDefault(country) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('set_as_default_country_confirm'),
                confirmButtonText: __('yes_sure'),
                cancelButtonText: __('cancel'),
                icon: 'question',
                showCancelButton: true,
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (!result.value) return;
                this.settingDefaultId = country.id;
                axios.post(this.$apiUrl + '/countries/set_default', { id: country.id })
                    .then(response => {
                        const data = response.data;
                        if (data.status === 1) {
                            this.showMessage('success', data.message);
                            this.getRecords();
                        } else {
                            this.showError(data.message);
                        }
                    })
                    .catch(() => this.showError(__('something_went_wrong')))
                    .finally(() => { this.settingDefaultId = null; });
            });
        },
        deleteRecord(index, id) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('you_want_be_able_to_revert_this'),
                confirmButtonText: __('yes_sure'),
                cancelButtonText: __('cancel'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (result.value) {
                    this.isLoading = true
                    let postData = {
                        id: id
                    }
                    axios.post(this.$apiUrl + '/countries/delete', postData)
                        .then((response) => {
                            this.isLoading = false
                            let data = response.data;
                            if (data.status === 1) {
                                // Find the index of the country in the array based on its id
                                const indexOfDeletedCountry = this.countries.findIndex(country => country.id === postData.id);

                                if (indexOfDeletedCountry !== -1) {
                                    // If the country is found in the array, remove it
                                    this.countries.splice(indexOfDeletedCountry, 1);
                                    this.showMessage('success', data.message);
                                    this.$eventBus.emit('countriesChanged');
                                } else {
                                    console.error("Country not found in the array.");
                                }
                            } else {
                                this.showError(data.message);
                            }
                        }).catch(error => {
                            vm.isLoading = false;
                            if (error?.request?.statusText) {
                                this.showError(error.request.statusText);
                            } else if (error.message) {
                                this.showError(error.message);
                            } else {
                                this.showError("Something went wrong!");
                            }
                        });
                }
            });
        },

    }
};
</script>
