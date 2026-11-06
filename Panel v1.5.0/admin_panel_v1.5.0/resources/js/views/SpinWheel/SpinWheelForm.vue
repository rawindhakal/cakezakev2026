<template>
  <div class="sw-editor">
    <!-- Top bar: identity and the actions, always reachable. -->
    <div class="sw-topbar">
      <button type="button" class="btn btn-sm btn-outline-secondary d-inline-flex align-items-center gap-1"
        @click="goBack">
        <ArrowLeft :size="15" /> {{ __('back') }}
      </button>
      <div class="sw-topbar-title">
        <h5 class="mb-0">{{ campaignName || (id ? __('edit_spin_wheel_campaign') : __('create_spin_wheel_campaign')) }}</h5>
        <small class="text-muted">{{ __('spin_wheel_form_hint') }}</small>
      </div>
      <div class="ms-auto d-flex align-items-center gap-2">
        <button type="button" class="btn btn-sm btn-secondary" @click="goBack">{{ __('cancel') }}</button>
        <button type="button" class="btn btn-sm btn-primary" :disabled="isLoading" @click="saveRecord">
          {{ id ? __('update') : __('save') }}
          <b-spinner v-if="isLoading" small></b-spinner>
        </button>
      </div>
    </div>

    <div v-if="isLoadingRecord" class="text-center p-5"><b-spinner></b-spinner></div>

    <div v-else class="sw-grid">
      <!-- ===== Col 1: what the wheel is made of ===== -->
      <div class="sw-col sw-col-list">
        <div class="sw-list-sticky">
          <div class="sw-row" v-for="s in settingRows" :key="s.key" :class="{ active: selectedKey === s.key }"
            @click="selectedKey = s.key">
            <span class="sw-row-icon"><component :is="s.icon" :size="15" /></span>
            <span class="sw-row-title">{{ s.label }}</span>
          </div>

          <div class="d-flex align-items-center justify-content-between my-2">
            <h6 class="mb-0 fw-bold">{{ __('segments') }}</h6>
            <button type="button" class="btn btn-sm btn-primary d-inline-flex align-items-center gap-1"
              @click="addSegment()">
              <Plus :size="15" /> {{ __('add') }}
            </button>
          </div>

          <!-- Order here is the order on the wheel, so the list is the drag target. -->
          <draggable v-model="segments" item-key="uid" handle=".sw-row-grip" :animation="180"
            ghost-class="sw-drag-ghost">
            <template #item="{ element: seg, index }">
              <div class="sw-row" :class="{ active: selectedKey === 'seg:' + seg.uid, inactive: Number(seg.status) !== 1 }"
                @click="selectedKey = 'seg:' + seg.uid">
                <span class="sw-row-grip" :title="__('drag_to_reorder')"><GripVertical :size="15" /></span>
                <span class="sw-swatch" :style="{ background: seg.color }"></span>
                <span class="sw-row-title">
                  {{ segmentLabel(seg) || (__('segment') + ' ' + (index + 1)) }}
                  <small class="text-muted">{{ roundChance(seg.win_chance) }}%</small>
                </span>
                <button type="button" class="sw-row-btn ms-auto" @click.stop="cloneSegment(index)" v-b-tooltip.hover
                  :title="__('clone')"><Copy :size="14" /></button>
                <button type="button" class="sw-row-btn is-delete" @click.stop="removeSegment(index)"
                  v-b-tooltip.hover :title="__('delete')"><Trash2 :size="14" /></button>
              </div>
            </template>
          </draggable>

          <p v-if="!segments.length" class="text-muted text-center py-3 small">{{ __('no_segments_yet') }}</p>

          <div class="alert alert-warning py-2 px-3 small mb-0" v-if="!isBalanced && segments.length">
            {{ __('spin_wheel_chances_must_total_100') }}
          </div>
        </div>
      </div>

      <!-- ===== Col 2: the wheel, live ===== -->
      <div class="sw-col sw-col-preview">
        <div class="sw-preview-sticky">
          <div class="card sw-preview-card">
            <div class="card-body">
              <!-- Prizes differ per country, so the preview is per country too: a wedge
                   with no amount here is dimmed, exactly as the app would hide it. One
                   country means nothing to choose, so the picker stays hidden. -->
              <div class="mb-2" v-if="countries.length > 1">
                <label class="form-label small text-muted mb-1">{{ __('preview_for_country') }}</label>
                <AppSelect class="form-select form-select-sm" v-model="previewCountryId"
                  :options="countryOptions" :searchable="countries.length > 6" :allow-empty="false" />
              </div>

              <WheelPreview :segments="previewSegments" :theme="previewTheme" :title="campaignName"
                :selected-index="selectedSegmentIndex" @select="selectByIndex" />

              <div class="alert alert-warning py-2 px-3 small mt-2 mb-0" v-if="previewUnavailable.length">
                <b>{{ __('not_offered_in_this_country') }}</b>
                <div>{{ previewUnavailable.join(', ') }}</div>
              </div>
            </div>
          </div>

          <ul class="list-unstyled small text-muted sw-hints mb-0">
            <li>• {{ __('click_a_wedge_to_edit_it') }}</li>
            <li>• {{ __('no_luck_absorbs_hint') }}</li>
            <li>• {{ __('odds_never_sent_to_app') }}</li>
          </ul>
        </div>
      </div>

      <!-- ===== Col 3: the form for whatever is selected ===== -->
      <div class="sw-col sw-col-config">
        <div class="sw-config-panel">
          <div class="sw-config-head">
            <component :is="configIcon" :size="16" />
            <h6 class="mb-0 fw-bold">{{ configTitle }}</h6>
          </div>

          <!-- Campaign: names, artwork, status -->
          <div v-if="selectedKey === 'basic'" class="row g-2">
            <div class="col-12" v-if="languages.length > 0">
              <ul class="nav nav-tabs mb-2 align-items-center" v-if="languages.length > 1">
                <li class="nav-item" v-for="(language, idx) in languages" :key="'tab-' + language.id">
                  <a class="nav-link" href="javascript:void(0)" :class="{ active: activeLanguageTab === idx }"
                    @click="activeLanguageTab = idx">
                    <span :class="{ 'text-primary fw-bold': language.is_default }">{{ language.name }}</span>
                  </a>
                </li>
                <li class="nav-item ms-auto d-flex align-items-center">
                  <TranslateLanguages :languages="languages" :default-language-id="defaultLanguageId"
                    :busy="translating" :progress="translateProgress" @translate="runTranslate" />
                </li>
              </ul>

              <template v-for="(language, idx) in languages" :key="'pane-' + language.id">
                <div v-show="activeLanguageTab === idx" class="row g-2">
                  <div class="form-group col-12 col-xl-6">
                    <label>{{ __('campaign_name') }}<i class="text-danger" v-if="language.is_default">*</i></label>
                    <input type="text" class="form-control" maxlength="15" v-model="translations[language.id].name"
                      :placeholder="__('campaign_name')" />
                    <small class="text-muted">{{ __('campaign_name_hint') }}</small>
                  </div>
                </div>
              </template>
            </div>

            <div class="form-group col-12 col-xl-6">
              <label>{{ __('coupon_code_prefix') }}</label>
              <input type="text" class="form-control text-uppercase" maxlength="16" v-model="code_prefix"
                placeholder="SPIN" />
              <small class="text-muted">{{ __('coupon_code_prefix_hint') }}</small>
            </div>

            <div class="form-group col-12 col-xl-6">
              <label>{{ __('status') }}</label>
              <div class="text-left mt-1">
                <div class="btn-group btn-group-toggle" role="group">
                  <label class="btn btn-outline-primary btn-sm" :class="{ active: status == 0 }">
                    <input type="radio" :value="0" v-model.number="status" autocomplete="off"> {{ __('deactivate') }}
                  </label>
                  <label class="btn btn-outline-primary btn-sm" :class="{ active: status == 1 }">
                    <input type="radio" :value="1" v-model.number="status" autocomplete="off"> {{ __('activate') }}
                  </label>
                </div>
              </div>
              <small class="text-warning d-block mt-1" v-if="status == 1">
                {{ __('activating_deactivates_other_campaigns') }}
              </small>
            </div>

            <!-- Who may spin, how often, and when the campaign runs. -->
            <div class="col-12"><hr class="my-2" /><h6 class="fw-bold small mb-0">{{ __('spin_rules') }}</h6></div>

            <div class="form-group col-12 col-xl-6">
              <label>{{ __('spins_per_day') }}<i class="text-danger">*</i></label>
              <input type="number" min="1" step="1" class="form-control" v-model.number="spins_per_day" />
              <small class="text-muted">{{ __('spins_per_day_hint') }}</small>
            </div>
            <div class="form-group col-12 col-xl-6">
              <label>{{ __('max_spins_per_user') }}</label>
              <input type="number" min="0" step="1" class="form-control" v-model.number="max_spins_per_user" />
              <small class="text-muted">{{ __('set_0_if_you_want_ro_remove_limit') }}</small>
            </div>
            <div class="form-group col-12 col-xl-6">
              <label>{{ __('min_delivered_orders') }}</label>
              <input type="number" min="0" step="1" class="form-control" v-model.number="min_delivered_orders" />
              <small class="text-muted">{{ __('min_delivered_orders_hint') }}</small>
            </div>
            <div class="form-group col-12 col-xl-6">
              <label>{{ __('start_date') }}</label>
              <input type="datetime-local" class="form-control" v-model="start_date" />
            </div>
            <div class="form-group col-12 col-xl-6">
              <label>{{ __('end_date') }}</label>
              <input type="datetime-local" class="form-control" v-model="end_date" />
              <small class="text-muted">{{ __('leave_empty_for_no_date_limit') }}</small>
            </div>

            <!-- Right after the window it belongs to, not on a row of its own. -->
            <div class="form-group col-12 col-xl-6" v-if="start_date">
              <label class="d-block mb-1" for="is_scheduled">{{ __('activate_on_start_date') }}</label>
              <div class="form-check form-switch ps-0">
                <input class="form-check-input ms-0" type="checkbox" role="switch" id="is_scheduled"
                  v-model="is_scheduled" :disabled="status == 1" />
              </div>
              <small class="text-muted">
                {{ status == 1 ? __('campaign_already_active') : __('activate_on_start_date_hint') }}
              </small>
            </div>
          </div>

          <!-- Theme: one background colour drives the card's gradients; the pointer,
               rim and Spin button take their own. -->
          <div v-else-if="selectedKey === 'theme'" class="row g-3">
            <div class="col-6">
              <label class="form-label small text-muted mb-1">{{ __('background_color') }}</label>
              <ColorInput show-hex v-model="theme.bg_color" placeholder="#FE3C5E" />
              <small class="text-muted">{{ __('background_color_hint') }}</small>
            </div>
            <div class="col-6">
              <label class="form-label small text-muted mb-1">{{ __('title_color') }}</label>
              <ColorInput show-hex v-model="theme.title_color" placeholder="#B9F2C3" />
              <small class="text-muted">{{ __('title_color_hint') }}</small>
            </div>
            <div class="col-6">
              <label class="form-label small text-muted mb-1">{{ __('title_color_second_line') }}</label>
              <ColorInput show-hex v-model="theme.title_color_2" placeholder="#B9F2C3" />
            </div>
            <div class="col-6">
              <label class="form-label small text-muted mb-1">{{ __('pointer_color') }}</label>
              <ColorInput show-hex v-model="theme.pointer_color" placeholder="#F5C542" />
            </div>
            <div class="col-6">
              <label class="form-label small text-muted mb-1">{{ __('rim_color') }}</label>
              <ColorInput show-hex v-model="theme.border_color" placeholder="#F5C542" />
            </div>
            <div class="col-6">
              <label class="form-label small text-muted mb-1">{{ __('border_color') }}</label>
              <ColorInput show-hex v-model="theme.line_color" placeholder="#0A5E18" />
              <small class="text-muted">{{ __('border_color_hint') }}</small>
            </div>
            <div class="col-6">
              <label class="form-label small text-muted mb-1">{{ __('spin_button_color') }}</label>
              <ColorInput show-hex v-model="theme.button_color" placeholder="#F5C542" />
            </div>
            <div class="col-6">
              <label class="form-label small text-muted mb-1">{{ __('spin_button_text') }}</label>
              <input type="text" class="form-control" maxlength="10" v-model="theme.button_text" placeholder="SPIN" />
            </div>
            <div class="col-6">
              <label class="form-label small text-muted mb-1">{{ __('spin_button_text_color') }}</label>
              <ColorInput show-hex v-model="theme.button_text_color" placeholder="#5A3A00" />
            </div>
            <div class="col-6">
              <label class="form-label small text-muted mb-1">{{ __('light_color') }}</label>
              <ColorInput show-hex v-model="theme.light_color" placeholder="#FFFFFF" />
              <small class="text-muted">{{ __('light_color_hint') }}</small>
            </div>
            <div class="col-6">
              <label class="form-label small text-muted mb-1">{{ __('segment_fill') }}</label>
              <AppSelect class="form-control form-select" v-model="theme.segment_fill"
                :options="segmentFillOptions" :searchable="false" />
            </div>
            <div class="col-12">
              <HbImageUpload v-model="theme.hub_icon" :label="__('center_icon')"
                endpoint="/spin_wheel/upload_image" :max-size-mb="5" />
              <small class="text-muted">{{ __('center_icon_hint') }}</small>
            </div>
          </div>

          <!-- One wedge -->
          <div v-else-if="selectedSegment" class="row g-2">
            <div class="form-group col-12">
              <label>{{ __('label') }}<i class="text-danger">*</i></label>
              <input type="text" class="form-control" v-model="selectedSegment.translations[defaultLanguageId].label"
                :placeholder="__('label')" />
              <a href="javascript:void(0)" class="small" v-if="languages.length > 1"
                @click="selectedSegment.showLangs = !selectedSegment.showLangs">
                {{ selectedSegment.showLangs ? __('hide_translations') : __('other_languages') }}
              </a>
              <div v-if="selectedSegment.showLangs" class="mt-2">
                <div class="mb-1" v-for="lang in otherLanguages" :key="'sl' + selectedSegment.uid + lang.id">
                  <label class="small text-muted mb-0">{{ lang.name }}</label>
                  <input type="text" class="form-control form-control-sm"
                    v-model="selectedSegment.translations[lang.id].label" />
                </div>
              </div>
            </div>

            <div class="form-group col-6">
              <label>{{ __('reward_type') }}<i class="text-danger">*</i></label>
              <AppSelect class="form-control form-select" v-model="selectedSegment.type" :options="typeOptions"
                :searchable="false" @update:model-value="onTypeChange(selectedSegment)" />
            </div>
            <div class="form-group col-6">
              <label>{{ __('win_chance') }} (%)<i class="text-danger">*</i></label>
              <input type="number" min="0" max="100" step="0.01" class="form-control"
                v-model.number="selectedSegment.win_chance" />
              <small class="text-muted">{{ __('remaining_to_100') }}: {{ roundChance(100 - totalChance) }}%</small>
            </div>

            <div class="form-group col-6">
              <label>{{ __('winner_limit') }}</label>
              <input type="number" min="0" step="1" class="form-control" v-model.number="selectedSegment.winner_limit"
                :disabled="selectedSegment.type === 'no_luck'" />
              <small class="text-muted" v-if="selectedSegment.id && Number(selectedSegment.winner_limit) > 0">
                {{ __('already_won') }}: {{ selectedSegment.wins_count || 0 }}
              </small>
              <small class="text-muted" v-else>{{ __('set_0_if_you_want_ro_remove_limit') }}</small>
            </div>
            <div class="form-group col-6">
              <label>{{ __('status') }}</label>
              <div class="text-left mt-1">
                <div class="btn-group btn-group-toggle" role="group">
                  <label class="btn btn-outline-primary btn-sm" :class="{ active: selectedSegment.status == 0 }">
                    <input type="radio" :value="0" v-model.number="selectedSegment.status" autocomplete="off">
                    {{ __('deactivate') }}
                  </label>
                  <label class="btn btn-outline-primary btn-sm" :class="{ active: selectedSegment.status == 1 }">
                    <input type="radio" :value="1" v-model.number="selectedSegment.status" autocomplete="off">
                    {{ __('activate') }}
                  </label>
                </div>
              </div>
            </div>

            <div class="col-6">
              <label class="form-label small text-muted mb-1">{{ __('segment_color') }}</label>
              <ColorInput show-hex v-model="selectedSegment.color" placeholder="#F97316" />
            </div>
            <div class="col-6">
              <label class="form-label small text-muted mb-1">{{ __('label_color') }}</label>
              <ColorInput show-hex v-model="selectedSegment.text_color" placeholder="#FFFFFF" />
            </div>
            <div class="form-group col-6">
              <label>{{ __('display_mode') }}</label>
              <AppSelect class="form-control form-select" v-model="selectedSegment.display_mode"
                :options="displayModeOptions" :searchable="false" />
            </div>
            <div class="col-6" v-if="selectedSegment.display_mode !== 'name'">
              <HbImageUpload v-model="selectedSegment.icon" :label="__('segment_icon')"
                endpoint="/spin_wheel/upload_image" :max-size-mb="5" />
            </div>

            <!-- Coupon configuration -->
            <template v-if="selectedSegment.type === 'promo_code'">
              <div class="form-group col-6">
                <label>{{ __('discount_type') }}<i class="text-danger">*</i></label>
                <AppSelect class="form-control form-select" v-model="selectedSegment.discount_type"
                  :options="discountTypeOptions" :searchable="false" />
              </div>
              <div class="form-group col-6">
                <label>{{ __('discount_apply_type') }}</label>
                <AppSelect class="form-control form-select" v-model="selectedSegment.discount_apply_type"
                  :options="discountApplyTypeOptions" :searchable="false" />
                <small class="text-muted">{{ selectedSegment.discount_apply_type === 'wallet' ? __('spin_apply_type_wallet_hint') : __('spin_apply_type_instant_hint') }}</small>
              </div>
              <div class="form-group col-6" v-if="selectedSegment.discount_type === 'percentage'">
                <label>{{ __('discount_percentage') }}<i class="text-danger">*</i></label>
                <input type="number" min="1" max="100" step="0.01" class="form-control"
                  v-model.number="selectedSegment.discount_value" />
              </div>
              <div class="form-group col-6">
                <label>{{ __('validity_days') }}<i class="text-danger">*</i></label>
                <input type="number" min="1" step="1" class="form-control"
                  v-model.number="selectedSegment.validity_days" />
                <small class="text-muted">{{ __('validity_days_hint') }}</small>
              </div>
              <div class="form-group col-6">
                <label>{{ __('apply_to') }}</label>
                <AppSelect class="form-control form-select" v-model="selectedSegment.applicability"
                  :options="applicabilityOptions" :searchable="false"
                  @update:model-value="selectedSegment.applicability_ids = []" />
              </div>
              <div class="form-group col-12" v-if="selectedSegment.applicability !== 'all'">
                <label>{{ __('select') }}</label>
                <AppSelect class="form-control form-select" multiple v-model="selectedSegment.applicability_ids"
                  :options="applicabilityList(selectedSegment.applicability)" :placeholder="__('select')" />
                <small class="text-danger d-block" v-if="!(selectedSegment.applicability_ids || []).length">
                  {{ __('applicability_ids_required') }}
                </small>
              </div>
            </template>

            <template v-if="selectedSegment.type === 'free_delivery'">
              <div class="form-group col-6">
                <label>{{ __('validity_days') }}<i class="text-danger">*</i></label>
                <input type="number" min="1" step="1" class="form-control"
                  v-model.number="selectedSegment.validity_days" />
                <small class="text-muted">{{ __('validity_days_hint') }}</small>
              </div>
            </template>

            <!-- Per-country money: one line per country, each field carrying that
                 country's own currency sign. -->
            <div class="col-12" v-if="countryFields(selectedSegment).length">
              <div class="sw-amounts mt-2">
                <div class="d-flex justify-content-between align-items-center mb-1">
                  <label class="mb-0 fw-semibold small">{{ countryTableTitle(selectedSegment) }}</label>
                  <small class="text-muted">{{ __('blank_country_not_offered') }}</small>
                </div>

                <!-- One header row instead of a caption under every field, and a grid so
                     every currency chip and input lines up down the column. -->
                <div class="sw-amt-grid" :style="amountGridStyle(selectedSegment)">
                  <div class="sw-amt-head">{{ __('country') }}</div>
                  <div class="sw-amt-head" v-for="f in countryFields(selectedSegment)" :key="'h' + f.key">
                    {{ f.label }}
                  </div>

                  <template v-for="c in countries" :key="selectedSegment.uid + '-' + c.id">
                    <div class="sw-amt-country">
                      <img v-if="c.logo_url" :src="c.logo_url" class="cz-flag" alt="" />
                      <span class="text-truncate">{{ c.name }}</span>
                    </div>
                    <div class="input-group input-group-sm" v-for="f in countryFields(selectedSegment)"
                      :key="c.id + f.key">
                      <span class="input-group-text">{{ c.currency || '' }}</span>
                      <input type="number" min="0" step="0.01" class="form-control"
                        v-model.number="selectedSegment.amounts[c.id][f.key]" placeholder="0" />
                    </div>
                  </template>
                </div>

                <small class="text-muted d-block mt-2">{{ amountNote(selectedSegment) }}</small>
              </div>
            </div>

            <div class="col-12" v-if="missingAmountFor(selectedSegment).length">
              <div class="alert alert-warning py-2 px-3 small mb-0">
                <b>{{ __('missing_country_amounts') }}</b>
                <div>{{ missingAmountFor(selectedSegment).join(', ') }}</div>
              </div>
            </div>
          </div>

          <div v-else class="sw-config-empty text-muted small">
            {{ __('select_something_to_edit') }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios';
import draggable from 'vuedraggable';
import TranslationHelper from '../../mixins/TranslationHelper.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';
import WheelPreview from './WheelPreview.vue';
import HbImageUpload from '../HomeBuilder/components/HbImageUpload.vue';
import ColorInput from '../HomeBuilder/components/ColorInput.vue';
import { resolveImageUrl } from '../HomeBuilder/homeBuilderHelpers.js';
import { markRaw } from 'vue';
import {
  ArrowLeft, Plus, Trash2, Copy, GripVertical, Settings, Palette, Disc3,
} from 'lucide-vue-next';

// Wedge colours handed out to new segments, so a fresh wheel is never all one colour.
const PALETTE = ['#f97316', '#0ea5e9', '#22c55e', '#a855f7', '#ef4444', '#eab308', '#14b8a6', '#ec4899'];

let uid = 0;

export default {
  name: 'SpinWheelForm',
  mixins: [TranslationHelper, UnsavedChanges],
  components: {
    draggable, WheelPreview, HbImageUpload, ColorInput,
    ArrowLeft, Plus, Trash2, Copy, GripVertical, Settings, Palette, Disc3,
  },
  data() {
    return {
      id: this.$route.params.id || '',
      isLoading: false,
      isLoadingRecord: false,
      // 'basic' | 'rules' | 'theme' | 'seg:<uid>' — what the right panel is editing.
      selectedKey: 'basic',
      // campaign fields
      code_prefix: 'SPIN',
      status: 0,
      is_scheduled: false,
      start_date: '',
      end_date: '',
      spins_per_day: 1,
      max_spins_per_user: 0,
      min_delivered_orders: 0,
      theme: {
        // The admin theme colour unless the admin picks another.
        bg_color: window.adminThemeColor || '#FE3C5E',
        title_color: '#b9f2c3',
        title_color_2: '#b9f2c3',
        pointer_color: '#f4b400',
        border_color: '#f4b400',
        line_color: '#0a5e18',
        button_color: '#f4b400',
        button_text: 'SPIN',
        button_text_color: '#5a3a00',
        light_color: '#ffffff',
        hub_icon: '',
        segment_fill: 'flat',
      },
      segments: [],
      // dropdown data
      countries: [],
      categories: [],
      brands: [],
      previewCountryId: 0,
      // languages / translations
      activeLanguageTab: 0,
      translations: {},
      defaultLanguageId: null,
      languages: [],
      translatableFields: ['name'],
    };
  },
  computed: {
    settingRows() {
      return [
        // Rules live inside Campaign Settings — one place for everything about the
        // campaign, leaving the list to be about the wheel itself.
        { key: 'basic', label: __('campaign_settings'), icon: markRaw(Settings) },
        { key: 'theme', label: __('wheel_theme'), icon: markRaw(Palette) },
      ];
    },
    configIcon() {
      const row = this.settingRows.find(r => r.key === this.selectedKey);
      return row ? row.icon : markRaw(Disc3);
    },
    configTitle() {
      const row = this.settingRows.find(r => r.key === this.selectedKey);
      if (row) return row.label;
      const seg = this.selectedSegment;
      if (!seg) return __('select_something_to_edit');
      return (this.segmentLabel(seg) || __('segment')) + ' — ' + this.typeLabel(seg.type);
    },
    selectedSegment() {
      if (!this.selectedKey.startsWith('seg:')) return null;
      const wanted = this.selectedKey.slice(4);
      return this.segments.find(s => s.uid === wanted) || null;
    },
    selectedSegmentIndex() {
      if (!this.selectedKey.startsWith('seg:')) return -1;
      const wanted = this.selectedKey.slice(4);
      return this.segments.findIndex(s => s.uid === wanted);
    },
    campaignName() {
      const def = this.translations[this.defaultLanguageId];
      return (def && def.name) || '';
    },
    previewTheme() {
      return { ...this.theme, hub_icon_url: resolveImageUrl(this.theme.hub_icon) };
    },
    countryOptions() {
      return this.countries.map(c => ({ id: c.id, name: c.name }));
    },
    previewCountry() {
      return this.countries.find(c => Number(c.id) === Number(this.previewCountryId)) || this.countries[0] || null;
    },
    otherLanguages() {
      return this.languages.filter(l => l.id !== this.defaultLanguageId);
    },
    typeOptions() {
      return [
        { id: 'promo_code', name: __('promo_code') },
        { id: 'wallet', name: __('wallet_amount') },
        { id: 'free_delivery', name: __('free_delivery') },
        { id: 'no_luck', name: __('no_luck_segment') },
      ];
    },
    discountTypeOptions() {
      return [
        { id: 'percentage', name: __('percentage') },
        { id: 'flat', name: __('flat') },
      ];
    },
    discountApplyTypeOptions() {
      return [
        { id: 'instant', name: __('instant_discount') },
        { id: 'wallet', name: __('wallet_cashback') },
      ];
    },
    segmentFillOptions() {
      return [
        { id: 'flat', name: __('flat_color') },
        { id: 'glossy', name: __('glossy_gradient') },
      ];
    },
    displayModeOptions() {
      return [
        { id: 'both', name: __('name_and_icon') },
        { id: 'name', name: __('name_only') },
        { id: 'icon', name: __('icon_only') },
      ];
    },
    applicabilityOptions() {
      return [
        { id: 'all', name: __('all_products') },
        { id: 'categories', name: __('specific_categories') },
        { id: 'brands', name: __('specific_brands') },
      ];
    },
    totalChance() {
      return this.segments.reduce((sum, s) => sum + (Number(s.win_chance) || 0), 0);
    },
    isBalanced() {
      return Math.abs(this.totalChance - 100) < 0.01;
    },
    noLuckCount() {
      return this.segments.filter(s => s.type === 'no_luck').length;
    },
    /**
     * The wheel as it would look in the previewed country: labels, colours, the odds for
     * the test spin, and whether the wedge is offered there at all.
     */
    previewSegments() {
      const country = this.previewCountry;
      return this.segments.map(s => ({
        id: s.uid,
        label: this.segmentLabel(s),
        win_chance: s.win_chance,
        color: s.color,
        text_color: s.text_color,
        display_mode: s.display_mode,
        icon_url: resolveImageUrl(s.icon),
        type: s.type,
        available: this.isAvailableIn(s, country),
        prize: this.prizeText(s, country),
      }));
    },
    previewUnavailable() {
      return this.segments
        .filter(s => Number(s.status) === 1 && s.type !== 'no_luck' && !this.isAvailableIn(s, this.previewCountry))
        .map(s => this.segmentLabel(s) || __('segment'));
    },
  },
  methods: {
    goBack() { this.$router.push({ path: '/spin_wheel' }); },
    selectByIndex(index) {
      const seg = this.segments[index];
      if (seg) this.selectedKey = 'seg:' + seg.uid;
    },
    selectSegment(seg) {
      if (seg) this.selectedKey = 'seg:' + seg.uid;
    },
    /**
     * Translations arrive keyed by language id (getAllActiveLanguageTranslations), while
     * amounts arrive as a list — accept either shape rather than trusting one.
     */
    asList(value) {
      if (Array.isArray(value)) return value;
      if (value && typeof value === 'object') return Object.values(value);
      return [];
    },
    // The admin edits in their LOCAL time; the server, scheduler and window check run in
    // UTC — the same convention as the maintenance schedule. Stored form: UTC
    // "YYYY-MM-DD HH:mm:ss"; the picker gets and gives local "YYYY-MM-DDTHH:mm".
    pad(n) { return String(n).padStart(2, '0'); },
    /** Stored UTC -> local, for the datetime-local input. */
    toInputDateTime(value) {
      if (!value) return '';
      const d = new Date(String(value).replace(' ', 'T') + 'Z'); // parse as UTC
      if (isNaN(d.getTime())) return '';
      return `${d.getFullYear()}-${this.pad(d.getMonth() + 1)}-${this.pad(d.getDate())}`
        + `T${this.pad(d.getHours())}:${this.pad(d.getMinutes())}`;
    },
    /** Local picker value -> UTC, for storage. */
    toServerDateTime(value) {
      if (!value) return '';
      const d = new Date(value); // the picker's value is local time
      if (isNaN(d.getTime())) return '';
      return `${d.getUTCFullYear()}-${this.pad(d.getUTCMonth() + 1)}-${this.pad(d.getUTCDate())}`
        + ` ${this.pad(d.getUTCHours())}:${this.pad(d.getUTCMinutes())}:00`;
    },
    roundChance(value) {
      return String(Math.round((Number(value) || 0) * 100) / 100);
    },
    formState() {
      return {
        translations: this.translations,
        code_prefix: this.code_prefix,
        status: this.status,
        is_scheduled: this.is_scheduled,
        start_date: this.start_date,
        end_date: this.end_date,
        spins_per_day: this.spins_per_day,
        max_spins_per_user: this.max_spins_per_user,
        min_delivered_orders: this.min_delivered_orders,
        theme: this.theme,
        segments: this.segments,
      };
    },
    typeLabel(type) {
      const match = this.typeOptions.find(o => o.id === type);
      return match ? match.name : type;
    },
    segmentLabel(seg) {
      const tr = seg.translations || {};
      const def = tr[this.defaultLanguageId];
      return (def && def.label) || '';
    },
    needsAmount(seg) {
      // Wallet prizes are money; a flat coupon is money. A percentage coupon and free
      // delivery are not — they only take optional limits.
      return seg.type === 'wallet' || (seg.type === 'promo_code' && seg.discount_type === 'flat');
    },
    /** Which money fields a segment actually uses, so no dead inputs are shown. */
    countryFields(seg) {
      if (!seg) return [];
      if (seg.type === 'wallet') {
        return [{ key: 'amount', label: __('wallet_amount') }];
      }
      if (seg.type === 'free_delivery') {
        return [{ key: 'minimum_order_amount', label: __('min_order_amount') }];
      }
      if (seg.type === 'promo_code') {
        return seg.discount_type === 'flat'
          ? [{ key: 'amount', label: __('discount_amount') }, { key: 'minimum_order_amount', label: __('min_order_amount') }]
          : [{ key: 'minimum_order_amount', label: __('min_order_amount') }, { key: 'max_discount_amount', label: __('max_discount_amount') }];
      }
      return [];
    },
    /** Country column plus one equal column per money field this type uses. */
    amountGridStyle(seg) {
      return {
        gridTemplateColumns: `minmax(110px, 1.2fr) repeat(${this.countryFields(seg).length}, minmax(96px, 1fr))`,
      };
    },
    /**
     * A blank field is a real setting here, not an omission — for a money prize it
     * withdraws the wedge in that country, for a limit it removes the limit — so say
     * which it is for the type on screen.
     */
    amountNote(seg) {
      if (!seg) return '';
      if (seg.type === 'wallet') return __('spin_note_wallet_amount');
      if (seg.type === 'free_delivery') return __('spin_note_free_delivery');
      if (seg.type === 'promo_code') {
        return seg.discount_type === 'flat' ? __('spin_note_flat_coupon') : __('spin_note_percentage_coupon');
      }
      return '';
    },
    countryTableTitle(seg) {
      return this.needsAmount(seg) ? __('country_wise_prize') : __('country_wise_conditions');
    },
    /** Countries where this money prize has no amount, so it cannot be won there. */
    missingAmountFor(seg) {
      if (!seg || !this.needsAmount(seg) || Number(seg.status) !== 1) return [];
      return this.countries
        .filter(c => !(Number(seg.amounts[c.id] && seg.amounts[c.id].amount) > 0))
        .map(c => c.name);
    },
    /** Same rule the server applies: no money for this country means not offered here. */
    isAvailableIn(seg, country) {
      if (Number(seg.status) !== 1) return false;
      if (seg.type === 'no_luck') return true;
      if (!this.needsAmount(seg)) return true;
      if (!country) return false;
      const row = seg.amounts[country.id];
      return !!(row && Number(row.amount) > 0);
    },
    /** One line describing what landing on this wedge pays, in the previewed country. */
    prizeText(seg, country) {
      const symbol = (country && country.currency) || '';
      const row = (country && seg.amounts[country.id]) || {};
      const min = Number(row.minimum_order_amount) > 0
        ? ' · ' + __('min_order') + ' ' + symbol + Number(row.minimum_order_amount) : '';

      if (seg.type === 'wallet') {
        return Number(row.amount) > 0
          ? symbol + Number(row.amount) + ' ' + __('wallet_amount')
          : __('not_offered_here');
      }
      if (seg.type === 'free_delivery') {
        return __('free_delivery') + min;
      }
      if (seg.type === 'promo_code') {
        if (seg.discount_type === 'flat') {
          return Number(row.amount) > 0
            ? symbol + Number(row.amount) + ' ' + __('discount') + min
            : __('not_offered_here');
        }
        const cap = Number(row.max_discount_amount) > 0
          ? ' · ' + __('max_discount') + ' ' + symbol + Number(row.max_discount_amount) : '';
        return (Number(seg.discount_value) || 0) + '% ' + __('discount') + cap + min;
      }
      return '';
    },
    applicabilityList(kind) {
      if (kind === 'categories') return this.categories;
      if (kind === 'brands') return this.brands;
      return [];
    },
    emptyTranslations(keys) {
      const out = {};
      this.languages.forEach(l => {
        out[l.id] = {};
        keys.forEach(k => { out[l.id][k] = ''; });
      });
      return out;
    },
    emptyAmounts() {
      const out = {};
      this.countries.forEach(c => {
        out[c.id] = { amount: '', max_discount_amount: '', minimum_order_amount: '' };
      });
      return out;
    },
    newSegment(type) {
      return {
        uid: 'n' + (++uid),
        id: 0,
        type: type || 'promo_code',
        win_chance: 0,
        winner_limit: 0,
        wins_count: 0,
        color: PALETTE[this.segments.length % PALETTE.length],
        text_color: '#ffffff',
        display_mode: 'both',
        status: 1,
        icon: '',
        discount_type: 'percentage',
        discount_apply_type: 'instant',
        discount_value: 10,
        validity_days: 7,
        applicability: 'all',
        applicability_ids: [],
        showLangs: false,
        translations: this.emptyTranslations(['label']),
        amounts: this.emptyAmounts(),
      };
    },
    addSegment(type) {
      // The no-luck wedge is mandatory and unique, so offer it only while missing.
      const seg = this.newSegment(type || (this.noLuckCount ? 'promo_code' : 'no_luck'));
      this.segments.push(seg);
      this.selectSegment(seg);
    },
    /** A copy, minus its identity: a clone must not inherit the original's win count. */
    cloneSegment(index) {
      const source = this.segments[index];
      if (!source) return;
      const copy = JSON.parse(JSON.stringify(source));
      copy.uid = 'n' + (++uid);
      copy.id = 0;
      copy.wins_count = 0;
      copy.win_chance = 0;
      this.segments.splice(index + 1, 0, copy);
      this.selectSegment(copy);
    },
    removeSegment(index) {
      const removed = this.segments[index];
      this.segments.splice(index, 1);
      if (removed && this.selectedKey === 'seg:' + removed.uid) {
        this.selectedKey = 'basic';
      }
    },
    onTypeChange(seg) {
      if (seg.type === 'no_luck') {
        seg.winner_limit = 0;
        seg.applicability = 'all';
        seg.applicability_ids = [];
      }
      if (seg.type === 'promo_code' && !seg.discount_type) seg.discount_type = 'percentage';
    },
    loadDropdownData() {
      const get = (url) => axios.get(this.$apiUrl + url).catch(() => ({ data: { data: [] } }));
      return Promise.all([
        get('/countries/active'), get('/categories/active'), get('/products/brands/get'),
      ]).then(([co, c, b]) => {
        this.countries = (co.data?.data || []).map(x => ({
          id: Number(x.id),
          name: this.plainName(x.name),
          currency: x.currency || '',
          logo_url: x.logo_url || '',
          is_default: Number(x.is_default || 0),
        }));
        const def = this.countries.find(x => x.is_default === 1) || this.countries[0];
        this.previewCountryId = def ? def.id : 0;
        this.categories = this.normalizeList(c);
        this.brands = this.normalizeList(b);
      });
    },
    // Country names arrive translated as an object on some installs.
    plainName(name) {
      if (name == null) return '';
      if (typeof name === 'string') return name;
      const loc = window.appLocale || 'en';
      return String(name[loc] || Object.values(name).find(v => v && String(v).trim() !== '') || '');
    },
    normalizeList(res) {
      const body = res && res.data ? res.data : {};
      const payload = body.data !== undefined ? body.data : body;
      let arr = [];
      if (Array.isArray(payload)) arr = payload;
      else if (payload && typeof payload === 'object') {
        arr = payload.rows || payload.result || Object.values(payload).find(v => Array.isArray(v)) || [];
      }
      return arr.map(i => ({ id: i.id, name: this.plainName(i.name || i.title) || ('#' + i.id) }));
    },
    fetchActiveLanguages() {
      return axios.get(this.$apiUrl + '/active_languages').then(res => {
        this.languages = res.data?.data || [];
        const defIdx = this.languages.findIndex(l => Number(l.is_default) === 1);
        this.defaultLanguageId = defIdx >= 0 ? this.languages[defIdx].id : (this.languages[0] || {}).id;
        this.activeLanguageTab = defIdx >= 0 ? defIdx : 0;
        this.translations = this.emptyTranslations(['name']);
      }).catch(e => console.error('languages', e));
    },
    loadRecord() {
      if (!this.id) return Promise.resolve();
      this.isLoadingRecord = true;
      return axios.get(this.$apiUrl + '/spin_wheel/edit/' + this.id).then(res => {
        const rec = res.data?.data || {};
        this.code_prefix = rec.code_prefix || 'SPIN';
        this.status = Number(rec.status || 0);
        this.is_scheduled = Number(rec.is_scheduled || 0) === 1;
        this.start_date = this.toInputDateTime(rec.start_date);
        this.end_date = this.toInputDateTime(rec.end_date);
        this.spins_per_day = Number(rec.spins_per_day || 1);
        this.max_spins_per_user = Number(rec.max_spins_per_user || 0);
        this.min_delivered_orders = Number(rec.min_delivered_orders || 0);
        if (rec.theme && typeof rec.theme === 'object') {
          this.theme = Object.assign({}, this.theme, rec.theme);
        }

        this.asList(rec.translations).forEach(t => {
          if (!this.translations[t.language_id]) return;
          this.translations[t.language_id].name = t.name || '';
        });
        if (this.defaultLanguageId && !this.translations[this.defaultLanguageId].name) {
          this.translations[this.defaultLanguageId].name = rec.name || '';
        }

        this.segments = this.asList(rec.segments).map(s => {
          const seg = this.newSegment(s.type);
          seg.id = s.id;
          seg.type = s.type;
          seg.win_chance = Number(s.win_chance || 0);
          seg.winner_limit = Number(s.winner_limit || 0);
          seg.wins_count = Number(s.wins_count || 0);
          seg.color = s.color || seg.color;
          seg.text_color = s.text_color || '#ffffff';
          seg.display_mode = s.display_mode || 'both';
          seg.status = Number(s.status === undefined ? 1 : s.status);
          seg.icon = s.icon || '';
          seg.discount_type = s.discount_type || 'percentage';
          seg.discount_apply_type = s.discount_apply_type || 'instant';
          seg.discount_value = Number(s.discount_value || 0);
          seg.validity_days = Number(s.validity_days || 7);
          seg.applicability = s.applicability || 'all';
          seg.applicability_ids = s.applicability_ids || [];

          this.asList(s.translations).forEach(t => {
            if (seg.translations[t.language_id]) seg.translations[t.language_id].label = t.label || '';
          });
          if (this.defaultLanguageId && !seg.translations[this.defaultLanguageId].label) {
            seg.translations[this.defaultLanguageId].label = s.label || '';
          }

          this.asList(s.amounts).forEach(a => {
            if (!seg.amounts[a.country_id]) return;
            seg.amounts[a.country_id] = {
              amount: Number(a.amount) || '',
              max_discount_amount: Number(a.max_discount_amount) || '',
              minimum_order_amount: Number(a.minimum_order_amount) || '',
            };
          });

          return seg;
        });

        this.isLoadingRecord = false;
      }).catch(() => {
        this.isLoadingRecord = false;
        this.showError(__('something_went_wrong'));
      });
    },
    /**
     * A new campaign opens on a working wheel — four wedges, one of each type, odds
     * already totalling 100 — so the admin edits a valid wheel instead of assembling
     * one from nothing and hitting the 100% rule on their first save.
     */
    seedDefaultWheel() {
      const preset = [
        { type: 'promo_code', chance: 20, label: __('discount_coupon'), color: PALETTE[0] },
        { type: 'wallet', chance: 15, label: __('wallet_amount'), color: PALETTE[1] },
        { type: 'free_delivery', chance: 15, label: __('free_delivery'), color: PALETTE[2] },
        { type: 'no_luck', chance: 50, label: __('no_luck_segment'), color: PALETTE[4] },
      ];
      this.segments = preset.map(p => {
        const seg = this.newSegment(p.type);
        seg.win_chance = p.chance;
        seg.color = p.color;
        if (this.defaultLanguageId) seg.translations[this.defaultLanguageId].label = p.label;
        return seg;
      });
    },
    /**
     * Everything the server would reject, caught here so the admin keeps their input —
     * and the panel jumps to whatever needs fixing.
     */
    validate() {
      const name = (this.translations[this.defaultLanguageId] || {}).name || '';
      if (!name.trim()) {
        this.selectedKey = 'basic';
        return __('please_fill_default_language_required_fields');
      }
      if (Number(this.spins_per_day) < 1) {
        this.selectedKey = 'basic';
        return __('spins_per_day_must_be_at_least_1');
      }
      if (this.start_date && this.end_date && this.end_date < this.start_date) {
        this.selectedKey = 'basic';
        return __('end_date_must_be_after_start_date');
      }
      if (this.segments.length < 2) {
        return __('spin_wheel_min_two_segments');
      }
      if (!this.isBalanced) {
        return __('spin_wheel_chances_must_total_100');
      }
      for (const seg of this.segments) {
        if (!this.segmentLabel(seg).trim()) {
          this.selectSegment(seg);
          return __('segment_label_required');
        }
        if (seg.type === 'promo_code' || seg.type === 'free_delivery') {
          if (Number(seg.validity_days) < 1) {
            this.selectSegment(seg);
            return __('spin_wheel_validity_days_required');
          }
        }
        if (seg.type === 'promo_code') {
          if (!['percentage', 'flat'].includes(seg.discount_type)) {
            this.selectSegment(seg);
            return __('spin_wheel_discount_type_required');
          }
          if (seg.discount_type === 'percentage'
            && (Number(seg.discount_value) <= 0 || Number(seg.discount_value) > 100)) {
            this.selectSegment(seg);
            return __('spin_wheel_invalid_percentage');
          }
          if (seg.applicability !== 'all' && !(seg.applicability_ids || []).length) {
            this.selectSegment(seg);
            return __('applicability_ids_required');
          }
        }
        // A money prize with no country amount anywhere can never be won.
        if (this.needsAmount(seg) && Number(seg.status) === 1) {
          const any = this.countries.some(c => Number(seg.amounts[c.id].amount) > 0);
          if (!any) {
            this.selectSegment(seg);
            return __('segment_needs_one_country_amount');
          }
        }
      }
      return null;
    },
    segmentPayload(seg) {
      return {
        id: seg.id || 0,
        type: seg.type,
        label: this.segmentLabel(seg),
        win_chance: Number(seg.win_chance) || 0,
        winner_limit: Number(seg.winner_limit) || 0,
        color: seg.color,
        text_color: seg.text_color,
        display_mode: seg.display_mode,
        status: Number(seg.status),
        // Already-uploaded path; empty means the wedge has no icon.
        icon: seg.icon || '',
        discount_type: seg.type === 'promo_code' ? seg.discount_type : null,
        discount_apply_type: seg.type === 'promo_code' ? (seg.discount_apply_type || 'instant') : 'instant',
        discount_value: seg.type === 'promo_code' && seg.discount_type === 'percentage'
          ? Number(seg.discount_value) || 0 : 0,
        validity_days: Number(seg.validity_days) || 7,
        applicability: seg.applicability,
        applicability_ids: seg.applicability === 'all' ? [] : (seg.applicability_ids || []),
        translations: this.languages.map(l => ({
          language_id: l.id,
          label: (seg.translations[l.id] && seg.translations[l.id].label) || '',
        })),
        amounts: seg.type === 'no_luck' ? [] : this.countries.map(c => ({
          country_id: c.id,
          amount: Number(seg.amounts[c.id].amount) || 0,
          max_discount_amount: Number(seg.amounts[c.id].max_discount_amount) || 0,
          minimum_order_amount: Number(seg.amounts[c.id].minimum_order_amount) || 0,
        })),
      };
    },
    saveRecord() {
      const error = this.validate();
      if (error) {
        this.showError(error);
        return;
      }

      // Editing a campaign changes what customers see the moment it is saved (an
      // active wheel has no draft state), so the admin confirms before it goes out.
      if (this.id) {
        this.$swal.fire({
          title: __('are_you_sure'),
          text: __('spin_wheel_update_goes_live_warning'),
          icon: 'warning',
          showCancelButton: true,
          confirmButtonText: __('yes_update'),
          cancelButtonText: __('cancel'),
          confirmButtonColor: window.adminThemeColor || '#435ebe',
          cancelButtonColor: '#d33',
        }).then(result => { if (result.value) this.submitRecord(); });
        return;
      }
      this.submitRecord();
    },
    submitRecord() {
      const vm = this;
      this.isLoading = true;

      const def = this.translations[this.defaultLanguageId] || {};
      const payload = {
        name: def.name || '',
        code_prefix: (this.code_prefix || 'SPIN').toUpperCase(),
        status: this.status,
        // Queuing only makes sense for a campaign that isn't already running.
        is_scheduled: this.status == 1 ? 0 : (this.is_scheduled && this.start_date ? 1 : 0),
        start_date: this.toServerDateTime(this.start_date),
        end_date: this.toServerDateTime(this.end_date),
        spins_per_day: this.spins_per_day || 1,
        max_spins_per_user: this.max_spins_per_user || 0,
        min_delivered_orders: this.min_delivered_orders || 0,
        theme: {
          bg_color: this.theme.bg_color,
          title_color: this.theme.title_color,
          title_color_2: this.theme.title_color_2 || this.theme.title_color,
          pointer_color: this.theme.pointer_color,
          border_color: this.theme.border_color,
          line_color: this.theme.line_color,
          button_color: this.theme.button_color,
          button_text: String(this.theme.button_text || '').trim() || 'SPIN',
          button_text_color: this.theme.button_text_color,
          light_color: this.theme.light_color,
          hub_icon: this.theme.hub_icon || '',
          segment_fill: this.theme.segment_fill === 'glossy' ? 'glossy' : 'flat',
        },
        translations: this.languages.map(l => ({
          language_id: l.id,
          name: (this.translations[l.id] && this.translations[l.id].name) || '',
        })),
        segments: this.segments.map(s => this.segmentPayload(s)),
      };
      if (this.id) payload.id = this.id;

      axios.post(this.$apiUrl + '/spin_wheel/save', payload).then(res => {
        if (res.data.status === 1) {
          vm.showMessage('success', res.data.message || __('spin_wheel_campaign_saved_successfully'));
          vm.$eventBus.emit('recordSaved');
          if (vm.id) {
            // Editing: stay on the page with the saved state reloaded (segment ids etc.).
            vm.loadRecord().finally(() => { vm.captureFormBaseline(); vm.isLoading = false; });
          } else {
            // New campaign: move to its edit URL so a second save updates, not duplicates.
            const newId = res.data.data?.id;
            vm.captureFormBaseline();
            if (newId) {
              vm.id = newId; // same component instance is reused across the route swap
              vm.$router.replace({ path: '/spin_wheel/edit/' + newId });
              vm.loadRecord().finally(() => { vm.captureFormBaseline(); vm.isLoading = false; });
            } else {
              vm.$router.replace({ path: '/spin_wheel' });
            }
          }
        } else {
          vm.showError(res.data.message);
          vm.isLoading = false;
        }
      }).catch(err => {
        vm.isLoading = false;
        vm.showError(err.response?.data?.message || err.message || __('something_went_wrong'));
      });
    },
  },
  mounted() {
    // Three columns need the width, so the admin sidebar folds away while building and
    // comes back on leave — same as the home builder.
    const sb = document.getElementById('sidebar');
    this._sidebarWasActive = sb ? sb.classList.contains('active') : false;
    if (sb) sb.classList.remove('active');
    window.dispatchEvent(new Event('resize'));

    // Countries and languages must be in hand before a record loads: both decide the
    // shape of every segment row.
    Promise.all([this.fetchActiveLanguages(), this.loadDropdownData()])
      .then(() => this.loadRecord())
      .then(() => {
        if (!this.id && !this.segments.length) this.seedDefaultWheel();
      })
      .then(() => this.captureFormBaseline());
  },
  beforeUnmount() {
    const sb = document.getElementById('sidebar');
    if (sb && this._sidebarWasActive) sb.classList.add('active');
    window.dispatchEvent(new Event('resize'));
  },
};
</script>

<style scoped>
.sw-editor { padding-bottom: 24px; }

.sw-topbar {
  position: sticky; top: var(--app-header-h, 64px); z-index: 7;
  display: flex; align-items: center; gap: 12px; flex-wrap: wrap;
  padding: .55rem .75rem; margin-bottom: .75rem;
  background: var(--app-card-bg); border: 1px solid var(--app-card-border); border-radius: .6rem;
}
.sw-topbar-title h5 { font-size: 15px; }

/* Segments | wheel | form — the builder layout. */
.sw-grid { display: flex; flex-wrap: wrap; gap: 1rem; align-items: flex-start; }
.sw-col-list { flex: 0 0 280px; width: 280px; min-width: 0; }
.sw-col-preview { flex: 0 0 auto; width: 360px; }
.sw-col-config { flex: 1 1 340px; min-width: 0; }

/* List and wheel stick just under the top bar; the form column rides the page, so no
   column ever grows its own scrollbar. */
.sw-editor { --sw-stick: calc(var(--app-header-h, 64px) + 3.9rem); }
.sw-list-sticky { position: sticky; top: var(--sw-stick); }
.sw-preview-sticky {
  position: sticky; top: var(--sw-stick);
  display: flex; flex-direction: column; gap: 8px;
}
.sw-config-panel {
  border: 1px solid var(--app-card-border); border-radius: .6rem;
  background: var(--app-card-bg, #fff); padding: .75rem;
}
.sw-config-head {
  display: flex; align-items: center; gap: .5rem;
  padding-bottom: .5rem; margin-bottom: .5rem; border-bottom: 1px solid var(--app-card-border);
}
.sw-config-head h6 { font-size: .85rem; }
.sw-config-empty { padding: 2.5rem 1rem; text-align: center; }

@media (min-width: 700px) and (max-width: 1399.98px) {
  .sw-col-preview { flex: 1 1 auto; width: auto; }
  .sw-col-config { flex: 1 1 100%; width: 100%; min-width: 100%; }
}
@media (max-width: 699.98px) {
  .sw-grid { flex-direction: column; flex-wrap: nowrap; }
  .sw-col { flex: 1 1 auto !important; width: 100% !important; }
  .sw-list-sticky, .sw-preview-sticky { position: static; }
}

/* List rows */
.sw-row {
  display: flex; align-items: center; gap: 8px;
  padding: .45rem .5rem; margin-bottom: .4rem;
  border: 1px solid var(--app-card-border); border-radius: .5rem;
  background: var(--app-card-bg, #fff); cursor: pointer;
  transition: border-color .15s, box-shadow .15s;
}
.sw-row:hover { border-color: var(--bs-primary); }
.sw-row.active { border-color: var(--bs-primary); box-shadow: 0 0 0 2px rgba(var(--bs-primary-rgb), .15); }
.sw-row.inactive { opacity: .55; }
.sw-row-grip { cursor: grab; color: var(--app-muted); display: inline-flex; flex: 0 0 auto; }
.sw-row-icon { color: var(--bs-primary); display: inline-flex; flex: 0 0 auto; }
.sw-row-title {
  font-size: .82rem; font-weight: 500; white-space: nowrap; overflow: hidden;
  text-overflow: ellipsis; min-width: 0;
}
.sw-row-btn {
  border: 0; background: transparent; color: var(--app-muted); padding: 2px; line-height: 1;
  display: inline-flex; flex: 0 0 auto; border-radius: 4px;
}
.sw-row-btn:hover { color: var(--bs-primary); background: rgba(var(--bs-primary-rgb), .1); }
.sw-row-btn.is-delete:hover { color: #dc3545; background: rgba(220, 53, 69, .1); }
.sw-swatch { width: 14px; height: 14px; border-radius: 4px; border: 1px solid rgba(0, 0, 0, .1); flex: 0 0 auto; }
.sw-drag-ghost { opacity: .4; }

.sw-preview-card { margin-bottom: 0; }
.sw-preview-head {
  display: flex; flex-direction: column; align-items: center; gap: 2px;
  margin-bottom: 8px; text-align: center;
}
.sw-hints { line-height: 1.5; }


/* Per-country money: country on the left, its own currency on every field. */
.sw-amounts { border-top: 1px dashed var(--bs-border-color); padding-top: 10px; }
.sw-amt-grid { display: grid; column-gap: 8px; row-gap: 6px; align-items: center; }
.sw-amt-head {
  font-size: 10.5px; font-weight: 600; text-transform: uppercase; letter-spacing: .02em;
  color: var(--bs-secondary-color); padding-bottom: 2px;
}
.sw-amt-country {
  display: flex; align-items: center; gap: 6px; min-width: 0;
  font-size: 12.5px; font-weight: 500;
}
/* Fixed-width chip so a three-letter code and a one-glyph symbol still align. */
.sw-amt-grid .input-group-text {
  min-width: 40px; justify-content: center; padding: .15rem .3rem; font-size: 11px;
}
/* Spinners add nothing to a price field and crowd a narrow column. */
.sw-amt-grid input[type="number"] { -moz-appearance: textfield; }
.sw-amt-grid input[type="number"]::-webkit-outer-spin-button,
.sw-amt-grid input[type="number"]::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }
.cz-flag { width: 18px; height: 12px; object-fit: cover; border-radius: 2px; flex: 0 0 auto; }

.sw-editor .card, .sw-editor .card-body { overflow: visible; }
.sw-editor :deep(.multiselect) { z-index: 1; }
.sw-editor :deep(.multiselect--active) { z-index: 1000; }
.sw-editor :deep(.multiselect__content-wrapper) { z-index: 1000; }
</style>
