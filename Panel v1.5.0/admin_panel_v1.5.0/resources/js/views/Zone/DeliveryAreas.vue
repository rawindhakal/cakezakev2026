<template>
    <div>
        <div class="page-heading">
            <div class="page-head" v-if="!embedded">
                <h3 class="page-head-title">{{ __('delivery_areas') }}</h3>
            </div>

            <section class="section">

                <!-- Create / Edit Delivery Area -->
                <div class="card">
                    <div class="card-body">
                        <form @submit.prevent="saveArea" novalidate>
                            <div class="row g-3">
                                <div class="col-md-4">
                                    <label class="form-label">{{ __('master_city') }} <span class="text-danger">*</span></label>
                                    <input v-if="lockedCityId" type="text" class="form-control"
                                        :value="cityNameById(lockedCityId)" readonly>
                                    <AppSelect v-else class="form-select" v-model="areaForm.delivery_city_id"
                                        :options="cities" :placeholder="__('select_city')" />
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label">{{ __('area_name') }} <span class="text-danger">*</span></label>
                                    <input type="text" class="form-control" v-model="areaForm.name"
                                        :placeholder="__('area_name')" required>
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label d-block">{{ __('status') }}</label>
                                    <div class="btn-group btn-group-toggle" role="group">
                                        <label class="btn btn-outline-primary" :class="{ active: areaForm.status == 0 }">
                                            <input type="radio" :value="0" v-model.number="areaForm.status" autocomplete="off"> {{ __('deactivate') }}
                                        </label>
                                        <label class="btn btn-outline-primary" :class="{ active: areaForm.status == 1 }">
                                            <input type="radio" :value="1" v-model.number="areaForm.status" autocomplete="off"> {{ __('activate') }}
                                        </label>
                                    </div>
                                </div>
                                <div class="col-12">
                                    <label class="form-label">{{ __('boundary_on_map') }}</label>
                                    <small class="text-muted d-block mb-2">{{ __('draw_area_boundary_hint') }}</small>
                                    <BoundaryMap :key="mapKey" v-model="areaForm.boundary_points" />
                                </div>
                                <div class="col-12 text-end">
                                    <button class="btn btn-secondary me-2" type="button" @click="resetAreaForm"
                                        v-if="areaForm.id">{{ __('cancel') }}</button>
                                    <button class="btn btn-primary" type="submit" :disabled="areaSaving"
                                        v-if="areaForm.id ? $can('delivery_area_update') : $can('delivery_area_create')">
                                        <b-spinner small v-if="areaSaving"></b-spinner>
                                        {{ areaForm.id ? __('update') : __('save') }}
                                    </button>
                                </div>
                            </div>
                            <small class="text-muted d-block mt-2" v-if="!cities.length && !citiesLoading">
                                {{ __('please_create_a_delivery_city_first') }}
                            </small>
                        </form>
                    </div>
                </div>

                <!-- Delivery Areas List -->
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
                            <AppSelect class="form-select list-select" v-model="areaCityFilter"
                                :options="cityFilterOptions" @update:model-value="loadAreas" />
                        </div>
                        <div class="list-search">
                            <Search class="list-search-icon" />
                            <input v-model="areaSearch" type="search" class="form-control" :placeholder="__('search')">
                        </div>
                        <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="loadAreas">
                            <RefreshCw :class="{ 'is-spinning': areasLoading }" />
                        </button>
                    </div>

                    <MazerDatatable responsive :items="areaRows" :fields="areaFields" :filter="areaSearch"
                        :current-page="areaPage" :per-page="areaPerPage" :busy="areasLoading"
                        stacked="md" show-empty small>
                        <template #cell(status)="row">
                            <span class="status-pill" :class="row.item.status ? 'is-active' : 'is-inactive'">
                                {{ row.item.status ? __('active') : __('inactive') }}
                            </span>
                        </template>
                        <template #cell(actions)="row">
                            <div class="list-actions">
                                <button class="list-action-btn is-edit" @click="editArea(row.item)"
                                    v-if="$can('delivery_area_update')"
                                    v-b-tooltip.hover :title="__('edit')">
                                    <Pencil :size="15" />
                                </button>
                                <button class="list-action-btn is-delete" @click="deleteArea(row.item)"
                                    v-if="$can('delivery_area_delete')"
                                    v-b-tooltip.hover :title="__('delete')">
                                    <Trash2 :size="15" />
                                </button>
                            </div>
                        </template>
                    </MazerDatatable>

                    <div class="list-footer">
                        <div class="list-perpage">
                            <span>{{ __('per_page') }}</span>
                            <b-form-select v-model="areaPerPage" :options="pageOptions" size="sm"
                                class="form-select"></b-form-select>
                        </div>
                        <b-pagination v-model="areaPage" :total-rows="areaRows.length" :per-page="areaPerPage"
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
    name: 'DeliveryAreas',
    mixins: [CountryZoneFilter],
    components: { BoundaryMap, Pencil, Trash2, Search, RefreshCw },
    // `embedded` hides the page chrome (heading + list) so only the create form renders
    // — used to show this same form inside a modal (e.g. EditZone). `lockedCityId` pins
    // the area to one city (city shown read-only) for the inline add-from-zone flow.
    props: {
        embedded: { type: Boolean, default: false },
        lockedCityId: { type: [Number, String], default: null },
    },
    emits: ['saved'],
    data() {
        return {
            czAllowAll: true,
            czShowZone: false, // areas are country-scoped via their city (no zone)
            cities: [],
            citiesLoading: false,

            areas: [],
            areasLoading: false,
            areaSearch: '',
            areaCityFilter: '',
            areaSaving: false,
            areaForm: { id: null, delivery_city_id: '', name: '', status: 1, boundary_points: [] },

            areaSearchTimer: null,
            mapKey: 0,
            areaPage: 1,
            areaPerPage: 10,
            pageOptions: this.$pageOptions,
            areaFields: [
                { key: 'name', label: __('area_name'), sortable: true, class: 'text-center' },
                { key: 'city_name', label: __('city'), sortable: false, class: 'text-center' },
                { key: 'status', label: __('status'), sortable: true, class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false, class: 'text-center' },
            ],
        };
    },
    computed: {
        cityFilterOptions() {
            return [{ id: '', name: __('all_cities') }].concat(this.cities || []);
        },
        // Flatten city name onto each row so it renders + filters in the datatable.
        areaRows() {
            return (this.areas || []).map(a => ({
                ...a,
                city_name: a.city?.name || '-',
            }));
        },
    },
    created() {
        this.loadCities();
        if (!this.embedded) {
            this.czLoad(); // country filter drives the area list
        }
        if (this.lockedCityId) {
            this.areaForm.delivery_city_id = this.lockedCityId;
        }
    },
    methods: {
        czOnFilter() { this.areaCityFilter = ''; this.loadCities(); this.loadAreas(); },
        cityNameById(id) {
            const c = this.cities.find(c => Number(c.id) === Number(id));
            return c?.name || '';
        },
        loadCities() {
            this.citiesLoading = true;
            const params = { country_id: this.czCountryParam };
            axios.get(this.$apiUrl + '/delivery_cities', { params })
                .then(res => {
                    this.cities = res.data?.data?.cities || [];
                })
                .catch(() => { this.cities = []; })
                .finally(() => { this.citiesLoading = false; });
        },
        loadAreas() {
            this.areasLoading = true;
            const params = { country_id: this.czCountryParam };
            if (this.areaSearch) params.search = this.areaSearch;
            if (this.areaCityFilter) params.delivery_city_id = this.areaCityFilter;
            axios.get(this.$apiUrl + '/delivery_areas', { params })
                .then(res => {
                    this.areas = res.data?.data?.areas || [];
                })
                .catch(() => { this.areas = []; })
                .finally(() => { this.areasLoading = false; });
        },
        onAreaSearch() {
            clearTimeout(this.areaSearchTimer);
            this.areaSearchTimer = setTimeout(() => this.loadAreas(), 300);
        },
        saveArea() {
            if (!this.areaForm.delivery_city_id) {
                this.showError(__('master_city') + ' ' + __('is_required'));
                return;
            }
            if (!this.areaForm.name?.trim()) {
                this.showError(__('area_name') + ' ' + __('is_required'));
                return;
            }
            if (!this.areaForm.boundary_points || !this.areaForm.boundary_points.length) {
                this.showError(__('please_draw_the_boundary_on_map'));
                return;
            }
            this.areaSaving = true;
            const fd = new FormData();
            if (this.areaForm.id) fd.append('id', this.areaForm.id);
            fd.append('delivery_city_id', this.areaForm.delivery_city_id);
            fd.append('name', this.areaForm.name);
            fd.append('status', this.areaForm.status);
            const boundary = this.areaForm.boundary_points || [];
            fd.append('boundary_points', JSON.stringify(boundary));
            const center = this.polygonCenter(boundary);
            fd.append('latitude', center.lat);
            fd.append('longitude', center.lng);
            axios.post(this.$apiUrl + '/delivery_areas/save', fd)
                .then(res => {
                    // responseError comes back as HTTP 200 with status:0 — surface its message.
                    if (res.data && res.data.status == 0) {
                        this.showError(res.data.message || __('something_went_wrong'));
                        return;
                    }
                    this.showMessage('success', res.data?.message || __('delivery_area_saved_successfully'));
                    if (this.embedded) {
                        this.$emit('saved', res.data?.data?.area || null);
                        this.resetAreaForm();
                        if (this.lockedCityId) {
                            this.areaForm.delivery_city_id = this.lockedCityId;
                        }
                        return;
                    }
                    this.resetAreaForm();
                    this.loadAreas();
                })
                .catch(err => {
                    this.showError(err.response?.data?.message || __('something_went_wrong'));
                })
                .finally(() => { this.areaSaving = false; });
        },
        editArea(a) {
            let boundary = a.boundary_points || [];
            if (typeof boundary === 'string') {
                try { boundary = JSON.parse(boundary) || []; } catch { boundary = []; }
            }
            this.areaForm = { id: a.id, delivery_city_id: a.delivery_city_id, name: a.name, status: a.status, boundary_points: boundary };
            this.mapKey++;
            window.scrollTo({ top: 0, behavior: 'smooth' });
        },
        resetAreaForm() {
            this.areaForm = { id: null, delivery_city_id: '', name: '', status: 1, boundary_points: [] };
            this.mapKey++;
        },
        polygonCenter(points) {
            if (!points || !points.length) return { lat: '', lng: '' };
            const sum = points.reduce((a, p) => ({ lat: a.lat + Number(p.lat), lng: a.lng + Number(p.lng) }), { lat: 0, lng: 0 });
            return { lat: (sum.lat / points.length).toFixed(8), lng: (sum.lng / points.length).toFixed(8) };
        },
        deleteArea(a) {
            this.$swal.fire({
                title: __('are_you_sure'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: __('yes_delete'),
                cancelButtonText: __('cancel'),
            }).then(r => {
                if (!r.isConfirmed) return;
                const fd = new FormData();
                fd.append('id', a.id);
                axios.post(this.$apiUrl + '/delivery_areas/delete', fd)
                    .then(() => {
                        this.showMessage('success', __('delivery_area_deleted_successfully'));
                        this.loadAreas();
                    })
                    .catch(err => this.showError(err.response?.data?.message || __('something_went_wrong')));
            });
        },
    },
};
</script>
