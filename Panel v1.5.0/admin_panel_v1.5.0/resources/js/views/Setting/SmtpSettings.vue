<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('smtp_mail_setting') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <section class="section">
                <div class="card">
                    <div class="card-body">
                        <form method="post" enctype="multipart/form-data" @submit.prevent="saveSmtpMailSetting">
                            <div class="row">
                                <div class="form-group col-md-6 mt-0">
                                    <label for="mailer">{{ __('mailer') }}:</label>
                                    <AppSelect class="form-control form-select" v-model="store_settings.mailer" :options="mailerOptions" :searchable="false" />
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="smtp_from_mail">{{ __('from_email_id')
                                    }}:</label>
                                    <input type="text" class="form-control" required name="smtp_from_mail"
                                        id="smtp_from_mail" v-model="store_settings.smtp_from_mail"
                                        placeholder='From SMTP Email ID' />
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="smtp_reply_to">{{ __('reply_to_email_id')
                                    }}:</label>
                                    <input type="email" class="form-control" required name="smtp_reply_to"
                                        id="smtp_reply_to" v-model="store_settings.smtp_reply_to"
                                        placeholder='From SMTP Email ID' />
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="smtp_email_password">{{
                                        __('smtp_email_password') }}: </label>
                                    <input type="text" class="form-control" :required="!shouldHideConfidential" name="smtp_email_password"
                                        id="smtp_email_password"
                                        :value="shouldHideConfidential ? '' : store_settings.smtp_email_password"
                                        @input="!shouldHideConfidential && (store_settings.smtp_email_password = $event.target.value)"
                                        :placeholder="shouldHideConfidential ? __('demo_mode') : 'Enter your SMTP email password'"
                                        :readonly="shouldHideConfidential" />
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="smtp_host">{{ __('smtp_host') }}: </label>
                                    <input type="text" class="form-control" required name="smtp_host" id="smtp_host"
                                        v-model="store_settings.smtp_host" placeholder='SMTP Host address' />
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="smtp_port">{{ __('smtp_port') }}:</label> <span
                                        class="text text-primary font-size-13"> ( <b>TLS:
                                        </b>587 <b>SSL: </b>465 )</span>
                                    <input type="text" class="form-control" required name="smtp_port" id="smtp_port"
                                        v-model="store_settings.smtp_port" placeholder='SMTP Port' />

                                </div>
                                <div class="form-group col-md-6">
                                    <label for="smtp_content_type">{{
                                        __('smtp_email_content_type') }}: </label>
                                    <AppSelect class="form-control form-select" v-model="store_settings.smtp_content_type" :options="smtp_content_typeOptions" :searchable="false" />
                                </div>
                                <div class="form-group col-md-6">
                                    <label for="smtp_encryption_type">{{ __('smtp_encryption')
                                    }}: </label>
                                    <AppSelect class="form-control form-select" v-model="store_settings.smtp_encryption_type" :options="smtp_encryption_typeOptions" :searchable="false" />
                                </div>
                            </div>


                            <hr>
                            <div class="row">
                                <h6>{{ __('email_test') }}</h6>
                                <div class="form-group col-md-6">
                                    <div class="input-group">
                                        <input type="text" class="form-control" name="test_email"
                                            v-model="store_settings.test_email"
                                            placeholder='Enter Email Address for Test'>
                                        <b-button type="button" class="m-0" variant="primary" @click="testMail"
                                            :disabled="isSendingTestEmail">
                                            {{ __('test_mail') }}
                                            <b-spinner v-if="isSendingTestEmail" small label="Spinning"></b-spinner>
                                        </b-button>
                                    </div>
                                </div>
                            </div>
                            <div class="row justify-content-end">
                                <div class="form-group col-auto">
                                    <b-button type="submit" variant="primary" :disabled="isLoading || shouldHideConfidential"
                                        v-if="$can('manage_smtp_settings') && ($isDemo != 1 || (login_user && login_user.id === 1))">{{ __('update') }}
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
import Auth from '../../Auth.js';

const SMTP_FIELDS = [
    'mailer', 'smtp_from_mail', 'smtp_reply_to', 'smtp_email_password', 'smtp_host',
    'smtp_port', 'smtp_content_type', 'smtp_encryption_type',
];

export default {
    name: 'SmtpSettings',
    mixins: [StoreSettingsPage, UnsavedChanges],
    components: { ArrowLeft },
    data() {
        return {
            isSendingTestEmail: false,
            login_user: Auth.user,
            store_settings: {
                mailer: 'smtp',
                smtp_from_mail: '',
                smtp_reply_to: '',
                smtp_email_password: '',
                smtp_host: '',
                smtp_port: '',
                smtp_content_type: '',
                smtp_encryption_type: '',
                // Read-only extras the test mail needs.
                test_email: '',
                support_email: '',
                app_name: '',
            },
        };
    },
    created() {
        // Snapshot the loaded settings as the "clean" baseline for the guard.
        this.loadStoreSettings().then(() => this.captureFormBaseline());
    },
    computed: {
        // Hide confidential values in demo mode, except for auth user id 1.
        shouldHideConfidential() {
            return this.$isDemo == 1 && (!this.login_user || this.login_user.id !== 1);
        },
        // Fixed option set — no search box needed.
        mailerOptions() {
            return [
                { id: 'smtp', name: 'SMTP' },
                { id: 'sendmail', name: 'Sendmail' },
            ];
        },
        // Fixed option set — no search box needed.
        smtp_content_typeOptions() {
            return [
                { id: '', name: (__('select_smtp_email_content_tpe')) },
                { id: 'html', name: (__('html')) },
                { id: 'text', name: (__('text')) },
            ];
        },
        // Fixed option set — no search box needed.
        smtp_encryption_typeOptions() {
            return [
                { id: '', name: (__('select_smtp_encryption_type')) },
                { id: 'tls', name: (__('tls')) },
                { id: 'ssl', name: (__('ssl')) },
            ];
        },
    },
    methods: {
        // Tracked state for the UnsavedChanges guard (persisted SMTP fields only).
        formState() {
            return SMTP_FIELDS.reduce((state, key) => {
                state[key] = this.store_settings[key];
                return state;
            }, {});
        },
        saveSmtpMailSetting() {
            // Re-baseline after the save+reload settles so the form reads clean again.
            this.postStoreSettings('/store_settings/save_smtp_mail_setting', SMTP_FIELDS)
                .then(() => this.captureFormBaseline());
        },
        testMail: function () {

            let data = {
                'mailer': this.store_settings.mailer,
                'email': this.store_settings.test_email,
                'host': this.store_settings.smtp_host,
                'username': this.store_settings.smtp_from_mail,
                'password': this.store_settings.smtp_email_password,
                'port': this.store_settings.smtp_port,
                'encryption': this.store_settings.smtp_encryption_type,
                'support_email': this.store_settings.support_email,
                'app_name': this.store_settings.app_name,
            };

            let url = this.$apiUrl + '/store_settings/test_mail';
            let vm = this;
            vm.isSendingTestEmail = true;
            axios.post(url, data).then(res => {
                vm.isSendingTestEmail = false;
                let data = res.data;
                if (data.status === 1) {
                    this.showMessage("success", data.message);
                } else {
                    vm.showError(data.message);
                    vm.isLoading = false;
                }
            }).catch(error => {
                vm.isSendingTestEmail = false;
                if (error.request.statusText) {
                    this.showError(error.request.statusText);
                } else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError("Something went wrong!");
                }
            })
        },
    },
};
</script>
