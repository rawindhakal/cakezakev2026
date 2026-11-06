<template>
  <div class="list-page">
    <div class="page-head">
      <div>
        <h3 class="page-head-title mb-0">{{ __('spin_history') }}</h3>
        <p class="text-muted small mb-0 mt-1">{{ __('spin_history_hint') }}</p>
      </div>
      <button type="button"
        class="btn btn-outline-secondary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
        @click="$router.push('/spin_wheel')">
        <ArrowLeft :size="16" /> {{ __('back') }}
      </button>
    </div>

    <!-- Totals for the current filter, not for all time — so a country or date filter
         answers "what did this cost us there". -->
    <div class="row g-3 mb-3">
      <div class="col-6 col-sm-4 col-lg-3 col-xl" v-for="c in statCards" :key="c.key">
        <div class="stat-card">
          <span class="stat-icon"><component :is="c.icon" :size="20" /></span>
          <div class="stat-meta">
            <div class="stat-label">{{ c.label }}</div>
            <div class="stat-num">{{ c.value }}</div>
          </div>
        </div>
      </div>
    </div>

    <div class="list-surface">
      <div class="list-toolbar">
        <div class="list-toolbar-start flex-wrap">
          <AppSelect v-if="czShowCountry" class="form-select list-select cz-sel" v-model="czCountryId"
            :options="czCountryOptions" :searchable="czCountryOptions.length > 6" :allow-empty="false"
            label-key="label" track-by="id" :placeholder="__('country')" @update:model-value="czOnCountry">
            <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                  :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
            <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url" :src="option.logo_url"
                  class="cz-flag" />{{ option.label }}</span></template>
          </AppSelect>

          <AppSelect class="form-select list-select" v-model="campaignFilter" :options="campaignOptions"
            :searchable="campaignOptions.length > 6" @update:model-value="reload" />
          <AppSelect class="form-select list-select" v-model="rewardFilter" :options="rewardOptions"
            :searchable="false" @update:model-value="reload" />

          <div class="cc-daterange">
            <date-range-picker v-model="dateRange" :config="datePickerConfig" @update="reload"></date-range-picker>
          </div>
          <button v-if="dateRange" class="list-icon-btn" @click="dateRange = ''; reload()" v-b-tooltip.hover
            :title="__('clear')">
            <X :size="16" />
          </button>
        </div>

        <div class="list-search">
          <Search class="list-search-icon" />
          <input v-model="search" type="search" class="form-control" :placeholder="__('search_customer_or_code')"
            @input="debouncedReload" />
        </div>

        <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getHistory()">
          <RefreshCw :class="{ 'is-spinning': isLoading }" />
        </button>
      </div>

      <MazerDatatable responsive :items="spins" :fields="fields" :busy="isLoading" stacked="md" show-empty small>

        <template #cell(spun_at)="row">
          {{ $filters.formatDateTime(row.item.spun_at) }}
        </template>

        <template #cell(customer)="row">
          <div class="text-start">
            <div class="fw-semibold">{{ row.item.customer_name || '—' }}</div>
            <small class="text-muted">{{ row.item.customer_mobile || '' }}</small>
          </div>
        </template>

        <template #cell(campaign_name)="row">
          <div class="text-start">
            <div>{{ row.item.campaign_name || '—' }}</div>
            <small class="text-muted">{{ row.item.segment_label || '' }}</small>
          </div>
        </template>

        <template #cell(reward_type)="row">
          <span class="status-pill" :class="rewardClass(row.item.reward_type)">
            {{ rewardLabel(row.item.reward_type) }}
          </span>
        </template>

        <template #cell(amount)="row">
          <span v-if="Number(row.item.amount) > 0">
            {{ row.item.currency || '' }}{{ row.item.amount }}
          </span>
          <span v-else class="text-muted">—</span>
        </template>

        <template #cell(promo_code)="row">
          <div v-if="row.item.promo_code" class="text-start">
            <code>{{ row.item.promo_code }}</code>
            <small class="text-muted d-block" v-if="row.item.promo_expires_on">
              {{ __('expires_on') }}: {{ $filters.formatDate(row.item.promo_expires_on) }}
            </small>
          </div>
          <span v-else class="text-muted">—</span>
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
</template>

<script>
import axios from 'axios';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';
import DateRangePicker from '../../components/DateRangePicker.vue';
import { buildDateRangeConfig, toApiDate } from '../../utils/dateRange.js';
import { Search, RefreshCw, X, ArrowLeft, RotateCcw, Trophy, Wallet, TicketPercent, Truck } from 'lucide-vue-next';

export default {
  name: 'SpinHistory',
  mixins: [CountryZoneFilter],
  components: { DateRangePicker, Search, RefreshCw, X, ArrowLeft },
  data() {
    return {
      // Spins are logged per country, but the report reads fine across all of them —
      // each row carries its own currency.
      czAllowAll: true,
      czShowZone: false,
      spins: [],
      summary: { spins: 0, wins: 0, wallet_credited: 0, promo_codes_issued: 0, free_deliveries: 0 },
      campaigns: [],
      campaignFilter: '',
      rewardFilter: '',
      dateRange: '',
      datePickerConfig: buildDateRangeConfig({ maxDate: new Date() }),
      search: '',
      isLoading: false,
      totalRows: 0,
      currentPage: 1,
      perPage: this.$perPage,
      pageOptions: this.$pageOptions,
      fields: [
        { key: 'spun_at', label: __('date'), class: 'text-center' },
        { key: 'customer', label: __('customer'), class: 'text-center' },
        { key: 'campaign_name', label: __('campaign'), class: 'text-center' },
        { key: 'reward_type', label: __('reward'), class: 'text-center' },
        { key: 'amount', label: __('amount'), class: 'text-center' },
        { key: 'promo_code', label: __('promo_code'), class: 'text-center' },
      ],
      _debounce: null,
    };
  },
  computed: {
    campaignOptions() {
      return [{ id: '', name: __('all_campaigns') }]
        .concat((this.campaigns || []).map(c => ({ id: c.id, name: c.name })));
    },
    rewardOptions() {
      return [
        { id: '', name: __('all_rewards') },
        { id: 'promo_code', name: __('promo_code') },
        { id: 'wallet', name: __('wallet_amount') },
        { id: 'free_delivery', name: __('free_delivery') },
        { id: 'no_luck', name: __('no_luck_segment') },
      ];
    },
    statCards() {
      // Wallet money is shown with the selected country's symbol; with "All countries"
      // picked the figure mixes currencies, so no symbol is claimed.
      const symbol = this.czIsAll ? '' : (this.czCurrency || '');
      return [
        { key: 'spins', label: __('spins'), value: this.summary.spins, icon: RotateCcw },
        { key: 'wins', label: __('wins'), value: this.summary.wins, icon: Trophy },
        { key: 'wallet', label: __('wallet_credited'), value: symbol + this.summary.wallet_credited, icon: Wallet },
        { key: 'codes', label: __('coupons_issued'), value: this.summary.promo_codes_issued, icon: TicketPercent },
        { key: 'free', label: __('free_deliveries'), value: this.summary.free_deliveries, icon: Truck },
      ];
    },
  },
  watch: {
    currentPage() { this.getHistory(); },
    perPage() { this.currentPage = 1; this.getHistory(); },
  },
  mounted() {
    this.loadCampaigns();
    // czLoad resolves the country, then calls czOnFilter.
    this.czLoad();
  },
  methods: {
    // Called by CountryZoneFilter whenever the country changes.
    czOnFilter() {
      this.reload();
    },
    debouncedReload() {
      clearTimeout(this._debounce);
      this._debounce = setTimeout(() => this.reload(), 400);
    },
    reload() {
      this.currentPage = 1;
      this.getHistory();
    },
    loadCampaigns() {
      axios.get(this.$apiUrl + '/spin_wheel').then(res => {
        this.campaigns = (res.data?.data || []).map(c => ({ id: c.id, name: c.name }));
      }).catch(() => { /* the filter simply stays at "all campaigns" */ });
    },
    getHistory() {
      this.isLoading = true;
      const params = {
        limit: this.perPage,
        offset: (this.currentPage - 1) * this.perPage,
        search: this.search || '',
        country_id: this.czCountryParam,
        campaign_id: this.campaignFilter || '',
        reward_type: this.rewardFilter || '',
      };
      if (this.dateRange) {
        params.start_date = toApiDate(this.dateRange, 'start');
        params.end_date = toApiDate(this.dateRange, 'end');
      }
      axios.get(this.$apiUrl + '/spin_wheel/history', { params }).then(res => {
        const data = res.data?.data || {};
        this.spins = data.spins || [];
        this.summary = data.summary || this.summary;
        this.totalRows = res.data?.total || 0;
      }).catch(() => this.showError(__('something_went_wrong')))
        .finally(() => { this.isLoading = false; });
    },
    rewardLabel(type) {
      const match = this.rewardOptions.find(o => o.id === type);
      return match ? match.name : type;
    },
    rewardClass(type) {
      return type === 'no_luck' ? 'is-inactive' : 'is-active';
    },
  },
};
</script>

<style scoped>
.stat-card {
  display: flex; align-items: center; gap: .75rem; height: 100%;
  background: var(--app-card-bg); border: 1px solid var(--app-card-border);
  border-radius: 12px; padding: .9rem 1rem;
}
.stat-icon {
  width: 44px; height: 44px; border-radius: 12px; flex-shrink: 0;
  display: inline-flex; align-items: center; justify-content: center;
  background: rgba(var(--bs-primary-rgb), .1); color: var(--bs-primary);
}
.stat-label { font-size: 12px; color: var(--bs-secondary-color); }
.stat-num { font-size: 18px; font-weight: 700; }
.cc-daterange { width: 240px; flex-shrink: 0; }
.cc-daterange :deep(.date-range-picker),
.cc-daterange :deep(.form-control) { width: 100%; height: 36px; border-radius: 8px; }
.cz-flag { width: 18px; height: 12px; object-fit: cover; border-radius: 2px; margin-right: 4px; }
</style>
