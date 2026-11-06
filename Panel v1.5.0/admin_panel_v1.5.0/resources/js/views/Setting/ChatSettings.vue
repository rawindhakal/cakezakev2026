<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('chat_setting') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <section class="section">
                <div class="card">
                    <div class="card-body">
                        <p class="text text-muted font-size-13">
                            {{ __('chat_setting_hint') }}
                        </p>

                        <form method="post" @submit.prevent="saveBroadcastSetting">
                            <!-- Driver picker: exactly one is active -->
                            <div class="row">
                                <div class="form-group col-md-12">
                                    <label>{{ __('realtime_driver') }}<span
                                            class="text-danger text-xs">*</span></label><br>
                                    <div class="btn-group btn-group-toggle d-flex flex-wrap flex-md-nowrap" role="group"
                                        style="max-width:420px;">
                                        <label class="btn btn-outline-primary"
                                            :class="{ active: broadcast_settings.broadcast_driver === 'reverb' }">
                                            <input type="radio" value="reverb"
                                                v-model="broadcast_settings.broadcast_driver" autocomplete="off"> {{
                                            __('reverb') }}
                                        </label>
                                        <label class="btn btn-outline-primary"
                                            :class="{ active: broadcast_settings.broadcast_driver === 'pusher' }">
                                            <input type="radio" value="pusher"
                                                v-model="broadcast_settings.broadcast_driver" autocomplete="off"> {{
                                            __('pusher') }}
                                        </label>
                                    </div>
                                </div>
                            </div>

                            <!-- ===== Reverb (self-hosted websocket server) ===== -->
                            <div v-if="broadcast_settings.broadcast_driver === 'reverb'">
                                <div class="list-group-item m-0 mt-2">
                                    <h6 class="mb-0">{{ __('reverb_credentials') }}</h6>
                                    <p class="text text-muted font-size-13 mb-0">
                                        {{ __('reverb_hint') }}
                                    </p>
                                    <div class="row mt-2">
                                        <div class="form-group col-md-4">
                                            <label for="reverb_app_id">{{ __('app_id') }}<span
                                                    class="text-danger text-xs">*</span></label>
                                            <input type="text" class="form-control" id="reverb_app_id"
                                                v-model="broadcast_settings.reverb_app_id"
                                                :readonly="shouldHideThirdPartyValues" :placeholder="__('app_id')">
                                        </div>
                                        <div class="form-group col-md-4">
                                            <label for="reverb_app_key">{{ __('app_key') }}<span
                                                    class="text-danger text-xs">*</span></label>
                                            <input type="text" class="form-control" id="reverb_app_key"
                                                v-model="broadcast_settings.reverb_app_key"
                                                :readonly="shouldHideThirdPartyValues" :placeholder="__('app_key')">
                                        </div>
                                        <div class="form-group col-md-4">
                                            <label for="reverb_app_secret">{{ __('app_secret')
                                            }}<span class="text-danger text-xs">*</span></label>
                                            <input type="text" class="form-control" id="reverb_app_secret"
                                                v-model="broadcast_settings.reverb_app_secret"
                                                :readonly="shouldHideThirdPartyValues" :placeholder="__('app_secret')">
                                        </div>
                                        <div class="form-group col-md-4">
                                            <label for="reverb_host">{{ __('host') }}<span
                                                    class="text-danger text-xs">*</span></label>
                                            <input type="text" class="form-control" id="reverb_host"
                                                v-model="broadcast_settings.reverb_host"
                                                :readonly="shouldHideThirdPartyValues" placeholder="localhost">
                                        </div>
                                        <div class="form-group col-md-4">
                                            <label for="reverb_port">{{ __('port') }}<span
                                                    class="text-danger text-xs">*</span></label>
                                            <input type="number" min="1" max="65535" class="form-control"
                                                id="reverb_port" v-model="broadcast_settings.reverb_port"
                                                :readonly="shouldHideThirdPartyValues" placeholder="8080">
                                        </div>
                                        <div class="form-group col-md-4">
                                            <label for="reverb_scheme">{{ __('scheme') }}<span
                                                    class="text-danger text-xs">*</span></label>
                                            <AppSelect class="form-select" v-model="broadcast_settings.reverb_scheme" :options="reverb_schemeOptions" :searchable="false" :disabled="shouldHideThirdPartyValues" />
                                        </div>
                                    </div>
                                    <div class="alert alert-warning mb-0 mt-1 py-2 font-size-13">
                                        {{ __('reverb_server_required_note') }}
                                    </div>
                                </div>
                            </div>

                            <!-- ===== Pusher (hosted; no websocket server of ours) ===== -->
                            <div v-if="broadcast_settings.broadcast_driver === 'pusher'">
                                <div class="list-group-item m-0 mt-2">
                                    <h6 class="mb-0">{{ __('pusher_credentials') }}</h6>
                                    <p class="text text-muted font-size-13 mb-0">
                                        {{ __('pusher_hint') }}
                                        <a href="https://dashboard.pusher.com/channels" target="_blank"
                                            rel="noopener">dashboard.pusher.com</a>
                                    </p>
                                    <div class="row mt-2">
                                        <div class="form-group col-md-3">
                                            <label for="pusher_app_id">{{ __('app_id') }}<span
                                                    class="text-danger text-xs">*</span></label>
                                            <input type="text" class="form-control" id="pusher_app_id"
                                                v-model="broadcast_settings.pusher_app_id"
                                                :readonly="shouldHideThirdPartyValues" :placeholder="__('app_id')">
                                        </div>
                                        <div class="form-group col-md-3">
                                            <label for="pusher_app_key">{{ __('app_key') }}<span
                                                    class="text-danger text-xs">*</span></label>
                                            <input type="text" class="form-control" id="pusher_app_key"
                                                v-model="broadcast_settings.pusher_app_key"
                                                :readonly="shouldHideThirdPartyValues" :placeholder="__('app_key')">
                                        </div>
                                        <div class="form-group col-md-3">
                                            <label for="pusher_app_secret">{{ __('app_secret')
                                            }}<span class="text-danger text-xs">*</span></label>
                                            <input type="text" class="form-control" id="pusher_app_secret"
                                                v-model="broadcast_settings.pusher_app_secret"
                                                :readonly="shouldHideThirdPartyValues" :placeholder="__('app_secret')">
                                        </div>
                                        <div class="form-group col-md-3">
                                            <label for="pusher_app_cluster">{{ __('cluster')
                                            }}<span class="text-danger text-xs">*</span></label>
                                            <input type="text" class="form-control" id="pusher_app_cluster"
                                                v-model="broadcast_settings.pusher_app_cluster"
                                                :readonly="shouldHideThirdPartyValues" placeholder="ap2">
                                        </div>
                                    </div>
                                    <div class="alert alert-info mb-0 mt-1 py-2 font-size-13">
                                        {{ __('pusher_no_server_note') }}
                                    </div>
                                </div>
                            </div>

                            <div class="row mt-3 justify-content-end">
                                <div class="form-group col-auto">
                                    <b-button type="submit" variant="primary"
                                        :disabled="isLoading || shouldHideThirdPartyValues"
                                        v-if="$can('manage_chat_settings') && ($isDemo != 1 || (login_user && login_user.id === 1))">
                                        {{ __('update') }}
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
import Auth from '../../Auth.js';
import { ArrowLeft } from 'lucide-vue-next';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';

export default {
    name: 'ChatSettings',
    mixins: [UnsavedChanges],
    components: { ArrowLeft },
    data() {
        return {
            isLoading: false,
            login_user: Auth.user,
            // Lives in .env (not the settings table), so it has its own endpoint.
            broadcast_settings: {
                broadcast_driver: 'reverb',
                reverb_app_id: '',
                reverb_app_key: '',
                reverb_app_secret: '',
                reverb_host: '',
                reverb_port: '',
                reverb_scheme: 'http',
                pusher_app_id: '',
                pusher_app_key: '',
                pusher_app_secret: '',
                pusher_app_cluster: '',
            },
        };
    },
    computed: {
        // Fixed option set — no search box needed.
        reverb_schemeOptions() {
            return [
                { id: 'http', name: 'http' },
                { id: 'https', name: 'https' },
            ];
        },
        shouldHideThirdPartyValues() {
            return this.$isDemo == 1 && (!this.login_user || this.login_user.id !== 1);
        },
    },
    created() { this.getBroadcastSetting(); },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return this.broadcast_settings;
        },
        getBroadcastSetting() {
            return axios.get(this.$apiUrl + '/store_settings/broadcast_setting').then((res) => {
                if (res.data.status === 1 && res.data.data) {
                    this.broadcast_settings = Object.assign({}, this.broadcast_settings, res.data.data);
                }
                // Snapshot the loaded settings as the "clean" baseline.
                this.captureFormBaseline();
            }).catch(() => { /* leave defaults; the form still renders */ });
        },

        saveBroadcastSetting() {
            this.isLoading = true;
            axios.post(this.$apiUrl + '/store_settings/save_broadcast_setting', this.broadcast_settings).then((res) => {
                this.isLoading = false;
                const data = res.data;
                if (data.status === 1) {
                    // Mark clean so the post-save reload doesn't trip the guard.
                    this.captureFormBaseline();
                    this.showMessage('success', data.message);
                    // The driver + its keys are injected into the page by the blade at
                    // load time, so Echo only picks up the new driver on a fresh load.
                    setTimeout(() => window.location.reload(), 1200);
                } else {
                    this.showError(data.message);
                }
            }).catch((error) => {
                this.isLoading = false;
                this.showError(error?.response?.data?.message || error.message || __('something_went_wrong'));
            });
        },
    },
};
</script>
