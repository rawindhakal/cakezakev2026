<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('delivery_boys') }}</h3>

            <router-link to="/delivery_boys/create"
                class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap ms-auto"
                v-if="$can('delivery_boy_create')">
                <Plus :size="16" />
                <span>{{ __('add_delivery_boy') }}</span>
            </router-link>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-toolbar-start">
                    <AppSelect v-if="czShowCountry" class="form-control form-select cz-sel" v-model="czCountryId"
                        :options="czCountryOptions" :searchable="czCountryOptions.length > 6" :allow-empty="false"
                        label-key="label" track-by="id" :placeholder="__('country')" @update:model-value="czOnCountry">
                        <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                    :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                        <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                    :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                    </AppSelect>
                    <AppSelect v-if="czShowZoneDropdown" class="form-control form-select cz-sel" v-model="czZoneId"
                        :options="czZoneOptions" :searchable="false" :allow-empty="false" label-key="label"
                        track-by="id" :placeholder="__('zone')" @update:model-value="czOnZone" />
                    <AppSelect class="form-control form-select" v-model="filterStatus" :options="filterStatusOptions" :searchable="false" @update:model-value="getDeliveryBoys()" />
                </div>

                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input id="filter-input" v-model="filter" type="search" class="form-control"
                        :placeholder="__('search')" @input="getDeliveryBoys()">
                </div>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')"
                    @click="getDeliveryBoys()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive :items="translatedDeliveryBoys" :fields="fields" :current-page="currentPage"
                                :per-page="perPage" :filter="filter" :filter-included-fields="filterOn"
                                v-model:sort-by="sortBy" v-model:sort-desc="sortDesc" :sort-direction="sortDirection"
                                :busy="isLoading" stacked="md" show-empty small>

                                <template #cell(balance)="row">
                                    <strong>{{ rowCurrency(row.item) + row.item.balance }}</strong>
                                </template>

                                <template #cell(name)="row">
                                    <div class="db-identity justify-content-center">
                                        <img v-if="row.item.profile_url" :src="row.item.profile_url"
                                            class="db-identity-avatar" alt="" />
                                        <span v-else class="db-identity-avatar"></span>
                                        <router-link class="db-identity-name"
                                            :to="{ name: 'ViewDeliveryBoy', params: { id: row.item.id } }">
                                            {{ getTranslatedName ? getTranslatedName(row.item) : row.item.name }}
                                        </router-link>
                                    </div>
                                </template>

                                <template #cell(mobile)="row">
                                    {{ (row.item.country_code ? row.item.country_code + ' ' : '') + $filters.mobileMask(row.item.mobile) }}
                                </template>

                                <template #cell(email)="row">
                                    {{ $filters.emailMask(row.item.email) }}
                                </template>

                                <template #cell(zone)="row">
                                    {{ row.item.zone ? row.item.zone.name : '—' }}
                                </template>

                                <template #cell(bonus_percentage)="row">
                                    <small :id="'bonus' + row.item.id"
                                        class="d-inline-flex mb-3 px-2 py-1 text-muted bg-secondary bg-opacity-10 border border-secondary border-opacity-10 rounded-2">
                                        <Info :size="14" />
                                    </small>
                                    <b-popover :target="'bonus' + row.item.id" triggers="hover" placement="left">
                                        <template #title>
                                            {{ __('bonus_details') }}
                                        </template>
                                        <table class="table table-sm table-borderless mb-2">
                                            <thead><tr><th colspan="2" class="text-primary">{{ __('order_bonus') }}</th></tr></thead>
                                            <tbody>
                                            <tr>
                                                <th>{{ __('bonus_type') }}</th>
                                                <td class="text-end">{{ row.item.bonus_type ===
                                                    1 ? __('commission') : __('fixed_salaried') }}</td>
                                            </tr>
                                            <template v-if="row.item.bonus_type === 1">
                                                <tr>
                                                    <th>{{ __('commission') }} (%)</th>
                                                    <td class="text-end">{{ row.item.bonus_percentage }}</td>
                                                </tr>
                                                <tr>
                                                    <th>{{ __('min_amount') }} ({{ rowCurrency(row.item) }})</th>
                                                    <td class="text-end">{{ row.item.bonus_min_amount }}</td>
                                                </tr>
                                                <tr>
                                                    <th>{{ __('max_amount') }} ({{ rowCurrency(row.item) }})</th>
                                                    <td class="text-end">{{ row.item.bonus_max_amount }}</td>
                                                </tr>
                                            </template>
                                            </tbody>
                                        </table>
                                        <table class="table table-sm table-borderless mb-0">
                                            <thead><tr><th colspan="2" class="text-primary">{{ __('return_bonus') }}</th></tr></thead>
                                            <tbody>
                                            <tr>
                                                <th>{{ __('bonus_type') }}</th>
                                                <td class="text-end">{{ row.item.return_bonus_type ===
                                                    1 ? __('commission') : __('fixed_salaried') }}</td>
                                            </tr>
                                            <template v-if="row.item.return_bonus_type === 1">
                                                <tr>
                                                    <th>{{ __('commission') }} (%)</th>
                                                    <td class="text-end">{{ row.item.return_bonus_percentage }}</td>
                                                </tr>
                                                <tr>
                                                    <th>{{ __('min_amount') }} ({{ rowCurrency(row.item) }})</th>
                                                    <td class="text-end">{{ row.item.return_bonus_min_amount }}</td>
                                                </tr>
                                                <tr>
                                                    <th>{{ __('max_amount') }} ({{ rowCurrency(row.item) }})</th>
                                                    <td class="text-end">{{ row.item.return_bonus_max_amount }}</td>
                                                </tr>
                                            </template>
                                            </tbody>
                                        </table>
                                    </b-popover>

                                </template>

                                <template #cell(status)="row">
                                    <label v-if="row.item.status == 0" class='badge bg-primary'>{{ __('registered')
                                        }}</label>
                                    <label v-else-if="row.item.status == 1" class='status-pill is-active'>{{ __('active')
                                        }}</label>
                                    <label v-else-if="row.item.status == 2" class='badge bg-warning'>{{__('not_approved')
                                        }}</label>
                                    <label v-else-if="row.item.status == 3" class='status-pill is-inactive'>{{ __('deactive')
                                        }}</label>
                                    <label v-else-if="row.item.status == 4" class='badge bg-black'>{{ __('blocked')
                                        }}</label>
                                    <label v-else-if="row.item.status == 7" class='status-pill is-inactive'>{{ __('removed')
                                        }}</label>
                                </template>

                                <template #cell(actions)="row">
                                    <div class="list-actions">
                                        <router-link :to="{ name: 'ViewDeliveryBoy', params: { id: row.item.id } }"
                                            class="list-action-btn is-view"
                                            v-b-tooltip.hover :title="__('view')">
                                            <Eye :size="15" />
                                        </router-link>
                                        <router-link
                                            :to="{ name: 'EditDeliveryBoy', params: { id: row.item.id, record: row.item } }"
                                            class="list-action-btn is-edit"
                                            v-if="$can('delivery_boy_update')" v-b-tooltip.hover :title="__('edit')">
                                            <Pencil :size="15" />
                                        </router-link>

                                        <button class="list-action-btn is-delete"
                                            @click="deleteDeliveryBoys(row.index, row.item.id)"
                                            v-if="$can('delivery_boy_delete')" v-b-tooltip.hover :title="__('delete')">
                                            <Trash2 :size="15" />
                                        </button>
                                    </div>
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
import { Search, RefreshCw, Plus, Pencil, Trash2, Eye, Info } from 'lucide-vue-next';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';
import ListState from '../../mixins/ListState.js';

export default {
    mixins: [CountryZoneFilter, ListState],
    // Come back from a delivery boy and land where you left, not on page 1.
    listState: ['currentPage', 'perPage', 'filter', 'filterStatus', 'sortBy', 'sortDesc'],
    components: { Search, RefreshCw, Plus, Pencil, Trash2, Eye, Info },
    data: function () {
        return {
            czAllowAll: true,   // per-row currency → All Countries allowed
            fields: [
                // Narrow, centred: ids are 1-3 digits, no need for a wide column.
                { key: 'id', label: __('id'), sortable: true, sortDirection: 'desc', class: 'text-center', thStyle: 'width: 72px' },
                { key: 'name', label: __('name'), sortable: false, class: 'text-center' },
                { key: 'mobile', label: __('mobile'), sortable: false, class: 'text-center' },
                { key: 'email', label: __('email'), sortable: false, class: 'text-center' },
                { key: 'zone', label: __('zone'), sortable: false, class: 'text-center' },
                { key: 'bonus_percentage', label: __('bonus'), sortable: false, class: 'text-center' },
                { key: 'balance', label: __('balance'), sortable: false, class: 'text-center' },
                { key: 'status', label: __('status'), sortable: true, class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false, }
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

            categories: null,
            products: null,

            deliveryBoys: [],
            filterStatus: '',
            currentLanguageId: null,
            activeLanguages: []
        }
    },
    computed: {
        // Fixed option set — no search box needed.
        filterStatusOptions() {
            return [
                { id: '', name: (__('all')) },
                { id: '1', name: (__('active')) },
                { id: '2', name: (__('not_approved')) },
                { id: '3', name: (__('deactive')) },
                { id: '4', name: (__('blocked')) },
            ];
        },
        translatedDeliveryBoys() {
            if (!this.currentLanguageId || !Array.isArray(this.deliveryBoys)) {
                return this.deliveryBoys;
            }

            return this.deliveryBoys.map(boy => {
                const translatedBoy = { ...boy };

                if (boy.translations && Array.isArray(boy.translations)) {
                    const translation = boy.translations.find(
                        t => t.language_id === this.currentLanguageId
                    );

                    if (translation) {
                        // translate fields safely
                        if (translation.name && translation.name.trim() !== '') {
                            translatedBoy.name = translation.name;
                        }

                        if (translation.address && translation.address.trim() !== '') {
                            translatedBoy.address = translation.address;
                        }

                        if (translation.other_payment_information && translation.other_payment_information.trim() !== '') {
                            translatedBoy.other_payment_information = translation.other_payment_information;
                        }
                    }
                }

                return translatedBoy;
            });
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
        this.totalRows = this.deliveryBoys.length
    },

    created: function () {
        this.$eventBus.on('deliveryBoysSaved', (message) => {
            this.showMessage("success", message);
            this.getDeliveryBoys();
            this.create_new = null;
        });
        this.fetchActiveLanguages();
        this.czLoad();
    },
    methods: {
        czOnFilter() { this.getDeliveryBoys(); },
        rowCurrency(item) {
            return (item.country && item.country.currency) || this.$currency;
        },
        fetchActiveLanguages() {
            return axios.get(this.$apiUrl + '/active_languages')
                .then(response => {
                    if (Array.isArray(response.data.data)) {
                        this.activeLanguages = response.data.data;

                        const appLocale = window.appLocale || 'en';

                        const currentLanguage = this.activeLanguages.find(
                            lang => lang.code === appLocale
                        );

                        if (currentLanguage) {
                            this.currentLanguageId = currentLanguage.id;
                        } else {
                            const defaultLang = this.activeLanguages.find(
                                lang => lang.is_default === 1
                            );
                            if (defaultLang) {
                                this.currentLanguageId = defaultLang.id;
                            }
                        }
                    }
                })
                .catch(err => {
                    console.error('Language load error:', err);
                });
        },
        getDeliveryBoys() {
            this.isLoading = true

            axios.get(this.$apiUrl + '/delivery_boys', {
                params: {
                    filterStatus: this.filterStatus,
                    search: this.filter,
                    country_id: this.czCountryParam,
                    zone_id: this.czZoneParam
                }
            })
                .then((response) => {
                    this.isLoading = false
                    this.deliveryBoys = response.data.data.filter(boy => boy.status !== 0) || []
                    this.totalRows = this.deliveryBoys.length
                });
        },
        deleteDeliveryBoys(index, id) {
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
                    axios.post(this.$apiUrl + '/delivery_boys/delete', postData)
                        .then((response) => {
                            this.isLoading = false
                            this.deliveryBoys.splice(index, 1)
                            this.showMessage('success', response.data.message);
                        });
                }
            });
        },

        hideModal() {
            this.create_new = false
            this.edit_record = false
            this.$router.push({ path: '/delivery_boys' });
        },
    }
};
</script>
