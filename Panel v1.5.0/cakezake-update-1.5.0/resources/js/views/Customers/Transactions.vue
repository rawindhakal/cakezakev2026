<template>
    <div>
        <div class="list-page">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('transactions') }}</h3>
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

                    <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getTransactions()">
                        <RefreshCw :class="{ 'is-spinning': isLoading }" />
                    </button>
                </div>

                <MazerDatatable responsive
                    :items="transactions"
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
                    <template #cell(name)="row">
                        <router-link class="db-identity-name" v-if="row.item.user_id"
                            :to="{ name: 'ViewCustomer', params: { id: row.item.user_id } }">
                            {{ row.item.name || '—' }}
                        </router-link>
                        <template v-else>{{ row.item.name || '—' }}</template>
                    </template>


                    <template #cell(order_id)="row">
                        {{ row.item.order_number || (row.item.order_id ? '#' + row.item.order_id : '—') }}
                    </template>
                    <template #cell(amount)="row">
                        {{ (row.item.currency || $currency) }}{{ row.item.amount }}
                    </template>
                    <template #cell(transaction_date)="row">
                        {{ $filters.formatDateTime(row.item.transaction_date) }}
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
                    ></b-pagination>
                </div>
            </div>
        </div>
    </div>
</template>
<script>
import { Search, RefreshCw } from 'lucide-vue-next';

export default {
    components: { Search, RefreshCw },
    data: function() {
        return {
            fields: [
                { key: 'id', label:  __('id') , sortable: true, sortDirection: 'desc' },
                { key: 'name', label: __('name'), sortable: false, class: 'text-center' },
                { key: 'order_id', label: __('order_id'), sortable: false, class: 'text-center' },
                { key: 'type', label: __('type'), sortable: false, class: 'text-center' },
                { key: 'txn_id', label: __('txn_id'), sortable: false, class: 'text-center' },
                { key: 'amount', label: __('amount'), sortable: false, class: 'text-center' },
                { key: 'message', label: __('message'), sortable: false, class: 'text-center' },
                { key: 'transaction_date', label: __('transaction_date'), sortable: true, class: 'text-center' },
                { key: 'status', label: __('status'), sortable: true, class: 'text-center' }
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
            transactions: [],
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
        this.totalRows = this.transactions.length
    },
    created: function() {
        this.getTransactions();
    },
    methods: {
        getTransactions(){
            this.isLoading = true
            axios.get(this.$apiUrl + '/transactions')
                .then((response) => {
                    this.isLoading = false
                    this.transactions = response.data.data;
                    this.totalRows = this.transactions.length
                });
        },
    }
};
</script>
