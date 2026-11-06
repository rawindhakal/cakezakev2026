<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('deeplink_setting') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <section class="section">
                <div class="card">
                    <div class="card-body">
                        <p class="text text-muted font-size-13">{{ __('deeplink_setting_hint') }}
                        </p>
                        <div class="alert alert-light border small mb-3">
                            <b>{{ __('deeplink_instructions_title') }}</b>
                            <ul class="mb-0 mt-1 ps-3">
                                <li>{{ __('deeplink_instruction_1') }}</li>
                                <li>{{ __('deeplink_instruction_2') }}</li>
                                <li>{{ __('deeplink_instruction_3') }}</li>
                                <li>{{ __('deeplink_instruction_4') }}</li>
                            </ul>
                        </div>
                        <form method="post" @submit.prevent="saveDeeplinkSetting">
                            <div class="row">
                                <div class="form-group col-md-6">
                                    <label for="deeplink_schema">{{ __('deeplink_schema') }}<span
                                            class="text-danger text-xs">*</span></label><br>
                                    <input type="text" class="form-control" name="deeplink_schema" id="deeplink_schema"
                                        v-model="store_settings.deeplink_schema" :placeholder='__("deeplink_schema")'
                                        required />
                                </div>
                            </div>
                            <div class="d-flex justify-content-end">
                                <button type="submit" class="btn btn-primary" :disabled="isLoading">
                                    {{ __('save') }}
                                    <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                                </button>
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
    name: 'DeeplinkSettings',
    mixins: [StoreSettingsPage, UnsavedChanges],
    components: { ArrowLeft },
    data() {
        return {
            store_settings: {
                deeplink_schema: '',
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
        saveDeeplinkSetting() {
            // postStoreSettings re-reads on success; mark clean afterwards.
            this.postStoreSettings('/store_settings/save_deeplink_setting', ['deeplink_schema'])
                .then(() => this.captureFormBaseline());
        },
    },
};
</script>
