<template>
    <div class="list-page">
        <div class="row mb-2">
            <div class="col-6 col-md-4">
                <div class="cc-stat">
                    <span class="cc-stat-icon tone-hand"><Handshake :size="22" /></span>
                    <div class="cc-stat-meta">
                        <div class="cc-stat-label">{{ __('cash_in_hand') }}</div>
                        <div class="cc-stat-num">{{ cur+" "+cash_in_hand }}</div>
                    </div>
                </div>
            </div>
            <div class="col-6 col-md-4">
                <div class="cc-stat">
                    <span class="cc-stat-icon tone-cash"><Banknote :size="22" /></span>
                    <div class="cc-stat-meta">
                        <div class="cc-stat-label">{{ __('cash_collected') }}</div>
                        <div class="cc-stat-num">{{ cur+" "+Math.abs(cash_collected) }}</div>
                    </div>
                </div>
            </div>
        </div>

        <div class="page-head">
            <h3 class="page-head-title">{{ __('cash_collection_list') }}</h3>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-toolbar-start flex-nowrap">
                    <div class="cc-daterange">
                        <date-range-picker
                            v-model="dateRange"
                            :config="datePickerConfig"
                            @update="getTransactions"
                        ></date-range-picker>
                    </div>
                    <button v-if="dateRange" class="list-icon-btn" @click="dateRange = ''; getTransactions()"
                        v-b-tooltip.hover :title="__('clear')">
                        <X :size="16" />
                    </button>
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
                <template #cell(order_id)="row">
                    {{ row.item.order_number || (row.item.order_id ? '#' + row.item.order_id : '—') }}
                </template>
                <template #cell(message)="row">
                    {{ row.item.message }}
                </template>
                <template #cell(amount)="row">
                    <strong>{{ (row.item.currency || cur) + row.item.amount }}</strong>
                </template>
                <template #cell(created_at)="row">
                    {{ $filters.formatDateTime(row.item.transaction_date) }}
                </template>
                <template #cell(status)="row">
                    <span class="status-pill is-active">{{ row.item.status }}</span>
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
                    <span class="list-range text-success">{{ __('total_amount') }} :- {{ cur }} {{ total_amount }}</span>
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
</template>
<script>
import DateRangePicker from '../../components/DateRangePicker.vue'
import { buildDateRangeConfig, toApiDate } from '../../utils/dateRange.js';
import { Search, RefreshCw, Handshake, Banknote, X } from 'lucide-vue-next';
export default {
    name: "range_dates",
    components: {DateRangePicker, Search, RefreshCw, Handshake, Banknote, X},
    data: function () {
        return {
            dateRange: '',
            maxDate : new Date(),
            fields: [
                {key: 'id', label: __('id'), sortable: true, sortDirection: 'desc'},
                {key: 'order_id', label: __('order_id'), sortable: true, class: 'text-center'},
                {key: 'message', label: __('message'), sortable: true, class: 'text-center'},
                {key: 'amount', label: __('amount'), sortable: true, class: 'text-center'},
                {key: 'status', label: __('status'), sortable: true, class: 'text-center'},
                {key: 'transaction_date', label: __('date_time'), sortable: true, class: 'text-center'}
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
            max_visible_units: 12,
            max_col_in_single_row: 3,

            transactions: [],
            currency: '',
            cash_in_hand:0,
            cash_collected:0,
            total_amount:0
        }
    },
    computed: {
        cur() { return this.currency || this.$currency; },
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
        this.totalRows = this.transactions.length
    },
    created: function () {
        this.$eventBus.on('transactionsSaved', (message) => {
            this.showMessage("success", message);
            this.getTransactions();
            this.create_new = null;
        });
        this.getTransactions();
    },
    methods: {
        getTransactions() {
            this.isLoading = true
            let param = {
                "startDate": toApiDate(this.dateRange, 'start'),
                "endDate": toApiDate(this.dateRange, 'end'),
            }
            axios.get(this.$deliveryBoyApiUrl + '/cash_collection',{
                params: param
            }).then((response) => {
                this.transactions = response.data.data.transactions;
                this.cash_in_hand = response.data.data.cash_in_hand;
                this.cash_collected = response.data.data.cash_collected;
                this.currency = response.data.data.currency || '';

                this.totalRows = this.transactions.length;
                this.total_amount = this.transactions
                    .reduce((sum, item) => sum + (Number(item.amount) || 0), 0)
                    .toFixed(2);

                this.isLoading = false;
            });
        },
    }
};
</script>
<style>
.vue-daterange-picker[data-v-1ebd09d2] {
    min-width: 80%;
}
@media only screen and (min-width: 600px) {
    .vue-daterange-picker[data-v-1ebd09d2] {
        min-width: 90%;
    }
}
.cc-daterange {
    width: 240px;
    flex-shrink: 0;
}
.cc-daterange .date-range-picker,
.cc-daterange .form-control {
    width: 100%;
    height: 36px;
    border-radius: 8px;
}

/* Horizontal stat cards — tinted icon chip + label + amount (matches other views). */
.cc-stat {
    display: flex; align-items: center; gap: .75rem; height: 100%;
    background: var(--app-card-bg); border: 1px solid var(--app-card-border);
    border-radius: 12px; padding: .9rem 1rem;
}
.cc-stat-icon {
    width: 46px; height: 46px; border-radius: 12px; flex-shrink: 0;
    display: inline-flex; align-items: center; justify-content: center;
}
.cc-stat-icon.tone-hand { background: rgba(124, 58, 237, .12); color: #7c3aed; }
.cc-stat-icon.tone-cash { background: rgba(16, 185, 129, .12); color: #059669; }
.cc-stat-meta { min-width: 0; }
.cc-stat-label { font-size: .72rem; letter-spacing: .04em; text-transform: uppercase; color: var(--app-muted); }
.cc-stat-num { font-size: 1.35rem; font-weight: 800; color: var(--app-ink); line-height: 1.2; }
</style>
