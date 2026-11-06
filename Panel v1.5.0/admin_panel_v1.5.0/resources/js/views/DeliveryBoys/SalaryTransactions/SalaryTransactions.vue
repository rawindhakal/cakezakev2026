<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('salary_transactions') }}</h3>
            <button class="btn btn-primary ms-auto" v-if="$can('delivery_boy_salary_create')" @click="openAdd">
                <Plus :size="16" /> {{ __('add_salary') }}
            </button>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-toolbar-start flex-nowrap">
                    <AppSelect v-if="czShowCountry" class="form-control form-select list-select cz-sel"
                        v-model="czCountryId" :options="czCountryOptions" :searchable="czCountryOptions.length > 6"
                        :allow-empty="false" label-key="label" track-by="id" :placeholder="__('country')"
                        @update:model-value="czOnCountry">
                        <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                    :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                        <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                    :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                    </AppSelect>
                    <AppSelect v-model="deliveryBoyFilter" class="form-control form-select list-select list-select-lg"
                        :options="deliveryBoyOptions" @update:model-value="onFilterChange" />
                    <div class="sal-daterange">
                        <date-range-picker v-model="dateRange" :config="datePickerConfig"
                            :placeholder="__('filter_by_paid_on')" @update="onDateRange" />
                    </div>
                    <button v-if="dateRange" class="list-icon-btn" @click="dateRange = ''; onDateRange()"
                        v-b-tooltip.hover :title="__('clear')">
                        <X :size="16" />
                    </button>
                </div>

                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input type="search" class="form-control" v-model="search"
                        :placeholder="__('search')" @input="onSearch" />
                </div>

                <button class="list-icon-btn" @click="getRecords" :disabled="isLoading"
                    v-b-tooltip.hover :title="__('refresh')">
                    <RefreshCw :size="16" :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <div v-if="isLoading" class="text-center py-5">
                <b-spinner></b-spinner>
            </div>
            <div v-else-if="records.length === 0"
                class="d-flex flex-column align-items-center justify-content-center text-muted py-5">
                <Inbox :size="40" class="mb-2" />
                <p class="mb-0">{{ __('no_records_found') }}</p>
            </div>

            <div v-else class="table-responsive">
                <table class="table align-middle text-center">
                    <thead>
                        <tr>
                            <th>{{ __('id') }}</th>
                            <th>{{ __('delivery_boy') }}</th>
                            <th>{{ __('amount') }}</th>
                            <th>{{ __('paid_on') }}</th>
                            <th>{{ __('note') }}</th>
                            <th>{{ __('actions') }}</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-for="r in records" :key="'sal-' + r.id">
                            <td>{{ r.id }}</td>
                            <td>
                                <div class="db-identity">
                                    <img v-if="r.profile_url" :src="r.profile_url" class="db-identity-avatar" alt="" />
                                    <span v-else class="db-identity-avatar"></span>
                                    <span class="db-identity-lines">
                                        <router-link v-if="r.delivery_boy_id" class="db-identity-name"
                                            :to="{ name: 'ViewDeliveryBoy', params: { id: r.delivery_boy_id } }">
                                            {{ r.name || '—' }}
                                        </router-link>
                                        <span v-else class="db-identity-name">{{ r.name || '—' }}</span>
                                        <small v-if="r.email" class="db-identity-sub" :title="$filters.emailMask(r.email)">
                                            {{ $filters.emailMask(r.email) }}
                                        </small>
                                        <small class="db-identity-sub">{{ mobileWithCode(r) }}</small>
                                    </span>
                                </div>
                            </td>
                            <td class="fw-bold">{{ (r.currency || $currency) }}{{ Number(r.amount).toFixed(2) }}</td>
                            <td>{{ r.paid_on ? $filters.formatDate(r.paid_on) : '—' }}</td>
                            <td class="text-truncate mx-auto" style="max-width:220px;" :title="r.note">{{ r.note || '—' }}</td>
                            <td class="text-nowrap">
                                <div class="list-actions">
                                    <button class="list-action-btn is-edit" @click="openEdit(r)"
                                        v-if="$can('delivery_boy_salary_create')" v-b-tooltip.hover :title="__('edit')">
                                        <Pencil :size="15" />
                                    </button>
                                    <button class="list-action-btn is-delete" @click="deleteRecord(r)"
                                        v-if="$can('delivery_boy_salary_delete')" v-b-tooltip.hover :title="__('delete')">
                                        <Trash2 :size="15" />
                                    </button>
                                </div>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>

            <div v-if="!isLoading && records.length > 0" class="list-footer">
                <div class="list-perpage">
                    <span>{{ __('per_page') }}</span>
                    <b-form-select v-model="perPage" :options="pageOptions" size="sm"
                        class="form-select" @change="onPerPageChange"></b-form-select>
                </div>
                <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage"
                    align="end" size="sm" class="mb-0 list-pagination"></b-pagination>
            </div>
        </div>

        <app-salary-edit v-if="showModal" :record="edit_record" :currency="currency" @modalClose="showModal = false"></app-salary-edit>
    </div>
</template>

<script>
import axios from 'axios';
import EditRecord from './Edit.vue';
import DateRangePicker from '../../../components/DateRangePicker.vue';
import { buildDateRangeConfig, toApiDate } from '../../../utils/dateRange.js';
import { Plus, Search, RefreshCw, X, Pencil, Trash2, Inbox } from 'lucide-vue-next';
import CountryZoneFilter from '../../../mixins/CountryZoneFilter.js';

export default {
    mixins: [CountryZoneFilter],
    components: { 'app-salary-edit': EditRecord, DateRangePicker, Plus, Search, RefreshCw, X, Pencil, Trash2, Inbox },
    data() {
        return {
            czAllowAll: true,
            czShowZone: false,
            records: [],
            currency: '',
            search: '',
            deliveryBoyFilter: '',
            deliveryBoysList: [],
            dateRange: '',
            datePickerConfig: buildDateRangeConfig(),
            isLoading: false,
            currentPage: 1,
            perPage: 10,
            pageOptions: this.$pageOptions,
            totalRows: 0,
            showModal: false,
            edit_record: null,
            _searchTimer: null,
        };
    },
    created() {
        this.czLoad(); // loads country then czOnFilter (list + boy dropdown for that country)
        this.$eventBus?.on('salaryTransactionSaved', this._onSaved);
    },
    beforeUnmount() {
        this.$eventBus?.off('salaryTransactionSaved', this._onSaved);
    },
    computed: {
        // The mobile number used to be markup inside the option; fold it into the label.
        deliveryBoyOptions() {
            return [{ id: '', name: __('all_delivery_boys') }]
                .concat((this.deliveryBoysList || []).map(b => ({
                    id: b.id,
                    name: b.mobile
                        ? `${b.name} (${(b.country_code ? b.country_code + ' ' : '') + this.$filters.mobileMask(b.mobile)})`
                        : b.name,
                })));
        },
    },
    watch: {
        currentPage() { this.getRecords(); },
    },
    methods: {
        _onSaved(message) {
            this.showMessage('success', message);
            this.showModal = false;
            this.getRecords();
        },
        czOnFilter() {
            this.currentPage = 1;
            this.deliveryBoyFilter = '';
            this.fetchDeliveryBoys();
            this.getRecords();
        },
        getRecords() {
            this.isLoading = true;
            const params = {
                limit: this.perPage,
                offset: (this.currentPage - 1) * this.perPage,
                search: this.search,
                country_id: this.czCountryParam,
                delivery_boy_id: this.deliveryBoyFilter || '',
                start_date: this.dateRange ? toApiDate(this.dateRange, 'start') : '',
                end_date: this.dateRange ? toApiDate(this.dateRange, 'end') : '',
            };
            axios.get(this.$apiUrl + '/salary_transactions', { params }).then(r => {
                this.records = r.data.data || [];
                this.totalRows = r.data.total || 0;
                this.currency = (this.records[0] && this.records[0].currency) || this.currency;
            }).catch(() => { this.records = []; })
                .finally(() => { this.isLoading = false; });
        },
        onSearch() {
            if (this._searchTimer) clearTimeout(this._searchTimer);
            this._searchTimer = setTimeout(() => { this.currentPage = 1; this.getRecords(); }, 300);
        },
        onFilterChange() { this.currentPage = 1; this.getRecords(); },
        fetchDeliveryBoys() {
            axios.get(this.$apiUrl + '/delivery_boys', {
                params: {
                    country_id: this.czCountryParam,
                    filterStatus: 1,
                },
            }).then(r => {
                this.deliveryBoysList = (r.data.data || []).map(b => ({
                    id: b.id, name: b.name, mobile: b.mobile, country_code: b.country_code,
                }));
            }).catch(() => { this.deliveryBoysList = []; });
        },
        onPerPageChange() { this.currentPage = 1; this.getRecords(); },
        onDateRange() { this.currentPage = 1; this.getRecords(); },
        mobileWithCode(r) {
            const code = (r.country_code || '').toString().trim();
            const mob = (r.mobile || '').toString().trim();
            if (!mob) return '';
            // Masked in demo mode; the filter passes the value through otherwise.
            return (code ? code + ' ' : '') + this.$filters.mobileMask(mob);
        },
        openAdd() { this.edit_record = null; this.showModal = true; },
        openEdit(r) { this.edit_record = r; this.showModal = true; },
        deleteRecord(r) {
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
                if (!result.value) return;
                axios.post(this.$apiUrl + '/salary_transactions/delete', { id: r.id }).then(res => {
                    this.showMessage('success', res.data.message);
                    this.getRecords();
                }).catch(() => { });
            });
        },
    },
};
</script>

<style scoped>
.sal-daterange {
    width: 220px;
    flex-shrink: 0;
}
.sal-daterange :deep(.date-range-picker) {
    width: 100%;
    display: block;
}
.sal-daterange :deep(input),
.sal-daterange :deep(.form-control) {
    width: 100%;
    height: 36px;
    border-radius: 8px;
}
</style>
