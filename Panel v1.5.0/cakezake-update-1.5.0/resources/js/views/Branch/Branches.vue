<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('manage_branches') }}</h3>
            <router-link to="/branches/create"
                class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                v-if="$can('branch_create')">
                <Plus :size="16" /><span>{{ __('add_branch') }}</span>
            </router-link>
        </div>

        <div class="list-surface">
            <!-- Toolbar: filters left, search + refresh right -->
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
                    <AppSelect v-if="czShowZoneDropdown" class="form-select list-select cz-sel" v-model="czZoneId"
                        :options="czZoneOptions" :searchable="false" :allow-empty="false" label-key="label"
                        track-by="id" :placeholder="__('zone')" @update:model-value="czOnZone" />
                    <AppSelect class="form-select list-select" v-model="filterType" :options="filterTypeOptions" :searchable="false" @update:model-value="loadBranches" />
                    <AppSelect class="form-select list-select" v-model="filterStatus" :options="filterStatusOptions" :searchable="false" @update:model-value="loadBranches" />
                </div>

                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input type="search" class="form-control" v-model="search"
                        :placeholder="__('search')" @input="onSearch">
                </div>
                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="loadBranches">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <div class="list-panel-body">
                <div class="card-grid">
                    <EntityCardSkeleton v-if="isLoading" :count="perPage" />
                    <div v-else-if="!branches.length" class="card-grid-empty">
                        <BranchIcon :size="34" />
                        <span>{{ __('no_records_found') }}</span>
                    </div>

                    <div v-else v-for="s in branches" :key="s.id" class="entity-card branch-card">
                        <div class="entity-card-body">
                            <!-- Header: avatar + name, status pinned top-right -->
                            <div class="branch-head">
                                <span class="branch-avatar" :class="'ff-' + (s.fulfillment_type || 'ecommerce')">
                                    <BranchIcon :size="20" />
                                </span>
                                <div class="branch-head-main">
                                    <h4 class="entity-card-title">{{ s.name }}</h4>
                                </div>
                                <span class="status-pill" :class="s.status ? 'is-active' : 'is-inactive'">
                                    {{ s.status ? __('active') : __('inactive') }}
                                </span>
                            </div>

                            <!-- Channel + fulfilment chips -->
                            <div class="branch-tags">
                                <span class="mode-chip">
                                    <component :is="ffIcon(s.fulfillment_type)" :size="13" />
                                    {{ fulfillmentLabel(s.fulfillment_type) }}
                                </span>
                                <span class="mode-chip" v-if="s.service_modes && s.service_modes !== 'delivery'"
                                    v-b-tooltip.hover :title="s.service_modes === 'pickup' ? __('self_pickup_only') : __('delivery_and_pickup')">
                                    <PackageCheck :size="13" /> {{ __('self_pickup') }}
                                </span>
                            </div>

                            <!-- Useful info -->
                            <div class="entity-card-meta branch-meta">
                                <span class="entity-meta-row" v-if="s.provider">
                                    <Building2 :size="14" /> <b>{{ s.provider }}</b>
                                </span>
                                <span class="entity-meta-row" v-if="branchLocation(s)">
                                    <MapPin :size="14" /> {{ branchLocation(s) }}
                                </span>
                                <span class="entity-meta-row" v-if="s.contact_number">
                                    <Phone :size="14" /> {{ s.contact_number }}
                                </span>
                                <span class="entity-meta-row" v-if="s.email">
                                    <Mail :size="14" /> <span class="text-truncate">{{ s.email }}</span>
                                </span>
                            </div>

                            <div class="entity-card-foot">
                                <div class="list-actions">
                                    <router-link :to="`/branches/edit/${s.id}`" class="list-action-btn is-edit"
                                        v-if="$can('branch_update')" v-b-tooltip.hover :title="__('edit')">
                                        <Pencil :size="15" />
                                    </router-link>
                                    <button class="list-action-btn" @click="openPermissions(s)"
                                        v-if="$can('branch_update')" v-b-tooltip.hover :title="__('edit_permissions')">
                                        <ShieldCheck :size="15" />
                                    </button>
                                    <button class="list-action-btn is-delete" @click="confirmDelete(s)"
                                        v-if="$can('branch_delete')" v-b-tooltip.hover :title="__('delete')">
                                        <Trash2 :size="15" />
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Owner-permission quick editor (mirrors the Edit Role modal). -->
        <b-modal ref="perm-modal" size="xl" scrollable no-close-on-backdrop no-fade static>
            <template #modal-header="{ close }">
                <h5 class="modal-title">{{ __('owner_permissions') }} : <strong>{{ perm.branchName }}</strong></h5>
                <button type="button" aria-label="Close" class="close" @click="close()">×</button>
            </template>
            <div class="d-flex justify-content-end mb-2">
                <div class="btn-group btn-group-sm">
                    <button type="button" class="btn btn-outline-primary mb-0" @click="setAllPerm(true)">{{ __('select_all') }}</button>
                    <button type="button" class="btn btn-outline-secondary mb-0" @click="setAllPerm(false)">{{ __('deselect_all') }}</button>
                </div>
            </div>
            <div class="table-responsive">
                <table class="table table-lg table-striped">
                    <tbody>
                        <tr v-for="cat in perm.categories" :key="cat.id">
                            <th class="table-active">
                                <div class="form-check">
                                    <input class="form-check-input" type="checkbox" :id="'scatall_' + cat.id"
                                        :checked="isCatAll(cat)" @change="toggleCatPerm(cat, $event.target.checked)">
                                    <label class="form-check-label fw-bold" :for="'scatall_' + cat.id">{{ formattedName(cat.name) }}</label>
                                </div>
                            </th>
                            <td>
                                <div class="row">
                                    <div class="col-12 col-md-6 col-lg-4 mb-2" v-for="p in cat.permissions" :key="p.id">
                                        <div class="form-check form-switch">
                                            <input class="form-check-input" type="checkbox" :id="'sp_' + p.id" :value="p.id" v-model="perm.selected" @change="onBranchPermToggle(p)">
                                            <label class="form-check-label" style="margin-left: 5px" :for="'sp_' + p.id">{{ formattedName(p.name) }}</label>
                                        </div>
                                    </div>
                                </div>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
            <template #footer>
                <b-button variant="primary" :disabled="perm.saving" @click="savePermissions">{{ __('save') }}
                    <b-spinner v-if="perm.saving" small label="Spinning"></b-spinner>
                </b-button>
                <b-button variant="secondary" @click="closePermissions">{{ __('cancel') }}</b-button>
            </template>
        </b-modal>
    </div>
</template>

<script>
import axios from 'axios';
import {
    Plus, Search, RefreshCw, Store as BranchIcon, Pencil, Trash2, MapPin, Phone, Mail,
    Building2, Zap, ShoppingBag, PackageCheck, Layers, ShieldCheck,
} from 'lucide-vue-next';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';
import { cascadePermission } from '../../utils/permissionCascade.js';

export default {
    name: 'Branches',
    mixins: [CountryZoneFilter],
    components: {
        Plus, Search, RefreshCw, BranchIcon, Pencil, Trash2, MapPin, Phone, Mail,
        Building2, Zap, ShoppingBag, PackageCheck, Layers, ShieldCheck,
    },
    data() {
        return {
            czAllowAll: true,
            branches: [],
            isLoading: true,
            search: '',
            filterType: '',
            filterStatus: '',
            searchTimer: null,
            perm: { saving: false, branchId: null, branchName: '', categories: [], selected: [] },
        };
    },
    created() {
        this.czLoad();
    },
    computed: {
        // Fixed option set — no search box needed.
        filterTypeOptions() {
            return [
                { id: '', name: (__('all_fulfillment_types')) },
                { id: 'quick', name: (__('quick')) },
                { id: 'ecommerce', name: (__('ecommerce')) },
                { id: 'both', name: (__('both')) },
            ];
        },
        // Fixed option set — no search box needed.
        filterStatusOptions() {
            return [
                { id: '', name: (__('all_statuses') || 'All statuses') },
                { id: '1', name: (__('active')) },
                { id: '0', name: (__('inactive')) },
            ];
        },
    },
    methods: {
        czOnFilter() { this.loadBranches(); },
        async openPermissions(s) {
            this.perm.branchId = s.id;
            this.perm.branchName = s.name;
            this.perm.categories = [];
            this.perm.selected = [];
            const m = this.$refs['perm-modal'];
            if (m && typeof m.show === 'function') m.show();
            try {
                const [cat, edit] = await Promise.all([
                    axios.get(this.$apiUrl + '/branches/permission_catalog'),
                    axios.get(this.$apiUrl + '/branches/edit/' + s.id),
                ]);
                this.perm.categories = cat.data?.data?.categories || [];
                this.perm.selected = (edit.data?.data?.owner_permission_ids || []).map(Number);
            } catch (e) {
                this.showError(__('something_went_wrong'));
            }
        },
        closePermissions() {
            const m = this.$refs['perm-modal'];
            if (m && typeof m.hide === 'function') m.hide();
        },
        onBranchPermToggle(p) {
            this.perm.selected = cascadePermission(this.perm.selected, this.perm.categories, p);
        },
        allPermIds() { return this.perm.categories.flatMap(c => (c.permissions || []).map(p => p.id)); },
        setAllPerm(checked) { this.perm.selected = checked ? this.allPermIds() : []; },
        isCatAll(cat) {
            const ids = (cat.permissions || []).map(p => p.id);
            return ids.length > 0 && ids.every(id => this.perm.selected.includes(id));
        },
        toggleCatPerm(cat, checked) {
            const ids = (cat.permissions || []).map(p => p.id);
            if (checked) this.perm.selected = Array.from(new Set([...this.perm.selected, ...ids]));
            else this.perm.selected = this.perm.selected.filter(id => !ids.includes(id));
        },
        async savePermissions() {
            this.perm.saving = true;
            try {
                const fd = new FormData();
                fd.append('id', this.perm.branchId);
                this.perm.selected.forEach(id => fd.append('permissions[]', id));
                const res = await axios.post(this.$apiUrl + '/branches/save_permissions', fd);
                if (res.data?.status === 0) { this.showError(res.data.message); return; }
                this.showMessage('success', res.data?.message || __('permissions_updated_successfully'));
                this.closePermissions();
            } catch (e) {
                this.showError(e.response?.data?.message || __('something_went_wrong'));
            } finally {
                this.perm.saving = false;
            }
        },
        fulfillmentLabel(type) {
            if (type === 'quick') return __('quick');
            if (type === 'both') return __('both');
            return __('ecommerce');
        },
        ffIcon(type) {
            if (type === 'quick') return 'Zap';
            if (type === 'both') return 'Layers';
            return 'ShoppingBag';
        },
        branchLocation(s) {
            // Location now comes from the assigned zone.
            const z = s.zone || {};
            return [z.city, z.state, z.name].filter(Boolean).join(', ') || '—';
        },
        loadBranches() {
            this.isLoading = true;
            const params = {};
            if (this.search) params.search = this.search;
            if (this.filterType) params.fulfillment_type = this.filterType;
            if (this.filterStatus !== '') params.status = this.filterStatus;
            params.country_id = this.czCountryParam;
            params.zone_id = this.czZoneParam;
            axios.get(this.$apiUrl + '/branches', { params })
                .then(res => {
                    this.branches = res.data?.data?.branches || [];
                })
                .catch(() => {
                    this.branches = [];
                })
                .finally(() => { this.isLoading = false; });
        },
        onSearch() {
            clearTimeout(this.searchTimer);
            this.searchTimer = setTimeout(() => this.loadBranches(), 300);
        },
        confirmDelete(s) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('this_branch_will_be_deleted'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: __('yes_delete'),
                cancelButtonText: __('cancel'),
            }).then(r => {
                if (!r.isConfirmed) return;
                const fd = new FormData();
                fd.append('id', s.id);
                axios.post(this.$apiUrl + '/branches/delete', fd)
                    .then(res => {
                        const body = res.data || {};
                        if (Number(body.status) === 0) {
                            this.showError(body.message || __('something_went_wrong'));
                            return;
                        }
                        this.showMessage('success', body.message || __('branch_deleted_successfully'));
                        this.loadBranches();
                    })
                    .catch(err => this.showError(err.response?.data?.message || __('something_went_wrong')));
            });
        },
    },
};
</script>

<style scoped>
.branch-head {
    display: flex;
    align-items: center;
    gap: .6rem;
    margin-bottom: .6rem;
}
.branch-avatar {
    width: 42px;
    height: 42px;
    flex: none;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 10px;
    background: rgba(var(--bs-primary-rgb), .1);
    color: var(--bs-primary);
}
.branch-avatar.ff-quick { background: rgba(6, 182, 212, .12); color: #0891b2; }
.branch-avatar.ff-both { background: rgba(245, 158, 11, .14); color: #d97706; }
.branch-head-main { min-width: 0; flex: 1; }
.branch-tags { display: flex; align-items: center; flex-wrap: wrap; gap: .4rem; margin-bottom: .25rem; }
.branch-head .status-pill { flex-shrink: 0; align-self: flex-start; }
.branch-meta { margin-top: .5rem; }
.branch-meta .entity-meta-row { color: #55607a; }
</style>
