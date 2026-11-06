<template>
    <div>
        <div class="list-page">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('social_media') }}</h3>

                <div class="page-head-actions ms-auto">
                    <router-link to="/settings"
                        class="btn btn-outline-secondary d-inline-flex align-items-center gap-1 mb-0">
                        <ArrowLeft :size="16" /> {{ __('back') }}
                    </router-link>
                    <button
                        class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                        @click="create_new=true"
                        v-if="$can('manage_social_media')">
                        <Plus :size="16" />
                        <span>{{ __('add') }}</span>
                    </button>
                </div>
            </div>

            <div class="list-surface">
                <div class="list-toolbar">
                    <div class="list-search">
                        <Search class="list-search-icon" />
                        <input
                            id="filter-input"
                            v-model="filter"
                            type="search"
                            class="form-control"
                            :placeholder="__('search')">
                    </div>

                    <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getSocialMedia()">
                        <RefreshCw :class="{ 'is-spinning': isLoading }" />
                    </button>
                </div>

                <MazerDatatable responsive
                    :items="socialMedia"
                    :fields="fields"
                    :current-page="currentPage"
                    :per-page="perPage"
                    :filter="filter"
                    :filter-included-fields="filterOn"
                    v-model:sort-by="sortBy"
                    v-model:sort-desc="sortDesc"
                    :sort-direction="sortDirection"

                    :busy="isLoading"
                    stacked="md"
                    show-empty
                    small>
                    <template #cell(icon)="row">
                        <img v-if="row.item.icon_url" :src="row.item.icon_url" alt="icon"
                            style="width:28px;height:28px;object-fit:contain;">
                        <span v-else>-</span>
                    </template>

                    <template #cell(actions)="row">
                        <div class="list-actions">
                            <button class="list-action-btn is-edit" @click="edit_record = row.item" v-if="$can('manage_social_media')" v-b-tooltip.hover :title="__('edit')">
                                <Pencil :size="15" />
                            </button>
                            <button class="list-action-btn is-delete" @click="deleteSocialMedia(row.index,row.item.id)" v-if="$can('manage_social_media')" v-b-tooltip.hover :title="__('delete')">
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
                    </div>

                    <b-pagination
                        v-model="currentPage"
                        :total-rows="totalRows"
                        :per-page="perPage"
                        size="sm"
                        class="mb-0 list-pagination"
                    ></b-pagination>
                </div>
            </div>
        </div>
        <!-- Add / Edit -->
        <app-edit-record
            v-if="create_new || edit_record"
            :record="edit_record"
            @modalClose="hideModal()"
        ></app-edit-record>
    </div>
</template>
<script>
import EditRecord from './Edit.vue';
import { Search, RefreshCw, Plus, Pencil, Trash2, ArrowLeft } from 'lucide-vue-next';
export default {
    components: {
        'app-edit-record' : EditRecord,
        Search, RefreshCw, Plus, Pencil, Trash2, ArrowLeft,
    },
    data: function() {
        return {
            fields: [
                { key: 'id', label:  __('id') , sortable: true, sortDirection: 'desc' },
                { key: 'icon', label:  __('icon') , sortable: false, class: 'text-center' },
                { key: 'link', label: __('link') , sortable: false, class: 'text-center' },
                { key: 'actions', label:  __('actions'), sortable: false  }
            ],
            totalRows: 1,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions, 
            sortBy: '',
            sortDesc: false,
            sortDirection: 'asc',
            filter: null,
            filterOn: [],
            page: 1,
            per_page: 10,
            isLoading: false,

            sectionStyle : 'style_1',
            max_visible_units : 12,
            max_col_in_single_row : 3,
            create_new : null,
            edit_record : null,

            socialMedia: [],
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
        }
    },
    mounted() {
        // Set the initial number of items
        this.totalRows = this.socialMedia.length
    },
    created: function() {
        this.$eventBus.on('socialMediaSaved', (message) => {
            this.showMessage("success", message);
            this.getSocialMedia();
            this.create_new = null;
        });
        this.getSocialMedia();
    },
    methods: {
        getSocialMedia(){
            this.isLoading = true
           
            axios.get(this.$apiUrl + '/social_media')
                .then((response) => {
                    this.socialMedia = response.data.data;
                    this.totalRows = this.socialMedia.length
                    this.isLoading = false
                });
        },
        deleteSocialMedia(index, id){
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
                    axios.post(this.$apiUrl + '/social_media/delete',postData)
                        .then((response) => {
                            this.isLoading = false
                            this.socialMedia.splice(index, 1)
                            this.showMessage("success", response.data.message)
                        });
                }
            });
        },
        hideModal() {
            this.create_new = false
            this.edit_record = false
        },
    }
};
</script>
