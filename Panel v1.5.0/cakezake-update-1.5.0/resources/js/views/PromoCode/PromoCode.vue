<template>
  <div>
    <div class="list-page">
      <div class="page-head">
        <h3 class="page-head-title">{{ __('promo_code') }}</h3>
        <button
          class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
          @click="$router.push('/promo_code/create')"
          v-if="$can('promo_code_create')">
          <Plus :size="16" />
          <span>{{ __('add_promo_code') }}</span>
        </button>
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
            <AppSelect class="form-select list-select" v-model="validityFilter" :options="validityFilterOptions" :searchable="false" />
            <AppSelect class="form-select list-select" v-model="statusFilter" :options="statusFilterOptions" :searchable="false" />
            <AppSelect class="form-select list-select" v-model="channelFilter" :options="channelFilterOptions" :searchable="false" />
            <AppSelect class="form-select list-select" v-model="sourceFilter" :options="sourceFilterOptions" :searchable="false" @update:model-value="getPromoCode()" />
          </div>

          <div class="list-search">
            <Search class="list-search-icon" />
            <input
              id="filter-input"
              v-model="filter"
              type="search"
              class="form-control"
              :placeholder="__('search')">
          </div>

          <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getPromoCode()">
            <RefreshCw :class="{ 'is-spinning': isLoading }" />
          </button>
        </div>

        <div class="list-panel-body">
          <div class="card-grid">
            <EntityCardSkeleton v-if="isLoading" :count="perPage" />
            <div v-else-if="!filteredPromocode.length" class="card-grid-empty">
              <TicketPercent :size="34" />
              <span>{{ __('no_records_to_show') }}</span>
            </div>

            <div v-else v-for="p in pagedPromocode" :key="p.id" class="entity-card promo-card">
              <div class="entity-card-media is-contain">
                <img v-if="p.image_url" :src="p.image_url" :alt="p.promo_code" />
                <div v-else class="entity-card-ph"><TicketPercent :size="30" /></div>
                <span v-if="p.is_applicable === 1" class="status-pill is-active is-start">{{ __('applicable') || 'Applicable' }}</span>
                <span v-else class="status-pill is-inactive is-start">{{ __('not_applicable') || 'Not applicable' }}</span>
                <span class="status-pill" :class="p.status === 1 ? 'is-active' : 'is-inactive'">
                  {{ p.status === 1 ? __('active') : __('deactive') }}
                </span>
              </div>

              <div class="entity-card-body">
                <div class="promo-code-row">
                  <span class="promo-code">{{ p.promo_code }}</span>
                  <span class="promo-discount">{{ discountLabel(p) }}</span>
                </div>
                <h4 class="entity-card-title" v-if="p.title">{{ p.title }}</h4>

                <div class="d-flex flex-wrap gap-2 mb-1">
                  <span class="mode-chip">
                    <component :is="channelIcon(p)" :size="13" /> {{ channelLabel(p) }}
                  </span>
                  <span class="promo-apply-chip" :class="p.discount_apply_type === 'wallet' ? 'is-wallet' : 'is-instant'">
                    <component :is="p.discount_apply_type === 'wallet' ? 'Wallet' : 'Zap'" :size="13" /> {{ applyTypeLabel(p) }}
                  </span>
                </div>

                <div class="entity-card-meta">
                  <span class="entity-meta-row" v-if="Number(p.minimum_order_amount) > 0">
                    <ShoppingCart :size="14" /> {{ __('min_order') || 'Min order' }}: <b>{{ currencyOf(p) }}{{ p.minimum_order_amount }}</b>
                  </span>
                  <span class="entity-meta-row" v-if="Number(p.max_discount_amount) > 0">
                    <BadgePercent :size="14" /> {{ __('max_discount') || 'Max discount' }}: <b>{{ currencyOf(p) }}{{ p.max_discount_amount }}</b>
                  </span>
                  <span class="entity-meta-row" v-if="usageLabel(p)">
                    <Users :size="14" /> {{ usageLabel(p) }}
                  </span>
                  <!-- Actual redemptions to date, not the configured limit above. -->
                  <span class="entity-meta-row">
                    <TicketPercent :size="14" /> {{ __('total_redemptions') }}: <b>{{ num(p.used_count) }}</b>
                  </span>
                  <span class="entity-meta-row" v-if="Number(p.discount_given) > 0">
                    <Wallet :size="14" /> {{ __('discount_given') }}: <b>{{ currencyOf(p) }}{{ money(p.discount_given) }}</b>
                  </span>
                  <span class="entity-meta-row">
                    <CalendarDays :size="14" /> {{ validityLabel(p) }}
                  </span>
                  <span class="entity-meta-row" v-if="p.applicability && p.applicability !== 'all'">
                    <Tag :size="14" /> {{ __('applies_to') || 'Applies to' }}: <b class="text-capitalize">{{ p.applicability }}</b>
                  </span>
                  <span class="entity-meta-row" v-if="p.audience_type">
                    <UserCheck :size="14" /> {{ __('audience') || 'Audience' }}: <b>{{ audienceLabel(p) }}</b>
                  </span>
                  <span class="entity-meta-row" v-if="regionCount(p, 'country_ids') > 0">
                    <Globe :size="14" /> {{ __('restricted_to') || 'Restricted to' }}: <b>{{ regionCount(p, 'country_ids') }} {{ __('countries') }}</b>
                  </span>
                  <span class="entity-meta-row" v-if="regionCount(p, 'zone_ids') > 0">
                    <MapPin :size="14" /> {{ __('restricted_to') || 'Restricted to' }}: <b>{{ regionCount(p, 'zone_ids') }} {{ __('zones') }}</b>
                  </span>
                </div>

                <div class="entity-card-foot">
                  <div class="list-actions">
                    <button class="list-action-btn is-edit" @click="$router.push('/promo_code/edit/'+p.id)"
                      v-if="$can('promo_code_update')" v-b-tooltip.hover :title="__('edit')"><Pencil :size="15" /></button>
                    <button class="list-action-btn is-delete" @click="deletePromo(p.id)"
                      v-if="$can('promo_code_delete')" v-b-tooltip.hover :title="__('delete')"><Trash2 :size="15" /></button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="list-footer" v-if="filteredPromocode.length">
          <div class="list-perpage">
            <span>{{ __('per_page') }}</span>
            <b-form-select
              id="per-page-select"
              v-model="perPage"
              :options="pageOptions"
              size="sm"
              class="form-select"
            ></b-form-select>
            <span class="list-range">{{ __('total_records') }} : {{ filteredPromocode.length }}</span>
          </div>

          <b-pagination
            v-model="currentPage"
            :total-rows="filteredPromocode.length"
            :per-page="perPage"
            size="sm"
            class="mb-0 list-pagination"
          ></b-pagination>
        </div>
      </div>
    </div>

  </div>
</template>
<script>
import axios from "axios";
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';
import ListState from '../../mixins/ListState.js';
import {
  Search, RefreshCw, Plus, Pencil, Trash2, TicketPercent, ShoppingCart,
  BadgePercent, Users, CalendarDays, Tag, Zap, ShoppingBag, Layers, Wallet, UserCheck, Globe, MapPin,
} from 'lucide-vue-next';

export default {
  mixins: [CountryZoneFilter, ListState],
  // Come back from a promo code and land where you left, not on page 1.
  listState: ['currentPage', 'perPage', 'filter', 'statusFilter', 'sortBy', 'sortDesc'],
  components: {
    Search, RefreshCw, Plus, Pencil, Trash2, TicketPercent, ShoppingCart,
    BadgePercent, Users, CalendarDays, Tag, Zap, ShoppingBag, Layers, Wallet, UserCheck, Globe, MapPin,
  },
  data: function () {
    return {
      czShowZone: false, // promo list filters by country only (default country, no All)
      fields: [
        { key: "id", label: __("id"), sortable: true, headAttr: { width: '80px', textAlign: 'center' }, sortDirection: "desc" },
        { key: "promo_code", label: __('promo_code'), sortable: false, class: "text-center" },
        { key: "title", label: __('title'), sortable: false, class: "text-center" },
        { key: "discount", label: __('discount'), sortable: true, sortDirection: "desc", class: "text-center" },
        { key: "discount_type", label: __('discount_type'), sortable: false, class: "text-center" },
        { key: 'image', label: __('image'), sortable: false, class: 'text-center' },
        { key: "status", label: __('status'), sortable: true, sortDirection: "desc", class: "text-center" },
        { key: "validity", label: __('validity'), sortable: true, sortDirection: "desc", class: "text-center" },
        { key: "actions", label: __('actions'), sortable: false },
      ],
      totalRows: 1,
      currentPage: 1,
      perPage: 30,
      pageOptions: this.$pageOptions,
      sortBy: "",
      sortDesc: false,
      sortDirection: "asc",
      filter: null,
      statusFilter: '',
      validityFilter: '',
      channelFilter: '',
      sourceFilter: 'manual',
      filterOn: [],
      page: 1,

      promocode: [],
      isLoading: true,
      sectionStyle: "style_1",
      max_visible_promocode: 12,
      max_col_in_single_row: 12,
      // Language handling for translations
      currentLanguageId: null,
      activeLanguages: []
    };
  },
  computed: {
    // Status + validity filters + search, applied client-side.
    filteredPromocode() {
        let list = Array.isArray(this.promocode) ? this.promocode : [];
        if (this.statusFilter !== '') list = list.filter(p => String(p.status) === String(this.statusFilter));
        if (this.validityFilter !== '') list = list.filter(p => String(p.is_applicable) === String(this.validityFilter));
        if (this.channelFilter !== '') list = list.filter(p => (p.channel || 'both') === this.channelFilter);
        const q = (this.filter || '').toLowerCase().trim();
        if (q) {
            list = list.filter(p =>
                [p.promo_code, p.title, p.discount_type].some(v => String(v || '').toLowerCase().includes(q)));
        }
        return list;
    },
    // Card grid does its own paging (no MazerDatatable to slice for us).
    pagedPromocode() {
        const per = Number(this.perPage) || 12;
        const start = (this.currentPage - 1) * per;
        return this.filteredPromocode.slice(start, start + per);
    },
    sortOptions() {
      // Create an options list from our fields
      return this.fields
        .filter((f) => f.sortable)
        .map((f) => {
          return { text: f.label, value: f.key };
        });
    },
    // Fixed option set — no search box needed.
    validityFilterOptions() {
      return [
        { id: '', name: (__('all_validity') || 'All validity') },
        { id: '1', name: (__('applicable') || 'Applicable') },
        { id: '0', name: (__('not_applicable') || 'Not applicable') },
      ];
    },
    // Fixed option set — no search box needed.
    statusFilterOptions() {
      return [
        { id: '', name: (__('all_statuses') || 'All statuses') },
        { id: '1', name: (__('active')) },
        { id: '0', name: (__('deactive')) },
      ];
    },
    // Fixed option set — no search box needed.
    sourceFilterOptions() {
        return [
            { id: 'manual', name: __('manual_coupons') },
            { id: 'spin_wheel', name: __('spin_wheel_coupons') },
            { id: 'all', name: __('all_coupons') },
        ];
    },
    channelFilterOptions() {
      return [
        { id: '', name: (__('all_channels') || 'All channels') },
        { id: 'quick', name: (__('quick')) },
        { id: 'ecommerce', name: (__('ecommerce')) },
        { id: 'both', name: (__('both')) },
      ];
    },
  },
  mounted() {
    // Set the initial number of items
    this.totalRows = this.promocode.length;
  },
    watch: {
        filter() {
            this.getPromoCode();
        }
    },
  created: function () {
    this.$eventBus.on("PromoCodeSaved", (message) => {
      this.showMessage("success", message);
      this.getPromoCode();
    });
    // Load languages first so we know currentLanguageId before mapping translations.
    this.fetchActiveLanguages().catch(() => {});
    this.czLoad(); // sets default country then getPromoCode via czOnFilter
  },
  methods: {
    // Locale-formatted integer / 2dp amount for the usage stats on a card.
    num(v) { return Number(v || 0).toLocaleString(); },
    money(v) { return Number(v || 0).toFixed(2); },
    czOnFilter() { this.getPromoCode(); },
    // Fetch active languages and set current language ID
    fetchActiveLanguages() {
      return axios.get(this.$apiUrl + '/active_languages')
        .then(response => {
          if (response.data.data && Array.isArray(response.data.data)) {
            this.activeLanguages = response.data.data;
            
            const appLocale = window.appLocale || 'en';
            
            const currentLanguage = this.activeLanguages.find(
              lang => lang.code === appLocale
            );
            
            if (currentLanguage) {
              this.currentLanguageId = currentLanguage.id;
            } else {
              const defaultLanguage = this.activeLanguages.find(
                lang => lang.is_default === 1
              );
              if (defaultLanguage) {
                this.currentLanguageId = defaultLanguage.id;
              }
            }
          }
        })
        .catch(error => {
          console.error('Error loading languages:', error);
        });
    },
    // Get translated message with fallback logic
    getTranslatedMessage(promoCode) {
      // If no language is set yet, return the base message
      if (!this.currentLanguageId || !this.activeLanguages.length) {
        return promoCode.message || '';
      }

      // Get default language ID for fallback
      const defaultLanguage = this.activeLanguages.find(lang => lang.is_default === 1);
      const defaultLanguageId = defaultLanguage ? defaultLanguage.id : null;

      // Check if translations array exists
      if (promoCode.translations && Array.isArray(promoCode.translations) && promoCode.translations.length > 0) {
        // First try to find translation for current language
        let translation = promoCode.translations.find(
          t => t.language_id === this.currentLanguageId
        );

        // If not found, try default language
        if (!translation && defaultLanguageId) {
          translation = promoCode.translations.find(
            t => t.language_id === defaultLanguageId
          );
        }

        // Use translation message if available and not empty
        if (translation && translation.message && translation.message.trim() !== '') {
          return translation.message;
        }
      }

      // Fallback to base message
      return promoCode.message || '';
    },
    getPromoCode() {
      this.isLoading = true;
      const countryId = this.czCountryParam || '';
      axios.get(this.$apiUrl + "/promo_code?search=" + (this.filter || "") + "&country_id=" + countryId
        + "&source=" + (this.sourceFilter || 'manual')).then((response) => {
        this.isLoading = false;
        let data = response.data;
        // Ensure promo codes have proper structure with translations
        this.promocode = (data.data || []).map(code => {
          // Ensure translations array exists
          if (!code.translations) {
            code.translations = [];
          }
          return code;
        });
        this.totalRows = this.promocode.length;
      });
    },

    deleteSlider(index, id) {
      this.$swal
        .fire({
          title: __('are_you_sure'),
          text: __('you_want_be_able_to_revert_this'),
          confirmButtonText: __('yes_sure'),
          cancelButtonText: __('cancel'),
          icon: "warning",
          showCancelButton: true,
          confirmButtonColor: window.adminThemeColor || "#435ebe",
          cancelButtonColor: "#d33",
        })
        .then((result) => {
          if (result.value) {
            this.isLoading = true;
            let postData = {
              id: id,
            };
            axios
              .post(this.$apiUrl + "/promo_code/delete", postData)
              .then((response) => {
                this.isLoading = false;
                let data = response.data;
                this.promocode.splice(index, 1);
                //this.showSuccess(data.message);
                  this.showMessage("success", data.message);
              });
          }
        });
    },
    // Card-grid delete: refetch afterwards (no local index to splice).
    deletePromo(id) {
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
        if (!result.value) return;
        this.isLoading = true;
        axios.post(this.$apiUrl + '/promo_code/delete', { id }).then(response => {
          this.showMessage('success', response.data.message);
          this.getPromoCode();
        }).catch(() => { this.isLoading = false; });
      });
    },
    currencyOf() {
      // Header-selected country's currency, falling back to the global default.
      return this.czCurrency || this.$currency || '';
    },
    channelLabel(p) {
      if (p.channel === 'quick') return __('quick') || 'Quick';
      if (p.channel === 'ecommerce') return __('ecommerce') || 'eCommerce';
      return __('both') || 'Both';
    },
    channelIcon(p) {
      if (p.channel === 'quick') return 'Zap';
      if (p.channel === 'ecommerce') return 'ShoppingBag';
      return 'Layers';
    },
    applyTypeLabel(p) {
      return p.discount_apply_type === 'wallet'
        ? (__('wallet_cashback') || 'Wallet cashback')
        : (__('instant_discount') || 'Instant discount');
    },
    audienceLabel(p) {
      if (p.audience_type === 'new') return __('new_customers') || 'New customers';
      if (p.audience_type === 'specific') return __('specific_customers') || 'Specific customers';
      return __('all_customers') || 'All customers';
    },
    // country_ids / zone_ids may arrive as an array or a JSON string; empty = no restriction.
    regionCount(p, key) {
      let v = p[key];
      if (typeof v === 'string') { try { v = JSON.parse(v); } catch (e) { v = []; } }
      return Array.isArray(v) ? v.length : 0;
    },
    discountLabel(p) {
      if (p.discount_type === 'free_delivery') return __('free_delivery');
      if (p.discount_type === 'percentage') return p.discount + '% ' + (__('off') || 'OFF');
      return this.currencyOf(p) + p.discount + ' ' + (__('off') || 'OFF');
    },
    usageLabel(p) {
      const parts = [];
      if (Number(p.total_usage_limit) > 0) parts.push(p.total_usage_limit + ' ' + (__('total') || 'total'));
      if (Number(p.per_user_usage_limit) > 0) parts.push(p.per_user_usage_limit + '/' + (__('customer') || 'customer'));
      return parts.length ? (__('usage') || 'Usage') + ': ' + parts.join(' · ') : '';
    },
    validityLabel(p) {
      if (p.is_permanent === 1 || (!p.start_date && !p.end_date)) return __('permanent') || 'Permanent';
      const fmt = (d) => d ? (this.$filters && this.$filters.formatDate ? this.$filters.formatDate(d) : String(d).slice(0, 10)) : '—';
      return fmt(p.start_date) + ' → ' + fmt(p.end_date);
    },
  },
  beforeUnmount() {
      this.$eventBus.off('PromoCodeSaved');
  }
};
</script>

<style scoped>
.promo-code-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: .5rem;
  margin-bottom: .15rem;
}
.promo-code {
  font-family: SFMono-Regular, Menlo, Consolas, monospace;
  font-weight: 700;
  font-size: .95rem;
  letter-spacing: .5px;
  color: var(--app-ink, #25396f);
  background: rgba(var(--bs-primary-rgb), .08);
  border: 1px dashed rgba(var(--bs-primary-rgb), .35);
  padding: 2px 8px;
  border-radius: 6px;
  word-break: break-all;
}

@media (max-width: 575.98px) {
  .promo-code-row { flex-direction: column; align-items: flex-start; gap: .3rem; }
  .promo-code { max-width: 100%; font-size: .82rem; word-break: normal; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .promo-discount { font-size: .72rem; padding: 2px 8px; }
}
.promo-discount {
  flex-shrink: 0;
  font-weight: 700;
  font-size: .8rem;
  color: #fff;
  background: var(--bs-primary);
  padding: 3px 10px;
  border-radius: 999px;
  white-space: nowrap;
}
.promo-card .entity-meta-row b {
  color: var(--app-ink, #25396f);
}
.promo-apply-chip {
  display: inline-flex;
  align-items: center;
  gap: .35rem;
  font-size: .72rem;
  font-weight: 600;
  padding: 3px 9px;
  border-radius: 999px;
}
.promo-apply-chip.is-instant { background: rgba(var(--bs-primary-rgb), .1); color: var(--bs-primary); }
.promo-apply-chip.is-wallet { background: rgba(139, 92, 246, .12); color: #7c3aed; }
</style>
