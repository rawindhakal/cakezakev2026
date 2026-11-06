<template>
    <div>
        <div class="list-page">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('customers') }}</h3>
            </div>

            <div class="list-surface">
                <div class="list-toolbar">
                    <div class="list-toolbar-start d-flex flex-wrap gap-2">
                        <AppSelect v-model="statusFilter" class="form-select list-select"
                            :options="statusFilterOptions" :searchable="false" />
                        <AppSelect v-model="typeFilter" class="form-select list-select"
                            :options="typeFilterOptions" :searchable="false" />
                    </div>

                    <div class="list-search">
                        <Search class="list-search-icon" />
                        <input id="filter-input" v-model="filter" type="search" class="form-control"
                            :placeholder="__('search')">
                    </div>

                    <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getCustomers()">
                        <RefreshCw :class="{ 'is-spinning': isLoading }" />
                    </button>
                </div>

                <MazerDatatable responsive :items="displayCustomers" :fields="fields" :current-page="currentPage" :per-page="perPage"
                    :filter="filter" :filter-included-fields="filterOn" v-model:sort-by="sortBy"
                    v-model:sort-desc="sortDesc" :sort-direction="sortDirection"
                    :busy="isLoading" stacked="md" show-empty small>

                    <template #cell(name)="row">
                        <div class="db-identity justify-content-center">
                            <img v-if="row.item.profile" :src="row.item.profile" class="db-identity-avatar" alt="" />
                            <span v-else class="db-identity-avatar"></span>
                            <router-link class="db-identity-name"
                                :to="{ name: 'ViewCustomer', params: { id: row.item.id } }">
                                {{ row.item.name || '—' }}
                            </router-link>
                        </div>
                    </template>

                    <template #cell(email)="row">
                        {{ $filters.emailMask(row.item.email) }}
                    </template>

                    <template #cell(mobile)="row">
                        {{ (row.item.country_code ? row.item.country_code + ' ' : '') + $filters.mobileMask(row.item.mobile) }}
                    </template>

                    <template #cell(type)="row">
                        <img :src="$baseUrl + '/images/phone.png'" height="40" alt="phone"
                            v-if="row.item.type == 'phone'" />
                        <img :src="$baseUrl + '/images/google.png'" height="40" alt="google"
                            v-if="row.item.type == 'google'" />
                        <img :src="$baseUrl + '/images/apple.png'" height="40" alt="apple"
                            v-if="row.item.type == 'apple'" />
                        <img :src="$baseUrl + '/images/email.png'" height="40" email="email"
                            v-if="row.item.type == 'email'" />
                    </template>

                    <template #cell(status)="row">
                        <span v-if="row.item.status == 1" class="status-pill is-active">{{ __('active') }}</span>
                        <span v-else class="status-pill is-inactive">{{ __('deactive') }}</span>
                    </template>

                    <template #cell(created_at)="row">
                        {{ $filters.formatDateTime(row.item.created_at) }}
                    </template>
                    <template #cell(actions)="row">
                        <div class="list-actions">
                            <router-link :to="{ name: 'ViewCustomer', params: { id: row.item.id } }"
                                class="list-action-btn is-view" v-b-tooltip.hover :title="__('view')">
                                <Eye :size="15" />
                            </router-link>
                        </div>
                    </template>

                </MazerDatatable>

                <div class="list-footer">
                    <div class="list-perpage">
                        <span>{{ __('per_page') }}</span>
                        <b-form-select id="per-page-select" v-model="perPage" @change="addFilter" :options="pageOptions"
                            size="sm" class="form-select"></b-form-select>
                        <span class="list-range">{{ __('total_records') }} : {{ totalRows }}</span>
                    </div>

                    <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage" size="sm"
                        class="mb-0 list-pagination"></b-pagination>
                </div>
            </div>
        </div>


    </div>
</template>
<script>
import { Search, RefreshCw, Eye } from 'lucide-vue-next';
import ListState from '../../mixins/ListState.js';

export default {
    mixins: [ListState],
    // Come back from a customer and land where you left, not on page 1.
    listState: ['currentPage', 'perPage', 'filter', 'statusFilter', 'typeFilter', 'sortBy', 'sortDesc'],
    components: { Search, RefreshCw, Eye },
    data: function () {
        return {
            isLoading: false,
            fields: [
                { key: 'id', label: __('id'), sortable: true, sortDirection: 'desc' },
                { key: 'name', label: __('name'), sortable: false, class: 'text-center' },
                { key: 'email', label: __('email'), sortable: false, class: 'text-center' },
                { key: 'mobile', label: __('mobile_no'), sortable: false, class: 'text-center' },
                { key: 'status', label: __('status'), sortable: true, class: 'text-center' },
                { key: 'type', label: __('type'), sortable: false, class: 'text-center' },
                { key: 'created_at', label: __('date'), sortable: true, class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false, class: 'text-center' }
            ],
            totalRows: 1,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,

            sortBy: 'id',
            sortDesc: true,
            sortDirection: 'desc',
            filter: null,
            filterOn: [],
            statusFilter: '',
            typeFilter: '',
            customers: [],
        }
    },
    computed: {
        // Fixed option set — no search box needed. Values stay strings so the
        // existing filter comparisons keep working.
        statusFilterOptions() {
            return [
                { id: '', name: __('all_status') },
                { id: '1', name: __('active') },
                { id: '0', name: __('deactive') },
            ];
        },
        // How the customer signed up — the same four types the type column renders.
        typeFilterOptions() {
            return [
                { id: '', name: __('all_login_types') },
                { id: 'phone', name: __('phone') },
                { id: 'google', name: __('google') },
                { id: 'apple', name: __('apple') },
                { id: 'email', name: __('email') },
            ];
        },
        // The API applies status + login-type now; this is just the loaded list.
        displayCustomers() {
            return this.customers;
        },
        sortOptions() {
            // Create an options list from our fields
            return this.fields
                .filter(f => f.sortable)
                .map(f => {
                    return { text: f.label, value: f.key }
                })
        }
    },
    watch: {
        typeFilter() { this.currentPage = 1; this.getCustomers(); },
        statusFilter() { this.currentPage = 1; this.getCustomers(); },
    },
    mounted() {
        // Set the initial number of items
        this.totalRows = this.customers.length
    },
    created: function () {
        this.$eventBus.on('customersSaved', (message) => {
            this.showMessage("success", message);
            this.getCustomers();
            this.create_new = null;
        });
        this.getCustomers();
    },
    methods: {
        addFilter() {
            this.customers = [];
            this.totalRows = 1;
            this.currentPage = 1;
            this.offset = 0;
            this.getCustomers();
        },
        getCustomers() {
            let vm = this;
            this.isLoading = true;
            axios.get(this.$apiUrl + '/customers', {
                params: {
                    type: this.typeFilter || '',
                    status: this.statusFilter === '' ? '' : this.statusFilter,
                },
            })
                .then((response) => {
                    this.isLoading = false;
                    vm.isLoading = false;

                    this.customers = response.data.data;

                    this.totalRows = response.data.total;

                }).catch(error => {

                    vm.isLoading = false;
                    if (error.request?.statusText) {
                        this.showError(error.request?.statusText);
                    } else if (error.message) {
                        this.showError(error.message);
                    } else {
                        this.showError(__('something_went_wrong'));
                    }
                });

        },
    }
};
</script>
