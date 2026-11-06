<template>
    <div>
        <div class="list-page">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('withdrawal_requests') }}</h3>
            </div>

            <div class="list-surface">
                <div class="list-toolbar">
                    <div class="list-toolbar-start">
                        <AppSelect v-if="czShowCountry" class="form-select list-select cz-sel" v-model="czCountryId"
                            :options="czCountryOptions" :searchable="czCountryOptions.length > 6" :allow-empty="false"
                            label-key="label" track-by="id" :placeholder="__('country')" @update:model-value="czOnCountry">
                            <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                        :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                            <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                        :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                        </AppSelect>
                        <AppSelect class="form-select list-select" v-model="status" :options="statusOptions" :searchable="false" @update:model-value="getRecords()" />
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

                <div class="table-responsive withdrawal-table">
                    <MazerDatatable class="w-100" :items="withdrawalRequests" :fields="fields"
                        :current-page="currentPage" :per-page="perPage" :filter="filter"
                        :filter-included-fields="filterOn" v-model:sort-by="sortBy" v-model:sort-desc="sortDesc"
                        :sort-direction="sortDirection" :busy="isLoading" stacked="md"
                        show-empty small>
                        <template #cell(name)="row">
                            <div class="db-identity">
                                <img v-if="row.item.profile_url" :src="row.item.profile_url" class="db-identity-avatar" alt="" />
                                <span v-else class="db-identity-avatar"></span>
                                <span class="db-identity-lines">
                                    <router-link v-if="row.item.delivery_boy_id" class="db-identity-name"
                                        :to="{ name: 'ViewDeliveryBoy', params: { id: row.item.delivery_boy_id } }">
                                        {{ row.item.name || '—' }}
                                    </router-link>
                                    <span v-else class="db-identity-name">{{ row.item.name || '—' }}</span>
                                    <small v-if="row.item.email" class="db-identity-sub" :title="$filters.emailMask(row.item.email)">
                                        {{ $filters.emailMask(row.item.email) }}
                                    </small>
                                    <small v-if="row.item.mobile" class="db-identity-sub">
                                        {{ (row.item.country_code ? row.item.country_code + ' ' : '') + $filters.mobileMask(row.item.mobile) }}
                                    </small>
                                </span>
                            </div>
                        </template>

                        <template #cell(amount)="row">
                            <strong>{{ (row.item.currency || $currency) + row.item.amount }}</strong>
                        </template>

                        <template #cell(status)="row">
                            <span v-if="row.item.status === 0" class="badge bg-warning">{{ __('pending')
                                }}</span>
                            <span v-else-if="row.item.status === 1" class="badge bg-success">{{ __('approved')
                                }}</span>
                            <span v-else-if="row.item.status === 2" class="badge bg-danger">{{ __('rejected')
                                }}</span>
                            <span v-else class="badge bg-danger">{{ __('undefine') }}</span>
                        </template>
                        <template #cell(receipt_image)="row">
                            <img v-if="row.item.receipt_image_url" :src="row.item.receipt_image_url"
                                class="list-thumb" alt="" />
                            <span v-else class="text-muted">-</span>
                        </template>
                        <template #cell(message)="row">
                            <small :id="'bonus' + row.item.id"
                                class="d-inline-flex mb-3 px-2 py-1 text-muted bg-secondary bg-opacity-10 border border-secondary border-opacity-10 rounded-2">
                                <Info :size="14" />
                            </small>
                            <b-popover :target="'bonus' + row.item.id" triggers="hover" placement="left">
                                {{ row.item.message }}
                            </b-popover>

                        </template>
                        <template #cell(created_at)="row">
                            {{ $filters.formatDateTime(row.item.created_at) }}
                        </template>
                        <template #cell(actions)="row">
                            <div class="list-actions">
                                <button class="list-action-btn is-edit" @click="edit_record = row.item"
                                    v-if="$can('withdrawal_request_update')" v-b-tooltip.hover
                                    :title="__('edit')">
                                    <Pencil :size="15" />
                                </button>
                                <button class="list-action-btn is-delete"
                                    @click="deleteWithdrawalRequests(row.index, row.item.id)"
                                    v-if="$can('withdrawal_request_delete')" v-b-tooltip.hover
                                    :title="__('delete')">
                                    <Trash2 :size="15" />
                                </button>
                            </div>
                        </template>

                    </MazerDatatable>
                </div>

                <div class="list-footer">
                    <div class="list-perpage">
                        <span>{{ __('per_page') }}</span>
                        <b-form-select id="per-page-select" v-model="perPage" :options="pageOptions"
                            size="sm" class="form-select"></b-form-select>
                    </div>

                    <b-pagination v-model="currentPage" :total-rows="totalRowsFilter" :per-page="perPage"
                        size="sm" class="mb-0 list-pagination"></b-pagination>
                </div>
            </div>
        </div>
        <!-- Add / Edit -->
        <app-edit-record v-if="create_new || edit_record" :record="edit_record"
            @modalClose="hideModal()"></app-edit-record>
    </div>
</template>
<script>
import EditRecord from './Edit.vue';
import { Search, RefreshCw, Pencil, Trash2, Info } from 'lucide-vue-next';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';
export default {
    mixins: [CountryZoneFilter],
    components: {
        'app-edit-record': EditRecord,
        Search, RefreshCw, Pencil, Trash2, Info,
    },
    data: function () {
        return {
            czAllowAll: true,
            czShowZone: false,
            fields: [
                { key: 'id', label: __('id'), sortable: true, sortDirection: 'desc', thClass: 'text-nowrap' },
                { key: 'name', label: __('name'), sortable: false, class: 'text-center', thClass: 'text-nowrap' },
                { key: 'amount', label: __('amount'), sortable: false, class: 'text-center', thClass: 'text-nowrap' },
                { key: 'message', label: __('message'), sortable: false, class: 'text-center', thClass: 'text-nowrap' },
                { key: 'status', label: __('status'), sortable: true, class: 'text-center', thClass: 'text-nowrap' },
                { key: 'remark', label: __('remark'), sortable: false, class: 'text-center', thClass: 'text-nowrap' },
                { key: 'receipt_image', label: __('receipt_image'), sortable: false, class: 'text-center', thClass: 'text-nowrap' },
                { key: 'created_at', label: __('date'), sortable: true, class: 'text-center', thClass: 'text-nowrap' },
                { key: 'actions', label: __('actions'), sortable: false, thClass: 'text-nowrap', class: 'text-center' }
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
            sectionStyle: 'style_1',
            max_visible_units: 12,
            max_col_in_single_row: 3,
            create_new: null,
            edit_record: null,
            withdrawalRequests: [],
            status: "",
            remark: "",
            type: ""
        }
    },
    computed: {
        // Fixed option set — no search box needed.
        statusOptions() {
            return [
                { id: '', name: (__('select_status')) },
                { id: '0', name: (__('pending')) },
                { id: '1', name: (__('approved')) },
                { id: '2', name: (__('rejected')) },
            ];
        },
        sortOptions() {
            // Create an options list from our fields
            return this.fields
                .filter(f => f.sortable)
                .map(f => {
                    return { text: f.label, value: f.key }
                })
        },
        filteredWithdrawRequests: function () {
            const query = this.filter ? this.filter.toLowerCase() : '';
            return this.withdrawalRequests.filter(request => {
                return (
                    (request.type && request.type.toLowerCase().includes(query)) ||
                    (request.remark && request.remark.toLowerCase().includes(query))
                );
            });
        },
        totalRowsFilter: function () {
            return this.filteredWithdrawRequests.length;
        },
    },
    mounted() {
        // Set the initial number of items
        this.totalRows = this.withdrawalRequests.length
    },
    created: function () {
        this.$eventBus.on('withdrawalRequestSaved', (message) => {
            this.showMessage("success", message);
            this.getRecords();
            this.create_new = null;
        });
        this.czLoad();
    },
    methods: {
        czOnFilter() { this.currentPage = 1; this.getRecords(); },
        getRecords() {
            this.isLoading = true
            let param = {
                "type": this.type,
                "status": this.status,
                "country_id": this.czCountryParam,
            }
            axios.get(this.$apiUrl + '/withdrawal_requests', {
                params: param
            }).then((response) => {
                this.withdrawalRequests = response.data.data.withdraw_requests;
                this.totalRows = this.withdrawalRequests.length;
                this.isLoading = false;
            });
        },
        deleteWithdrawalRequests(index, id) {
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
                    axios.post(this.$apiUrl + '/withdrawal_requests/delete', postData)
                        .then((response) => {
                            this.isLoading = false
                            this.withdrawalRequests.splice(index, 1)
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
