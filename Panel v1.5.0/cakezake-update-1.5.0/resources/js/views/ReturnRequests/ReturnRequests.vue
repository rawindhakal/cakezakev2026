<template>
    <div>
        <div class="list-page">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('return_requests') }}</h3>
            </div>

            <div class="list-surface">
                <div class="list-toolbar">
                    <AppSelect v-if="czShowCountry && login_user.role_id != 3" class="form-select list-select cz-sel" v-model="czCountryId"
                        :options="czCountryOptions" :searchable="czCountryOptions.length > 6" :allow-empty="false"
                        label-key="label" track-by="id" :placeholder="__('country')" @update:model-value="czOnCountry">
                        <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                    :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                        <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                    :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                    </AppSelect>
                    <AppSelect v-if="czShowZoneDropdown && login_user.role_id != 3" class="form-select list-select cz-sel" v-model="czZoneId"
                        :options="czZoneOptions" :searchable="false" :allow-empty="false" label-key="label"
                        track-by="id" :placeholder="__('zone')" @update:model-value="czOnZone" />
                    <!-- me-auto pushes the search + refresh right. -->
                    <AppSelect v-model="statusFilter" class="form-select list-select list-select-lg me-auto"
                        :options="statusFilterOptions" :searchable="false" />
                    <div class="list-search">
                        <Search class="list-search-icon" />
                        <input id="filter-input" v-model="filter" type="search" class="form-control"
                            :placeholder="__('search')">
                    </div>

                    <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')"
                        @click="getReturnRequests()">
                        <RefreshCw :class="{ 'is-spinning': isLoading }" />
                    </button>
                </div>

                <MazerDatatable responsive :items="returnRequestsForTable" :fields="fields" :current-page="currentPage"
                    :per-page="perPage" :sort-direction="sortDirection" :busy="isLoading"
                    stacked="md" show-empty small>

                    <template #cell(id)="row">
                        {{ row.item.return_number || ('#' + row.item.id) }}
                    </template>
                    <template #cell(order_number)="row">
                        {{ row.item.order_number || ('#' + row.item.order_id) }}
                    </template>
                    <template #cell(sub_total)="row">
                        {{ (row.item.currency || $currency) }}{{ row.item.sub_total }}
                    </template>

                    <template #cell(status)="row">
                        <span v-if="row.item.status === 1" class="badge bg-warning">{{ __('return_requested')
                            }}</span>
                        <span v-else-if="row.item.status === 2" class="badge bg-success">{{ __('accepted')
                            }}</span>
                        <span v-else-if="row.item.status === 3" class="badge bg-danger">{{ __('rejected')
                            }}</span>
                        <span v-else-if="row.item.status === 4" class="badge bg-info">{{
                            __('delivery_boy_assigned') }}</span>
                        <span v-else-if="row.item.status === 5" class="badge bg-primary">{{
                            __('out_for_pickup') }}</span>
                        <span v-else-if="row.item.status === 6" class="badge bg-secondary">{{
                            __('received_from_customer') }}</span>
                        <span v-else-if="row.item.status === 7" class="badge bg-dark">{{
                            __('return_to_branch') }}</span>
                        <span v-else-if="row.item.status === 8" class="badge bg-success">{{
                            __('refund_completed') }}</span>
                        <span v-else class="badge bg-danger">{{ __('undefined') }}</span>
                    </template>
                    <template #cell(date)="row">
                        {{ $filters.formatDateTime(row.item.date) }}
                    </template>
                    <!-- Resolve name, product_name, variant_name when API sends object by lang code -->
                    <template #cell(name)="row">
                        {{ row.item.customer_name || row.item.name }}
                    </template>
                    <template #cell(product_name)="row">
                        {{ row.item.product_name }}
                    </template>
                    <template #cell(actions)="row">
                        <div class="list-actions">
                            <button class="list-action-btn is-view" @click="openReturn(row.item)"
                                v-b-tooltip.hover :title="__('view')"><Eye :size="15" /></button>
                            <button class="list-action-btn is-delete"
                                @click="deleteReturnRequests(row.index, row.item.id)"
                                v-if="$can('return_request_delete')" v-b-tooltip.hover :title="__('delete')"><Trash2 :size="15" /></button>
                        </div>
                    </template>

                </MazerDatatable>

                <div class="list-footer">
                    <div class="list-perpage">
                        <span>{{ __('per_page') }}</span>
                        <b-form-select id="per-page-select" v-model="perPage" :options="pageOptions"
                            size="sm" class="form-select"></b-form-select>
                    </div>

                    <b-pagination v-model="currentPage" :total-rows="returnRequestsForTable.length" :per-page="perPage"
                        size="sm" class="mb-0 list-pagination"></b-pagination>
                </div>
            </div>
        </div>
        <!-- Detail slider -->
        <ReturnDetailSlider v-model="sliderShow" :record="activeRecord" :nav-list="navList"
            @navigate="onNavigate" @updated="getReturnRequests" />
    </div>
</template>
<script>
import ReturnDetailSlider from './ReturnDetailSlider.vue';
import Auth from '../../Auth.js';
import { Search, RefreshCw, Eye, Trash2 } from 'lucide-vue-next';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';

export default {
    mixins: [CountryZoneFilter],
    components: {
        ReturnDetailSlider,
        Search, RefreshCw, Eye, Trash2,
    },
    data: function () {
        return {
            czAllowAll: true,
            login_user: Auth.user,
            fields: [
                { key: 'id', label: __('id'), sortable: true, sortDirection: 'desc' },
                { key: 'order_number', label: __('order_number'), sortable: false, class: 'text-center' },
                { key: 'name', label: __('name'), sortable: false, class: 'text-center' },
                { key: 'product_name', label: __('product_name'), sortable: false, class: 'text-center' },
                { key: 'quantity', label: __('quantity'), sortable: false, class: 'text-center' },
                { key: 'sub_total', label: __('total'), sortable: false, class: 'text-center' },
                { key: 'status', label: __('status'), sortable: true, class: 'text-center' },
                { key: 'return_reason', label: __('return_reason'), sortable: false, class: 'text-center' },
                { key: 'date', label: __('date'), sortable: true, class: 'text-center' },
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
            statusFilter: '',
            filterOn: [],
            page: 1,

            isLoading: false,
            sectionStyle: 'style_1',
            max_visible_units: 12,
            max_col_in_single_row: 3,
            sliderShow: false,
            activeRecord: null,
            returnRequests: [],
        }
    },
    computed: {
        // returnStatuses is {value,label}; AppSelect works in {id,name}.
        statusFilterOptions() {
            return [{ id: '', name: __('all_statuses') }]
                .concat(this.returnStatuses.map(s => ({ id: s.value, name: s.label })));
        },
        appLocale() {
            return (typeof window !== 'undefined' && (window.appLocale || (window.localStorage && window.localStorage.getItem('lang')))) || 'en';
        },
        returnStatuses() {
            return [
                { value: 1, label: __('return_requested') },
                { value: 2, label: __('accepted') },
                { value: 3, label: __('rejected') },
                { value: 4, label: __('delivery_boy_assigned') },
                { value: 5, label: __('out_for_pickup') },
                { value: 6, label: __('received_from_customer') },
                { value: 7, label: __('return_to_branch') },
                { value: 8, label: __('refund_completed') },
            ];
        },
        returnRequestsForTable() {
            const list = this.returnRequests || [];
            if (this.statusFilter === '') return list;
            return list.filter(r => Number(r.status) === Number(this.statusFilter));
        },
        navList() {
            return (this.returnRequests || []).map(r => ({ id: r.id }));
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
        // totalRows set in getReturnRequests when data loads
    },
    created: function () {
        this.czLoad();
    },
    watch: {
        filter() {
            this.currentPage = 1;
            this.getReturnRequests();
        },
        currentPage() {
            if (this.login_user.role_id == 3) {
                this.getReturnRequests();
            }
        },
        perPage() {
            this.currentPage = 1;
            if (this.login_user.role_id == 3) {
                this.getReturnRequests();
            }
        }
    },
    methods: {
        czOnFilter() { this.getReturnRequests(); },
        getReturnRequests() {
            this.isLoading = true

            let apiBase = this.$apiUrl;
            let apiEndpoint = '/return_requests';
            if (this.login_user.role_id == 3) { // Delivery Boy
                apiBase = this.$deliveryBoyApiUrl;
                apiEndpoint = '/return_requests';
            }

            const isPaginatedApi = this.login_user.role_id == 3;
            const offset = isPaginatedApi ? (this.currentPage - 1) * this.perPage : 0;
            const limit = isPaginatedApi ? this.perPage : 1000;

            let url = apiBase + apiEndpoint + "?search=" + encodeURIComponent(this.filter || "");
            if (isPaginatedApi) {
                url += "&offset=" + offset + "&limit=" + limit;
            } else {
                // Admin list follows the header-selected country/zone (resolved via the order).
                url += "&country_id=" + (this.czCountryParam || '')
                    + "&zone_id=" + (this.czZoneParam || '');
            }

            axios.get(url)
                .then((response) => {
                    this.returnRequests = response.data.data || [];
                    this.totalRows = (isPaginatedApi && response.data.total) ? response.data.total : this.returnRequests.length;
                    this.isLoading = false;
                    // Keep the open slider's record in sync after an update.
                    if (this.sliderShow && this.activeRecord) {
                        const fresh = this.returnRequests.find(r => String(r.id) === String(this.activeRecord.id));
                        if (fresh) this.activeRecord = fresh;
                    }
                });
        },
        deleteReturnRequests(index, id) {
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

                    let apiEndpoint = '/return_requests/delete';

                    axios.post(this.$apiUrl + apiEndpoint, postData)
                        .then((response) => {
                            this.isLoading = false
                            this.returnRequests.splice(index, 1)
                            this.showMessage("success", response.data.message)
                        });
                }
            });
        },
        openReturn(item) {
            this.activeRecord = item;
            this.sliderShow = true;
        },
        onNavigate(entry) {
            const found = (this.returnRequests || []).find(r => String(r.id) === String(entry.id));
            if (found) this.activeRecord = found;
        },
    }
};
</script>
