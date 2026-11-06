<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('manage_zones') }}</h3>
            <router-link to="/zones/create"
                class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap ms-auto"
                v-if="$can('zone_create')">
                <Plus :size="16" /> <span>{{ __('add_zone') }}</span>
            </router-link>
        </div>

        <div class="list-surface">
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
                    <AppSelect v-model="filterSalesChannel" class="form-select list-select list-select-lg"
                        :options="salesChannelOptions" :searchable="false" @update:model-value="loadZones" />
                </div>

                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input v-model="search" type="search" class="form-control" :placeholder="__('search')"
                        @input="onSearch">
                </div>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="loadZones">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <div class="list-panel-body">
                <div v-if="isLoading" class="card-grid">
                    <EntityCardSkeleton :count="8" />
                </div>
                <div v-else-if="!zones.length" class="card-grid-empty">
                    <MapPin :size="34" />
                    <span>{{ __('no_records_found') }}</span>
                </div>

                <div v-else class="zone-grid">
                    <div v-for="zone in zones" :key="zone.id" class="zone-card">
                        <!-- Header -->
                        <div class="zc-head">
                            <span class="zc-avatar" :class="isQuick(zone) ? 'ff-quick' : 'ff-ecommerce'">
                                <component :is="isQuick(zone) ? 'Zap' : 'ShoppingBag'" :size="20" />
                            </span>
                            <div class="zc-head-main">
                                <div class="zc-name" :title="zone.name">{{ zone.name }}</div>
                                <div class="zc-loc">
                                    <MapPin :size="13" />
                                    {{ locationText(zone) }}
                                </div>
                            </div>
                            <span class="status-pill" :class="zone.status ? 'is-active' : 'is-inactive'">
                                {{ zone.status ? __('active') : __('inactive') }}
                            </span>
                        </div>

                        <!-- Tags -->
                        <div class="zc-tags">
                            <span class="mode-chip">
                                <component :is="isBoth(zone) ? 'Layers' : (isQuick(zone) ? 'Zap' : 'ShoppingBag')" :size="13" />
                                {{ isBoth(zone) ? __('both') : (isQuick(zone) ? __('quick') : __('ecommerce')) }}
                            </span>
                            <span class="zc-chip">
                                <Tag :size="13" /> {{ pricingLabel(zone) }}
                            </span>
                        </div>

                        <!-- Metrics -->
                        <div class="zc-metrics">
                            <div class="zc-metric" v-for="(m, i) in metrics(zone)" :key="i">
                                <div class="zc-metric-val">{{ m.value }}</div>
                                <div class="zc-metric-lbl">{{ m.label }}</div>
                            </div>
                        </div>

                        <!-- Slab breakdown (eCommerce slab) -->
                        <div v-if="slabRows(zone).length" class="zc-slabs">
                            <div v-for="(s, i) in slabRows(zone)" :key="'s-' + i" class="zc-slab-row">
                                <span>{{ money(s.min) }}–{{ s.max === '' || s.max == null ? '∞' : money(s.max)
                                    }}</span>
                                <strong>{{ money(s.charge) }}</strong>
                            </div>
                        </div>

                        <!-- Quick extra details -->
                        <ul v-if="isQuick(zone)" class="zc-extra">
                            <li><Ruler :size="14" /> {{ zone.distance_unit || 'km' }}</li>
                            <li v-if="Number(zone.minimum_order_amount) > 0">
                                <ShoppingCart :size="14" />
                                {{ __('min_order') }}: {{ money(zone.minimum_order_amount) }}
                            </li>
                            <li v-if="firstSurge(zone)">
                                <Moon :size="14" />
                                {{ firstSurge(zone).label || __('surge') }}: {{ money(firstSurge(zone).charge)
                                }}
                                <small class="text-muted">({{ firstSurge(zone).start }}–{{ firstSurge(zone).end
                                    }})</small>
                            </li>
                        </ul>

                        <!-- Footer -->
                        <div class="zc-foot">
                            <router-link :to="`/zones/edit/${zone.id}`"
                                class="btn btn-sm btn-outline-primary flex-fill d-inline-flex align-items-center justify-content-center gap-1"
                                v-if="$can('zone_update')">
                                <Pencil :size="14" /> {{ __('edit') }}
                            </router-link>
                            <button
                                class="btn btn-sm btn-outline-danger flex-fill d-inline-flex align-items-center justify-content-center gap-1"
                                @click="confirmDelete(zone)" v-if="$can('zone_delete')">
                                <Trash2 :size="14" /> {{ __('delete') }}
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import axios from 'axios';
import { Plus, Search, RefreshCw, MapPin, Zap, ShoppingBag, Layers, Tag, Ruler, ShoppingCart, Moon, Pencil, Trash2 } from 'lucide-vue-next';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';

export default {
    name: 'Zones',
    mixins: [CountryZoneFilter],
    components: { Plus, Search, RefreshCw, MapPin, Zap, ShoppingBag, Tag, Ruler, ShoppingCart, Moon, Pencil, Trash2, Layers},
    computed: {
        // Fixed option set — no search box needed.
        salesChannelOptions() {
            return [
                { id: '', name: __('all_sales_channels') },
                { id: 'both', name: __('both') },
                { id: 'quick', name: __('quick') },
                { id: 'ecommerce', name: __('ecommerce') },
            ];
        },
    },
    data() {
        return {
            czAllowAll: true,
            czShowZone: false, // this IS the zones list — filter by country only
            zones: [],
            isLoading: true,
            search: '',
            filterSalesChannel: '',
            searchTimer: null,
        };
    },
    created() {
        this.czLoad();
    },
    methods: {
        czOnFilter() { this.loadZones(); },
        loadZones() {
            this.isLoading = true;
            const params = {};
            if (this.search) params.search = this.search;
            if (this.filterSalesChannel) params.sales_channel = this.filterSalesChannel;
            params.country_id = this.czCountryParam;
            axios.get(this.$apiUrl + '/zones', { params })
                .then(res => {
                    this.zones = res.data?.data || [];
                })
                .catch(() => {
                    this.zones = [];
                })
                .finally(() => {
                    this.isLoading = false;
                });
        },
        onSearch() {
            clearTimeout(this.searchTimer);
            this.searchTimer = setTimeout(() => this.loadZones(), 300);
        },

        isBoth(zone) {
            return zone.sales_channel === 'both';
        },
        // 'both' zones show the quick-side extras too, since they have quick pricing.
        isQuick(zone) {
            return zone.sales_channel === 'quick' || zone.sales_channel === 'both';
        },
        initials(name) {
            return (name || '?').trim().split(/\s+/).slice(0, 2).map(w => w[0]).join('').toUpperCase();
        },
        locationText(zone) {
            return [zone.city, zone.state, zone.country].filter(Boolean).join(', ') || '-';
        },
        money(v) {
            return (this.$currency || '') + Number(v || 0);
        },
        pricingLabel(zone) {
            if (this.isQuick(zone)) {
                const n = (zone.surge_slots || []).length;
                return n ? `${n} ${n > 1 ? __('surge_slots') : __('surge_slot')}` : __('distance_pricing');
            }
            return zone.pricing_strategy === 'slab' ? __('slab_pricing') : __('flat_pricing');
        },
        slabRows(zone) {
            if (this.isQuick(zone) || zone.pricing_strategy !== 'slab') return [];
            return Array.isArray(zone.slab_pricing) ? zone.slab_pricing : [];
        },
        firstSurge(zone) {
            return (zone.surge_slots || [])[0] || null;
        },
        metrics(zone) {
            if (this.isQuick(zone)) {
                return [
                    { value: this.money(zone.base_delivery_charge), label: __('base_charge') },
                    { value: Number(zone.base_distance || 0) + ' ' + (zone.distance_unit || 'km'), label: __('base_distance') },
                    { value: this.money(zone.charge_per_km), label: __('per_km') },
                    { value: this.money(zone.free_delivery_above), label: __('free_above') },
                ];
            }
            if (zone.pricing_strategy === 'slab') {
                const slabs = this.slabRows(zone);
                return [
                    { value: slabs.length, label: __('slabs') },
                    { value: this.money(slabs.length ? slabs[0].charge : 0), label: __('first_slab') },
                    { value: this.money(zone.default_delivery_charge), label: __('fallback') },
                ];
            }
            return [
                { value: this.money(zone.flat_delivery_charge), label: __('delivery_fee') },
                { value: this.money(zone.flat_free_delivery_above), label: __('free_above') },
                { value: this.money(zone.default_delivery_charge), label: __('fallback') },
            ];
        },

        confirmDelete(zone) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('this_zone_will_be_deleted'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: __('yes_delete'),
                cancelButtonText: __('cancel'),
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (result.isConfirmed) {
                    const form = new FormData();
                    form.append('id', zone.id);
                    axios.post(this.$apiUrl + '/zones/delete', form)
                        .then(res => {
                            const body = res.data || {};
                            if (Number(body.status) === 0) {
                                this.showError(body.message || __('something_went_wrong'));
                                return;
                            }
                            this.showMessage('success', body.message || __('zone_deleted_successfully'));
                            this.loadZones();
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
