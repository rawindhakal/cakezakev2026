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

                    <!-- PayPal -->
                    <div class="col-md-6 mb-4">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">{{ __('paypal_payments') }}</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0" v-model="form.payment_gateways.paypal_payment_method">
                                </div>
                            </div>
                            <div class="card-body">
                                <template v-if="form.payment_gateways.paypal_payment_method == 1">
                                    <div class="form-group mb-3">
                                        <label>{{ __('payment_mode') }} <small>[ {{ __('sandbox') }} / {{ __('live') }} ]</small></label>
                                        <AppSelect class="form-control form-select" v-model="form.payment_gateways.paypal_mode" :options="paypal_modeOptions" :searchable="false" />
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('currency_code') }}</label>
                                        <AppSelect class="form-control form-select"
                                            v-model="form.payment_gateways.paypal_currency_code"
                                            :options="paypalCurrencyOptions"
                                            :placeholder="__('select_currency_code')" />
                                    </div>

                                    <div class="form-group mb-3">
                                        <label>{{ __('client_id') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.paypal_client_id" @input="!shouldHideCreds && (form.payment_gateways.paypal_client_id = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Paypal Client ID'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('client_secret') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.paypal_client_secret" @input="!shouldHideCreds && (form.payment_gateways.paypal_client_secret = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Paypal Client Secret'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('webhook_id') }} <small>({{ __('from_the_webhook_you_create_below') }})</small></label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.paypal_webhook_id" @input="!shouldHideCreds && (form.payment_gateways.paypal_webhook_id = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Paypal Webhook ID'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group">
                                        <label>{{ __('webhook_url') }} <small>({{ __('add_this_webhook_in_your_paypal_app') }})</small></label>
                                        <input type="text" class="form-control" :value="webhookUrls.paypal" placeholder="Paypal webhook URL" disabled>
                                    </div>
                                </template>
                            </div>
                        </div>
                    </div>

                    <!-- Razorpay -->
                    <div class="col-md-6 mb-4">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">{{ __('razorpay_payments') }}</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0" v-model="form.payment_gateways.razorpay_payment_method">
                                </div>
                            </div>
                            <div class="card-body">
                                <template v-if="form.payment_gateways.razorpay_payment_method == 1">
                                    <div class="form-group mb-3">
                                        <label>{{ __('razorpay_key_id') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.razorpay_key" @input="!shouldHideCreds && (form.payment_gateways.razorpay_key = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Razor Key ID'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group">
                                        <label>{{ __('secret_key') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.razorpay_secret_key" @input="!shouldHideCreds && (form.payment_gateways.razorpay_secret_key = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Razorpay Secret Key'" :readonly="shouldHideCreds">
                                    </div>
                                </template>
                            </div>
                        </div>
                    </div>

                    <!-- Paystack -->
                    <div class="col-md-6 mb-4">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">{{ __('paystack_payments') }}</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0" v-model="form.payment_gateways.paystack_payment_method">
                                </div>
                            </div>
                            <div class="card-body">
                                <template v-if="form.payment_gateways.paystack_payment_method == 1">
                                    <div class="form-group mb-3">
                                        <label>{{ __('paystack_public_key') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.paystack_public_key" @input="!shouldHideCreds && (form.payment_gateways.paystack_public_key = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Paystack Public key'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('paystack_secret_key') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.paystack_secret_key" @input="!shouldHideCreds && (form.payment_gateways.paystack_secret_key = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Paystack Secret Key'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group">
                                        <label>{{ __('currency_code') }}</label>
                                        <AppSelect class="form-control form-select"
                                            v-model="form.payment_gateways.paystack_currency_code"
                                            :options="paystackCurrencyOptions"
                                            :placeholder="__('select_currency_code')" />
                                    </div>
                                </template>
                            </div>
                        </div>
                    </div>

                    <!-- Stripe -->
                    <div class="col-md-6 mb-4">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">{{ __('stripe_payments') }}</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0" v-model="form.payment_gateways.stripe_payment_method">
                                </div>
                            </div>
                            <div class="card-body">
                                <template v-if="form.payment_gateways.stripe_payment_method == 1">
                                    <div class="form-group mb-3">
                                        <label>{{ __('mode') }}</label>
                                        <AppSelect class="form-control form-select" v-model="form.payment_gateways.stripe_mode" :options="stripe_modeOptions" :searchable="false" />
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('stripe_publishable_key') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.stripe_publishable_key" @input="!shouldHideCreds && (form.payment_gateways.stripe_publishable_key = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Stripe Publishable Key'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('stripe_secret_key') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.stripe_secret_key" @input="!shouldHideCreds && (form.payment_gateways.stripe_secret_key = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Stripe Secret Key'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('stripe_webhook_secret_key') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.stripe_webhook_secret_key" @input="!shouldHideCreds && (form.payment_gateways.stripe_webhook_secret_key = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Stripe Webhook Secret Key'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group">
                                        <label>{{ __('currency_code') }}</label>
                                        <AppSelect class="form-control form-select"
                                            v-model="form.payment_gateways.stripe_currency_code"
                                            :options="stripeCurrencyOptions"
                                            :placeholder="__('select_currency_code')" />
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('payment_endpoint_url') }} <small>({{ __('set_this_as_url_in_your_stripe_account') }})</small></label>
                                        <input type="text" class="form-control" :value="webhookUrls.stripe" readonly>
                                    </div>
                                </template>
                            </div>
                        </div>
                    </div>

                    <!-- Midtrans -->
                    <div class="col-md-6 mb-4">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">{{ __('midtrans_payments') }}</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0" v-model="form.payment_gateways.midtrans_payment_method">
                                </div>
                            </div>
                            <div class="card-body">
                                <template v-if="form.payment_gateways.midtrans_payment_method == 1">
                                    <div class="form-group mb-3">
                                        <label>{{ __('midtrans_payment_mode') }} <small>[ {{ __('sandbox') }} / {{ __('live') }} ]</small></label>
                                        <AppSelect class="form-control form-select" v-model="form.payment_gateways.midtrans_mode" :options="midtrans_modeOptions" :searchable="false" />
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('server_key') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.midtrans_server_key" @input="!shouldHideCreds && (form.payment_gateways.midtrans_server_key = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Midtrans Server Key'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('notification_url') }} <small>{{ __('set_webhook_url') }}</small></label>
                                        <input type="text" class="form-control" :value="webhookUrls.midtrans" placeholder="Midtrans Webhook URL" disabled>
                                    </div>
                                    <div class="form-group">
                                        <label>{{ __('return_url') }}</label>
                                        <input type="text" class="form-control" :value="webhookUrls.midtransReturn" placeholder="Midtrans Return URL" disabled>
                                    </div>
                                </template>
                            </div>
                        </div>
                    </div>

                    <!-- PhonePe -->
                    <div class="col-md-6 mb-4">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">{{ __('phonepay_payments') }}</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0" v-model="form.payment_gateways.phonepay_payment_method">
                                </div>
                            </div>
                            <div class="card-body">
                                <template v-if="form.payment_gateways.phonepay_payment_method == 1">
                                    <div class="form-group mb-3">
                                        <label>{{ __('phonepay_payment_mode') }} <small>[ {{ __('sandbox') }} / {{ __('live') }} ]</small></label>
                                        <AppSelect class="form-control form-select" v-model="form.payment_gateways.phonepay_mode" :options="phonepay_modeOptions" :searchable="false" />
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('merchant_id') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.phonepay_merchant_id" @input="!shouldHideCreds && (form.payment_gateways.phonepay_merchant_id = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Phonepe Merchant ID'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('client_id') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.phonepay_client_id" @input="!shouldHideCreds && (form.payment_gateways.phonepay_client_id = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Phonepe Client ID'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('client_version') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.phonepay_client_version" @input="!shouldHideCreds && (form.payment_gateways.phonepay_client_version = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Phonepe Client Version'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group">
                                        <label>{{ __('client_secret') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.phonepay_client_secret" @input="!shouldHideCreds && (form.payment_gateways.phonepay_client_secret = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Phonepe Client Secret'" :readonly="shouldHideCreds">
                                    </div>
                                </template>
                            </div>
                        </div>
                    </div>

                    <!-- Cashfree -->
                    <div class="col-md-6 mb-4">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">{{ __('cashfree_payments') }}</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0" v-model="form.payment_gateways.cashfree_payment_method">
                                </div>
                            </div>
                            <div class="card-body">
                                <template v-if="form.payment_gateways.cashfree_payment_method == 1">
                                    <div class="form-group mb-3">
                                        <label>{{ __('cashfree_payment_mode') }} <small>[ {{ __('sandbox') }} / {{ __('live') }} ]</small></label>
                                        <AppSelect class="form-control form-select" v-model="form.payment_gateways.cashfree_mode" :options="cashfree_modeOptions" :searchable="false" />
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('app_id') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.cashfree_app_id" @input="!shouldHideCreds && (form.payment_gateways.cashfree_app_id = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Cashfree APP ID'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('secret_key') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.cashfree_secret_key" @input="!shouldHideCreds && (form.payment_gateways.cashfree_secret_key = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Cashfree Secret Key'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group">
                                        <label>{{ __('notification_url') }} <small>{{ __('set_webhook_url_for_cashfree') }}</small></label>
                                        <input type="text" class="form-control" :value="webhookUrls.cashfree" placeholder="Cashfree Webhook URL" disabled>
                                    </div>
                                </template>
                            </div>
                        </div>
                    </div>

                    <!-- Paytabs -->
                    <div class="col-md-6 mb-4">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">{{ __('paytabs_payments') }}</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0" v-model="form.payment_gateways.paytabs_payment_method">
                                </div>
                            </div>
                            <div class="card-body">
                                <template v-if="form.payment_gateways.paytabs_payment_method == 1">
                                    <div class="form-group mb-3">
                                        <label>{{ __('paytabs_payment_mode') }} <small>[ {{ __('sandbox') }} / {{ __('live') }} ]</small></label>
                                        <AppSelect class="form-control form-select" v-model="form.payment_gateways.paytabs_mode" :options="paytabs_modeOptions" :searchable="false" />
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('profile_id') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.paytabs_profile_id" @input="!shouldHideCreds && (form.payment_gateways.paytabs_profile_id = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Paytabs Profile ID'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group mb-3">
                                        <label>{{ __('secret_key') }}</label>
                                        <input type="text" class="form-control" :value="shouldHideCreds ? '' : form.payment_gateways.paytabs_secret_key" @input="!shouldHideCreds && (form.payment_gateways.paytabs_secret_key = $event.target.value)" :placeholder="shouldHideCreds ? __('demo_mode') : 'Paytabs Secret Key'" :readonly="shouldHideCreds">
                                    </div>
                                    <div class="form-group">
                                        <label>{{ __('notification_url') }} <small>{{ __('set_webhook_url_for_paytabs') }}</small></label>
                                        <input type="text" class="form-control" :value="webhookUrls.paytabs" placeholder="Paytabs Webhook URL" disabled>
                                    </div>
                                </template>
                            </div>
                        </div>
                    </div>

                    <!-- Gateways from installed plugins. Rendered from the manifest schema,
                         written into the same payment_gateways object the form already
                         saves, so nothing about the save path changes. -->
                    <div class="col-md-6 mb-4" v-for="gw in pluginGateways" :key="gw.code">
                        <div class="card h-100 border shadow-none">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h6 class="card-title mb-0">{{ gw.label }}</h6>
                                <div class="form-check form-switch m-0">
                                    <input class="form-check-input" type="checkbox" true-value="1" false-value="0"
                                        v-model="form.payment_gateways[gw.toggle_key]">
                                </div>
                            </div>
                            <div class="card-body">
                                <template v-if="form.payment_gateways[gw.toggle_key] == 1">
                                    <div class="form-group mb-3" v-for="field in gw.fields" :key="field.key">
                                        <label>
                                            {{ __(field.label) }}
                                            <span v-if="field.required" class="text-danger">*</span>
                                        </label>

                                        <AppSelect v-if="field.type === 'select'" class="form-control form-select"
                                            v-model="form.payment_gateways[field.key]"
                                            :options="pluginFieldOptions(field)" :searchable="false" />

                                        <div v-else-if="field.type === 'toggle'" class="form-check form-switch">
                                            <input class="form-check-input" type="checkbox" true-value="1" false-value="0"
                                                v-model="form.payment_gateways[field.key]">
                                        </div>

                                        <!-- A secret is hidden in demo mode, exactly like the core gateways' keys. -->
                                        <input v-else :type="field.type === 'number' ? 'number' : 'text'" class="form-control"
                                            :value="field.secret && shouldHideCreds ? '' : form.payment_gateways[field.key]"
                                            @input="!(field.secret && shouldHideCreds) && (form.payment_gateways[field.key] = $event.target.value)"
                                            :readonly="field.secret && shouldHideCreds"
                                            :placeholder="field.secret && shouldHideCreds ? __('demo_mode') : __(field.placeholder || field.label)">

                                    </div>

                                    <div class="form-group">
                                        <label>{{ __('notification_url') }}</label>
                                        <input type="text" class="form-control" :value="gw.webhook_url" disabled>
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
    created() {
        this.loadPluginGateways();
    },
    methods: {
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
