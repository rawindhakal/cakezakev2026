<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('firebase_settings') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>
            <section class="section">
                <form id="api_key_form" method="post" enctype="multipart/form-data" @submit.prevent="saveRecord">
                    <div class="card">
                        <div class="card-body">
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="form-group">
                                        <label for="firebase_apiKey">{{ __('apikey') }}<span
                                                class="text-danger text-xs">*</span></label>
                                        <input type="text" class="form-control" name="firebase_apiKey"
                                            id="firebase_apiKey"
                                            :value="shouldHideConfidential ? '' : firebase.firebase_apiKey"
                                            @input="!shouldHideConfidential && (firebase.firebase_apiKey = $event.target.value)"
                                            :readonly="shouldHideConfidential"
                                            :placeholder="shouldHideConfidential ? __('demo_mode') : __('apikey')">
                                    </div>
                                </div>

                                <div class="col-md-6">
                                    <div class="form-group">
                                        <label for="projectId">{{ __('projectid') }} <span
                                                class="text-danger text-xs">*</span></label>
                                        <input type="text" class="form-control" name="projectId" id="projectId"
                                            v-model="firebase.projectId" :placeholder="__('projectid')">
                                    </div>
                                </div>

                                <div class="col-md-6">
                                    <div class="form-group">
                                        <label for="messagingSenderId"> {{ __('messagingsenderid') }}<span
                                                class="text-danger text-xs">*</span></label>
                                        <input type="text" class="form-control" name="messagingSenderId"
                                            id="messagingSenderId" v-model="firebase.messagingSenderId"
                                            :placeholder="__('messagingsenderid')">
                                    </div>
                                </div>

                                <div class="col-md-6">
                                    <div class="form-group">
                                        <label for="appId"> {{ __('appid') }}<span
                                                class="text-danger text-xs">*</span></label>
                                        <input type="text" class="form-control" name="appId" id="appId"
                                            v-model="firebase.appId" :placeholder="__('appid')">
                                    </div>
                                </div>

                                <div class="col-md-6">
                                    <div class="form-group">
                                        <label for="firebase_vapid_key">{{ __('vapid_key') }}<span
                                                class="text-danger text-xs">*</span></label>
                                        <input type="text" class="form-control" name="firebase_vapid_key"
                                            id="firebase_vapid_key" v-model="firebase.firebase_vapid_key"
                                            :placeholder="__('web_push_certificate_key_pair')">
                                        <small class="text-muted">{{ __('vapid_key_hint') }}</small>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <label for="jsonFile">{{ __('firebase_json_file') }}
                                        <span v-if="fileExists" class="text-success ms-2">
                                            <i class="fa fa-check-circle"></i> {{ __('file_exists') }}
                                        </span>
                                        <span v-else class="text-danger ms-2">
                                            <i class="fa fa-times-circle"></i> {{ __('file_not_exists') }}
                                        </span>
                                    </label>
                                    <FileUpload v-if="!shouldHideConfidential" v-model="firebase.jsonFile" accept=".json,application/json"
                                        :recommended-text="__('supported_formats') + ': JSON'" :show-preview="false"
                                        @change="onJsonFileChange" />
                                    <input v-else type="text" class="form-control" readonly :placeholder="__('demo_mode')">
                                </div>
                            </div>
                        </div>
                        <div class="card-footer d-flex justify-content-end">
                            <b-button type="submit" variant="primary" :disabled="isLoading || shouldHideConfidential"
                                v-if="$isDemo != 1 || (login_user && login_user.id === 1)">{{ __('update') }}
                                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                            </b-button>
                        </div>
                    </div>
                </form>
            </section>
        </div>
    </div>
</template>
<script>
import axios from "axios";
import { ArrowLeft } from 'lucide-vue-next';
import Auth from '../../Auth.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';

export default {
    mixins: [UnsavedChanges],
    components: { ArrowLeft },
    data: function () {
        return {
            isLoading: false,
            fileExists: false,
            login_user: Auth.user,

            editorConfig: {},
            firebase: {
                firebase_apiKey: "",
                projectId: "",
                messagingSenderId: "",
                appId: "",
                firebase_vapid_key: "",
                jsonFile: "",

            },
            record: null
        }
    },
    created: function () {
        this.getFirebaseData();
    },
    computed: {
        // Hide confidential Firebase values in demo mode, except for auth user id 1.
        shouldHideConfidential() {
            return this.$isDemo == 1 && (!this.login_user || this.login_user.id !== 1);
        },
    },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return this.firebase;
        },
        getFirebaseData() {
            axios.get(this.$apiUrl + '/firebase').then((response) => {
                if (response.data.data) {
                    this.record = response.data.data;
                    this.record.map((item, index) => {
                        if (item.variable === 'file_exists') {
                            // Handle file existence status
                            this.fileExists = (item.value === '1');
                        } else if (item.value === '0' || item.value === '1') {
                            this.firebase[item.variable] = (item.value === '0') ? 0 : 1;
                        } else {
                            this.firebase[item.variable] = item.value;
                        }
                    });
                }
                // Snapshot the loaded settings as the "clean" baseline for the guard.
                this.captureFormBaseline();
            }).catch(error => {
                if (error.request.statusText) {
                    this.showError(error.request.statusText);
                } else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError(__('something_went_wrong'));
                }
            });
        },

        onJsonFileChange(file) {
            if (file) {
                this.fileExists = true;
            } else {
                // File removed: fall back to the server-known file status.
                const item = (this.record || []).find(i => i.variable === 'file_exists');
                this.fileExists = item ? item.value === '1' : false;
            }
        },

        saveRecord: function () {
            this.isLoading = true;

            let object = this.firebase;
            let formData = new FormData();
            for (let key in object) {
                formData.append(key, object[key]);
            }

            let url = this.$apiUrl + '/firebase/save';
            let vm = this;

            axios.post(url, formData).then(res => {

                let data = res.data;
                if (data.status === 1) {
                    this.showMessage("success", data.message);
                    // Refresh data to get updated file status
                    vm.getFirebaseData();
                    // Mark clean after a successful save (before the redirect fires).
                    vm.captureFormBaseline();
                    setTimeout(
                        function () {
                            vm.$swal.close();
                            vm.$router.push({ path: '/settings/firebase' });
                            vm.isLoading = false;
                        }, 100);
                } else {
                    vm.showError(data.message);
                    vm.isLoading = false;
                }


            }).catch(error => {
                if (error.request.statusText) {
                    this.showError(error.request.statusText);
                } else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError(__('something_went_wrong'));
                }
                vm.isLoading = true;
            });

        }
    }
}
</script>
