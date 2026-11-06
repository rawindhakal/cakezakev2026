<template>
    <div>
        <div class="page-heading">
            <div class="page-head" v-if="!embedded">
                <h3 class="page-head-title">{{ __('delivery_cities') }}</h3>
            </div>

            <section class="section">

                <!-- Create / Edit Delivery City -->
                <div class="card">
                    <div class="card-body">
                        <form @submit.prevent="saveCity" novalidate>
                            <div class="row g-3">
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('city_name') }} <span class="text-danger">*</span></label>
                                    <input type="text" class="form-control" v-model="cityForm.name" :placeholder="__('city_name')" required>
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('state') }}</label>
                                    <input type="text" class="form-control" v-model="cityForm.state"
                                        :placeholder="__('state')">
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('country') }} <span class="text-danger">*</span></label>
                                    <AppSelect class="form-select" v-model="cityForm.country_id"
                                        :options="countries" :placeholder="__('select_country')" />
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label d-block">{{ __('status') }}</label>
                                    <div class="btn-group btn-group-toggle" role="group">
                                        <label class="btn btn-outline-primary" :class="{ active: cityForm.status == 0 }">
                                            <input type="radio" :value="0" v-model.number="cityForm.status" autocomplete="off"> {{ __('deactivate') }}
                                        </label>
                                        <label class="btn btn-outline-primary" :class="{ active: cityForm.status == 1 }">
                                            <input type="radio" :value="1" v-model.number="cityForm.status" autocomplete="off"> {{ __('activate') }}
                                        </label>
                                    </div>
                                </div>
                                <div class="col-12">
                                    <label class="form-label">{{ __('boundary_on_map') }}</label>
                                    <small class="text-muted d-block mb-2">{{ __('draw_city_boundary_hint') }}</small>
                                    <BoundaryMap :key="mapKey" v-model="cityForm.boundary_points" />
                                </div>
                                <div class="col-12 text-end">
                                    <button class="btn btn-secondary me-2" type="button" @click="resetCityForm"
                                        v-if="cityForm.id">{{ __('cancel') }}</button>
                                    <button class="btn btn-primary" type="submit" :disabled="citySaving"
                                        v-if="cityForm.id ? $can('delivery_city_update') : $can('delivery_city_create')">
                                        <b-spinner small v-if="citySaving"></b-spinner>
                                        {{ cityForm.id ? __('update') : __('save') }}
                                    </button>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>

                <!-- Delivery Cities List -->
                <div class="list-surface" v-if="!embedded">
                    <div class="list-toolbar">
                        <div class="list-toolbar-start">
                            <AppSelect v-if="czShowCountry" class="form-select list-select cz-sel" v-model="czCountryId"
                                :options="czCountryOptions" :searchable="czCountryOptions.length > 6" :allow-empty="false"
                                label-key="label" track-by="id" :placeholder="__('country')" @update:model-value="czOnCountry">
                                <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                            :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                                <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                            :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                            </AppSelect>
                            <span class="small text-muted">{{ __('used_for_ecommerce_zone_pricing_city_area_modes') }}</span>
                        </div>
                        <div class="list-search">
                            <Search class="list-search-icon" />
                            <input v-model="citySearch" type="search" class="form-control" :placeholder="__('search')">
                        </div>
                        <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="loadCities">
                            <RefreshCw :class="{ 'is-spinning': citiesLoading }" />
                        </button>
                    </div>

                    <MazerDatatable responsive :items="cityRows" :fields="cityFields" :filter="citySearch"
                        :current-page="cityPage" :per-page="cityPerPage" :busy="citiesLoading"
                        stacked="md" show-empty small>
                        <template #cell(status)="row">
                            <span class="status-pill" :class="row.item.status ? 'is-active' : 'is-inactive'">
                                {{ row.item.status ? __('active') : __('inactive') }}
                            </span>
                        </template>
                        <template #cell(actions)="row">
                            <div class="list-actions">
                                <button class="list-action-btn is-edit" @click="editCity(row.item)"
                                    v-if="$can('delivery_city_update')"
                                    v-b-tooltip.hover :title="__('edit')">
                                    <Pencil :size="15" />
                                </button>
                                <button class="list-action-btn is-delete" @click="deleteCity(row.item)"
                                    v-if="$can('delivery_city_delete')"
                                    v-b-tooltip.hover :title="__('delete')">
                                    <Trash2 :size="15" />
                                </button>
                            </div>
                        </template>
                    </MazerDatatable>

                    <div class="list-footer">
                        <div class="list-perpage">
                            <span>{{ __('per_page') }}</span>
                            <b-form-select v-model="cityPerPage" :options="pageOptions" size="sm"
                                class="form-select"></b-form-select>
                        </div>
                        <b-pagination v-model="cityPage" :total-rows="cityRows.length" :per-page="cityPerPage"
                            size="sm" class="mb-0 list-pagination"></b-pagination>
                    </div>
                </div>
            </section>
        </div>
    </div>
</template>

<script>
import axios from 'axios';
import BoundaryMap from '../../components/BoundaryMap.vue';
import { Pencil, Trash2, Search, RefreshCw } from 'lucide-vue-next';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';

export default {
    name: 'DeliveryCities',
    mixins: [CountryZoneFilter],
    components: { BoundaryMap, Pencil, Trash2, Search, RefreshCw },
    // When `embedded` is true the page chrome (heading + list) is hidden and only the
    // create form is shown — used to render this same form inside a modal (e.g. EditZone).
    props: {
        embedded: { type: Boolean, default: false },
    },
    emits: ['saved'],
    data() {
        return {
            czAllowAll: true,
            czShowZone: false, // cities are country-scoped (no zone in the data model)
            cities: [],
            countries: [],
            citiesLoading: false,
            citySearch: '',
            citySaving: false,
            cityForm: { id: null, name: '', state: '', country_id: '', status: 1, boundary_points: [] },
            citySearchTimer: null,
            mapKey: 0,
            cityPage: 1,
            cityPerPage: 10,
            pageOptions: this.$pageOptions,
            cityFields: [
                { key: 'name', label: __('name'), sortable: true, class: 'text-center' },
                { key: 'state', label: __('state'), sortable: false, class: 'text-center' },
                { key: 'country_name', label: __('country'), sortable: false, class: 'text-center' },
                { key: 'status', label: __('status'), sortable: true, class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false, class: 'text-center' },
            ],
        };
    },
    computed: {
        // Rows for the datatable: flatten country name so it renders + filters.
        cityRows() {
            return (this.cities || []).map(c => ({
                ...c,
                state: c.state || '-',
                country_name: this.countryName(c.country_id),
            }));
        },
    },
    created() {
        this.loadCountries();
        if (!this.embedded) {
            this.czLoad(); // standalone list: country filter drives loadCities
        }
    },
    methods: {
        czOnFilter() { this.loadCities(); },
        loadCountries() {
            axios.get(this.$apiUrl + '/countries/active').then(res => {
                this.countries = res.data?.data || [];
                // Default new city to the default country (else the first).
                if (!this.cityForm.id && !this.cityForm.country_id) {
                    const def = this.countries.find(c => Number(c.is_default) === 1) || this.countries[0];
                    if (def) this.cityForm.country_id = Number(def.id);
                }
            }).catch(() => { this.countries = []; });
        },
        loadCities() {
            this.citiesLoading = true;
            const params = { country_id: this.czCountryParam };
            if (this.citySearch) params.search = this.citySearch;
            axios.get(this.$apiUrl + '/delivery_cities', { params })
                .then(res => {
                    this.cities = res.data?.data?.cities || [];
                })
                .catch(() => { this.cities = []; })
                .finally(() => { this.citiesLoading = false; });
        },
        onCitySearch() {
            clearTimeout(this.citySearchTimer);
            this.citySearchTimer = setTimeout(() => this.loadCities(), 300);
        },
        countryName(id) {
            const c = this.countries.find(x => Number(x.id) === Number(id));
            return c ? c.name : '-';
        },
        saveCity() {
            if (!this.cityForm.name?.trim()) {
                this.showError(__('city_name') + ' ' + __('is_required'));
                return;
            }
            if (!this.cityForm.country_id) {
                this.showError(__('country_is_required_for_the_zone'));
                return;
            }
            if (!this.cityForm.boundary_points || !this.cityForm.boundary_points.length) {
                this.showError(__('please_draw_the_boundary_on_map'));
                return;
            }
            this.citySaving = true;
            const fd = new FormData();
            if (this.cityForm.id) fd.append('id', this.cityForm.id);
            fd.append('name', this.cityForm.name);
            fd.append('state', this.cityForm.state || '');
            fd.append('country_id', this.cityForm.country_id || '');
            fd.append('status', this.cityForm.status);
            const boundary = this.cityForm.boundary_points || [];
            fd.append('boundary_points', JSON.stringify(boundary));
            const center = this.polygonCenter(boundary);
            fd.append('latitude', center.lat);
            fd.append('longitude', center.lng);
            axios.post(this.$apiUrl + '/delivery_cities/save', fd)
                .then(res => {
                    // responseError comes back as HTTP 200 with status:0 — surface its message.
                    if (res.data && res.data.status == 0) {
                        this.showError(res.data.message || __('something_went_wrong'));
                        return;
                    }
                    this.showMessage('success', res.data?.message || __('delivery_city_saved_successfully'));
                    if (this.embedded) {
                        this.$emit('saved', res.data?.data?.city || null);
                        this.resetCityForm();
                        return;
                    }
                    this.resetCityForm();
                    this.loadCities();
                })
                .catch(err => {
                    this.showError(err.response?.data?.message || __('something_went_wrong'));
                })
                .finally(() => { this.citySaving = false; });
        },
        editCity(c) {
            let boundary = c.boundary_points || [];
            if (typeof boundary === 'string') {
                try { boundary = JSON.parse(boundary) || []; } catch { boundary = []; }
            }
            this.cityForm = { id: c.id, name: c.name, state: c.state || '', country_id: c.country_id || '', status: c.status, boundary_points: boundary };
            this.mapKey++; // remount map with the edited city's polygon
            window.scrollTo({ top: 0, behavior: 'smooth' });
        },
        resetCityForm() {
            this.cityForm = { id: null, name: '', state: '', country_id: '', status: 1, boundary_points: [] };
            const def = this.countries.find(c => Number(c.is_default) === 1) || this.countries[0];
            if (def) this.cityForm.country_id = Number(def.id);
            this.mapKey++;
        },
        // Average of polygon vertices — a "good enough" center for storing lat/lng.
        polygonCenter(points) {
            if (!points || !points.length) return { lat: '', lng: '' };
            const sum = points.reduce((a, p) => ({ lat: a.lat + Number(p.lat), lng: a.lng + Number(p.lng) }), { lat: 0, lng: 0 });
            return { lat: (sum.lat / points.length).toFixed(8), lng: (sum.lng / points.length).toFixed(8) };
        },
        deleteCity(c) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('all_areas_of_this_city_will_be_deleted'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: __('yes_delete'),
                cancelButtonText: __('cancel'),
            }).then(r => {
                if (!r.isConfirmed) return;
                const fd = new FormData();
                fd.append('id', c.id);
                axios.post(this.$apiUrl + '/delivery_cities/delete', fd)
                    .then(() => {
                        this.showMessage('success', __('delivery_city_deleted_successfully'));
                        this.loadCities();
                    })
                    .catch(err => this.showError(err.response?.data?.message || __('something_went_wrong')));
            });
        },
    },
};
</script>
