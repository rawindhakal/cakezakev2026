<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('emails') }}</h3>

            <button
                class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                @click="create_new=true"
                v-if="$can('send_email')">
                <Plus :size="16" />
                <span>{{ __('send_email') }}</span>
            </button>
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

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getEmails()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive
                :items="emails"
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

                <template #cell(image)="row">
                    <p v-if="row.item.image ===''">{{ __('no_image') }}</p>
                    <img :src="$storageUrl + row.item.image" class="list-thumb" v-else/>
                </template>
                <template #cell(type)="row">
                    {{ typeLabel(row.item.type) }}
                </template>
                <template #cell(actions)="row">
                    <div class="list-actions">
                        <button class="list-action-btn is-delete" @click="deleteEmail(row.index,row.item.id)"  v-if="$can('delete_send_email')" v-b-tooltip.hover :title="__('delete')"><Trash2 :size="15" /></button>
                    </div>
                </template>
                <template #cell(message)="row">
                    <small :id="'bonus'+row.item.id" class="d-inline-flex mb-3 px-2 py-1 text-muted bg-secondary bg-opacity-10 border border-secondary border-opacity-10 rounded-2">
                        <Info :size="14" />
                    </small>
                     <b-popover :target="'bonus'+row.item.id" triggers="hover" placement="left">
                            <div v-html="row.item.message"></div>
                    </b-popover>
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

        <!-- Add / Edit -->
        <app-edit-record
            v-if="create_new || edit_record"
            :record="edit_record"
            :users="users"
            :delivery_boys="delivery_boys"
            @modalClose="hideModal()"
        ></app-edit-record>
    </div>
</template>
<script>
import EditRecord from './Edit.vue';
import { Search, RefreshCw, Plus, Trash2, Info } from 'lucide-vue-next';
export default {
    components: {
        'app-edit-record' : EditRecord,
        Search, RefreshCw, Plus, Trash2, Info,
    },
    data: function() {
        return {
            fields: [
                { key: 'id', label: __('id'), sortable: true, sortDirection: 'desc', class: 'text-center' },
                { key: 'title', label: __('title'), sortable: false, class: 'text-center' },
                { key: 'message', label: __('messgae'), sortable: false, class: 'text-center' },
                { key: 'type', label: __('type'), sortable: false, class: 'text-center' },
                { key: 'type_id', label: __('id'), sortable: false, class: 'text-center' },
                { key: 'image', label: __('image'), sortable: false, class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false, class: 'text-center' }
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
            isLoading: false,
            sectionStyle : 'style_1',
            max_visible_units : 12,
            max_col_in_single_row : 3,
            create_new : null,
            edit_record : null,

            users: [],
            delivery_boys: [],
            emails: [],
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
        this.totalRows = this.emails.length
    },
    watch: {
        $route(to, from) {
            this.showCreateModal();
        }
    },
    created: function() {
        if (!this.$can('manage_emails')) {
            this.showError("You do not have permission to view this page.");
            this.$router.back();
        }
        this.showCreateModal();
        this.ensureEventListeners();
        this.getEmails();
    },
    beforeUnmount() {
        this.$eventBus.off('emailSaved');
    },
    methods: {
        ensureEventListeners() {
            this.$eventBus.off('emailSaved');
            this.$eventBus.on('emailSaved', (message) => {
                this.showMessage("success", message);
                this.getEmails();
                this.create_new = null;
            });
        },
        // Map the stored type key to a human label (delivery_boy -> Delivery Boy).
        typeLabel(type) {
            const map = {
                default: __('default'),
                user: __('customer'),
                cart: __('cart'),
                delivery_boy: __('delivery_boy'),
            };
            return map[type] || (type ? String(type).replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()) : '');
        },
        getEmails(){
            this.isLoading = true
            axios.get(this.$apiUrl + '/emails')
                .then((response) => {
                    this.isLoading = false
                    this.users = response.data.data.users;
                    this.delivery_boys = response.data.data.delivery_boys || [];
                    this.emails = response.data.data.emails;
                    this.totalRows = this.emails.length
                });
        },
        deleteEmail(index, id){
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
                    axios.post(this.$apiUrl + '/emails/delete',postData)
                        .then((response) => {
                            this.isLoading = false
                            this.emails.splice(index, 1)
                            this.showMessage("success", response.data.message);
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
        hideModal() {
            this.create_new = false
            this.edit_record = false
            this.$router.push({path: '/emails'});
        },
    }
};
</script>
