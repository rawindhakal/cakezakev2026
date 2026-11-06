<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('settlement_history') }}</h3>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-toolbar-start">
                    <AppSelect v-model="entryTypeFilter" class="form-control form-select list-select list-select-lg"
                        :options="entryTypeOptions" :searchable="false" />
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

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getSettlements()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive
                :items="filteredSettlements"
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
                <template #cell(entry_type)="row">
                    <span class="badge" :class="entryTypeBadge(row.item.entry_type)">
                        {{ entryTypeLabels[row.item.entry_type] || row.item.entry_type }}
                    </span>
                </template>

                <template #cell(amount)="row">
                    <strong :class="row.item.type === 'credit' ? 'text-success' : 'text-danger'">
                        {{ (row.item.type === 'credit' ? '+' : '-') + (row.item.currency || $currency) + row.item.amount }}
                    </strong>
                </template>

                <template #cell(closing_balance)="row">
                    <span v-if="row.item.closing_balance === null">—</span>
                    <span v-else>{{ (row.item.currency || $currency) + row.item.closing_balance }}</span>
                </template>

                <template #cell(created_at)="row">
                    {{ $filters.formatDateTime(row.item.created_at) }}
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
</template>
<script>
import { Search, RefreshCw } from 'lucide-vue-next';

export default {
    components: { Search, RefreshCw },
    data: function () {
        return {
            fields: [
                {key: 'id', label: __('id'), sortable: true, sortDirection: 'desc'},
                {key: 'entry_type', label: __('type'), sortable: true, class: 'text-center'},
                {key: 'amount', label: __('amount'), sortable: true, class: 'text-center'},
                {key: 'closing_balance', label: __('closing_balance'), sortable: true, class: 'text-center'},
                {key: 'message', label: __('message'), sortable: true, class: 'text-center'},
                {key: 'created_at', label: __('date_created'), sortable: true, class: 'text-center'}
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
            entryTypeFilter: '',

            isLoading: false,
            settlements: [],
        }
    },
    computed: {
        // entryTypeLabels is a key -> label map; AppSelect works in { id, name }.
        entryTypeOptions() {
            return [{ id: '', name: __('all') }]
                .concat(Object.entries(this.entryTypeLabels).map(([id, name]) => ({ id, name })));
        },
        entryTypeLabels() {
            return {
                delivery_commission: __('delivery_commission'),
                return_commission: __('return_commission'),
                withdrawal: __('withdrawal'),
                cash_deposit_cash: __('cash_deposit_cash'),
                cash_deposit_wallet: __('cash_deposit_wallet'),
            };
        },
        filteredSettlements() {
            if (!this.entryTypeFilter) return this.settlements;
            return this.settlements.filter(s => s.entry_type === this.entryTypeFilter);
        },
    },
    created: function () {
        this.getSettlements();
    },
    methods: {
        entryTypeBadge(t) {
            return {
                delivery_commission: 'bg-success',
                return_commission: 'bg-info',
                withdrawal: 'bg-warning text-dark',
                cash_deposit_cash: 'bg-primary',
                cash_deposit_wallet: 'bg-secondary',
                credit: 'bg-success',
                debit: 'bg-danger',
            }[t] || 'bg-secondary';
        },
        getSettlements() {
            this.isLoading = true
            axios.get(this.$deliveryBoyApiUrl + '/settlement_history')
                .then((response) => {
                    this.isLoading = false
                    this.settlements = response.data.data;
                    this.totalRows = this.length
                });
        },
    }
};
</script>
