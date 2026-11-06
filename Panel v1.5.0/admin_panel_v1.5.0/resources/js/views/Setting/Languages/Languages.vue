<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('languages') }}</h3>

            <div class="page-head-actions ms-auto">
                <router-link to="/settings"
                    class="btn btn-outline-secondary d-inline-flex align-items-center gap-1 mb-0">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>

                <button class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                    @click="showSupportedLanguages = true">
                    <List :size="16" />
                    <span>{{ __('supported_languages_list') }}</span>
                </button>

                <router-link to="/languages/create"
                    class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                    v-if="$can('language_create')" v-b-tooltip.hover :title="__('add_language')">
                    <Plus :size="16" />
                    <span>{{ __('add_language') }}</span>
                </router-link>
            </div>
        </div>

        <b-modal v-model="showSupportedLanguages" size="lg"
            :title="__('supported_languages_list')" scrollable centered no-close-on-backdrop no-fade static>
            <b-container fluid>
                <b-row class="mb-2">
                    <b-col cols="12" lg="4" offset-lg="8">
                        <h6 class="box-title">{{ __('search') }}</h6>
                        <b-form-input id="filter-input" v-model="filterSL" type="search"
                            :placeholder="__('search')"></b-form-input>
                    </b-col>
                </b-row>

                <MazerDatatable responsive sticky-header hover stacked="md" show-empty small
                    :items="supported_languages" :fields="supported_languages_fields"
                    :filter="filterSL" v-model:sort-by="sortBySL" v-model:sort-desc="sortDescSL"
                    :sort-direction="sortDirectionSL">
                </MazerDatatable>

            </b-container>
            <template #footer>
                <b-button variant="danger" size="sm" class="float-right"
                    @click="showSupportedLanguages = false">
                    {{ __('close') }}
                </b-button>
            </template>
        </b-modal>

        <div class="list-surface">
            <div class="list-toolbar">
                <!-- Download Sample Files Section -->
                <div class="list-toolbar-start">
                    <span class="text-muted">{{ __('download_sample_files') }}</span>
                    <button class="btn btn-sm btn-outline-primary"
                        @click="downloadSampleFile('customer.json', getSystemTypeName(1))">
                        <Download :size="15" /> {{ __('customer_app') }}
                    </button>
                    <button class="btn btn-sm btn-outline-primary"
                        @click="downloadSampleFile('partner.json', getSystemTypeName(2))">
                        <Download :size="15" /> {{ __('rider_app') }}
                    </button>
                    <button class="btn btn-sm btn-outline-primary"
                        @click="downloadSampleFile('web.json', getSystemTypeName(3))">
                        <Download :size="15" /> {{ __('website') }}
                    </button>
                    <button class="btn btn-sm btn-outline-primary"
                        @click="downloadSampleFile('panel.json', getSystemTypeName(4))">
                        <Download :size="15" /> {{ __('admin_panel') }}
                    </button>
                </div>

                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input id="filter-input" v-model="filter" type="search" class="form-control"
                        :placeholder="__('search')">
                </div>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getRecords()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <!-- Simple table showing languages -->
            <MazerDatatable responsive :items="groupedLanguages" :fields="languageFields" :current-page="currentPage"
                :per-page="perPage" :filter="filter" :filter-included-fields="filterOn"
                v-model:sort-by="sortBy" v-model:sort-desc="sortDesc" :sort-direction="sortDirection"
                :busy="isLoading" stacked="md" show-empty small>
                <template #cell(name)="row">
                    <span>{{ row.item.name }}</span>
                </template>

                <template #cell(is_default)="row">
                    <span v-if="row.item.has_default" class="status-pill is-active">{{ __('yes') }}</span>
                    <span v-else class="status-pill is-inactive">{{ __('no') }}</span>
                </template>

                <template #cell(status)="row">
                    <span v-if="row.item.status == 1" class="status-pill is-active">{{ __('active') }}</span>
                    <span v-else class="status-pill is-inactive">{{ __('inactive') }}</span>
                </template>

                <template #cell(actions)="row">
                    <div class="list-actions">
                        <button v-if="$can('language_update')" class="list-action-btn is-edit"
                            @click="openEditModal(row.item)" v-b-tooltip.hover :title="__('edit')">
                            <Pencil :size="15" />
                        </button>
                        <button v-if="$can('language_delete')" class="list-action-btn is-delete"
                            @click="deleteLanguageGroup(row.item)" v-b-tooltip.hover
                            :title="__('delete')">
                            <Trash2 :size="15" />
                        </button>
                    </div>
                </template>
            </MazerDatatable>

            <div class="list-footer">
                <div class="list-perpage">
                    <span>{{ __('per_page') }}</span>
                    <b-form-select id="per-page-select" v-model="perPage" :options="pageOptions"
                        size="sm" class="form-select"></b-form-select>
                    <span class="list-range">{{ __('total_records') }} : {{ totalRows }}</span>
                </div>

                <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage"
                    size="sm" class="mb-0 list-pagination"></b-pagination>
            </div>
        </div>

        <!-- Add / Edit -->
        <app-edit-record v-if="create_new || edit_record" :record="edit_record" :system_types="system_types"
            :supported_languages="supported_languages" @modalClose="hideModal()"></app-edit-record>

        <!-- Edit Language Modal - Shows supported language, display name, is_default, and 4 Edit buttons -->
        <b-modal ref="edit-language-modal" :title="__('edit_language')" @hidden="closeEditModal" size="lg" scrollable
            centered no-close-on-backdrop no-fade static>
            <div v-if="selectedLanguageGroup" class="row">
                <div class="form-group col-md-6">
                    <label for="edit_supported_language">{{ __('supported_language') }}</label>
                    <input type="text" id="edit_supported_language" class="form-control"
                        :value="selectedLanguageGroup.name + ' (' + selectedLanguageGroup.code + ')'" readonly>
                </div>

                <div class="form-group col-md-6">
                    <label for="edit_display_name">{{ __('display_name') }}<span class="text-danger">*</span></label>
                    <input type="text" id="edit_display_name" class="form-control" v-model="editDisplayName"
                        :placeholder="__('enter_display_name')">
                </div>

                <div class="form-group col-md-6">
                    <input name="edit_is_default" id="edit_is_default" v-model="editIsDefault" true-value="1"
                        false-value="0" type="checkbox" class="form-check-input">
                    <label for="edit_is_default" class="form-check-label ms-2">{{ __('set_as_a_default_language')
                        }}</label>
                </div>

                <div class="form-group col-md-6">
                    <label>{{ __('status') }}</label>
                    <div class="text-left mt-1">
                        <div class="btn-group btn-group-toggle" role="group">
                            <label class="btn btn-outline-primary" :class="{ active: editStatus == 0 }">
                                <input type="radio" :value="0" v-model.number="editStatus" autocomplete="off"> {{ __('deactivate') }}
                            </label>
                            <label class="btn btn-outline-primary" :class="{ active: editStatus == 1 }">
                                <input type="radio" :value="1" v-model.number="editStatus" autocomplete="off"> {{ __('activate') }}
                            </label>
                        </div>
                    </div>
                </div>

                <div class="form-group col-md-12">
                    <label class="mb-2">{{ __('edit_json_data_for_system_types') }}:</label>
                    <div class="row">
                        <div class="col-md-6 mb-2" v-for="systemType in system_types" :key="systemType.id">
                            <button class="btn btn-primary btn-block"
                                @click="openJsonEditModal(systemType, selectedLanguageGroup)">
                                <Pencil :size="15" /> {{ __('edit') }} {{ systemType.name }}
                            </button>
                        </div>
                    </div>
                </div>
            </div>
            <template #footer>
                <b-button variant="primary" @click="saveLanguageSettings" :disabled="isSaving">
                    {{ __('save') }}
                    <b-spinner v-if="isSaving" small label="Spinning"></b-spinner>
                </b-button>
                <b-button variant="secondary" @click="closeEditModal">{{ __('cancel') }}</b-button>
            </template>
        </b-modal>

        <app-json-edit v-if="jsonEditRecord" :record="jsonEditRecord" :system_type="jsonEditSystemType"
            @modalClose="closeJsonEditModal" @jsonSaved="closeEditModal"></app-json-edit>
    </div>

</template>
<script>

import EditRecord from './Edit.vue';
import JsonEdit from './JsonEdit.vue';
import axios from "axios";
import { Search, RefreshCw, Plus, Pencil, Trash2, Download, List, ArrowLeft } from 'lucide-vue-next';


export default {
    components: {
        'app-edit-record': EditRecord,
        'app-json-edit': JsonEdit,
        Search, RefreshCw, Plus, Pencil, Trash2, Download, List, ArrowLeft,
    },
    data: function () {
        return {
            fields: [
                { key: 'id', label: __('id'), class: 'text-center', sortable: true, sortDirection: 'desc' },
                { key: 'name', label: __('name'), sortable: false, class: 'text-center' },
                { key: 'code', label: __('code'), sortable: false, class: 'text-center' },
                { key: 'is_default', label: __('default'), sortable: false, class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false, class: 'text-center' }
            ],
            languageFields: [
                { key: 'name', label: __('language'), class: 'text-center text-nowrap', sortable: false },
                { key: 'code', label: __('code'), class: 'text-center text-nowrap', sortable: false },
                { key: 'is_default', label: __('default'), class: 'text-center text-nowrap', sortable: false },
                { key: 'status', label: __('status'), class: 'text-center text-nowrap', sortable: true },
                { key: 'actions', label: __('actions'), class: 'text-center text-nowrap', sortable: false }
            ],
            totalRows: 1,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            sortBy: 'id',
            sortDesc: true,
            sortDirection: 'desc',
            filter: null,
            filterOn: ['name', 'code'],
            page: 1,

            isLoading: false,
            sectionStyle: 'style_1',
            max_visible_units: 12,
            max_col_in_single_row: 3,

            languages: [],
            system_types: [],
            system_type: "",
            supported_languages: [],
            supported_languages_fields: [
                { key: 'id', label: __('id'), class: 'text-center', sortable: true, sortDirection: 'asc' },
                { key: 'name', label: __('name'), class: 'text-center' },
                { key: 'code', label: __('code'), class: 'text-center' },
                { key: 'type', label: __('type'), class: 'text-center' }
            ],
            sortBySL: 'id',
            sortDescSL: false,
            sortDirectionSL: 'asc',
            filterSL: null,
            showSupportedLanguages: false,
            isSystemRefreshing: false,


            create_new: null,
            edit_record: null,
            selectedLanguageGroup: null,
            editDisplayName: '',
            editIsDefault: 0,
            editStatus: 1,
            isSaving: false,
            jsonEditRecord: null,
            jsonEditSystemType: null,
        }
    },
    computed: {
        sortOptions() {
            // Create an options list from our fields
            return this.fields
                .filter(f => f.sortable)
                .map(f => {
                    return { text: f.label, value: f.key }
                })
        },
        groupedLanguages() {
            const grouped = {};

            this.languages.forEach(lang => {
                const key = lang.supported_language_id;

                if (!grouped[key]) {
                    grouped[key] = {
                        id: lang.supported_language_id,
                        supported_language_id: lang.supported_language_id,
                        name: lang.name,
                        code: lang.code,
                        type: lang.type,
                        display_name: lang.display_name,
                        has_default: false,
                        status: lang.status,
                        languages: []
                    };
                }

                grouped[key].languages.push(lang);

                if (lang.is_default == 1) {
                    grouped[key].has_default = true;
                }
            });

            return Object.values(grouped).sort((a, b) => {
                return a.name.localeCompare(b.name);
            });
        }
    },
    mounted() {
        // Set the initial number of items
        this.totalRows = this.groupedLanguages.length
    },
    watch: {
        $route(to, from) {
            this.showCreateModal();
        },
        groupedLanguages: {
            handler(newVal) {
                this.totalRows = newVal.length;
            },
            immediate: true
        }
    },
    created: function () {
        this.showCreateModal();
        this.$eventBus.on('recordSaved', (message) => {
            this.showMessage('success', message);
            this.getRecords();
            this.create_new = null;
        });
        this.getRecords();
        this.getSupportedLanguages();
    },
    methods: {

        getRecords() {
            this.isLoading = true
            axios.get(this.$apiUrl + '/languages')
                .then((response) => {
                    this.isLoading = false
                    let data = response.data;
                    this.languages = data.data || [];
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
        getSupportedLanguages() {
            this.isLoading = true
            axios.get(this.$apiUrl + '/languages/supported_languages')
                .then((response) => {
                    this.isLoading = false
                    let data = response.data;

                    this.system_types = data.data.system_types;
                    this.system_types = this.system_types; // this line is remove System type admin panel.

                    this.supported_languages = data.data.supported_languages;
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
        downloadJSON(row) {
            // Translations live in files now, so fetch the bundle on demand.
            axios.get(this.$apiUrl + '/languages/get_json', { params: { id: row.id } })
                .then(res => {
                    const data = res.data.data || {};
                    const json = JSON.stringify(data.json_data || {}, null, 2);
                    const blob = new Blob([json], { type: 'application/json' });
                    const url = URL.createObjectURL(blob);

                    const link = document.createElement('a');
                    link.href = url;
                    link.download = row.code + '.json';
                    link.click();

                    URL.revokeObjectURL(url);
                })
                .catch(() => this.showError(__('something_went_wrong')));
        },

        convertInJsonData(data) {
            data = JSON.parse(data);
            if (Array.isArray(data)) {
                data = data[0];
            }
            return data;
        },

        deleteRecord(index, id) {
            this.$swal.fire({
                title: "Are you Sure?",
                text: "You want be able to revert this",
                confirmButtonText: "Yes, Sure",
                cancelButtonText: "Cancel",
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
                    axios.post(this.$apiUrl + '/languages/delete', postData)
                        .then((response) => {
                            this.isLoading = false

                            let data = response.data;


                            if (data.status === 1) {
                                this.getRecords();
                                this.showMessage('success', data.message);
                            } else {
                                this.showError(data.message);
                            }

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
                }
            });
        },

        showCreateModal() {
            let create = this.$route.params.create;
            if (create) {
                this.create_new = true;
            }
        },
        hideModal() {
            this.create_new = false
            this.edit_record = false
            this.$router.push({ path: '/languages' });
        },
        openEditModal(languageGroup) {
            this.selectedLanguageGroup = languageGroup;
            this.editDisplayName = languageGroup.display_name || '';
            this.editIsDefault = languageGroup.has_default ? 1 : 0;
            // Get status from the first language in the group (all should have the same status)
            this.editStatus = languageGroup.languages[0]?.status ?? 1;
            this.$refs['edit-language-modal'].show();
        },
        closeEditModal() {
            this.selectedLanguageGroup = null;
            this.editDisplayName = '';
            this.editIsDefault = 0;
            this.editStatus = 1;
            this.$refs['edit-language-modal'].hide();
        },
        openJsonEditModal(systemType, languageGroup) {
            const langRecord = languageGroup.languages.find(l => l.system_type == systemType.id);

            if (langRecord) {
                this.jsonEditRecord = langRecord;
                this.jsonEditSystemType = systemType;
            } else {
                this.jsonEditRecord = {
                    id: null,
                    supported_language_id: languageGroup.supported_language_id,
                    system_type: systemType.id,
                    display_name: languageGroup.display_name,
                    is_default: 0,
                    status: 1
                };
                this.jsonEditSystemType = systemType;
            }
        },
        closeJsonEditModal() {
            this.jsonEditRecord = null;
            this.jsonEditSystemType = null;
            this.getRecords();
        },
        saveLanguageSettings() {
            if (!this.selectedLanguageGroup) return;

            this.isSaving = true;

            const updatePromises = this.selectedLanguageGroup.languages.map(lang => {
                const formData = new FormData();
                formData.append('id', lang.id);
                formData.append('system_type', lang.system_type);
                formData.append('supported_language', lang.supported_language_id);
                formData.append('display_name', this.editDisplayName);
                formData.append('is_default', this.editIsDefault);
                formData.append('status', this.editStatus);

                return axios.post(this.$apiUrl + '/languages/update', formData);
            });

            Promise.all(updatePromises)
                .then(responses => {
                    for (let i = 0; i < responses.length; i++) {
                        const response = responses[i];
                        const data = response.data;

                        if (data.status !== 1) {
                            this.isSaving = false;
                            const errorMessage = data.message || __('something_went_wrong');
                            this.showError(errorMessage);
                            return;
                        }
                    }

                    this.isSaving = false;
                    const message = responses[0]?.data?.message || __('language_updated_successfully');
                    this.showMessage('success', message);
                    this.closeEditModal();
                    this.getRecords();
                })
                .catch(error => {
                    this.isSaving = false;

                    let errorMessage = __('something_went_wrong');

                    if (error.response && error.response.data) {
                        if (error.response.data.message) {
                            errorMessage = error.response.data.message;
                        } else if (error.response.data.error) {
                            errorMessage = error.response.data.error;
                        }
                    } else if (error.request && error.request.statusText) {
                        errorMessage = error.request.statusText;
                    } else if (error.message) {
                        errorMessage = error.message;
                    }

                    this.showError(errorMessage);
                });
        },
        // Get system type name by ID
        getSystemTypeName(systemTypeId) {
            const systemType = this.system_types.find(st => st.id == systemTypeId);
            return systemType ? systemType.name : '';
        },
        downloadSampleFile(fileName, systemTypeName) {
            const fileUrl = this.$baseUrl + '/sample-file/' + fileName;

            // Create a temporary anchor element to trigger download
            const link = document.createElement('a');
            link.href = fileUrl;
            link.download = fileName;
            link.target = '_blank';

            // Append to body, click, and remove
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            // Show success message
            this.showMessage('success', __('sample_file_downloaded') + ': ' + systemTypeName);
        },
        deleteLanguageGroup(languageGroup) {
            const languageIds = languageGroup.languages.map(l => l.id);
            const languageName = languageGroup.name;

            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('you_will_not_be_able_to_revert_this'),
                confirmButtonText: __('yes_sure'),
                cancelButtonText: __('cancel'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (result.value) {
                    this.isLoading = true;
                    // One request deletes the whole group: the API removes every row
                    // sharing this supported_language_id (one per system_type). Sending
                    // one call per id made the first succeed and the rest report
                    // "language not found" for rows the first call had already removed.
                    axios.post(this.$apiUrl + '/languages/delete', { id: languageIds[0] })
                        .then((response) => {
                            this.isLoading = false;
                            this.getRecords();
                            const data = response.data || {};
                            if (Number(data.status) === 0) {
                                this.showError(data.message || __('something_went_wrong'));
                                return;
                            }
                            this.showMessage('success', data.message || __('language_deleted_successfully'));
                        })
                        .catch(error => {
                            this.isLoading = false;
                            this.getRecords();
                            if (error.response && error.response.data && error.response.data.message) {
                                this.showError(error.response.data.message);
                            } else {
                                this.showError(__('something_went_wrong'));
                            }
                        });
                }
            });
        },
    },
    beforeUnmount() {
        this.$eventBus.off('recordSaved');
    }
};
</script>
