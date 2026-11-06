<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('edit_country') }}</h3>
                <router-link to="/countries" class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <section class="section">
                <div v-if="isLoadingData" class="text-center p-5"><b-spinner label="Loading..."></b-spinner></div>

                <form ref="my-form" @submit.prevent="saveRecord" v-show="!isLoadingData">
                    <div class="card">
                        <div class="card-body">
                            <div class="row g-0 country-stepper">
                                <!-- Left rail -->
                                <div class="col-md-2 step-rail">
                                    <ul class="list-unstyled mb-0">
                                        <li v-for="(s, i) in steps" :key="s.key"
                                            class="step-item d-flex align-items-center gap-2"
                                            :class="{ active: currentStep === i + 1, done: currentStep > i + 1 }"
                                            @click="goStep(i + 1)">
                                            <span class="step-num">
                                                <i v-if="currentStep > i + 1" class="fa fa-check"></i>
                                                <template v-else>{{ i + 1 }}</template>
                                            </span>
                                            <span class="step-label">{{ __(s.label) }}</span>
                                        </li>
                                    </ul>
                                </div>

                                <!-- Right content -->
                                <div class="col-md-10 step-content ps-md-4 pt-3 pt-md-0">

                                    <!-- ===== STEP 1: Country Details ===== -->
                                    <div v-if="currentStep === 1">
                                        <h4 class="fw-bold mb-1">{{ __('country_details') }}</h4>
                                        <p class="text-muted">{{ __('configure_basic_country_information') }}</p>

                                        <b-tabs v-model="activeLanguageTab" content-class="mt-3" v-if="languages.length"
                                            :nav-class="languages.length <= 1 ? 'd-none' : null">
                                            <b-tab v-for="language in languages" :key="'s1-' + language.id" :id="'cf-lang-' + language.id">
                                                <template #title>
                                                    <span :class="{ 'text-primary font-weight-bold': language.is_default }">{{ language.name }}</span>
                                                </template>

                                                <div class="row">
                                                    <div class="form-group mt-0" :class="language.is_default ? 'col-md-4' : 'col-md-12'">
                                                        <label>{{ __('name') }} <i v-if="language.is_default" class="text-danger">*</i></label>
                                                        <input type="text" class="form-control" v-model="translations[language.id].name"
                                                            :required="language.is_default == 1 ? true : undefined" :placeholder="__('name')">
                                                    </div>

                                                    <template v-if="language.is_default">
                                                        <div class="form-group col-md-4">
                                                            <label>{{ __('dial_code') }} <span class="text-danger">*</span></label>
                                                            <input type="text" class="form-control" v-model="dial_code" required :placeholder="__('dial_code')">
                                                        </div>
                                                        <div class="form-group col-md-4">
                                                            <label>{{ __('country_code') }} <span class="text-danger">*</span></label>
                                                            <input type="text" class="form-control" v-model="code" required :placeholder="__('country_code')" :disabled="!!id">
                                                        </div>

                                                        <div class="form-group col-md-4">
                                                            <label>{{ __('min_mobile_number_count') }}</label>
                                                            <input type="number" min="4" max="15" step="1" class="form-control"
                                                                v-model.number="form.min_mobile_length">
                                                            <small class="text-muted">{{ __('min_mobile_number_count_help') }}</small>
                                                        </div>
                                                        <div class="form-group col-md-4">
                                                            <label>{{ __('max_mobile_number_count') }}</label>
                                                            <input type="number" min="4" max="15" step="1" class="form-control"
                                                                v-model.number="form.max_mobile_length">
                                                            <small class="text-muted">{{ __('max_mobile_number_count_help') }}</small>
                                                        </div>

                                                        <div class="form-group col-md-4">
                                                            <label>{{ __('date_format') }}</label>
                                                            <AppSelect class="form-select" v-model="form.date_format"
                                                                :options="dateFormatOptions" label-key="label"
                                                                track-by="value" :searchable="false" />
                                                        </div>
                                                        <div class="form-group col-md-4">
                                                            <label>{{ __('time_format') }}</label>
                                                            <AppSelect class="form-select" v-model="form.time_format"
                                                                :options="timeFormatOptions" label-key="label"
                                                                track-by="value" :searchable="false" />
                                                        </div>
                                                        <div class="form-group col-md-4">
                                                            <label>{{ __('timezone') }} <span class="text-danger">*</span></label>
                                                            <AppSelect class="form-select" v-model="form.timezone"
                                                                :options="timezoneSelectOptions" />
                                                            <small class="text-muted d-block mt-1">{{ __('timezone_usage_note') }}</small>
                                                        </div>

                                                        <!-- Buyer tax registration. A business buyer has to be able to put
                                                             its own number on the order, and what that number is called is
                                                             local: GSTIN in India, VAT Number in the EU, TRN in the UAE. -->
                                                        <div class="form-group col-md-4">
                                                            <label class="d-block">
                                                                {{ __('buyer_tax_number_field') }}
                                                                <i class="fa fa-circle-info text-muted ms-1" v-b-tooltip.hover
                                                                    :title="__('buyer_tax_number_field_help')"></i>
                                                            </label>
                                                            <div class="form-check form-switch">
                                                                <input class="form-check-input" type="checkbox" role="switch"
                                                                    id="buyer_tax_enabled" v-model="form.buyer_tax_enabled">
                                                                <label class="form-check-label" for="buyer_tax_enabled">
                                                                    {{ form.buyer_tax_enabled ? __('asked_at_checkout') : __('not_asked') }}
                                                                </label>
                                                            </div>
                                                        </div>

                                                        <div class="form-group col-md-4" v-if="form.buyer_tax_enabled">
                                                            <label>{{ __('tax_number_label') }}</label>
                                                            <input type="text" class="form-control" maxlength="48"
                                                                v-model="form.buyer_tax_label" placeholder="GSTIN">
                                                            <small class="text-muted">{{ __('tax_number_label_help') }}</small>
                                                        </div>

                                                        <div class="form-group col-md-4" v-if="form.buyer_tax_enabled">
                                                            <label>{{ __('tax_number_format') }}</label>
                                                            <input type="text" class="form-control" maxlength="191"
                                                                :class="{ 'is-invalid': buyerTaxRegexInvalid }"
                                                                v-model="form.buyer_tax_regex" placeholder="^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$">
                                                            <!-- A broken pattern would turn away every number a buyer typed, with
                                                                 nothing on the checkout screen to say why. Say so here instead. -->
                                                            <small v-if="buyerTaxRegexInvalid" class="text-danger d-block">{{ __('invalid_tax_number_format_pattern') }}</small>
                                                            <small v-else-if="buyerTaxRegexUnanchored" class="text-warning d-block">{{ __('tax_number_format_not_anchored') }}</small>
                                                            <small v-else class="text-muted d-block">{{ __('tax_number_format_help') }}</small>

                                                            <!-- A pattern can be perfectly valid and still accept nothing a buyer
                                                                 would ever type. Only trying a real number shows that, so the
                                                                 field to try one sits right here. -->
                                                            <div v-if="form.buyer_tax_regex && !buyerTaxRegexInvalid" class="mt-2">
                                                                <input type="text" class="form-control form-control-sm"
                                                                    v-model="buyerTaxSample" :placeholder="__('try_a_number')">
                                                                <small v-if="buyerTaxSample" class="d-block"
                                                                    :class="buyerTaxSampleMatches ? 'text-success' : 'text-danger'">
                                                                    {{ buyerTaxSampleMatches ? __('this_number_would_be_accepted') : __('this_number_would_be_refused') }}
                                                                </small>
                                                            </div>
                                                        </div>

                                                        <div class="form-group col-md-4">
                                                            <label class="d-block">{{ __('status') }}</label>
                                                            <div class="btn-group btn-group-toggle d-block" role="group">
                                                                <label class="btn btn-outline-primary" :class="{ active: status == 0 }">
                                                                    <input type="radio" :value="0" v-model.number="status"> {{ __('deactive') }}
                                                                </label>
                                                                <label class="btn btn-outline-primary" :class="{ active: status == 1 }">
                                                                    <input type="radio" :value="1" v-model.number="status"> {{ __('active') }}
                                                                </label>
                                                            </div>
                                                        </div>

                                                        <div class="col-md-4">
                                                            <FileUpload v-model="logo" :label="__('flag')" required accept="image/*"
                                                                recommended-size="64x64px" :preview-url="logo_url" />
                                                        </div>
                                                    </template>
                                                </div>
                                            </b-tab>

                                            <!-- Translate control, inline with the language tabs. Only on this
                                                 first tab row — the policy tab rows below share the same v-model. -->
                                            <template #tabs-end>
                                                <li class="nav-item ms-auto d-flex align-items-center">
                                                    <TranslateLanguages :languages="languages"
                                                        :default-language-id="defaultLanguageId" :busy="translating"
                                                        :progress="translateProgress" @translate="runTranslate" />
                                                </li>
                                            </template>
                                        </b-tabs>
                                    </div>

                                    <!-- ===== STEP 2: Payment Gateways ===== -->
                                    <div v-if="currentStep === 2">
                                        <h4 class="fw-bold mb-1">{{ __('currency') }} &amp; {{ __('payment_gateways') }}</h4>
                                        <p class="text-muted">{{ __('configure_currency_and_payment_gateways') }}</p>
                                        <div class="alert alert-info py-2 small">Online gateways are disabled for CakeZake — only COD, pay at counter, eSewa, bank transfer and QR payment are offered. Manage them in <router-link to="/payment_methods">Payment methods</router-link>. Any gateway keys below are ignored.</div>
                                        <PaymentGatewaysSection :form="form" />
                                    </div>

                                    <!-- ===== STEP 3: Refer & Earn ===== -->
                                    <div v-if="currentStep === 3">
                                        <h4 class="fw-bold mb-1">{{ __('refer_earn_setting') }}</h4>
                                        <p class="text-muted">{{ __('configure_referral_rewards') }}</p>
                                        <div class="alert alert-info py-2">
                                            <i class="fa fa-info-circle me-1"></i> {{ __('refer_earn_note') }}
                                        </div>
                                        <div class="row">
                                            <div class="form-group col-md-4">
                                                <label>{{ __('referral_min_order_amount') }}</label>
                                                <input type="number" min="0" step="0.01" class="form-control" v-model.number="form.referral_min_order_amount">
                                                <small class="text-muted">{{ __('referral_min_order_amount_help') }}</small>
                                            </div>
                                            <div class="form-group col-md-4">
                                                <label>{{ __('referrer_reward_amount') }}</label>
                                                <input type="number" min="0" step="0.01" class="form-control" v-model.number="form.referral_credit_first_order">
                                                <small class="text-muted">{{ __('referrer_reward_help') }}</small>
                                            </div>
                                            <div class="form-group col-md-4">
                                                <label>{{ __('referred_user_reward_amount') }}</label>
                                                <input type="number" min="0" step="0.01" class="form-control" v-model.number="form.referral_credit_referred">
                                                <small class="text-muted">{{ __('referred_user_reward_help') }}</small>
                                            </div>
                                            <div class="form-group col-md-4">
                                                <label>{{ __('referral_usage_limit') }}</label>
                                                <input type="number" min="0" step="1" class="form-control" v-model="form.referral_usage_limit" :placeholder="__('unlimited')">
                                                <small class="text-muted">{{ __('referral_usage_limit_help') }}</small>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- ===== STEP 4: Customer Policies ===== -->
                                    <div v-if="currentStep === 4">
                                        <h4 class="fw-bold mb-1">{{ __('customer_policies') }}</h4>
                                        <!-- b-tabs used as the language nav; editors rendered below for the active language. -->
                                        <b-tabs v-model="activeLanguageTab" v-if="languages.length"
                                            :nav-class="languages.length <= 1 ? 'd-none' : null">
                                            <b-tab v-for="language in languages" :key="'s4-' + language.id" :id="'cf-lang-' + language.id">
                                                <template #title>
                                                    <span :class="{ 'text-primary font-weight-bold': language.is_default }">{{ language.name }}</span>
                                                </template>
                                            </b-tab>
                                        </b-tabs>
                                        <!-- Keyed by language: the whole block remounts on tab switch. Keying the
                                             <editor> alone makes Vue patch siblings around TinyMCE-mutated DOM
                                             (insertBefore errors, editors randomly missing). -->
                                        <div v-if="activeLanguage" :key="'s4-lang-' + activeLanguage.id">
                                            <div class="form-group" v-for="(p, idx) in customerPolicies" :key="p.field">
                                                <div class="d-flex w-100 align-items-center mb-2">
                                                    <label class="mb-0">{{ __(p.label) }} <i class="text-danger" v-if="activeLanguage.is_default">*</i></label>
                                                    <a v-if="id" :href="viewUrl(p.view, activeLanguage.code)" target="_blank"
                                                        class="btn btn-sm btn-primary ms-auto" v-b-tooltip.hover :title="__('view')"><i class="fa fa-eye"></i></a>
                                                </div>
                                                <editor v-if="tinymceReady"
                                                    v-model="translations[activeLanguage.id][p.field]"
                                                    :init="tinymceInit"
                                                    tinymce-script-src="/assets/js/tinymce/tinymce.min.js?v=7922"
                                                    license-key="gpl" />
                                                <div v-else class="text-muted small py-2"><b-spinner small></b-spinner> {{ __('loading') }}</div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- ===== STEP 5: Delivery Partner Policies ===== -->
                                    <div v-if="currentStep === 5">
                                        <h4 class="fw-bold mb-1">{{ __('delivery_boy_policies') }}</h4>
                                        <b-tabs v-model="activeLanguageTab" v-if="languages.length"
                                            :nav-class="languages.length <= 1 ? 'd-none' : null">
                                            <b-tab v-for="language in languages" :key="'s5-' + language.id" :id="'cf-lang-' + language.id">
                                                <template #title>
                                                    <span :class="{ 'text-primary font-weight-bold': language.is_default }">{{ language.name }}</span>
                                                </template>
                                            </b-tab>
                                        </b-tabs>
                                        <div v-if="activeLanguage" :key="'s5-lang-' + activeLanguage.id">
                                            <div class="form-group" v-for="(p, idx) in deliveryPolicies" :key="p.field">
                                                <div class="d-flex w-100 align-items-center mb-2">
                                                    <label class="mb-0">{{ __(p.label) }} <i class="text-danger" v-if="activeLanguage.is_default">*</i></label>
                                                    <a v-if="id" :href="viewUrl(p.view, activeLanguage.code)" target="_blank"
                                                        class="btn btn-sm btn-primary ms-auto" v-b-tooltip.hover :title="__('view')"><i class="fa fa-eye"></i></a>
                                                </div>
                                                <editor v-if="tinymceReady"
                                                    v-model="translations[activeLanguage.id][p.field]"
                                                    :init="tinymceInit"
                                                    tinymce-script-src="/assets/js/tinymce/tinymce.min.js?v=7922"
                                                    license-key="gpl" />
                                                <div v-else class="text-muted small py-2"><b-spinner small></b-spinner> {{ __('loading') }}</div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Nav buttons -->
                                    <div class="d-flex justify-content-between mt-4">
                                        <button type="button" class="btn btn-outline-secondary" :disabled="currentStep === 1" @click="prevStep">
                                            <i class="fa fa-arrow-left"></i> {{ __('previous') }}
                                        </button>
                                        <div>
                                            <router-link to="/countries" class="btn btn-secondary me-2">{{ __('cancel') }}</router-link>
                                            <button v-if="currentStep < steps.length" type="button" class="btn btn-primary" @click="nextStep">
                                                {{ __('next') }} <i class="fa fa-arrow-right"></i>
                                            </button>
                                            <button v-else type="submit" class="btn btn-primary" :disabled="isLoading">
                                                <b-spinner small v-if="isLoading"></b-spinner> {{ id ? __('update') : __('save') }}
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </form>
            </section>
        </div>
    </div>
</template>

<script>
import axios from 'axios'
import Editor from '@tinymce/tinymce-vue'
import { tinymceInit as buildTinymceInit } from '../../utils/tinymce.js'
import TranslationHelper from '../../mixins/TranslationHelper.js'
import UnsavedChanges from '../../mixins/UnsavedChanges.js'
import PaymentGatewaysSection from './PaymentGatewaysSection.vue'
import { defaultGateways, fillMissingModes } from '../../utils/paymentGateways.js'
import { ArrowLeft } from 'lucide-vue-next'

export default {
    name: 'CountryForm',
    mixins: [TranslationHelper, UnsavedChanges],
    components: { PaymentGatewaysSection, editor: Editor, ArrowLeft },
    data() {
        return {
            isLoadingData: true,
            isLoading: false,
            // Load the TinyMCE script ONCE up-front, then render editors. Prevents the
            // race where 5 policy editors each try to load the script concurrently
            // (some ending up blank).
            tinymceReady: false,
            // Same self-hosted TinyMCE config as the product form.
            tinymceInit: buildTinymceInit({ height: 320 }),
            currentStep: 1,
            // Admin-only scratch field: a number typed to try the pattern, never saved.
            buyerTaxSample: '',
            steps: [
                { key: 'details', label: 'country_details' },
                { key: 'payments', label: 'payment_gateways' },
                { key: 'refer', label: 'refer_earn_setting' },
                { key: 'customer_policies', label: 'customer_policies' },
                { key: 'delivery_policies', label: 'delivery_boy_policies' },
            ],

            id: this.$route.params.id || null,
            dial_code: '',
            code: '',
            logo_url: null,
            status: 1,
            logo: null,

            languages: [],
            translations: {},
            activeLanguageTab: 0,
            defaultLanguageId: null,
            translatableFields: ['name', 'privacy_policy', 'return_policy', 'shipping_policy', 'cancellation_policy', 'terms_conditions', 'privacy_policy_delivery_boy', 'terms_conditions_delivery_boy'],

            customerPolicies: [
                { field: 'privacy_policy', label: 'privacy_policy', view: 'customer-privacy-policy' },
                { field: 'return_policy', label: 'return_policy', view: 'customer-returns-and-exchanges-policy' },
                { field: 'shipping_policy', label: 'shipping_policy', view: 'customer-shipping-policy' },
                { field: 'cancellation_policy', label: 'cancellation_policy', view: 'customer-cancellation-policy' },
                { field: 'terms_conditions', label: 'terms_conditions', view: 'customer-terms-conditions' },
            ],
            deliveryPolicies: [
                { field: 'privacy_policy_delivery_boy', label: 'privacy_policy', view: 'delivery-boy-privacy-policy' },
                { field: 'terms_conditions_delivery_boy', label: 'terms_conditions', view: 'delivery-boy-terms-conditions' },
            ],

            form: {
                currency: '',
                currency_code: '',
                decimal_point: 2,
                min_mobile_length: 7,
                max_mobile_length: 15,
                payment_gateways: defaultGateways(),
                date_format: 'd-m-Y',
                time_format: 'h:i A',
                timezone: 'UTC',
                referral_min_order_amount: 0,
                referral_credit_first_order: 0,
                referral_credit_referred: 0,
                referral_usage_limit: '',
                buyer_tax_enabled: false,
                buyer_tax_label: '',
                buyer_tax_regex: '',
            },

            dateFormatOptions: [
                { value: 'd-m-Y', label: 'DD-MM-YYYY' },
                { value: 'm-d-Y', label: 'MM-DD-YYYY' },
                { value: 'Y-m-d', label: 'YYYY-MM-DD' },
                { value: 'd/m/Y', label: 'DD/MM/YYYY' },
                { value: 'm/d/Y', label: 'MM/DD/YYYY' },
                { value: 'd M Y', label: 'DD Mon YYYY' },
            ],
            timeFormatOptions: [
                { value: 'h:i A', label: '12 Hour (hh:mm AM/PM)' },
                { value: 'H:i', label: '24 Hour (HH:mm)' },
            ],
        }
    },
    computed: {
        /* An unparsable pattern is worse than none: it matches nothing, so every number a
           buyer enters is refused. JavaScript's engine is close enough to the server's to
           catch a typo here, and the server checks it again on save. */
        buyerTaxRegexInvalid() {
            const pattern = String(this.form.buyer_tax_regex || '').trim();
            if (!pattern) return false;
            try {
                new RegExp(pattern);
                return false;
            } catch {
                return true;
            }
        },
        /* An unanchored pattern passes anything that merely CONTAINS a match, so
           `[0-9]{2}` would accept a whole paragraph with two digits in it. Valid, almost
           never intended, and invisible until a bad number is already on an invoice. */
        buyerTaxRegexUnanchored() {
            const pattern = String(this.form.buyer_tax_regex || '').trim();
            if (!pattern || this.buyerTaxRegexInvalid) return false;
            return !pattern.startsWith('^') || !pattern.endsWith('$');
        },
        buyerTaxSampleMatches() {
            const pattern = String(this.form.buyer_tax_regex || '').trim();
            const sample = String(this.buyerTaxSample || '').replace(/\s+/g, '').toUpperCase();
            if (!pattern || !sample || this.buyerTaxRegexInvalid) return false;
            try {
                // Same normalisation the server applies before it matches.
                return new RegExp(pattern).test(sample);
            } catch {
                return false;
            }
        },
        // timezoneOptions is a plain string list; AppSelect works in { id, name }.
        timezoneSelectOptions() {
            return (this.timezoneOptions || []).map(tz => {
                const off = this.tzOffset(tz);
                return { id: tz, name: off ? `${tz} (${off})` : tz };
            });
        },
        timezoneOptions() {
            let list;
            try {
                list = Intl.supportedValuesOf('timeZone');
            } catch {
                list = ['UTC'];
            }
            // The stored value may be an alias the browser list doesn't contain
            // (e.g. DB "Asia/Kolkata" vs Chrome's "Asia/Calcutta") — keep it
            // selectable so the edit form never shows an empty select.
            const cur = this.form.timezone;
            if (cur && !list.includes(cur)) list = [cur, ...list];
            if (!list.includes('UTC')) list = ['UTC', ...list];
            return list;
        },
        allPolicyFields() {
            return [...this.customerPolicies, ...this.deliveryPolicies].map(p => p.field);
        },
        // bootstrap-vue-next b-tabs v-model is the tab id STRING ('cf-lang-<id>'),
        // not an index — but we also seed it with a number before tabs mount.
        activeLanguage() {
            const v = this.activeLanguageTab;
            const m = String(v ?? '').match(/^cf-lang-(\d+)$/);
            if (m) return this.languages.find(l => l.id === parseInt(m[1], 10)) || null;
            if (typeof v === 'number') return this.languages[v] || null;
            return this.languages[0] || null;
        },
    },
    created() {
        if (!this.id) this.form.payment_gateways.cod_payment_method = 1;
        this.deferDataLoad();
    },
    mounted() {
        this.loadTinymce();
    },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return {
                dial_code: this.dial_code,
                code: this.code,
                status: this.status,
                logo: this.logo,
                translations: this.translations,
                form: this.form,
            };
        },
        // GMT offset for a tz via Intl (e.g. "GMT+5:30"); '' if unsupported.
        tzOffset(tz) {
            try {
                const parts = new Intl.DateTimeFormat('en-US', { timeZone: tz, timeZoneName: 'shortOffset' })
                    .formatToParts(new Date());
                return parts.find(p => p.type === 'timeZoneName')?.value || '';
            } catch {
                return '';
            }
        },
        // Ensure window.tinymce exists before any <editor> mounts (single script load).
        loadTinymce() {
            if (window.tinymce) { this.tinymceReady = true; return; }
            const src = '/assets/js/tinymce/tinymce.min.js?v=7922';
            let s = document.querySelector('script[data-tinymce-loader]');
            if (!s) {
                s = document.createElement('script');
                s.src = src;
                s.setAttribute('data-tinymce-loader', '1');
                s.referrerPolicy = 'origin';
                document.head.appendChild(s);
            }
            const done = () => { this.tinymceReady = true; };
            if (window.tinymce) { done(); return; }
            s.addEventListener('load', done);
            s.addEventListener('error', done); // fall through — editor will try its own src
        },
        emptyTranslation() {
            const t = { name: '' };
            this.allPolicyFields.forEach(f => { t[f] = ''; });
            return t;
        },
        parseObj(v) {
            if (!v) return {};
            if (typeof v === 'object') return v;
            try { return JSON.parse(v) || {}; } catch { return {}; }
        },
        viewUrl(path, langCode = '') {
            return `${this.$baseUrl}/${path}?country_id=${this.id}&lang=${langCode}`;
        },
        deferDataLoad() {
            this.isLoadingData = true;
            this.fetchActiveLanguages().then(() => {
                const def = this.languages.find(l => l.is_default == 1);
                if (def) {
                    this.defaultLanguageId = def.id;
                    this.activeLanguageTab = 'cf-lang-' + def.id;
                }
                if (this.id) return this.loadCountry();
                this.isLoadingData = false;
            }).then(() => {
                // Baseline the loaded form for the UnsavedChanges guard.
                this.captureFormBaseline();
            }).catch(() => { this.isLoadingData = false; });
        },
        fetchActiveLanguages() {
            return axios.get(this.$apiUrl + '/active_languages').then(res => {
                this.languages = res.data.data || [];
                const t = {};
                this.languages.forEach(l => { t[l.id] = this.emptyTranslation(); });
                this.translations = t;
                return this.languages;
            });
        },
        loadCountry() {
            return axios.get(this.$apiUrl + '/countries', { params: { id: this.id } }).then(res => {
                const country = Array.isArray(res.data.data) ? res.data.data[0] : res.data.data;
                if (!country) { this.isLoadingData = false; return; }
                this.dial_code = country.dial_code;
                this.code = country.code;
                this.status = country.status;
                this.logo_url = country.logo_url;

                this.form.currency = country.currency || '';
                this.form.currency_code = country.currency_code || '';
                this.form.decimal_point = country.decimal_point ?? 2;
                this.form.min_mobile_length = Number(country.min_mobile_length || 7);
                this.form.max_mobile_length = Number(country.max_mobile_length || 15);
                // A stored '' would leave the mode dropdown blank; fill it with the default.
                this.form.payment_gateways = fillMissingModes({ ...defaultGateways(), ...this.parseObj(country.payment_gateways) });
                this.form.date_format = country.date_format || 'd-m-Y';
                this.form.time_format = country.time_format || 'h:i A';
                this.form.timezone = country.timezone || 'UTC';
                this.form.referral_min_order_amount = Number(country.referral_min_order_amount || 0);
                this.form.referral_credit_first_order = Number(country.referral_credit_first_order || 0);
                this.form.referral_credit_referred = Number(country.referral_credit_referred || 0);
                this.form.referral_usage_limit = (country.referral_usage_limit ?? '') === null ? '' : (country.referral_usage_limit ?? '');
                this.form.buyer_tax_enabled = Number(country.buyer_tax_enabled || 0) === 1;
                this.form.buyer_tax_label = country.buyer_tax_label || '';
                this.form.buyer_tax_regex = country.buyer_tax_regex || '';

                const t = {};
                this.languages.forEach(l => { t[l.id] = this.emptyTranslation(); });
                if (Array.isArray(country.translations)) {
                    country.translations.forEach(tr => {
                        if (!t[tr.language_id]) t[tr.language_id] = this.emptyTranslation();
                        t[tr.language_id].name = tr.name || '';
                        this.allPolicyFields.forEach(f => { t[tr.language_id][f] = tr[f] || ''; });
                    });
                }
                const def = this.languages.find(l => l.is_default == 1);
                if (def && !t[def.id].name) t[def.id].name = country.name || '';
                this.translations = t;
                this.isLoadingData = false;
            }).catch(() => { this.isLoadingData = false; });
        },

        /* ---- navigation + per-step validation ---- */
        stripHtml(v) { return String(v || '').replace(/<[^>]*>/g, '').trim(); },
        // Validate one step. showErr=false → silent (used when jumping). Returns true if valid.
        validateStep(step, showErr = true) {
            const def = this.translations[this.defaultLanguageId] || {};
            const fail = (msg, toDefaultLang) => {
                if (showErr) {
                    this.showError(msg);
                    if (toDefaultLang) this.switchToDefaultLanguageTab();
                }
                return false;
            };
            if (step === 1) {
                if (!def.name || !def.name.trim()) return fail(__('please_fill_default_language_required_fields'), true);
                if (!String(this.dial_code || '').trim() || !String(this.code || '').trim())
                    return fail(__('please_fill_default_language_required_fields'), true);
                if (!this.id && !this.logo && !this.logo_url) return fail(__('flag') + ' ' + __('is_required'), true);
                if (!String(this.form.timezone || '').trim()) return fail(__('timezone') + ' ' + __('is_required'), true);
            } else if (step === 2) {
                if (!String(this.form.currency || '').trim() || !String(this.form.currency_code || '').trim())
                    return fail(__('currency_symbol') + ' & ' + __('currency_code') + ' ' + __('is_required'), false);
                const gw = this.form.payment_gateways || {};
                const anyEnabled = Object.keys(gw).some(k => k.endsWith('_payment_method') && (gw[k] === 1 || gw[k] === '1' || gw[k] === true));
                if (!anyEnabled) return fail(__('at_least_one_payment_method_must_be_enabled'), false);
            } else if (step === 4) {
                if (this.customerPolicies.some(p => !this.stripHtml(def[p.field])))
                    return fail(__('please_fill_all_policies_in_default_language'), true);
            } else if (step === 5) {
                if (this.deliveryPolicies.some(p => !this.stripHtml(def[p.field])))
                    return fail(__('please_fill_all_policies_in_default_language'), true);
            }
            // step 3 (refer & earn) has no required fields.
            return true;
        },
        goStep(n) {
            if (n <= this.currentStep) { this.currentStep = n; return; }
            // Forward jump: every step in between must be valid.
            for (let s = this.currentStep; s < n; s++) {
                if (!this.validateStep(s)) { this.currentStep = s; return; }
            }
            this.currentStep = n;
        },
        nextStep() {
            if (!this.validateStep(this.currentStep)) return;
            if (this.currentStep < this.steps.length) this.currentStep++;
        },
        prevStep() {
            if (this.currentStep > 1) this.currentStep--;
        },

        switchToDefaultLanguageTab() {
            if (this.defaultLanguageId) this.activeLanguageTab = 'cf-lang-' + this.defaultLanguageId;
        },
        missingPolicyStep() {
            const def = this.translations[this.defaultLanguageId] || {};
            const strip = (v) => String(v || '').replace(/<[^>]*>/g, '').trim();
            if (this.customerPolicies.some(p => !strip(def[p.field]))) return 4;
            if (this.deliveryPolicies.some(p => !strip(def[p.field]))) return 5;
            return 0;
        },
        async saveRecord() {
            const def = this.translations[this.defaultLanguageId];
            if (!def || !def.name || def.name.trim() === '') {
                this.showError(__('please_fill_default_language_required_fields'));
                this.switchToDefaultLanguageTab();
                this.currentStep = 1;
                return;
            }
            if (!this.dial_code || !this.code) {
                this.showError(__('please_fill_default_language_required_fields'));
                this.currentStep = 1;
                return;
            }
            if (!this.id && !this.logo && !this.logo_url) {
                this.showError(this.__('please_fill_default_language_required_fields'));
                this.currentStep = 1;
                return;
            }
            // Currency symbol + code required.
            if (!String(this.form.currency || '').trim() || !String(this.form.currency_code || '').trim()) {
                this.showError(__('currency_symbol') + ' & ' + __('currency_code') + ' ' + __('is_required'));
                this.currentStep = 2;
                return;
            }
            // At least one payment gateway enabled.
            const gw = this.form.payment_gateways || {};
            const anyEnabled = Object.keys(gw).some(k => k.endsWith('_payment_method') && (gw[k] === 1 || gw[k] === '1' || gw[k] === true));
            if (!anyEnabled) {
                this.showError(__('at_least_one_payment_method_must_be_enabled'));
                this.currentStep = 2;
                return;
            }
            // A pattern that cannot compile would refuse every buyer tax number.
            if (this.buyerTaxRegexInvalid) {
                this.showError(__('invalid_tax_number_format_pattern'));
                this.currentStep = 1;
                return;
            }
            // Policies required in default language.
            const missStep = this.missingPolicyStep();
            if (missStep) {
                this.showError(__('please_fill_all_policies_in_default_language'));
                this.switchToDefaultLanguageTab();
                this.currentStep = missStep;
                return;
            }

            this.isLoading = true;
            try {
                const fd = new FormData();
                if (this.id) fd.append('id', this.id);
                fd.append('dial_code', this.dial_code);
                fd.append('code', this.code);
                fd.append('status', this.status);
                fd.append('translations', JSON.stringify(this.translations));

                fd.append('currency', this.form.currency ?? '');
                fd.append('currency_code', this.form.currency_code ?? '');
                fd.append('decimal_point', this.form.decimal_point ?? 2);
                fd.append('min_mobile_length', this.form.min_mobile_length ?? 7);
                fd.append('max_mobile_length', this.form.max_mobile_length ?? 15);
                fd.append('date_format', this.form.date_format ?? 'd-m-Y');
                fd.append('time_format', this.form.time_format ?? 'h:i A');
                fd.append('timezone', this.form.timezone ?? 'UTC');
                fd.append('referral_min_order_amount', this.form.referral_min_order_amount ?? 0);
                fd.append('referral_credit_first_order', this.form.referral_credit_first_order ?? 0);
                fd.append('referral_credit_referred', this.form.referral_credit_referred ?? 0);
                // Blank = unlimited (controller branches NULL).
                fd.append('referral_usage_limit', this.form.referral_usage_limit ?? '');
                fd.append('payment_gateways', JSON.stringify(this.form.payment_gateways));
                fd.append('buyer_tax_enabled', this.form.buyer_tax_enabled ? 1 : 0);
                fd.append('buyer_tax_label', this.form.buyer_tax_label ?? '');
                fd.append('buyer_tax_regex', this.form.buyer_tax_regex ?? '');

                const logoFile = this.logo;
                if (logoFile) fd.append('logo', logoFile, logoFile.name);

                const url = this.id ? this.$apiUrl + '/countries/update' : this.$apiUrl + '/countries/save';
                const res = await axios.post(url, fd);
                const msg = res?.data?.message || __(this.id ? 'country_updated_successfully' : 'country_saved_successfully');
                this.showMessage('success', msg);
                this.$eventBus.emit('countriesChanged');
                // Mark clean so the post-save redirect doesn't trip the guard.
                this.captureFormBaseline();
                this.$router.push({ path: '/countries' });
            } catch (e) {
                this.showError(e?.response?.data?.message || __('something_went_wrong'));
            }
            this.isLoading = false;
        },
    },
}
</script>

<style scoped>
.country-stepper .step-rail {
    border-right: 1px solid var(--app-card-border);
}
@media (max-width: 767.98px) {
    .country-stepper .step-rail { border-right: 0; border-bottom: 1px solid var(--app-card-border); padding-bottom: .5rem; }
}
.step-item {
    padding: .7rem .5rem;
    cursor: pointer;
    color: var(--app-muted);
    border-radius: .5rem;
}
.step-item:hover { background: var(--app-thead-bg); }
.step-item.active { color: #ea580c; font-weight: 700; }
.step-item.active .step-num { background: #ea580c; color: var(--app-card-bg); border-color: #ea580c; }
.step-item.done .step-num { background: #22c55e; color: var(--app-card-bg); border-color: #22c55e; }
.step-num {
    width: 28px; height: 28px; flex: none;
    border-radius: 50%;
    border: 2px solid #cbd5e1;
    display: inline-flex; align-items: center; justify-content: center;
    font-size: .8rem; font-weight: 700; background: var(--app-card-bg);
}
.step-label { font-size: .9rem; }
</style>
