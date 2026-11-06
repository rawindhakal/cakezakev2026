<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('cash_collection_list') }}</h3>

            <button
                class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                @click="create_new = true"
                v-if="$can('cash_collection_create')">
                <Plus :size="16" />
                <span>{{ __('add_cash_collection') }}</span>
            </button>
        </div>

        <div class="list-surface">
            <b-tabs content-class="mt-0" class="list-tabs px-3 pt-2">
                <b-tab :title="__('pending_collections')" active>
                    <div class="table-responsive">
                        <table class="table align-middle">
                            <thead>
                                <tr>
                                    <th>{{ __('id') }}</th>
                                    <th>{{ __('name') }}</th>
                                    <th>{{ __('mobile') }}</th>
                                    <th class="text-end">{{ __('cash_in_hand') }}</th>
                                    <th class="text-end">{{ __('wallet_balance') }}</th>
                                    <th class="text-center">{{ __('action') }}</th>
                                </tr>
                            </thead>
                            <tbody v-if="isLoading">
                                <tr>
                                    <td colspan="6" class="text-center py-4">
                                        <b-spinner></b-spinner>
                                    </td>
                                </tr>
                            </tbody>
                            <tbody v-else>
                                <tr v-for="boy in pendingCollections" :key="boy.id">
                                    <td>{{ boy.id }}</td>
                                    <td>
                                        <div class="db-identity">
                                            <img v-if="boy.profile_url" :src="boy.profile_url" class="db-identity-avatar" alt="" />
                                            <span v-else class="db-identity-avatar"></span>
                                            <span class="db-identity-lines">
                                                <router-link class="db-identity-name"
                                                    :to="{ name: 'ViewDeliveryBoy', params: { id: boy.id } }">
                                                    {{ getTranslatedName(boy) }}
                                                </router-link>
                                                <small v-if="boy.email" class="db-identity-sub" :title="$filters.emailMask(boy.email)">
                                                    {{ $filters.emailMask(boy.email) }}
                                                </small>
                                            </span>
                                        </div>
                                    </td>
                                    <td>{{ (boy.country_code ? boy.country_code + ' ' : '') + $filters.mobileMask(boy.mobile) }}</td>
                                    <td class="text-end fw-bold text-danger">{{ boyCurrency(boy) + money(boy.cash_received) }}</td>
                                    <td class="text-end text-success">{{ boyCurrency(boy) + money(boy.balance) }}</td>
                                    <td class="text-center">
                                        <button class="btn btn-sm btn-primary" v-if="$can('cash_collection_create')"
                                            @click="collectFrom(boy)">{{ __('collect') }}</button>
                                    </td>
                                </tr>
                                <tr v-if="!pendingCollections.length">
                                    <td colspan="6" class="text-center text-muted py-4">{{ __('no_pending_cash_collections') }}</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </b-tab>

                <b-tab :title="__('transactions')">
                    <div class="list-toolbar justify-content-end py-3">
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
                            <div class="cc-daterange">
                                <date-range-picker v-model="dateRange"
                                    :config="datePickerConfig" @update="getTransactions"></date-range-picker>
                            </div>
                            <button v-if="dateRange" class="list-icon-btn" @click="dateRange = ''; getTransactions()"
                                v-b-tooltip.hover :title="__('clear')">
                                <X :size="16" />
                            </button>

                            <AppSelect v-model="deliveryBoy" class="form-control form-select list-select"
                                :options="deliveryBoyOptions" @update:model-value="getTransactions()" />
                        </div>

                        <div class="list-search">
                            <Search class="list-search-icon" />
                            <input id="filter-input" v-model="filter" type="search" class="form-control"
                                :placeholder="__('search')">
                        </div>

                        <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')"
                            @click="getTransactions()">
                            <RefreshCw :class="{ 'is-spinning': isLoading }" />
                        </button>
                    </div>

                    <MazerDatatable :items="transactions" :fields="fields" :current-page="currentPage"
                        :per-page="perPage" :filter="filter" :filter-included-fields="filterOn"
                        v-model:sort-by="sortBy" v-model:sort-desc="sortDesc" :sort-direction="sortDirection"
                        :busy="isLoading" stacked="md" show-empty small>
                        <template #cell(order_id)="row">
                            {{ row.item.order_number || (row.item.order_id ? '#' + row.item.order_id : '—') }}
                        </template>
                        <template #cell(amount)="row">
                            <strong>{{ (row.item.currency || $currency) + row.item.amount }}</strong>
                        </template>
                        <template #cell(final_total)="row">
                            <span v-if="row.item.final_total === '-'">-</span>
                            <span v-else>{{ (row.item.currency || $currency) + row.item.final_total }}</span>
                        </template>
                        <template #cell(status)="row">
                            <span v-if="row.item.status === '1'" class="status-pill is-active">{{ __('active')
                                }}</span>
                            <span v-else class="status-pill is-inactive">{{ __('deactive') }}</span>
                        </template>
                        <template #cell(created_at)="row">
                            {{ $filters.formatDateTime(row.item.transaction_date) }}
                        </template>
                        <template #cell(message)="row">
                            {{ row.item.message }}
                        </template>
                        <template #cell(name)="row">
                            <div class="db-identity">
                                <img v-if="row.item.profile_url" :src="row.item.profile_url" class="db-identity-avatar" alt="" />
                                <span v-else class="db-identity-avatar"></span>
                                <span class="db-identity-lines">
                                    <router-link class="db-identity-name"
                                        :to="{ name: 'ViewDeliveryBoy', params: { id: row.item.delivery_boy_id } }">
                                        {{ getTranslatedName(row.item) }}
                                    </router-link>
                                    <small v-if="row.item.email" class="db-identity-sub" :title="$filters.emailMask(row.item.email)">
                                        {{ $filters.emailMask(row.item.email) }}
                                    </small>
                                </span>
                            </div>
                        </template>
                        <template #cell(mobile)="row">
                            {{ (row.item.country_code ? row.item.country_code + ' ' : '') + $filters.mobileMask(row.item.mobile || '') }}
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
                </b-tab>
            </b-tabs>
        </div>

        <!-- Add / Edit -->
        <app-edit-record v-if="create_new || edit_record" :record="edit_record" :deliveryBoys="deliveryBoys"
            :preselectBoy="preselect_boy" @modalClose="hideModal()"></app-edit-record>
    </div>
</template>
<script>
import EditRecord from './Edit.vue';
import DateRangePicker from '../../../components/DateRangePicker.vue'
import { buildDateRangeConfig, toApiDate } from '../../../utils/dateRange.js'
import { Search, RefreshCw, Plus, X } from 'lucide-vue-next';
import CountryZoneFilter from '../../../mixins/CountryZoneFilter.js';
export default {
    name: "range_dates",
    mixins: [CountryZoneFilter],
    components: {
        DateRangePicker,
        'app-edit-record': EditRecord,
        Search, RefreshCw, Plus, X,
    },
    data: function () {
        return {
            czAllowAll: true,   // per-boy currency → All Countries allowed
            czShowZone: false,  // cash collection filters by country only
            dateRange: '',
            datePickerConfig: buildDateRangeConfig({ maxDate: new Date() }),
            fields: [
                { key: 'id', label: __('id'), sortable: true, sortDirection: 'desc' },
                { key: 'name', label: ('name'), sortable: false, class: 'text-center' },
                { key: 'mobile', label: __('mobile'), sortable: false, class: 'text-center' },
                { key: 'order_id', label: __('order_no'), sortable: false, class: 'text-center' },
                { key: 'final_total', label: __('final_total'), sortable: false, class: 'text-center' },
                { key: 'amount', label: __('amount'), sortable: false, class: 'text-center' },
                { key: 'type', label: __('type'), sortable: true, class: 'text-center' },
                { key: 'delivery_boy_bonus_amount', label: __('bonus_amount'), sortable: false, class: 'text-center' },
                { key: 'message', label: __('message'), sortable: false, class: 'text-center' },
                { key: 'transaction_date', label: __('date_time'), sortable: true, class: 'text-center' }
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
            preselect_boy: null,

            deliveryBoys: null,
            deliveryBoy: "",
            transactions: [],
            pendingCollections: [],
            currentLanguageId: null,
            activeLanguages: []
        }
    },
    computed: {
        // Names are translated objects, so resolve them before AppSelect renders.
        deliveryBoyOptions() {
            return [{ id: '', name: __('all_delivery_boy') }]
                .concat((this.deliveryBoys || []).map(b => ({ id: b.id, name: this.getTranslatedName(b) })));
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
        this.fetchActiveLanguages();
        this.czLoad(); // sets default/all country then loads via czOnFilter
    },
    methods: {
        czOnFilter() { this.getTransactions(); },
        // Always two decimals, whatever the API sends back.
        money(v) {
            return Number(v || 0).toFixed(2);
        },
        boyCurrency(boy) {
            return (boy.country && boy.country.currency) || this.$currency;
        },
        async fetchActiveLanguages() {
            try {
                const res = await axios.get(this.$apiUrl + '/active_languages');

                if (res.data.status === 1 && Array.isArray(res.data.data)) {
                    this.activeLanguages = res.data.data;

                    const appLocale = window.appLocale || 'en';

                    const currentLang = this.activeLanguages.find(
                        l => l.code === appLocale
                    );

                    if (currentLang) {
                        this.currentLanguageId = currentLang.id;
                    } else {
                        const def = this.activeLanguages.find(l => l.is_default === 1);
                        if (def) this.currentLanguageId = def.id;
                    }
                }
            } catch (e) {
                console.error('Language load failed', e);
            }
        },
        getTranslatedName(item) {
            // If no language is set, return main table name
            if (!this.currentLanguageId) {
                return item.name || '';
            }

            // Check if item has translations array
            if (item.translations && Array.isArray(item.translations)) {
                const translation = item.translations.find(
                    t => t.language_id === this.currentLanguageId
                );

                // Use translation if it exists and has value
                if (translation && translation.name && translation.name.trim() !== '') {
                    return translation.name;
                }
            }

            // Fallback: Use main table name if no translation found
            return item.name || '';
        },
        getTransactions() {
            this.isLoading = true
            let param = {
                "startDate": toApiDate(this.dateRange, 'start'),
                "endDate": toApiDate(this.dateRange, 'end'),
                "delivery_boy_id": this.deliveryBoy,
                "country_id": this.czCountryParam,
            }
            axios.get(this.$apiUrl + '/cash_collection', {
                params: param
            }).then((response) => {
                this.transactions = response.data.data.transactions;
                this.deliveryBoys = response.data.data.deliveryBoys;
                this.pendingCollections = response.data.data.pendingCollections || [];
                this.totalRows = this.transactions.length;
                this.isLoading = false;
            });
        },
        // "Collect" from the pending tab — open the modal with the boy preselected.
        collectFrom(boy) {
            this.preselect_boy = boy;
            this.create_new = true;
        },
        hideModal() {
            this.create_new = false
            this.edit_record = false
            this.preselect_boy = null
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
.cc-daterange .date-range-picker {
    width: 100%;
    display: block;
}
.cc-daterange input,
.cc-daterange .form-control {
    width: 100%;
    height: 36px;
    border-radius: 8px;
}
</style>
