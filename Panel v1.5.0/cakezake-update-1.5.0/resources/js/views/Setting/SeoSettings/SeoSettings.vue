<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('seo_settings') }}</h3>

            <div class="page-head-actions ms-auto">
                <router-link to="/settings"
                    class="btn btn-outline-secondary d-inline-flex align-items-center gap-1 m-0">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
                <button
                    class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                    @click="create_new=true"
                    v-if="$can('manage_seo_settings')">
                    <Plus :size="16" />
                    <span>{{ __('add_seo_page') }}</span>
                </button>
            </div>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div v-if="czShowCountry || czShowZoneDropdown" class="list-toolbar-start">
                    <AppSelect v-if="czShowCountry" class="form-select list-select cz-sel" v-model="czCountryId"
                        :options="czCountryOptions" :searchable="czCountryOptions.length > 6" :allow-empty="false"
                        label-key="label" track-by="id" :placeholder="__('country')" @update:model-value="czOnCountry">
                        <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                    :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                        <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                    :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                    </AppSelect>
                    <AppSelect v-if="czShowZoneDropdown" class="form-select list-select cz-sel" v-model="czZoneId"
                        :options="czZoneOptions" :searchable="false" :allow-empty="false" label-key="label"
                        track-by="id" :placeholder="__('zone')" @update:model-value="czOnZone" />
                </div>
                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input
                        id="filter-input"
                        v-model="filter"
                        type="search"
                        class="form-control"
                        :placeholder="__('search')">
                </div>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getSeoSettings()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive
                :items="translatedSeoSettings"
                :fields="fields"

                :filter="filter"
                :filter-included-fields="filterOn"
                v-model:sort-by="sortBy"
                v-model:sort-desc="sortDesc"
                :sort-direction="sortDirection"

                :busy="isLoading"
                stacked="md"
                show-empty
                small>

                <template #cell(schema_markup)="row">
                    <div v-if="shouldTruncate(row.item.schema_markup)">
                        <span v-if="!expandedSchema[row.item.id]">
                            {{ getTruncatedText(row.item.schema_markup) }}
                            <a href="#" @click.prevent="toggleSchemaExpansion(row.item.id)" class="text-info">View More</a>
                        </span>
                        <span v-else>
                            {{ row.item.schema_markup }}
                            <a href="#" @click.prevent="toggleSchemaExpansion(row.item.id)" class="text-info">View Less</a>
                        </span>
                    </div>
                    <span v-else>{{ row.item.schema_markup }}</span>
                </template>

                <template #cell(meta_description)="row">
                    <div v-if="shouldTruncate(row.item.meta_description)">
                        <span v-if="!expandedMeta[row.item.id]">
                            {{ getTruncatedText(row.item.meta_description) }}
                            <a href="#" @click.prevent="toggleMetaExpansion(row.item.id)" class="text-info">View More</a>
                        </span>
                        <span v-else>
                            {{ row.item.meta_description }}
                            <a href="#" @click.prevent="toggleMetaExpansion(row.item.id)" class="text-info">View Less</a>
                        </span>
                    </div>
                    <span v-else>{{ row.item.meta_description }}</span>
                </template>

                <template #cell(og_image)="row">
                    <img :src="row.item.og_image_url" class="list-thumb" alt="" />
                </template>

                <template #cell(actions)="row">
                    <div class="list-actions">
                        <button class="list-action-btn is-edit" @click="edit_record = row.item" v-if="$can('manage_seo_settings')" v-b-tooltip.hover :title="__('edit')">
                            <Pencil :size="15" />
                        </button>
                        <button class="list-action-btn is-delete" @click="deleteSeoSettings(row.index,row.item.id)" v-if="$can('manage_seo_settings')" v-b-tooltip.hover :title="__('delete')">
                            <Trash2 :size="15" />
                        </button>
                    </div>
                </template>

            </MazerDatatable>

            <div class="list-footer">
                <div class="list-perpage">
                    <span>{{ __('per_page') }}</span>
                    <b-form-select
                        id="per-page-select"
                        v-model="perPage"
                        :options="pageOptions"
                        size="sm"
                        class="form-select"
                    ></b-form-select>
                    <span class="list-range">{{__('total_records')}} : {{ totalRows }}</span>
                </div>

                <b-pagination
                    v-model="currentPage"
                    :total-rows="totalRows"
                    :per-page="perPage"
                    size="sm"
                    class="mb-0 list-pagination"
                    @change="getSeoSettings"
                ></b-pagination>
            </div>
        </div>

        <!-- Add / Edit -->
        <app-edit-record
            v-if="create_new || edit_record"
            :record="edit_record"
            @saved="onSeoSaved"
            @modalClose="hideModal()"
        ></app-edit-record>
    </div>

</template>
<script>

import EditRecord from './Edit.vue';
import { Search, RefreshCw, Plus, Pencil, Trash2, ArrowLeft } from 'lucide-vue-next';
import CountryZoneFilter from '../../../mixins/CountryZoneFilter.js';
export default {
    mixins: [CountryZoneFilter],
    components: {
        ArrowLeft,
        'app-edit-record' : EditRecord,
        Search, RefreshCw, Plus, Pencil, Trash2,
    },
    data: function() {
        return {
            czAllowAll: true,
            fields: [
                { key: 'id', label: __('id'), class: 'text-center', sortable: true, sortDirection: 'asc' },
                { key: 'page_type', label: __('page_type'), class: 'text-center', sortable: false, sortDirection: 'desc' },
                { key: 'zone_name', label: __('zone'), class: 'text-center', sortable: false },
                { key: 'meta_title', label: __('meta_title'), class: 'text-center', sortable: false },
                { key: 'meta_keyword', label: __('meta_keywords'), class: 'text-center', sortable: false },
                { key: 'schema_markup', label: __('schema_markup'),  class: 'text-center', sortable: false },
                { key: 'meta_description', label: __('meta_description'),  class: 'text-center', sortable: false },
                { key: 'og_image', label: __('og_image'),  class: 'text-center', sortable: false },
                { key: 'actions', label: __('actions'), class: 'text-center', sortable: false }
            ],
            totalRows: 1,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            sortBy: 'id',
            sortDesc: true,
            sortDirection: 'asc',
            filter: null,
            filterOn: [],
            page: 1,

            seo_settings: [],
            isLoading: false,
            sectionStyle : 'style_1',
          
            create_new : null,
            edit_record : null,
            settingModalShow:false,
            
            // View more functionality data
            expandedSchema: {},
            expandedMeta: {},
            maxLength: 100,     
    activeLanguages: [],
    currentLanguageId: null,
        }
    },
    computed: {
      
    translatedSeoSettings() {
        if (!this.currentLanguageId) return this.seo_settings;

        return this.seo_settings.map(item => {
            const translated = { ...item };

            if (item.translations && Array.isArray(item.translations)) {
                const t = item.translations.find(
                    tr => tr.language_id === this.currentLanguageId
                );

                if (t) {
                    translated.meta_title =
                        t.meta_title?.trim() !== '' ? t.meta_title : item.meta_title;

                    translated.meta_keyword =
                        t.meta_keyword?.trim() !== '' ? t.meta_keyword : item.meta_keyword;

                    translated.schema_markup =
                        t.schema_markup?.trim() !== '' ? t.schema_markup : item.schema_markup;

                    translated.meta_description =
                        t.meta_description?.trim() !== '' ? t.meta_description : item.meta_description;
                }
            }

            return translated;
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
        
    },
    watch: {
        $route(to, from) {
            this.showCreateModal();
        },
        currentPage(newPage) {
            this.getSeoSettings();
        },
        perPage(newPerPage) {
            this.getSeoSettings();
        }
    },
    created: function() {
        this.fetchActiveLanguages();
        this.czLoad();
    },
    methods: {
        czOnFilter() { this.getSeoSettings(); },
        fetchActiveLanguages() {
    return axios.get(this.$apiUrl + '/active_languages')
        .then(response => {
            if (response.data.data && Array.isArray(response.data.data)) {
                this.activeLanguages = response.data.data;

                const appLocale = window.appLocale || 'en';

                let currentLang = this.activeLanguages.find(
                    l => l.code === appLocale
                );

                if (!currentLang) {
                    currentLang = this.activeLanguages.find(
                        l => l.is_default === 1
                    );
                }

                this.currentLanguageId = currentLang ? currentLang.id : null;
            }
        });
},


        getSeoSettings(){

            this.isLoading = true
            const params = {
                offset: this.currentPage,
                limit: this.perPage,
                filter: this.filter,
                // Zone filter: the API also returns the global (all zones) rows.
                zone_id: this.czZoneParam,
            };
            axios.get(this.$apiUrl + '/seo_settings', { params }) 
                .then((response) => {
                    this.isLoading = false
                    let data = response.data;
                    this.seo_settings = data.data;
                    this.totalRows = data.total
                });
        },
        

        deleteSeoSettings(index, id){
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
                        id : id
                    }
                    axios.post(this.$apiUrl + '/seo_settings/delete',postData)
                        .then((response) => {
                            this.isLoading = false
                            let data = response.data;
                            this.seo_settings.splice(index, 1)
                            this.showMessage('success', data.message);
                        });
                }
            });
        },
        showCreateModal(){
            let create = this.$route.params.create;
            if(create){
                this.create_new = true;
            }
        },
        onSeoSaved(message) {
            this.showMessage('success', message);
            this.getSeoSettings();
            this.hideModal();
        },
        hideModal() {
            this.create_new = false
            this.edit_record = false
             this.getSeoSettings();
        },
        
        // View more functionality methods
        toggleSchemaExpansion(id) {
            this.expandedSchema[id] = !this.expandedSchema[id];
        },
        
        toggleMetaExpansion(id) {
            this.expandedMeta[id] = !this.expandedMeta[id];
        },
        
        shouldTruncate(text) {
            return text && text.length > this.maxLength;
        },
        
        getTruncatedText(text) {
            if (!text) return '';
            return text.length > this.maxLength ? text.substring(0, this.maxLength) + '...' : text;
        },
    }
};
</script>
