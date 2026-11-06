<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('carts') }}</h3>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="cart-date-filter">
                    <date-range-picker class="cart-date-input" v-model="dateRange" :config="datePickerConfig"
                        @update="getCarts" />
                    <button v-if="dateRange" class="list-icon-btn" v-b-tooltip.hover :title="__('clear')"
                        @click="clearDates()">
                        <X :size="15" />
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

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getCarts()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive
                :items="carts"
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
                    <template #cell(user_name)="row">
                        <router-link class="db-identity-name" v-if="row.item.user_id"
                            :to="{ name: 'ViewCustomer', params: { id: row.item.user_id } }">
                            {{ row.item.user_name || '—' }}
                        </router-link>
                        <template v-else>{{ row.item.user_name || '—' }}</template>
                    </template>

                    <template #cell(product_name)="row">
                        <router-link class="db-identity-name" v-if="row.item.product_id"
                            :to="{ name: 'ViewProduct', params: { id: row.item.product_id } }">
                            {{ row.item.product_name || '—' }}
                        </router-link>
                        <template v-else>{{ row.item.product_name || '—' }}</template>
                    </template>

                <template #cell(branch_name)="row">
                    {{ row.item.branch_name || '-' }}
                </template>
                <template #cell(channel)="row">
                    {{ row.item.channel ? __(row.item.channel) : '-' }}
                </template>
                <template #cell(created_at)="row">
                    {{ $filters.formatDateTime(row.item.created_at) }}
                </template>
                <template #cell(actions)="row">
                    <div class="list-actions">
                        <button class="list-action-btn is-delete" v-b-tooltip.hover :title="__('remove')" @click="confirmRemove(row.item)">
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
</template>
<script>
import { Search, RefreshCw, Trash2, X } from 'lucide-vue-next';
import DateRangePicker from '../../components/DateRangePicker.vue';
import { buildDateRangeConfig, toApiDate } from '../../utils/dateRange.js';

export default {
    components: { Search, RefreshCw, Trash2, X, DateRangePicker },
    data: function() {
        return {
            fields: [
                { key: 'id', label: __('id'), sortable: true, sortDirection: 'desc', class: 'text-center' },
                { key: 'user_name', label: __('user'), sortable: false, class: 'text-center' },
                { key: 'product_name', label: __('product'), sortable: false, class: 'text-center' },
                { key: 'variant_name', label: __('variant'), sortable: false, class: 'text-center' },
                { key: 'branch_name', label: __('branch'), sortable: false, class: 'text-center' },
                { key: 'channel', label: __('channel'), sortable: false, class: 'text-center' },
                { key: 'qty', label: __('quantity'), sortable: true, class: 'text-center' },
                { key: 'created_at', label: __('added_on'), sortable: true, class: 'text-center' },
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
            dateRange: '',
            datePickerConfig: buildDateRangeConfig({ maxDate: new Date() }),

            isLoading: false,
            carts: [],
        }
    },
    computed: {
        sortOptions() {
            return this.fields
                .filter(f => f.sortable)
                .map(f => {
                    return { text: f.label, value: f.key }
                })
        }
    },
    mounted() {
        this.totalRows = this.carts.length
    },
    created: function() {
        this.getCarts();
    },
    methods: {
        getCarts(){
            this.isLoading = true
            const params = {};
            if (this.dateRange) {
                params.startDate = toApiDate(this.dateRange, 'start');
                params.endDate = toApiDate(this.dateRange, 'end');
            }
            axios.get(this.$apiUrl + '/carts', { params })
                .then((response) => {
                    this.isLoading = false
                    this.carts = response.data.data;
                    this.totalRows = this.carts.length
                    this.currentPage = 1
                })
                .catch(() => { this.isLoading = false });
        },
        clearDates(){
            this.dateRange = '';
            this.getCarts();
        },
        confirmRemove(item){
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('this_cart_item_will_be_removed'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: __('yes_remove'),
                cancelButtonText: __('cancel'),
            }).then(r => {
                if (!r.isConfirmed) return;
                const fd = new FormData();
                fd.append('id', item.id);
                axios.post(this.$apiUrl + '/carts/remove', fd)
                    .then(res => {
                        const body = res.data || {};
                        if (Number(body.status) === 0) {
                            this.showError(body.message || __('something_went_wrong'));
                            return;
                        }
                        this.showMessage('success', body.message || __('cart_item_removed_successfully'));
                        this.getCarts();
                    })
                    .catch(err => this.showError(err.response?.data?.message || __('something_went_wrong')));
            });
        },
    }
};
</script>
<style scoped>
.cart-date-filter {
    display: flex;
    align-items: center;
    gap: .4rem;
}
.cart-date-input {
    min-width: 220px;
}
</style>
