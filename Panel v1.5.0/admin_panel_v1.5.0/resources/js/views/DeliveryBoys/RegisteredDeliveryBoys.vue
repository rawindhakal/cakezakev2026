<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('new_registered_delivery_boys') }}</h3>
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
                </div>
                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input id="filter-input" v-model="filter" type="search" class="form-control"
                        :placeholder="__('search')">
                </div>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')"
                    @click="getDeliveryBoys()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive :items="translatedDeliveryBoys" :fields="fields" :current-page="currentPage"
                                :per-page="perPage"
                                v-model:sort-by="sortBy" v-model:sort-desc="sortDesc" :sort-direction="sortDirection"
                                :busy="isLoading" stacked="md" show-empty small>

                                <template #cell(name)="row">
                                    <div class="db-identity justify-content-center">
                                        <img v-if="row.item.profile_url" :src="row.item.profile_url"
                                            class="db-identity-avatar" alt="" />
                                        <span v-else class="db-identity-avatar"></span>
                                        <span class="db-identity-name">{{ row.item.name }}</span>
                                    </div>
                                </template>

                                <template #cell(email)="row">
                                    {{ $filters.emailMask(row.item.email) }}
                                </template>

                                <template #cell(mobile)="row">
                                    {{ $filters.mobileMask(row.item.mobile) }}
                                </template>

                                <template #cell(status)="row">
                                    <label v-if="row.item.status == 0" class='badge bg-primary'>{{ __('registered')
                                        }}</label>
                                    <label v-else-if="row.item.status == 1" class='status-pill is-active'>{{ __('active')
                                        }}</label>
                                    <label v-else-if="row.item.status == 2" class='badge bg-warning'>{{
                                        __('not_approved') }}</label>
                                    <label v-else-if="row.item.status == 3" class='status-pill is-inactive'>{{ __('deactive')
                                        }}</label>
                                    <label v-else-if="row.item.status == 4" class='badge bg-black'>{{ __('blocked')
                                        }}</label>
                                    <label v-else-if="row.item.status == 7" class='status-pill is-inactive'>{{ __('removed')
                                        }}</label>
                                </template>

                                <template #cell(documents)="row">
                                    <small :id="'other' + row.item.id"
                                        class="d-inline-flex mb-3 px-2 py-1 text-muted bg-secondary bg-opacity-10 border border-secondary border-opacity-10 rounded-2">
                                        <Info :size="14" />
                                    </small>
                                    <b-popover :target="'other' + row.item.id" triggers="hover" placement="left">
                                        <template #title>
                                            {{ __('documents') }}
                                        </template>

                                        <p> <a target="_blank" :href="row.item.driving_license_url"
                                                class="badge bg-success d-inline-flex align-items-center gap-1"> <Eye :size="13" />
                                                {{ __('driving_licence') }}</a></p>
                                        <p><a target="_blank" :href="row.item.national_identity_card_url"
                                                class="badge bg-success d-inline-flex align-items-center gap-1"> <Eye :size="13" />
                                                {{ __('national_identity_card') }} </a></p>
                                    </b-popover>
                                </template>
                                <template #cell(created_at)="row">
                                    {{ $filters.formatDateTime(row.item.created_at) }}
                                </template>
                                <template #cell(dob)="row">
                                    {{ $filters.formatDate(row.item.dob) }}
                                </template>
                                <template #cell(actions)="row">
                                    <div class="list-actions">
                                        <button class="btn btn-sm btn-outline-success" type="button"
                                            @click="updateStatus(row.index, row.item.id, 1)"
                                            v-if="$can('delivery_boy_update')" v-b-tooltip.hover :title="__('status')">
                                            {{ __('approved') }}
                                        </button>
                                        <button class="btn btn-sm btn-outline-danger" type="button"
                                            @click="updateStatus(row.index, row.item.id, 2)"
                                            v-if="$can('delivery_boy_update')" v-b-tooltip.hover :title="__('status')">
                                            {{ __('reject') }}
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
import { Search, RefreshCw, Eye, Info } from 'lucide-vue-next';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';

export default {
    mixins: [CountryZoneFilter],
    components: { Search, RefreshCw, Eye, Info },
    data: function () {
        return {
            czAllowAll: true,
            fields: [
                { key: 'id', label: __('id'), sortable: true, sortDirection: 'desc' },
                { key: 'name', label: __('name'), sortable: false, class: 'text-center' },
                { key: 'mobile', label: __('mobile'), sortable: false, class: 'text-center' },
                { key: 'email', label: __('email'), sortable: false, class: 'text-center' },
                { key: 'documents', label: __('documents'), sortable: false, class: 'text-center' },
                { key: 'dob', label: __('date_of_birth'), sortable: false, class: 'text-center' },
                { key: 'status', label: __('status'), sortable: true, class: 'text-center' },
                { key: 'created_at', label: __('date'), sortable: true, class: 'text-center' },
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
            filterStatus: 0,
            currentLanguageId: null,
            activeLanguages: []
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
        },
        translatedDeliveryBoys() {
            if (!this.currentLanguageId || !Array.isArray(this.deliveryBoys)) {
                return this.deliveryBoys;
            }

            return this.deliveryBoys.map(deliveryBoy => {
                const translated = { ...deliveryBoy };

                if (Array.isArray(deliveryBoy.translations)) {
                    const tr = deliveryBoy.translations.find(
                        t => t.language_id === this.currentLanguageId
                    );

                    if (tr) {
                        // Use translation if it exists and has value
                        if (tr.name?.trim()) {
                            translated.name = tr.name;
                        }
                    }
                }

                // Fallback: If no translation found or translation name is empty, use main table name
                if (!translated.name || !translated.name.trim()) {
                    translated.name = deliveryBoy.name || '';
                }

                return translated;
            });
        }
    },
    mounted() {
        // Set the initial number of items
        this.totalRows = this.deliveryBoys.length
    },
    watch: {
        $route(to, from) {
            this.showCreateModal();
        },
        // Server-side search — debounce so we don't fire on every keystroke.
        filter() {
            clearTimeout(this._searchTimer);
            this._searchTimer = setTimeout(() => this.getDeliveryBoys(), 350);
        }
    },
    created: function () {
        this.showCreateModal();
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
        getDeliveryBoys() {
            this.isLoading = true
            axios.get(this.$apiUrl + '/delivery_boys', {
                params: {
                    filterStatus: this.filterStatus,
                    country_id: this.czCountryParam,
                    zone_id: this.czZoneParam,
                    search: this.filter || ''
                }
            })
                .then((response) => {
                    this.isLoading = false
                    this.deliveryBoys = response.data.data;
                    this.totalRows = this.deliveryBoys.length
                });
        },
        updateStatus(index, id, selectedStatus) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('you_want_be_able_to_revert_this'),
                confirmButtonText: __('yes_sure'),
                cancelButtonText: __('cancel'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(async result => {
                if (result.value) {
                    let remarks = "";
                    if (selectedStatus === 2) {
                        const { value: text } = await this.$swal.fire({
                            title: __('remarks'),
                            input: 'textarea',

                            inputPlaceholder: 'Type your remarks here...',
                            inputAttributes: {
                                'aria-label': 'Type your remarks here'
                            },
                            confirmButtonText: "Submit",
                            cancelButtonText: "Cancel",
                            showCancelButton: true,

                            inputValidator: (value) => {
                                return new Promise((resolve) => {
                                    if (value !== '') {
                                        resolve()
                                    } else {
                                        resolve('The Remarks field is required')
                                    }
                                })
                            }
                        })
                        if (text) {
                            remarks = text;
                        }
                    }
                    if (selectedStatus === 1 || (selectedStatus === 2 && remarks !== "")) {
                        this.isLoading = true
                        let postData = {
                            id: id,
                            status: selectedStatus,
                            remark: remarks
                        }

                        axios.post(this.$apiUrl + '/delivery_boys/update_delivery_boy_status', postData)
                            .then((response) => {
                                this.isLoading = false
                                let data = response.data;
                                this.getDeliveryBoys();
                                this.showMessage('success', data.message);
                            });
                    }
                }
            });
        },



        deleteDeliveryBoys(index, id) {
            this.$swal.fire({
                title: "Are you Sure?",
                text: "You want be able to revert this",
                confirmButtonText: "Yes, Sure",
                cancelButtonText: "Cancel",
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
                            this.showSuccess(response.data.message)
                        });
                }
            });
        },
        showCreateModal() {
            let create = this.$route.params.create;
            if (create) {
                this.create_new = true;
            }
        },
        hideModal() {
            this.create_new = false
            this.edit_record = false
            this.$router.push({ path: '/delivery_boys' });
        },
    }
};
</script>
