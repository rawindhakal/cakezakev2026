<template>
  <div class="promo-form-page">
    <!-- Header: title + back button outside the cards. -->
    <div class="page-head">
      <div>
        <h3 class="page-head-title mb-0">{{ id ? __('edit_coupon') : __('create_new_coupon') }}</h3>
        <p class="text-muted small mb-0 mt-1">{{ __('fill_in_all_sections_to_configure_your_coupon') }}</p>
      </div>
      <button type="button"
        class="btn btn-outline-secondary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
        @click="goBack">
        <ArrowLeft :size="16" /> {{ __('back') }}
      </button>
    </div>

    <div v-if="isLoadingRecord" class="text-center p-5"><b-spinner></b-spinner></div>

    <form v-else ref="my-form" @submit.prevent="saveRecord">
      <div class="row">
        <!-- Sticky section nav -->
        <div class="col-md-3 col-lg-2">
          <div class="card sticky-nav bg-white">
            <div class="list-group list-group-flush">
              <small class="text-muted px-3 pt-2 pb-1 text-uppercase">{{ __('sections') }}</small>
              <a v-for="s in sections" :key="s.id" href="javascript:void(0)"
                class="list-group-item list-group-item-action border-0 py-2 promo-nav-item"
                :class="{ active: activeSection === s.id }"
                @click="scrollTo(s.id)">{{ s.label }}</a>
            </div>
          </div>
        </div>

        <!-- Form body -->
        <div class="col-md-9 col-lg-10">

          <!-- 1. Basic Information -->
          <div :id="secId('basic')" class="card mb-3">
            <div class="card-header py-2"><h6 class="mb-0 fw-bold text-dark">{{ __('basic_information') }}</h6></div>
            <div class="card-body">
              <div class="row">
                <div class="form-group col-md-6">
                  <label>{{ __('promo_code') }}<i class="text-danger">*</i></label>
                  <input type="text" class="form-control text-uppercase" v-model="promo_code" :placeholder="__('promo_code')" />
                  <small class="text-muted">{{ __('will_be_auto_uppercased') }}</small>
                </div>

                <!-- Translatable title + description. Manual nav-tabs + v-show so
                     the default-language fields are always visible on load. -->
                <div class="col-md-12 mt-2" v-if="languages.length > 0">
                  <ul class="nav nav-tabs mb-2 align-items-center" v-if="languages.length > 1">
                    <li class="nav-item" v-for="(language, idx) in languages" :key="'tab-' + language.id">
                      <a class="nav-link" href="javascript:void(0)"
                        :class="{ active: activeLanguageTab === idx }"
                        @click="activeLanguageTab = idx">
                        <span :class="{ 'text-primary fw-bold': language.is_default }">{{ language.name }}</span>
                      </a>
                    </li>
                    <!-- Translate control, inline with the language tabs. -->
                    <li class="nav-item ms-auto d-flex align-items-center">
                      <TranslateLanguages :languages="languages" :default-language-id="defaultLanguageId"
                        :busy="translating" :progress="translateProgress" @translate="runTranslate" />
                    </li>
                  </ul>

                  <template v-for="(language, idx) in languages" :key="'pane-' + language.id">
                    <div v-show="activeLanguageTab === idx">
                      <div class="row mt-2">
                        <div class="form-group col-md-6">
                          <label>{{ __('title') }}<i class="text-danger" v-if="language.is_default">*</i></label>
                          <input type="text" class="form-control" v-model="translations[language.id].title"
                            :placeholder="__('title')" />
                        </div>
                        <div class="form-group col-md-6">
                          <label>{{ __('description') }}</label>
                          <textarea class="form-control" rows="2" v-model="translations[language.id].description"
                            :placeholder="__('description')"></textarea>
                        </div>
                      </div>
                    </div>
                  </template>
                </div>

                <div class="col-md-6 mt-2">
                  <FileUpload v-model="image" :label="__('banner_image')" accept="image/*"
                    recommended-size="600x400px" :max-size-mb="2" :preview-url="image_url" />
                </div>

                <div class="form-group col-md-6 mt-2">
                  <label>{{ __('status') }}</label>
                  <div class="text-left mt-1">
                    <div class="btn-group btn-group-toggle" role="group">
                      <label class="btn btn-outline-primary" :class="{ active: status == 0 }">
                        <input type="radio" :value="0" v-model.number="status" autocomplete="off"> {{ __('deactivate') }}
                      </label>
                      <label class="btn btn-outline-primary" :class="{ active: status == 1 }">
                        <input type="radio" :value="1" v-model.number="status" autocomplete="off"> {{ __('activate') }}
                      </label>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- 2. Discount -->
          <div :id="secId('discount')" class="card mb-3">
            <div class="card-header py-2"><h6 class="mb-0 fw-bold text-dark">{{ __('discount') }}</h6></div>
            <div class="card-body"><div class="row">
              <div class="form-group col-md-6">
                <label>{{ __('discount_type') }}<i class="text-danger">*</i></label>
                <AppSelect class="form-control form-select" v-model="discount_type" :options="discount_typeOptions" :searchable="false" />
              </div>
              <div class="form-group col-md-6" v-if="discount_type !== 'free_delivery'">
                <label>{{ discount_type === 'percentage' ? __('discount_percentage') : __('discount_amount') }}<i class="text-danger">*</i></label>
                <input type="number" min="1" :max="discount_type === 'percentage' ? 100 : undefined" step="0.01" class="form-control" v-model="discount"
                  :class="{ 'is-invalid': submitted && validation.discount }" />
                <small v-if="submitted && validation.discount" class="text-danger d-block">{{ validation.discount }}</small>
              </div>
              <div class="form-group col-md-6" v-if="discount_type === 'percentage'">
                <label>{{ __('max_discount_amount') }}</label>
                <input type="number" min="0" step="0.01" class="form-control" v-model="max_discount_amount" :placeholder="__('set_0_if_you_want_ro_remove_limit')" />
              </div>
              <div class="form-group col-md-6" v-if="discount_type !== 'free_delivery'">
                <label>{{ __('discount_apply_type') }}</label>
                <AppSelect class="form-control form-select" v-model="discount_apply_type" :options="discount_apply_typeOptions" :searchable="false" />
              </div>
            </div></div>
          </div>

          <!-- 3. Applicability -->
          <div :id="secId('applicability')" class="card mb-3">
            <div class="card-header py-2"><h6 class="mb-0 fw-bold text-dark">{{ __('applicability') }}</h6></div>
            <div class="card-body"><div class="row">
              <div class="form-group col-md-6">
                <label>{{ __('apply_to') }}</label>
                <AppSelect class="form-control form-select" v-model="applicability" :options="applicabilityOptions" :searchable="false" @update:model-value="applicability_ids = []" />
              </div>
              <div class="form-group col-md-6" v-if="applicability === 'categories'">
                <label>{{ __('select_categories') }}</label>
                <AppSelect class="form-control form-select" multiple v-model="applicability_ids" :options="categories" :placeholder="__('select_categories')" />
              </div>
              <div class="form-group col-md-6" v-if="applicability === 'products'">
                <label>{{ __('select_products') }}</label>
                <AppSelect class="form-control form-select" multiple v-model="applicability_ids" :options="products" :placeholder="__('select_products')" />
              </div>
              <div class="form-group col-md-6" v-if="applicability === 'brands'">
                <label>{{ __('select_brands') }}</label>
                <AppSelect class="form-control form-select" multiple v-model="applicability_ids" :options="brands" :placeholder="__('select_brands')" />
              </div>
            </div></div>
          </div>

          <!-- 4. Cart Conditions -->
          <div :id="secId('cart')" class="card mb-3">
            <div class="card-header py-2"><h6 class="mb-0 fw-bold text-dark">{{ __('cart_conditions') }}</h6></div>
            <div class="card-body"><div class="row">
              <div class="form-group col-md-6">
                <label>{{ __('minimum_order_amount') }}</label>
                <input type="number" min="0" step="0.01" class="form-control" v-model="minimum_order_amount" placeholder="0"
                  :class="{ 'is-invalid': submitted && validation.minimum_order_amount }" />
                <small v-if="submitted && validation.minimum_order_amount" class="text-danger d-block">{{ validation.minimum_order_amount }}</small>
              </div>
              <div class="form-group col-md-6">
                <label>{{ __('min_product_quantity') }}</label>
                <input type="number" min="0" step="1" class="form-control" v-model="min_product_quantity" placeholder="0" />
              </div>
            </div></div>
          </div>

          <!-- 5. Usage Limits -->
          <div :id="secId('usage')" class="card mb-3">
            <div class="card-header py-2"><h6 class="mb-0 fw-bold text-dark">{{ __('usage_restrictions') }}</h6></div>
            <div class="card-body"><div class="row">
              <div class="form-group col-md-6">
                <label>{{ __('total_usage_limit') }}</label>
                <input type="number" min="0" step="1" class="form-control" v-model="total_usage_limit" :placeholder="__('set_0_if_you_want_ro_remove_limit')" />
              </div>
              <div class="form-group col-md-6">
                <label>{{ __('per_user_usage_limit') }}</label>
                <input type="number" min="0" step="1" class="form-control" v-model="per_user_usage_limit" :placeholder="__('set_0_if_you_want_ro_remove_limit')" />
              </div>
            </div></div>
          </div>

          <!-- 6. Schedule -->
          <div :id="secId('schedule')" class="card mb-3">
            <div class="card-header py-2"><h6 class="mb-0 fw-bold text-dark">{{ __('scheduling') }}</h6></div>
            <div class="card-body"><div class="row">
              <div class="form-group col-md-12">
                <label class="d-block mb-1" for="is_permanent">{{ __('permanent_promotion') }}</label>
                <div class="form-check form-switch ps-0">
                  <input class="form-check-input ms-0" type="checkbox" role="switch" id="is_permanent" v-model="is_permanent" />
                </div>
              </div>
              <div class="form-group col-md-6" v-if="!is_permanent">
                <label>{{ __('start_date') }}</label>
                <input type="date" class="form-control" v-model="start_date" />
              </div>
              <div class="form-group col-md-6" v-if="!is_permanent">
                <label>{{ __('end_date') }}</label>
                <input type="date" class="form-control" v-model="end_date" />
              </div>
              <div class="form-group col-md-12 mt-2">
                <label class="d-block mb-1" for="full_day_promotion">{{ __('full_day_promotion') }}</label>
                <div class="form-check form-switch ps-0">
                  <input class="form-check-input ms-0" type="checkbox" role="switch" id="full_day_promotion" v-model="full_day_promotion" />
                </div>
              </div>
              <div class="form-group col-md-6" v-if="!full_day_promotion">
                <label>{{ __('start_time') }}</label>
                <TimePicker v-model="start_time" />
              </div>
              <div class="form-group col-md-6" v-if="!full_day_promotion">
                <label>{{ __('end_time') }}</label>
                <TimePicker v-model="end_time" />
              </div>
              <div class="form-group col-md-12 mt-2">
                <label>{{ __('weekday_recurrence') }}</label>
                <div class="d-flex flex-wrap">
                  <button type="button" v-for="d in weekdays" :key="d.value" class="btn btn-sm m-1"
                    :class="weekday_recurrence.includes(d.value) ? 'btn-primary' : 'btn-outline-secondary'"
                    @click="toggleWeekday(d.value)">{{ d.label }}</button>
                </div>
              </div>
            </div></div>
          </div>

          <!-- 7. Audience -->
          <div :id="secId('audience')" class="card mb-3">
            <div class="card-header py-2"><h6 class="mb-0 fw-bold text-dark">{{ __('audience_targeting') }}</h6></div>
            <div class="card-body"><div class="row">
              <div class="form-group col-md-6">
                <label>{{ __('target_audience') }}</label>
                <AppSelect class="form-control form-select" v-model="audience_type" :options="audience_typeOptions" :searchable="false" @update:model-value="audience_ids = []" />
              </div>
              <div class="form-group col-md-6" v-if="audience_type === 'specific'">
                <label>{{ __('select_users') }}</label>
                <AppSelect class="form-control form-select" multiple v-model="audience_ids" :options="users" :placeholder="__('select_users')" />
              </div>
            </div></div>
          </div>

          <!-- 8. Platform & Visibility -->
          <div :id="secId('platform')" class="card mb-3">
            <div class="card-header py-2"><h6 class="mb-0 fw-bold text-dark">{{ __('platform_and_visibility') }}</h6></div>
            <div class="card-body"><div class="row">
              <div class="form-group col-md-6">
                <label>{{ __('visibility') }}</label>
                <AppSelect class="form-control form-select" v-model="visibility" :options="visibilityOptions" :searchable="false" />
              </div>
              <div class="form-group col-md-6">
                <label>{{ __('platform') }}</label>
                <AppSelect class="form-control form-select" v-model="platform" :options="platformOptions" :searchable="false" />
              </div>
            </div></div>
          </div>

          <!-- 9. Channel & Zone -->
          <div :id="secId('quick')" class="card mb-3">
            <div class="card-header py-2"><h6 class="mb-0 fw-bold text-dark">{{ __('channel_and_zone') }}</h6></div>
            <div class="card-body"><div class="row">
              <div class="form-group col-md-6">
                <label>{{ __('sales_channel') }}</label>
                <AppSelect class="form-control form-select" v-model="channel" :options="channelOptions" :searchable="false" @update:model-value="onChannelChange" />
                <small class="text-muted">{{ __('channel_determines_where_coupon_applies') }}</small>
              </div>
              <div class="w-100"></div>
              <div class="form-group col-md-6">
                <div class="d-flex justify-content-between align-items-center">
                  <label class="mb-0">{{ __('country_restriction') }} <i class="text-danger">*</i></label>
                </div>
                <AppSelect class="form-control form-select" multiple v-model="country_ids" :options="countries" :placeholder="__('select_countries')" :disabled="isBranchUser" @update:modelValue="onCountryChange" />
                <small class="text-muted">{{ __('coupon_country_required_hint') }}</small>
              </div>
              <div class="form-group col-md-6">
                <div class="d-flex justify-content-between align-items-center">
                  <label class="mb-0">{{ __('zone_restriction') }}</label>
                  <span v-if="!isBranchUser">
                    <a href="javascript:void(0)" class="small me-2" @click="selectAllZones">{{ __('select_all') }}</a>
                    <a href="javascript:void(0)" class="small text-danger" @click="zone_ids = []">{{ __('clear') }}</a>
                  </span>
                </div>
                <AppSelect class="form-control form-select" multiple v-model="zone_ids" :options="filteredZones" :placeholder="__('select_zones')" :disabled="isBranchUser" />
                <small class="text-muted">{{ isBranchUser ? __('locked_to_your_branch_zone') : __('coupon_zone_optional_hint') }}</small>
              </div>
            </div></div>
          </div>

          <!-- Submit -->
          <div class="d-flex justify-content-end gap-2 pb-5">
            <button type="button" class="btn btn-secondary" @click="goBack">{{ __('cancel') }}</button>
            <button type="submit" class="btn btn-primary" :disabled="isLoading">
              {{ id ? __('update_coupon') : __('create_coupon') }}
              <b-spinner v-if="isLoading" small></b-spinner>
            </button>
          </div>
        </div>
      </div>
    </form>
  </div>
</template>

<script>
import axios from "axios";
import TranslationHelper from '../../mixins/TranslationHelper.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';
import { ArrowLeft } from 'lucide-vue-next';
import TimePicker from '../../components/TimePicker.vue';

export default {
  mixins: [TranslationHelper, UnsavedChanges],
  components: { ArrowLeft, TimePicker },
  data() {
    return {
      id: this.$route.params.id || '',
      isLoading: false,
      isLoadingRecord: false,
      // Inline errors stay hidden until the first save attempt.
      submitted: false,
      activeSection: 'basic',
      sections: [
        { id: 'basic', label: '1. ' + __('basic_info') },
        { id: 'discount', label: '2. ' + __('discount') },
        { id: 'applicability', label: '3. ' + __('applicability') },
        { id: 'cart', label: '4. ' + __('cart_conditions') },
        { id: 'usage', label: '5. ' + __('usage_restrictions') },
        { id: 'schedule', label: '6. ' + __('scheduling') },
        { id: 'audience', label: '7. ' + __('audience_targeting') },
        { id: 'platform', label: '8. ' + __('platform_and_visibility') },
        { id: 'quick', label: '9. ' + __('channel_and_zone') },
      ],
      // fields
      promo_code: '',
      discount_type: 'percentage', discount: '', discount_apply_type: 'instant', max_discount_amount: 0,
      applicability: 'all', applicability_ids: [],
      minimum_order_amount: 0, min_product_quantity: 0,
      total_usage_limit: 0, per_user_usage_limit: 0,
      is_permanent: false, start_date: '', end_date: '',
      full_day_promotion: true, start_time: '', end_time: '', weekday_recurrence: [0, 1, 2, 3, 4, 5, 6],
      audience_type: 'all', audience_ids: [],
      visibility: 'public', platform: 'all',
      channel: 'both', country_ids: [], zone_ids: [],
      status: 1, image: null, image_url: '',
      // dropdown lists
      categories: [], products: [], brands: [], zones: [], users: [], countries: [],
      weekdays: [
        { label: __('sun'), value: 0 }, { label: __('mon'), value: 1 }, { label: __('tue'), value: 2 },
        { label: __('wed'), value: 3 }, { label: __('thu'), value: 4 }, { label: __('fri'), value: 5 }, { label: __('sat'), value: 6 },
      ],
      // languages / translations
      activeLanguageTab: 0, translations: {}, defaultLanguageId: null, languages: [],
      translatableFields: ['title', 'description'],
    };
  },
  computed: {
    // Zones offered match the selected channel AND the selected countries.
    // 'both' channel → all channels; no country selected → all countries.
    // Branch users are locked to their own branch's zone (server-enforced too).
    isBranchUser() {
      return typeof this.$isBranchUser === 'function' && this.$isBranchUser();
    },
    branchZoneId() {
      return window.BranchZoneId ? Number(window.BranchZoneId) : null;
    },
    branchCountryId() {
      return window.BranchCountryId ? Number(window.BranchCountryId) : null;
    },
    filteredZones() {
      const cids = (this.country_ids || []).map(Number);
      return this.zones.filter(z => {
        // A 'both' zone serves either channel, so it qualifies for any promo channel.
            const channelOk = this.channel === 'both' || !z.sales_channel
                || z.sales_channel === this.channel || z.sales_channel === 'both';
        const countryOk = cids.length === 0 || cids.includes(Number(z.country_id));
        return channelOk && countryOk;
      });
    },
    // Amount-related inline validations, keyed by field name. Empty object means
    // valid. Title / promo code are handled by their required attribute and the
    // API, so they are intentionally not here.
    validation() {
      const e = {};
      if (this.discount_type !== 'free_delivery') {
        const d = Number(this.discount);
        if (this.discount === '' || this.discount === null || this.discount === undefined || isNaN(d)) {
          e.discount = __('this_field_is_required');
        } else if (d < 1) {
          e.discount = __('amount_must_be_at_least_1');
        } else if (this.discount_type === 'percentage' && d > 100) {
          e.discount = __('percentage_cannot_be_greater_than_100');
        }
      }
      // A flat discount larger than the required minimum order lets the cart go
      // negative — the minimum must at least cover the discount.
      if (this.discount_type === 'flat' && Number(this.minimum_order_amount) > 0
        && Number(this.minimum_order_amount) < Number(this.discount)) {
        e.minimum_order_amount = __('minimum_order_amount_must_be_at_least_the_discount');
      }
      return e;
    },
        // Fixed option set — no search box needed.
        discount_typeOptions() {
            return [
                { id: 'percentage', name: (__('percentage')) },
                { id: 'flat', name: (__('flat')) },
                { id: 'free_delivery', name: (__('free_delivery')) },
            ];
        },
        // Fixed option set — no search box needed.
        discount_apply_typeOptions() {
            return [
                { id: 'instant', name: (__('instant_discount')) },
                { id: 'wallet', name: (__('wallet_cashback')) },
            ];
        },
        // Fixed option set — no search box needed.
        applicabilityOptions() {
            return [
                { id: 'all', name: (__('all_products')) },
                { id: 'categories', name: (__('specific_categories')) },
                { id: 'products', name: (__('specific_products')) },
                { id: 'brands', name: (__('specific_brands')) },
            ];
        },
        // Fixed option set — no search box needed.
        audience_typeOptions() {
            return [
                { id: 'all', name: (__('all_users')) },
                { id: 'new', name: (__('new_users_only')) },
                { id: 'specific', name: (__('specific_users')) },
            ];
        },
        // Fixed option set — no search box needed.
        visibilityOptions() {
            return [
                { id: 'public', name: (__('public')) },
                { id: 'hidden', name: (__('hidden')) },
            ];
        },
        // Fixed option set — no search box needed.
        platformOptions() {
            return [
                { id: 'all', name: (__('all')) },
                { id: 'app', name: (__('app')) },
                { id: 'web', name: (__('web')) },
            ];
        },
        // Fixed option set — no search box needed.
        channelOptions() {
            return [
                { id: 'both', name: (__('both')) },
                { id: 'quick', name: (__('quick')) },
                { id: 'ecommerce', name: (__('ecommerce')) },
            ];
        },
  },
  methods: {
    // Tracked state for the UnsavedChanges guard.
    formState() {
      return {
        promo_code: this.promo_code,
        discount_type: this.discount_type,
        discount: this.discount,
        discount_apply_type: this.discount_apply_type,
        max_discount_amount: this.max_discount_amount,
        applicability: this.applicability,
        applicability_ids: this.applicability_ids,
        minimum_order_amount: this.minimum_order_amount,
        min_product_quantity: this.min_product_quantity,
        total_usage_limit: this.total_usage_limit,
        per_user_usage_limit: this.per_user_usage_limit,
        is_permanent: this.is_permanent,
        start_date: this.start_date,
        end_date: this.end_date,
        full_day_promotion: this.full_day_promotion,
        start_time: this.start_time,
        end_time: this.end_time,
        weekday_recurrence: this.weekday_recurrence,
        audience_type: this.audience_type,
        audience_ids: this.audience_ids,
        visibility: this.visibility,
        platform: this.platform,
        channel: this.channel,
        country_ids: this.country_ids,
        zone_ids: this.zone_ids,
        status: this.status,
        image: this.image,
        translations: this.translations,
      };
    },
    // Drop selected zones that no longer belong to the chosen channel/countries.
    onChannelChange() {
      const allowed = new Set(this.filteredZones.map(z => z.id));
      this.zone_ids = (this.zone_ids || []).filter(id => allowed.has(id));
    },
    // Countries changed → prune zones outside the selected countries.
    onCountryChange() {
      const allowed = new Set(this.filteredZones.map(z => z.id));
      this.zone_ids = (this.zone_ids || []).filter(id => allowed.has(id));
    },

    applyDefaultCountry() {
      if (this.isBranchUser || (this.country_ids || []).length || !this.countries.length) return;
      const preferred = this.countries.find(c => Number(c.is_default) === 1) || this.countries[0];
      if (preferred) this.country_ids = [preferred.id];
    },
    // Select every zone available for the current channel + countries.
    selectAllZones() {
      this.zone_ids = this.filteredZones.map(z => z.id);
    },
    // A branch user's promo is always scoped to its own branch's zone.
    applyBranchLock() {
      if (!this.isBranchUser) return;
      if (this.branchCountryId) this.country_ids = [this.branchCountryId];
      if (this.branchZoneId) this.zone_ids = [this.branchZoneId];
    },
    secId(id) { return 'coupon-section-' + id; },
    goBack() { this.$router.push({ path: '/promo_code' }); },
    scrollTo(id) {
      this.activeSection = id;
      const el = document.getElementById(this.secId(id));
      if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    },
    onScroll() {
      let current = this.sections[0].id;
      for (const s of this.sections) {
        const el = document.getElementById(this.secId(s.id));
        if (el && el.getBoundingClientRect().top <= 140) current = s.id;
      }
      this.activeSection = current;
    },
    toggleWeekday(v) {
      const i = this.weekday_recurrence.indexOf(v);
      if (i === -1) this.weekday_recurrence.push(v); else this.weekday_recurrence.splice(i, 1);
    },
    normalizeList(res) {
      const body = res && res.data ? res.data : {};
      // Unwrap the standard envelope: { status, data: ... }
      const payload = body.data !== undefined ? body.data : body;
      let arr;
      if (Array.isArray(payload)) {
        arr = payload;
      } else if (payload && typeof payload === 'object') {
        // Wrapped under a named key, e.g. { total, branches: [...] } / { total, zones: [...] }
        arr = payload.rows || payload.result || payload.branches || payload.zones || payload.customers
          || Object.values(payload).find(v => Array.isArray(v)) || [];
      } else {
        arr = [];
      }
      return (arr || []).map(i => ({ id: i.id, name: i.name || i.title || i.full_name || i.promo_code || ('#' + i.id), sales_channel: i.sales_channel, country_id: i.country_id, is_default: i.is_default }));
    },
    loadDropdownData() {
      const get = (url) => axios.get(this.$apiUrl + url).catch(() => ({ data: { data: [] } }));
      Promise.all([
        get('/categories/active'), get('/products/active'), get('/products/brands/get'),
        get('/zones'), get('/customers'), get('/countries/active'),
      ]).then(([c, p, b, z, u, co]) => {
        this.categories = this.normalizeList(c); this.products = this.normalizeList(p); this.brands = this.normalizeList(b);
        this.zones = this.normalizeList(z); this.users = this.normalizeList(u); this.countries = this.normalizeList(co);
        this.applyDefaultCountry();
      });
    },
    fetchActiveLanguages() {
      return axios.get(this.$apiUrl + '/active_languages').then(response => {
        if (response.data.data) {
          this.languages = response.data.data;
          const def = this.languages.find(l => l.is_default === 1);
          if (def) this.defaultLanguageId = def.id;
          // Open the default language's tab by default so its title/description
          // fields are visible without clicking.
          const defIdx = this.languages.findIndex(l => l.is_default === 1);
          this.activeLanguageTab = defIdx >= 0 ? defIdx : 0;
          const all = {};
          this.languages.forEach(l => { all[l.id] = { title: '', description: '' }; });
          this.translations = all;
        }
      }).catch(e => console.error('languages', e));
    },
    loadRecord() {
      if (!this.id) return Promise.resolve();
      this.isLoadingRecord = true;
      return axios.get(this.$apiUrl + '/promo_code/edit/' + this.id).then(res => {
        const rec = res.data.data || {};
        const b = (v, d) => (v === undefined || v === null ? d : !!Number(v));
        this.promo_code = rec.promo_code || '';
        this.discount_type = rec.discount_type || 'percentage';
        this.discount = rec.discount || '';
        this.discount_apply_type = rec.discount_apply_type || 'instant';
        this.max_discount_amount = rec.max_discount_amount || 0;
        // Legacy per-branch applicability is dropped; zone restriction now covers branch scope (1 zone = 1
        // branch). Old rows still carry the pre-rename value 'store', so both spellings fall back to 'all'.
        this.applicability = (rec.applicability && !['store', 'branch'].includes(rec.applicability)) ? rec.applicability : 'all';
        this.applicability_ids = rec.applicability_ids || [];
        this.minimum_order_amount = rec.minimum_order_amount || 0;
        this.min_product_quantity = rec.min_product_quantity || 0;
        this.total_usage_limit = rec.total_usage_limit || 0;
        this.per_user_usage_limit = rec.per_user_usage_limit || 0;
        this.is_permanent = b(rec.is_permanent, false);
        this.start_date = rec.start_date || '';
        this.end_date = rec.end_date || '';
        this.full_day_promotion = b(rec.full_day_promotion, true);
        this.start_time = rec.start_time || '';
        this.end_time = rec.end_time || '';
        this.weekday_recurrence = rec.weekday_recurrence || [0, 1, 2, 3, 4, 5, 6];
        // Consolidated audience: legacy first_order_only / new_users_only → 'new';
        // legacy 'zone' audience is now driven by the Quick Commerce zone restriction (zone_ids).
        let aud = rec.audience_type || 'all';
        if (b(rec.first_order_only, false) || b(rec.new_users_only, false)) aud = 'new';
        else if (aud === 'zone') aud = 'all';
        this.audience_type = aud;
        this.audience_ids = rec.audience_ids || [];
        this.visibility = rec.visibility || 'public';
        this.platform = rec.platform || 'all';
        this.channel = ['quick', 'ecommerce', 'both'].includes(rec.channel) ? rec.channel : 'both';
        this.country_ids = (rec.country_ids || []).map(Number);
        this.zone_ids = rec.zone_ids || [];
        this.status = rec.status !== undefined ? Number(rec.status) : 1;
        this.image_url = rec.image_url || '';
        // translations
        if (Array.isArray(rec.translations)) {
          this.languages.forEach(l => {
            const t = rec.translations.find(t => t.language_id === l.id);
            if (t) {
              this.translations[l.id].title = t.title || '';
              this.translations[l.id].description = t.description || '';
            }
          });
        }
        if (this.defaultLanguageId) {
          if (!this.translations[this.defaultLanguageId].title && rec.title) {
            this.translations[this.defaultLanguageId].title = rec.title;
          }
          if (!this.translations[this.defaultLanguageId].description && rec.description) {
            this.translations[this.defaultLanguageId].description = rec.description;
          }
        }
        this.isLoadingRecord = false;
      }).catch(() => { this.isLoadingRecord = false; this.showError(__('something_went_wrong')); });
    },
    saveRecord() {
      // Reveal inline amount errors from this point on.
      this.submitted = true;
      const def = this.languages.find(l => l.is_default === 1);
      const defTitle = def && this.translations[def.id] ? (this.translations[def.id].title || '') : '';
      const defDesc = def && this.translations[def.id] ? (this.translations[def.id].description || '') : '';
      // Title / promo code use the required attribute + API validation.
      if (!defTitle.trim() || !this.promo_code || !this.promo_code.trim()) {
        this.showError(__('please_fill_default_language_required_fields'));
        this.scrollTo('basic');
        return;
      }
      // A coupon is an amount in one currency, so it must name its country.
      if (!this.isBranchUser && !(this.country_ids || []).length) {
        this.showError(__('please_select_at_least_one_country'));
        this.scrollTo('quick');
        return;
      }
      // Amount-related inline validations block the save.
      const errors = this.validation;
      if (Object.keys(errors).length > 0) {
        this.scrollTo(errors.discount ? 'discount' : 'cart');
        return;
      }
      let vm = this;
      this.isLoading = true;

      let fd = new FormData();
      if (this.id) fd.append('id', this.id);
      fd.append('title', defTitle);
      fd.append('promo_code', (this.promo_code || '').toUpperCase());
      fd.append('description', defDesc);
      fd.append('discount_type', this.discount_type);
      fd.append('discount', this.discount_type === 'free_delivery' ? 0 : (this.discount || 0));
      fd.append('discount_apply_type', this.discount_apply_type);
      fd.append('max_discount_amount', this.max_discount_amount || 0);
      fd.append('applicability', this.applicability);
      fd.append('applicability_ids', JSON.stringify(this.applicability_ids || []));
      fd.append('minimum_order_amount', this.minimum_order_amount || 0);
      fd.append('min_product_quantity', this.min_product_quantity || 0);
      fd.append('total_usage_limit', this.total_usage_limit || 0);
      fd.append('per_user_usage_limit', this.per_user_usage_limit || 0);
      fd.append('is_permanent', this.is_permanent ? 1 : 0);
      fd.append('start_date', this.is_permanent ? '' : (this.start_date || ''));
      fd.append('end_date', this.is_permanent ? '' : (this.end_date || ''));
      fd.append('full_day_promotion', this.full_day_promotion ? 1 : 0);
      fd.append('start_time', this.full_day_promotion ? '' : (this.start_time || ''));
      fd.append('end_time', this.full_day_promotion ? '' : (this.end_time || ''));
      fd.append('weekday_recurrence', JSON.stringify(this.weekday_recurrence || []));
      fd.append('audience_type', this.audience_type);
      fd.append('audience_ids', JSON.stringify(this.audience_ids || []));
      fd.append('visibility', this.visibility);
      fd.append('platform', this.platform);
      fd.append('channel', this.channel);
      fd.append('country_ids', JSON.stringify(this.country_ids || []));
      fd.append('zone_ids', JSON.stringify(this.zone_ids || []));
      fd.append('status', this.status);
      if (this.image && this.image.name) fd.append('image', this.image);
      const allT = this.languages.map(l => ({
        language_id: l.id,
        title: (this.translations[l.id] && this.translations[l.id].title) || '',
        description: (this.translations[l.id] && this.translations[l.id].description) || '',
      }));
      fd.append('translations', JSON.stringify(allT));

      const url = this.$apiUrl + (this.id ? '/promo_code/update' : '/promo_code/save');
      axios.post(url, fd, { headers: { 'Content-Type': 'multipart/form-data' } }).then(res => {
        if (res.data.status === 1) {
          vm.showMessage('success', res.data?.data?.message || res.data.message || __('promo_code_saved_successfully'));
          // Mark clean so the post-save redirect doesn't trip the guard.
          vm.captureFormBaseline();
          vm.$router.push({ path: '/promo_code' });
        } else {
          vm.showError(res.data.message); vm.isLoading = false;
        }
      }).catch(err => {
        vm.isLoading = false;
        const msg = err.response?.data?.message || err.message || __('something_went_wrong');
        vm.showError(msg);
      });
    },
  },
  mounted() {
    this.loadDropdownData();
    this.fetchActiveLanguages()
      .then(() => this.loadRecord())
      .then(() => this.applyBranchLock())
      // Baseline the loaded form for the UnsavedChanges guard.
      .then(() => this.captureFormBaseline());
    window.addEventListener('scroll', this.onScroll, true);
  },
  beforeUnmount() {
    window.removeEventListener('scroll', this.onScroll, true);
  },
};
</script>

<style scoped>
.sticky-nav { position: sticky; top: 80px; background: var(--app-card-bg); }
.sticky-nav .list-group { background: var(--app-card-bg); }
.sticky-nav .list-group-item { background: var(--app-card-bg); font-size: 13px; }
.promo-nav-item { cursor: pointer; transition: background .15s ease; }
.promo-nav-item.active,
.promo-nav-item.active:hover,
.promo-nav-item.active:focus {
    color: var(--bs-primary) !important;
    background: rgba(var(--bs-primary-rgb), 0.12) !important;
    border-left: 3px solid var(--bs-primary) !important;
    border-color: transparent;
    font-weight: 600;
}
.promo-form-page .error { font-size: 12px; }

/* Let multiselect dropdown overflow the card instead of being clipped */
.promo-form-page .card,
.promo-form-page .card-body { overflow: visible; }
.promo-form-page :deep(.multiselect) { z-index: 1; }
.promo-form-page :deep(.multiselect--active) { z-index: 1000; }
.promo-form-page :deep(.multiselect__content-wrapper) { z-index: 1000; }
</style>
