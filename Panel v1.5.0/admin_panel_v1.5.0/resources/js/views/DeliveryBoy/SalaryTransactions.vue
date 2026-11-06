<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('salary_transactions') }}</h3>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-toolbar-start flex-nowrap">
                    <div class="cc-daterange">
                        <date-range-picker
                            v-model="dateRange"
                            :config="datePickerConfig"
                            @update="reload"
                        ></date-range-picker>
                    </div>
                    <button v-if="dateRange" class="list-icon-btn" @click="dateRange = ''; reload()"
                        v-b-tooltip.hover :title="__('clear')">
                        <X :size="16" />
                    </button>
                </div>

                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input v-model="search" type="search" class="form-control" :placeholder="__('search')"
                        @input="debouncedReload" />
                </div>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="reload()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive
                :items="salaries"
                :fields="fields"
                :busy="isLoading"
                stacked="md"
                show-empty
                small>

                <template #head(amount)="row">
                    {{ __('amount') + ' (' + $currency + ')' }}
                </template>

                <template #cell(amount)="row">
                    <span class="status-pill is-active">
                        {{ row.item.currency || $currency }}{{ row.item.amount }}
                    </span>
                </template>

                <template #cell(paid_on)="row">
                    {{ $filters.formatDate(row.item.paid_on) }}
                </template>

                <template #cell(note)="row">
                    {{ row.item.note || '-' }}
                </template>

                <template #cell(created_at)="row">
                    {{ $filters.formatDateTime(row.item.created_at) }}
                </template>
            </MazerDatatable>

            <div class="list-footer">
                <div class="list-perpage">
                    <span>{{ __('per_page') }}</span>
                    <b-form-select id="per-page-select" v-model="perPage" :options="pageOptions"
                        size="sm" class="form-select"></b-form-select>
                </div>

                <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage"
                    size="sm" class="mb-0 list-pagination"></b-pagination>
            </div>
        </div>
    </div>
</template>

<script>
import DateRangePicker from '../../components/DateRangePicker.vue';
import { buildDateRangeConfig, toApiDate } from '../../utils/dateRange.js';
import { Search, RefreshCw, X } from 'lucide-vue-next';

export default {
    name: 'DeliveryBoySalaryTransactions',
    components: { DateRangePicker, Search, RefreshCw, X },
    data() {
        return {
            fields: [
                { key: 'id', label: __('id'), class: 'text-center' },
                { key: 'amount', label: __('amount'), class: 'text-center' },
                { key: 'paid_on', label: __('paid_on'), class: 'text-center' },
                { key: 'note', label: __('note'), class: 'text-center' },
                { key: 'created_at', label: __('date_created'), class: 'text-center' },
            ],
            salaries: [],
            totalRows: 0,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            search: '',
            dateRange: '',
            datePickerConfig: buildDateRangeConfig({ maxDate: new Date() }),
            isLoading: false,
            _debounce: null,
        };
    },
    created() {
        this.getSalaryTransactions();
    },
    watch: {
        // The API paginates server-side (limit/offset), so refetch on page/size change.
        currentPage() { this.getSalaryTransactions(); },
        perPage() { this.currentPage = 1; this.getSalaryTransactions(); },
    },
    methods: {
        debouncedReload() {
            clearTimeout(this._debounce);
            this._debounce = setTimeout(() => this.reload(), 400);
        },
        reload() {
            this.currentPage = 1;
            this.getSalaryTransactions();
        },
        getSalaryTransactions() {
            this.isLoading = true;
            const params = {
                limit: this.perPage,
                offset: (this.currentPage - 1) * this.perPage,
                search: this.search || '',
            };
            if (this.dateRange) {
                params.start_date = toApiDate(this.dateRange, 'start');
                params.end_date = toApiDate(this.dateRange, 'end');
            }
            axios.get(this.$deliveryBoyApiUrl + '/salary_transactions', { params })
                .then((response) => {
                    this.salaries = response.data.data || [];
                    this.totalRows = response.data.total || 0;
                })
                .catch(() => this.showError(__('something_went_wrong')))
                .finally(() => { this.isLoading = false; });
        },
    },
};
</script>

<style scoped>
.cc-daterange {
    width: 240px;
    flex-shrink: 0;
}
.cc-daterange :deep(.date-range-picker),
.cc-daterange :deep(.form-control) {
    width: 100%;
    height: 36px;
    border-radius: 8px;
}
</style>
