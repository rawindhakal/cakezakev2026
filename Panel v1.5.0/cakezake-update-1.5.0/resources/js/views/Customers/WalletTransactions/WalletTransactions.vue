<template>
    <div>
        <div class="list-page">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('wallet_transactions') }}</h3>

                <button
                    class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                    @click="create_new=true">
                    <Plus :size="16" />
                    <span>{{ __('add_transactions') }}</span>
                </button>
            </div>

            <div class="list-surface">
                <div class="list-toolbar">
                    <div v-if="czShowCountry" class="list-toolbar-start">
                        <AppSelect class="form-select list-select cz-sel" v-model="czCountryId"
                            :options="czCountryOptions" :searchable="czCountryOptions.length > 6" :allow-empty="false"
                            label-key="label" track-by="id" :placeholder="__('country')" @update:model-value="czOnCountry">
                            <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                        :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                            <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                        :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                        </AppSelect>
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

                    <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getWalletTransactions()">
                        <RefreshCw :class="{ 'is-spinning': isLoading }" />
                    </button>
                </div>

                <MazerDatatable responsive
                    :items="walletTransactions"
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

                    <template #cell(amount)="row">
                        {{ (row.item.currency || czCurrency || $currency) }}{{ row.item.amount }}
                    </template>
                    <template #cell(type)="row">
                        <span v-if="row.item.type === 'credit'" class="status-pill is-active">{{ __('credit') }}</span>
                        <span v-else class="status-pill is-inactive">{{ __('debit') }}</span>
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
        <!-- Add / Edit -->
        <app-edit-record
            v-if="create_new || edit_record"
            :record="edit_record"
            :customers="customers"
            :country-id="czCountryParam"
            :currency="czCurrency || $currency"
            @modalClose="hideModal()"
        ></app-edit-record>
    </div>
</template>
<script>
import EditRecord from './Edit.vue';
import { Search, RefreshCw, Plus } from 'lucide-vue-next';
import CountryZoneFilter from '../../../mixins/CountryZoneFilter.js';

export default {
    mixins: [CountryZoneFilter],
    components: {
        'app-edit-record': EditRecord,
        Search, RefreshCw, Plus,
    },
    data: function () {
        return {
            fields: [
                {key: 'id', label:  __('id') , sortable: true, sortDirection: 'desc'},
                {key: 'user_id', label:  __('user_id'), sortable: false, class: 'text-center'},
                {key: 'name', label:  __('user_name'), sortable: false, class: 'text-center'},
                {key: 'type', label:  __('type'), sortable: false, class: 'text-center'},
                {key: 'payment_type', label:  __('payment_type'), sortable: false, class: 'text-center'},
                {key: 'txn_id', label:  __('txn_id'), sortable: false, class: 'text-center'},
                {key: 'amount', label:  __('amount'), sortable: false, class: 'text-center'},
                {key: 'message', label:  __('message'), sortable: false, class: 'text-center'},
                {key: 'transaction_date', label:  __('transaction_date'), sortable: true, class: 'text-center'}
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

            czShowZone: false, // wallet is country-scoped (default country, no All)
            customers: null,
            walletTransactions: [],
        }
    },
    computed: {
        sortOptions() {
            // Create an options list from our fields
            return this.fields
                .filter(f => f.sortable)
                .map(f => {
                    return {text: f.label, value: f.key}
                })
        }
    },
    mounted() {
        // Set the initial number of items
        this.totalRows = this.walletTransactions.length
    },
    created: function () {
        this.$eventBus.on('walletTransactionsSaved', (message) => {
            //this.showSuccess(message);
            this.showMessage("success", message);
            this.getWalletTransactions();
            this.create_new = null;
        });
        this.czLoad();
    },
    methods: {
        czOnFilter() { this.getWalletTransactions(); },
        getWalletTransactions() {
            this.isLoading = true
            axios.get(this.$apiUrl + '/wallet_transactions', { params: { country_id: this.czCountryParam } })
                .then((response) => {
                    this.isLoading = false
                    const d = response.data.data;
                    this.walletTransactions = d.walletTransactions;
                    this.customers = d.customers;
                    if (d.currency) this.czCurrency = d.currency;
                    this.totalRows = this.walletTransactions.length
                });
        },
        hideModal() {
            this.create_new = false
            this.edit_record = false
        },
    }
};
</script>
