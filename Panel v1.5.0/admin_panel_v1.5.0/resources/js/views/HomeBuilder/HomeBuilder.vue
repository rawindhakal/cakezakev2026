<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('manage_home_builder') }}</h3>
            <button class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                @click="openWizard" v-if="$can('home_builder_create')">
                <Plus :size="16" /><span>{{ __('new_home_layout') }}</span>
            </button>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div v-if="czShowCountry || czShowZoneDropdown" class="list-toolbar-start">
                    <AppSelect v-if="czShowCountry" class="form-select list-select cz-sel" v-model="czCountryId"
                        :options="czCountryOptions" :searchable="czCountryOptions.length > 6" :allow-empty="false"
                        label-key="label" track-by="id" :placeholder="__('country')" @update:model-value="czOnCountry">
                        <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                    :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                        <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                    :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                    </AppSelect>
                    <AppSelect v-if="czShowZoneDropdown" class="form-select list-select cz-sel" v-model="czZoneId"
                        :options="czZoneOptions" :searchable="false" :allow-empty="false" label-key="label"
                        track-by="id" :placeholder="__('zone')" @update:model-value="czOnZone" />
                </div>
                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input type="search" v-model="filter" class="form-control" :placeholder="__('search')">
                </div>
                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="loadLayouts">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <MazerDatatable responsive :items="layouts" :fields="fields" :filter="filter"
                :filter-included-fields="['name', 'mode', 'home_type']" :busy="isLoading"
                stacked="md" show-empty small :empty-text="__('no_records_found')">

                <template #cell(name)="row">
                    <span>{{ row.item.name }}</span>
                </template>
                <template #cell(mode)="row">
                    <span class="text-capitalize">{{ row.item.mode }}</span>
                </template>
                <template #cell(home_type)="row">
                    <span class="text-capitalize">{{ (row.item.home_type || '').replace('_', ' ') }}</span>
                </template>
                <template #cell(zone)="row">
                    <span v-if="row.item.zone_scope === 'global'" class="text-muted">
                        {{ __('default_layout') }}
                    </span>
                    <span v-else>
                        {{ zoneNameById[row.item.zone_id] || ('#' + row.item.zone_id) }}
                    </span>
                </template>
                <template #cell(status)="row">
                    <span class="status-pill" :class="row.item.status === 'published' ? 'is-active' : 'is-warning'">
                        {{ row.item.status === 'published' ? __('published') : __('draft') }}
                    </span>
                    <div v-if="row.item.scheduled_publish_at" class="small text-info mt-1 d-flex align-items-center justify-content-center gap-1"
                        :title="__('draft_will_publish_at') + ' ' + formatLocal(row.item.scheduled_publish_at)">
                        <CalendarClock :size="12" /> {{ formatLocal(row.item.scheduled_publish_at) }}
                        <button v-if="$can('home_builder_publish')" type="button"
                            class="btn btn-link text-danger p-0 lh-1" :title="__('cancel_schedule')"
                            @click="unschedule(row.item)"><X :size="13" /></button>
                    </div>
                </template>
                <template #cell(active)="row">
                    <div class="form-check form-switch mb-0 d-flex justify-content-center">
                        <input class="form-check-input" type="checkbox" role="switch"
                            :checked="row.item.is_active"
                            :disabled="row.item.status !== 'published' || row.item.zone_scope === 'global' || !$can('home_builder_update')"
                            :title="row.item.zone_scope === 'global' ? __('default_home_layout_cannot_be_deactivated') : (row.item.status !== 'published' ? __('only_published_layout_can_be_activated') : '')"
                            @change="toggleActive(row.item, $event.target.checked)">
                    </div>
                </template>
                <template #cell(actions)="row">
                    <div class="list-actions">
                        <router-link :to="`/home_builder/edit/${row.item.id}`" class="list-action-btn is-edit"
                            v-if="$can('home_builder_update')" v-b-tooltip.hover :title="__('edit')">
                            <Pencil :size="15" />
                        </router-link>
                        <button class="list-action-btn is-edit" @click="openClone(row.item)"
                            v-if="$can('home_builder_create') && row.item.zone_scope === 'zone'"
                            v-b-tooltip.hover :title="__('clone_to_zone')">
                            <Copy :size="15" />
                        </button>
                        <button class="list-action-btn is-delete" @click="confirmDelete(row.item)"
                            v-if="$can('home_builder_delete')" v-b-tooltip.hover :title="__('delete')">
                            <Trash2 :size="15" />
                        </button>
                    </div>
                </template>
            </MazerDatatable>
        </div>

        <!-- Clone: copy an existing layout's design onto another zone as a draft. -->
        <b-modal v-model="clone.show" :title="__('clone_to_zone')" centered :no-footer="true">
            <p class="text-muted small">{{ __('clone_layout_help') }}</p>
            <div class="form-group mb-3">
                <label class="form-label">{{ __('zone') }}</label>
                <AppSelect class="form-select" v-model="clone.zone_id" :options="cloneTargetZoneOptions"
                    :placeholder="__('select_zone')" />
                <small v-if="!cloneTargetZones.length" class="text-danger">{{ __('no_records_found') }}</small>
            </div>
            <div class="d-flex justify-content-end gap-2">
                <button class="btn btn-outline-secondary" @click="clone.show = false">{{ __('cancel') }}</button>
                <button class="btn btn-primary" :disabled="!clone.zone_id || clone.saving" @click="doClone">
                    <b-spinner small v-if="clone.saving"></b-spinner>
                    {{ __('save') }}
                </button>
            </div>
        </b-modal>

        <HomeBuilderWizard v-if="showWizard" :existing-layouts="layouts" @complete="onWizardComplete"
            @close="showWizard = false" />
    </div>
</template>

<script>
import axios from 'axios';
import HomeBuilderWizard from './components/HomeBuilderWizard.vue';
import { Plus, Search, RefreshCw, Pencil, Trash2, Copy, CalendarClock, X } from 'lucide-vue-next';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';

export default {
    name: 'HomeBuilder',
    mixins: [CountryZoneFilter],
    components: { HomeBuilderWizard, Plus, Search, RefreshCw, Pencil, Trash2, Copy, CalendarClock, X },
    data() {
        return {
            czAllowAll: true,
            layouts: [],
            isLoading: false,
            showWizard: false,
            zoneNameById: {},
            zones: [],
            clone: { show: false, source: null, zone_id: null, saving: false },
            filter: '',
            fields: [
                { key: 'name', label: __('name'), sortable: false },
                { key: 'mode', label: __('channel'), class: 'text-center', sortable: false },
                { key: 'home_type', label: __('home_type'), class: 'text-center', sortable: false },
                { key: 'zone', label: __('zone'), class: 'text-center', sortable: false },
                { key: 'status', label: __('status'), class: 'text-center', sortable: false },
                { key: 'active', label: __('active'), class: 'text-center', sortable: false },
                { key: 'actions', label: __('actions'), class: 'text-center', sortable: false },
            ],
        };
    },
    created() {
        this.loadZones();
        this.czLoad();
    },
    computed: {
        // The "(both)" suffix was markup inside the option; fold it into the label.
        cloneTargetZoneOptions() {
            return (this.cloneTargetZones || []).map(z => ({
                id: z.id,
                name: z.sales_channel === 'both' ? `${z.name} (${__('both')})` : z.name,
            }));
        },
        // Valid clone targets: same channel as the source (a 'both' zone serves either)
        // and not already claimed by another layout on that channel.
        cloneTargetZones() {
            const src = this.clone.source;
            if (!src) return [];
            const taken = this.layouts
                .filter(l => l.zone_scope === 'zone' && l.mode === src.mode && l.zone_id)
                .map(l => Number(l.zone_id));
            const countryId = Number(this.czCountryParam) || 0;
            return this.zones.filter(z =>
                (z.sales_channel === src.mode || z.sales_channel === 'both')
                && !taken.includes(Number(z.id))
                && (!countryId || Number(z.country_id) === countryId));
        },
    },
    methods: {
        // Stored UTC schedule -> readable local string.
        formatLocal(iso) {
            if (!iso) return '';
            const d = new Date(iso);
            return isNaN(d.getTime()) ? '' : d.toLocaleString();
        },
        loadZones() {
            axios.get(this.$apiUrl + '/zones')
                .then(res => {
                    const list = res.data?.data || [];
                    const map = {};
                    list.forEach(z => { map[z.id] = z.name; });
                    this.zoneNameById = map;
                    this.zones = list;
                })
                .catch(() => { });
        },
        openClone(layout) {
            this.clone = { show: true, source: layout, zone_id: null, saving: false };
        },
        unschedule(layout) {
            this.$swal.fire({
                title: __('cancel_schedule'),
                text: __('cancel_schedule_confirm'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: __('ok'),
                cancelButtonText: __('cancel'),
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (!result.value) return;
                const form = new FormData();
                form.append('id', layout.id);
                form.append('scheduled_publish_at', '');
                axios.post(this.$apiUrl + '/home_layouts/schedule', form).then(res => {
                    if (res.data?.status === 0) {
                        this.showError(res.data?.message || __('something_went_wrong'));
                        return;
                    }
                    this.showMessage('success', __('home_layout_schedule_cancelled'));
                    this.loadLayouts();
                }).catch(() => { this.showError(__('something_went_wrong')); });
            });
        },
        doClone() {
            if (!this.clone.source || !this.clone.zone_id) return;
            this.clone.saving = true;
            axios.post(this.$apiUrl + '/home_layouts/clone', {
                id: this.clone.source.id,
                zone_id: this.clone.zone_id,
            }).then(res => {
                if (res.data?.status === 0) {
                    this.showError(res.data?.message || __('something_went_wrong'));
                    return;
                }
                this.showMessage('success', __('home_layout_cloned_successfully'));
                this.clone.show = false;
                const newId = res.data?.data?.id;
                if (newId) this.$router.push('/home_builder/edit/' + newId);
                else this.loadLayouts();
            }).catch(() => { this.showError(__('something_went_wrong')); })
                .finally(() => { this.clone.saving = false; });
        },
        czOnFilter() { this.loadLayouts(); },
        loadLayouts() {
            this.isLoading = true;
            const params = { country_id: this.czCountryParam, zone_id: this.czZoneParam };
            axios.get(this.$apiUrl + '/home_layouts', { params })
                .then(res => {
                    this.layouts = res.data?.data || [];
                })
                .catch(() => { this.layouts = []; })
                .finally(() => { this.isLoading = false; });
        },
        openWizard() {
            this.showWizard = true;
        },
        onWizardComplete(payload) {
            // The wizard collected the config metadata — create the record,
            // then jump straight into the builder.
            axios.post(this.$apiUrl + '/home_layouts/save', payload)
                .then(res => {
                    this.showWizard = false;
                    const id = res.data?.data?.id;
                    if (id) {
                        this.$router.push(`/home_builder/edit/${id}`);
                    } else {
                        this.loadLayouts();
                    }
                })
                .catch(err => {
                    this.showError(err.response?.data?.message || __('something_went_wrong'));
                });
        },
        toggleActive(layout, checked) {
            const form = new FormData();
            form.append('id', layout.id);
            form.append('is_active', checked ? 1 : 0);
            axios.post(this.$apiUrl + '/home_layouts/toggle_active', form)
                .then(res => {
                    if (res.data?.status === 0) {
                        this.showError(res.data.message || __('something_went_wrong'));
                        layout.is_active = !checked; // revert UI
                        return;
                    }
                    layout.is_active = checked;
                    this.showMessage('success', res.data?.message || __('home_layout_status_updated'));
                })
                .catch(err => {
                    layout.is_active = !checked; // revert UI
                    this.showError(err.response?.data?.message || __('something_went_wrong'));
                });
        },
        confirmDelete(layout) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('this_home_layout_will_be_deleted'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: __('yes_delete'),
                cancelButtonText: __('cancel'),
            }).then(result => {
                if (result.isConfirmed) {
                    const form = new FormData();
                    form.append('id', layout.id);
                    axios.post(this.$apiUrl + '/home_layouts/delete', form)
                        .then(res => {
                            if (res.data?.status === 0) {
                                this.showError(res.data.message || __('something_went_wrong'));
                                return;
                            }
                            this.showMessage('success', res.data?.message || __('home_layout_deleted_successfully'));
                            this.loadLayouts();
                        })
                        .catch(err => {
                            this.showError(err.response?.data?.message || __('something_went_wrong'));
                        });
                }
            });
        },
    },
};
</script>
