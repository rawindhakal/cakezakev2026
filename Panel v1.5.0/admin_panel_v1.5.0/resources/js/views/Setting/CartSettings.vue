<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('cart_setting') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <section class="section">
                <div class="card">
                    <div class="card-body">
                        <form method="post" enctype="multipart/form-data" @submit.prevent="saveCartSetting">
                            <div class="row">
                                <div class="form-group col-12 mt-0">
                                    <label for="low_stock_limit">{{ __('cart_notification') }}
                                    </label>
                                    <div class="form-check form-switch">
                                        <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                                            name="cart_notification" id="cart_notification"
                                            v-model="store_settings.cart_notification">
                                    </div>
                                    <small class="text-muted d-block">{{
                                        __('product_will_be_add_incart_without_login') }}</small>
                                </div>
                                <div class="form-group col-12 col-md-6 col-lg-4"
                                    v-if="store_settings.cart_notification == 1">
                                    <label for="notification_delay_after_cart_addition"> {{
                                        __('notification_delay_after_cart_addition') }}</label>
                                    <i class="text-danger">* </i>
                                    <div class="input-group">
                                        <div class="input-group-prepend">
                                            <div class="input-group-text myDivClass" style="height: 42px;">
                                                <span class="mySpanClass">{{ __('minutes')
                                                }}</span>
                                            </div>
                                        </div>
                                        <input type="number" style="height: 42px;" class="form-control"
                                            name="notification_delay_after_cart_addition"
                                            id="notification_delay_after_cart_addition" min="0"
                                            v-model="store_settings.notification_delay_after_cart_addition">
                                    </div>
                                    <small class="text-muted d-block">{{
                                        __('notification_delay_after_cart_addition_tooltip')
                                    }}</small>
                                </div>
                                <div class="form-group col-12 col-md-6 col-lg-4"
                                    v-if="store_settings.cart_notification == 1">
                                    <label for="notification_interval"> {{
                                        __('notification_interval') }}</label> <i class="text-danger">* </i>
                                    <div class="input-group">
                                        <div class="input-group-prepend">
                                            <div class="input-group-text myDivClass" style="height: 42px;">
                                                <span class="mySpanClass">{{ __('minutes')
                                                }}</span>
                                            </div>
                                        </div>
                                        <input type="number" style="height: 42px;" class="form-control"
                                            name="notification_interval" id="notification_interval" min="0"
                                            v-model="store_settings.notification_interval">
                                    </div>
                                    <small class="text-muted d-block">{{
                                        __('notification_interval_hint') }}</small>
                                </div>

                                <div class="form-group col-12 col-md-6 col-lg-4"
                                    v-if="store_settings.cart_notification == 1">
                                    <label for="notification_stop_time"> {{
                                        __('notification_stop_time') }}</label> <i class="text-danger">* </i>
                                    <div class="input-group">
                                        <div class="input-group-prepend">
                                            <div class="input-group-text myDivClass" style="height: 42px;">
                                                <span class="mySpanClass">{{ __('minutes')
                                                }}</span>
                                            </div>
                                        </div>
                                        <input type="number" style="height: 42px;" class="form-control"
                                            name="notification_stop_time" id="notification_stop_time" min="0"
                                            v-model="store_settings.notification_stop_time">
                                    </div>
                                    <small class="text-muted d-block">{{
                                        __('notification_stop_time_tooltip') }}</small>
                                </div>

                            </div>
                            <div class="row justify-content-end">
                                <div class="form-group col-auto">
                                    <b-button type="submit" variant="primary" :disabled="isLoading"
                                        v-if="$can('manage_cart_settings')">{{ __('update') }}
                                        <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                                    </b-button>
                                </div>
                            </div>
                        </form>
                    </div>

                </div>

            </section>
        </div>
    </div>
</template>
<script>
import axios from "axios";
import { ArrowLeft } from 'lucide-vue-next';
import StoreSettingsPage from '../../mixins/StoreSettingsPage.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';

export default {
    name: 'CartSettings',
    mixins: [StoreSettingsPage, UnsavedChanges],
    components: { ArrowLeft },
    data() {
        return {
            store_settings: {
                cart_notification: 0,
                notification_delay_after_cart_addition: '',
                notification_interval: '',
                notification_stop_time: '',
            },
        };
    },
    created() {
        // Snapshot the loaded settings as the "clean" baseline for the guard.
        this.loadStoreSettings().then(() => this.captureFormBaseline());
    },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return this.store_settings;
        },
        saveCartSetting() {
            // Re-baseline after the save+reload settles so the form reads clean again.
            this.postStoreSettings('/store_settings/save_cart_setting', [
                'cart_notification', 'notification_delay_after_cart_addition',
                'notification_interval', 'notification_stop_time',
            ]).then(() => this.captureFormBaseline());
        },
    },
};
</script>
