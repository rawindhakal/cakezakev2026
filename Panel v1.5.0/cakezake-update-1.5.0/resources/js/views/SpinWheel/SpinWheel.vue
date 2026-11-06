<template>
  <div>
    <div class="list-page">
      <div class="page-head">
        <h3 class="page-head-title">{{ __('spin_wheel_campaigns') }}</h3>
        <div class="d-flex gap-2">
          <button class="btn btn-outline-secondary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
            @click="$router.push('/spin_wheel/history')">
            <History :size="16" />
            <span>{{ __('spin_history') }}</span>
          </button>
          <button class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
            @click="$router.push('/spin_wheel/create')" v-if="$can('spin_wheel_create')">
            <Plus :size="16" />
            <span>{{ __('add_spin_wheel_campaign') }}</span>
          </button>
        </div>
      </div>

      <div class="list-surface">
        <div class="list-toolbar">
          <div class="list-toolbar-start">
            <AppSelect v-model="statusFilter" class="form-select list-select" :options="statusFilterOptions"
              :searchable="false" />
          </div>

          <div class="list-search">
            <Search class="list-search-icon" />
            <input id="filter-input" v-model="filter" type="search" class="form-control" :placeholder="__('search')" />
          </div>

          <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getCampaigns()">
            <RefreshCw :class="{ 'is-spinning': isLoading }" />
          </button>
        </div>

        <MazerDatatable responsive :items="pagedCampaigns" :fields="fields" v-model:sort-by="sortBy"
          v-model:sort-desc="sortDesc" :busy="isLoading" stacked="md" show-empty small>

          <template #cell(name)="row">
            <div class="text-start">
              <div class="fw-semibold">{{ row.item.name }}</div>
              <small class="text-muted">{{ row.item.code_prefix }}</small>
            </div>
          </template>

          <template #cell(window)="row">
            <span v-if="row.item.start_date || row.item.end_date" class="small">
              {{ row.item.start_date ? $filters.formatDateTime(row.item.start_date) : '—' }}
              <span class="text-muted">→</span>
              {{ row.item.end_date ? $filters.formatDateTime(row.item.end_date) : '—' }}
            </span>
            <span v-else class="text-muted">{{ __('no_date_limit') }}</span>
          </template>

          <template #cell(limits)="row">
            <div class="small">
              <div>{{ __('spins_per_day') }}: <b>{{ row.item.spins_per_day }}</b></div>
              <div class="text-muted">
                {{ __('lifetime') }}:
                {{ Number(row.item.max_spins_per_user) > 0 ? row.item.max_spins_per_user : __('unlimited') }}
              </div>
            </div>
          </template>

          <template #cell(segments_count)="row">
            <span class="badge bg-info">{{ row.item.segments_count || 0 }}</span>
          </template>

          <template #cell(activity)="row">
            <div class="small">
              <div>{{ __('spins') }}: <b>{{ row.item.spins_count || 0 }}</b></div>
              <div class="text-muted">{{ __('wins') }}: {{ row.item.wins_count || 0 }}</div>
            </div>
          </template>

          <template #cell(status)="row">
            <span class="status-pill is-active" v-if="Number(row.item.status) === 1">{{ __('active') }}</span>
            <span class="status-pill is-inactive" v-else-if="!Number(row.item.is_scheduled)">{{ __('deactive') }}</span>
            <span class="status-pill is-scheduled" v-else v-b-tooltip.hover
              :title="__('will_activate_on_start_date')">{{ __('scheduled') }}</span>
          </template>

          <template #cell(actions)="row">
            <div class="list-actions">
              <button class="list-action-btn is-edit" @click="$router.push('/spin_wheel/edit/' + row.item.id)"
                v-if="$can('spin_wheel_update')" v-b-tooltip.hover :title="__('edit')">
                <Pencil :size="15" />
              </button>
              <button class="list-action-btn is-delete" @click="deleteCampaign(row.item)"
                v-if="$can('spin_wheel_delete')" v-b-tooltip.hover :title="__('delete')">
                <Trash2 :size="15" />
              </button>
            </div>
          </template>

        </MazerDatatable>

        <div class="list-footer">
          <div class="list-perpage">
            <span>{{ __('per_page') }}</span>
            <b-form-select id="per-page-select" v-model="perPage" :options="pageOptions" size="sm"
              class="form-select"></b-form-select>
            <span class="list-range">{{ __('total_records') }} : {{ totalRows }}</span>
          </div>

          <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage" size="sm"
            class="mb-0 list-pagination"></b-pagination>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios';
import ListState from '../../mixins/ListState.js';
import { Search, RefreshCw, Plus, Pencil, Trash2, History } from 'lucide-vue-next';

export default {
  name: 'SpinWheel',
  mixins: [ListState],
  listState: ['currentPage', 'perPage', 'statusFilter'],
  components: { Search, RefreshCw, Plus, Pencil, Trash2, History },
  data() {
    return {
      campaigns: [],
      isLoading: false,
      filter: '',
      statusFilter: '',
      sortBy: 'id',
      sortDesc: true,
      fields: [
        { key: 'id', label: __('id'), sortable: true, class: 'text-center' },
        { key: 'name', label: __('campaign'), sortable: false, class: 'text-center' },
        { key: 'window', label: __('campaign_window'), sortable: false, class: 'text-center' },
        { key: 'limits', label: __('spin_limits'), sortable: false, class: 'text-center' },
        { key: 'segments_count', label: __('segments'), sortable: false, class: 'text-center' },
        { key: 'activity', label: __('activity'), sortable: false, class: 'text-center' },
        { key: 'status', label: __('status'), sortable: true, class: 'text-center' },
        { key: 'actions', label: __('actions'), sortable: false, class: 'text-center' },
      ],
      perPage: 30,
      currentPage: 1,
      pageOptions: this.$pageOptions,
    };
  },
  computed: {
    statusFilterOptions() {
      return [
        { id: '', name: __('all_status') },
        { id: '1', name: __('active') },
        { id: '0', name: __('deactive') },
      ];
    },
    filteredCampaigns() {
      const term = (this.filter || '').trim().toLowerCase();
      return (this.campaigns || []).filter(c => {
        if (this.statusFilter !== '' && String(c.status) !== String(this.statusFilter)) return false;
        if (!term) return true;
        return String(c.id) === term
          || (c.name || '').toLowerCase().includes(term)
          || (c.code_prefix || '').toLowerCase().includes(term);
      });
    },
    totalRows() {
      return this.filteredCampaigns.length;
    },
    pagedCampaigns() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.filteredCampaigns.slice(start, start + this.perPage);
    },
  },
  watch: {
    // A filter change means a different set, so page 1 — unless the list is being
    // restored, where the saved page is the whole point.
    filter() { if (!this.consumeListRestore()) this.currentPage = 1; },
    statusFilter() { if (!this.consumeListRestore()) this.currentPage = 1; },
  },
  mounted() {
    this.getCampaigns();
    this.$eventBus.on('recordSaved', this.getCampaigns);
  },
  beforeUnmount() {
    this.$eventBus.off('recordSaved', this.getCampaigns);
  },
  methods: {
    getCampaigns() {
      this.isLoading = true;
      axios.get(this.$apiUrl + '/spin_wheel').then(res => {
        this.campaigns = res.data?.data || [];
        this.isLoading = false;
      }).catch(() => {
        this.isLoading = false;
        this.showError(__('something_went_wrong'));
      });
    },
    deleteCampaign(campaign) {
      this.$swal.fire({
        title: __('are_you_sure'),
        // Prizes already handed out are not touched by the delete, and saying so
        // stops the admin worrying about clawing back live coupons.
        text: __('spin_wheel_delete_warning'),
        confirmButtonText: __('yes_sure'),
        cancelButtonText: __('cancel'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: window.adminThemeColor || '#435ebe',
        cancelButtonColor: '#d33',
      }).then(result => {
        if (!result.value) return;
        const fd = new FormData();
        fd.append('id', campaign.id);
        axios.post(this.$apiUrl + '/spin_wheel/delete', fd).then(res => {
          if (res.data.status === 1) {
            this.showMessage('success', res.data.message || __('spin_wheel_campaign_deleted_successfully'));
            this.getCampaigns();
          } else {
            this.showError(res.data.message);
          }
        }).catch(err => {
          this.showError(err.response?.data?.message || __('something_went_wrong'));
        });
      });
    },
  },
};
</script>

<style scoped>
.status-pill.is-scheduled { color: #b45309; background: rgba(245, 158, 11, .15); }
</style>
