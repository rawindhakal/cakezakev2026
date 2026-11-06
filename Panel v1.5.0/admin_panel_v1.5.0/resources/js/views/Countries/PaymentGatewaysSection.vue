<template>
    <div>
        <!-- Currency -->
        <div class="card">
            <div class="card-header">
                <h5 class="card-title text-uppercase mb-0">{{ __('currency') }}</h5>
            </div>
            <div class="card-body">
                <div class="row">
                    <div class="col-md-4 mb-3">
                        <label class="form-label">{{ __('currency_symbol') }} <span class="text-danger">*</span></label>
                        <input type="text" class="form-control" v-model="form.currency" placeholder="₹">
                    </div>
                    <div class="col-md-4 mb-3">
                        <label class="form-label">{{ __('currency_code') }} <span class="text-danger">*</span></label>
                        <input type="text" class="form-control" v-model="form.currency_code" placeholder="INR">
                    </div>
                    <div class="col-md-4 mb-3">
                        <label class="form-label">{{ __('decimal_point') }}</label>
                        <AppSelect class="form-select" v-model="form.decimal_point" :options="decimal_pointOptions" :searchable="false" />
                    </div>
                </div>
            </div>
        </div>

        <!-- Payment Gateways -->
        <div class="card">
            <div class="card-header">
                <h5 class="card-title text-uppercase mb-0">{{ __('payment_gateways') }}</h5>
            </div>
            <div class="card-body">
                <div class="row">
                    <!-- COD -->
                    <div class="col-md-6 mb-4">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">{{ __('cod_payments') }}</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0" v-model="form.payment_gateways.cod_payment_method">
                                </div>
                            </div>
                            <div class="card-body">
                                <div v-if="form.payment_gateways.cod_payment_method == 1" class="form-group">
                                    <label>{{ __('cod_mode') }}</label>
                                    <p class="mb-1"><small><b>{{ __('global') }} :</b> {{ __('will_be_considered_for_all_the_products') }}.</small></p>
                                    <p class="mb-2"><small><b>{{ __('product_wise') }} :</b> {{ __('product_wise_cod_will_be_considered') }}.</small></p>
                                    <AppSelect class="form-control form-select" v-model="form.payment_gateways.cod_mode" :options="cod_modeOptions" :searchable="false" />
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Pay at counter -->
                    <div class="col-md-6 mb-4">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">Pay at counter</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0" v-model="form.payment_gateways.counter_payment_method">
                                </div>
                            </div>
                            <div class="card-body">
                                <p class="text-muted small">Customer pays at the branch counter when collecting.</p>
                                <template v-if="form.payment_gateways.counter_payment_method == 1">
                                    <div class="form-group mb-3">
                                        <label>Instructions shown to customer</label>
                                        <input type="text" class="form-control" v-model="form.payment_gateways.counter_instructions" placeholder="e.g. Pay when you collect your order">
                                    </div>
                                </template>
                            </div>
                        </div>
                    </div>

                    <!-- eSewa -->
                    <div class="col-md-6 mb-4">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">eSewa</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0" v-model="form.payment_gateways.esewa_payment_method">
                                </div>
                            </div>
                            <div class="card-body">
                                <p class="text-muted small">Paid up front. The customer uploads a screenshot and staff verify it manually.</p>
                                <template v-if="form.payment_gateways.esewa_payment_method == 1">
                                    <div class="form-group mb-3">
                                        <label>eSewa ID / number</label>
                                        <input type="text" class="form-control" v-model="form.payment_gateways.esewa_id" placeholder="98XXXXXXXX">
                                    </div><div class="form-group mb-3">
                                        <label>Account name</label>
                                        <input type="text" class="form-control" v-model="form.payment_gateways.esewa_account_name" placeholder="">
                                    </div><div class="form-group mb-3">
                                        <label>QR image</label>
                                        <div v-if="form.payment_gateways.esewa_qr_image" class="mb-2">
                                            <img :src="storageUrl(form.payment_gateways.esewa_qr_image)" alt="QR" style="max-height:140px" class="border rounded p-1 d-block mb-1">
                                            <button type="button" class="btn btn-sm btn-outline-danger" @click="form.payment_gateways.esewa_qr_image = ''; form.esewa_qr = null">Remove</button>
                                        </div>
                                        <input type="file" class="form-control" accept="image/*" @change="form.esewa_qr = $event.target.files[0] || null">
                                    </div><div class="form-group mb-3">
                                        <label>Instructions</label>
                                        <input type="text" class="form-control" v-model="form.payment_gateways.esewa_instructions" placeholder="">
                                    </div>
                                </template>
                            </div>
                        </div>
                    </div>

                    <!-- Bank transfer -->
                    <div class="col-md-6 mb-4">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">Bank transfer</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0" v-model="form.payment_gateways.bank_payment_method">
                                </div>
                            </div>
                            <div class="card-body">
                                <p class="text-muted small">Paid up front. The customer uploads proof and staff verify it manually.</p>
                                <template v-if="form.payment_gateways.bank_payment_method == 1">
                                    <div class="form-group mb-3">
                                        <label>Bank name</label>
                                        <input type="text" class="form-control" v-model="form.payment_gateways.bank_name" placeholder="">
                                    </div><div class="form-group mb-3">
                                        <label>Account name</label>
                                        <input type="text" class="form-control" v-model="form.payment_gateways.bank_account_name" placeholder="">
                                    </div><div class="form-group mb-3">
                                        <label>Account number</label>
                                        <input type="text" class="form-control" v-model="form.payment_gateways.bank_account_number" placeholder="">
                                    </div><div class="form-group mb-3">
                                        <label>Branch</label>
                                        <input type="text" class="form-control" v-model="form.payment_gateways.bank_branch" placeholder="">
                                    </div><div class="form-group mb-3">
                                        <label>Instructions</label>
                                        <input type="text" class="form-control" v-model="form.payment_gateways.bank_instructions" placeholder="">
                                    </div>
                                </template>
                            </div>
                        </div>
                    </div>

                    <!-- QR payment -->
                    <div class="col-md-6 mb-4">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">QR payment</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0" v-model="form.payment_gateways.qr_payment_method">
                                </div>
                            </div>
                            <div class="card-body">
                                <p class="text-muted small">Upload your bank / wallet QR. The customer scans, pays and uploads proof for manual verification.</p>
                                <template v-if="form.payment_gateways.qr_payment_method == 1">
                                    <div class="form-group mb-3">
                                        <label>QR image</label>
                                        <div v-if="form.payment_gateways.qr_image" class="mb-2">
                                            <img :src="storageUrl(form.payment_gateways.qr_image)" alt="QR" style="max-height:140px" class="border rounded p-1 d-block mb-1">
                                            <button type="button" class="btn btn-sm btn-outline-danger" @click="form.payment_gateways.qr_image = ''; form.qr_image = null">Remove</button>
                                        </div>
                                        <input type="file" class="form-control" accept="image/*" @change="form.qr_image = $event.target.files[0] || null">
                                    </div><div class="form-group mb-3">
                                        <label>Instructions</label>
                                        <input type="text" class="form-control" v-model="form.payment_gateways.qr_instructions" placeholder="">
                                    </div>
                                </template>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import axios from 'axios';
import { currencyOptions, gatewayWebhookUrls } from '../../utils/paymentGateways.js';
import Auth from '../../Auth.js';

export default {
    name: 'CountryPaymentGatewaysSection',
    props: {
        // { currency, currency_code, decimal_point, payment_gateways } — mutated in place.
        form: { type: Object, required: true },
    },
    data() {
        // pluginGateways stays empty on an install with no payment plugin, so the section
        // renders exactly as before.
        return { currencyOptions, login_user: Auth.user, pluginGateways: [] };
    },
    methods: {
        storageUrl(path) {
            return /^https?:/.test(path) ? path : window.location.origin + '/storage/' + String(path).replace(/^\/+/, '');
        },
        /**
         * Gateways contributed by plugins, plus their default keys.
         *
         * The defaults are seeded into the form so a brand-new country saves the same
         * shape a core gateway does; existing values are never overwritten.
         */
        loadPluginGateways() {
            axios.get(this.$apiUrl + '/countries/plugin_payment_schemas')
                .then(res => {
                    if (res.data.status !== 1) return;
                    this.pluginGateways = res.data.data.gateways || [];
                    const defaults = res.data.data.defaults || {};
                    /* A key the country has never seen, or one saved empty before the
                       plugin declared a default — a blank mode would show as an empty
                       dropdown line. */
                    Object.keys(defaults).forEach(key => {
                        const current = this.form.payment_gateways[key];
                        if (current === undefined || current === '') {
                            this.form.payment_gateways[key] = defaults[key];
                        }
                    });
                })
                .catch(() => { /* no plugin gateways offered */ });
        },
        /** Manifest options are plain strings or { value, label } pairs. */
        pluginFieldOptions(field) {
            return (field.options || []).map(opt => (
                typeof opt === 'object'
                    ? { id: opt.value, name: __(opt.label ?? opt.value) }
                    : { id: opt, name: __(opt) }
            ));
        },
    },
    computed: {
        // In demo mode, hide third-party gateway credentials (same as other settings
        // pages). The primary super-admin (id 1) can still see/edit them.
        shouldHideCreds() {
            return this.$isDemo == 1 && (!this.login_user || this.login_user.id !== 1);
        },
        /* currencyOptions rows are { c: code, n: name }; AppSelect works in
           { id, name }. Paystack listed the name alone, the others "CODE - Name". */
        paypalCurrencyOptions() {
            return (this.currencyOptions.paypal || []).map(cc => ({ id: cc.c, name: `${cc.c} - ${cc.n}` }));
        },
        paystackCurrencyOptions() {
            return (this.currencyOptions.paystack || []).map(cc => ({ id: cc.c, name: cc.n }));
        },
        stripeCurrencyOptions() {
            return (this.currencyOptions.stripe || []).map(cc => ({ id: cc.c, name: `${cc.c} - ${cc.n}` }));
        },
        // Fixed option set — no search box needed.
        decimal_pointOptions() {
            return [
                { id: 0, name: '0' },
                { id: 1, name: '1' },
                { id: 2, name: '2' },
            ];
        },
        // Fixed option set — no search box needed.
        cod_modeOptions() {
            return [
                { id: 'global', name: (__('global')) },
                { id: 'product', name: (__('product_wise')) },
            ];
        },
        // Fixed option set — no search box needed.
        paypal_modeOptions() {
            return [
                { id: 'sandbox', name: (__('sandbox')) + ' ' + '(' + ' ' + (__('testing')) + ' ' + ')' },
                { id: 'production', name: (__('production')) + ' ' + '(' + ' ' + (__('live')) + ' ' + ')' },
            ];
        },
        // Fixed option set — no search box needed.
        stripe_modeOptions() {
            return [
                { id: 'sandbox', name: (__('sandbox')) + ' ' + '(' + ' ' + (__('testing')) + ' ' + ')' },
                { id: 'production', name: (__('production')) + ' ' + '(' + ' ' + (__('live')) + ' ' + ')' },
            ];
        },
        // Fixed option set — no search box needed.
        midtrans_modeOptions() {
            return [
                { id: 'sandbox', name: (__('sandbox')) + ' ' + '(' + ' ' + (__('testing')) + ' ' + ')' },
                { id: 'production', name: (__('production')) + ' ' + '(' + ' ' + (__('live')) + ' ' + ')' },
            ];
        },
        // Fixed option set — no search box needed.
        phonepay_modeOptions() {
            return [
                { id: 'uat', name: (__('sandbox')) + ' ' + '(' + ' ' + (__('testing')) + ' ' + ')' },
                { id: 'production', name: (__('production')) + ' ' + '(' + ' ' + (__('live')) + ' ' + ')' },
            ];
        },
        // Fixed option set — no search box needed.
        cashfree_modeOptions() {
            return [
                { id: 'sandbox', name: (__('sandbox')) + ' ' + '(' + ' ' + (__('testing')) + ' ' + ')' },
                { id: 'production', name: (__('production')) + ' ' + '(' + ' ' + (__('live')) + ' ' + ')' },
            ];
        },
        // Fixed option set — no search box needed.
        paytabs_modeOptions() {
            return [
                { id: 'sandbox', name: (__('sandbox')) + ' ' + '(' + ' ' + (__('testing')) + ' ' + ')' },
                { id: 'production', name: (__('production')) + ' ' + '(' + ' ' + (__('live')) + ' ' + ')' },
            ];
        },
        webhookUrls() {
            return gatewayWebhookUrls(this.$baseUrl, this.$websiteUrl);
        },
    },
};
</script>
