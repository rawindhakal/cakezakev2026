<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('maintenance_mode') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <section class="section">
                <div class="card">
                    <div class="card-body">
                        <p class="text-muted">{{ __('maintenance_mode_hint') }}</p>

                        <!-- Language tabs drive the multilingual maintenance message. -->
                        <b-tabs v-model="activeLangTab" content-class="mt-3" v-if="languages.length"
                            :nav-class="languages.length <= 1 ? 'd-none' : null">
                            <b-tab v-for="lang in languages" :key="lang.id">
                                <template #title>
                                    <span :class="{ 'text-primary fw-bold': lang.is_default }">{{ lang.name }}</span>
                                </template>

                                <div class="row g-3">
                                    <div class="col-md-4" v-for="s in surfaces" :key="s.key">
                                        <div class="border rounded p-3 h-100">
                                            <div class="d-flex justify-content-between align-items-center mb-2">
                                                <strong>{{ __(s.labelKey) }}</strong>
                                                <div class="form-check form-switch m-0">
                                                    <input class="form-check-input" type="checkbox" role="switch"
                                                        v-model="form[s.key].mode" :true-value="1" :false-value="0">
                                                </div>
                                            </div>
                                            <span class="badge" :class="form[s.key].mode ? 'bg-danger' : 'bg-success'">
                                                {{ form[s.key].mode ? __('under_maintenance') : __('live') }}
                                            </span>

                                            <div class="form-group mt-3">
                                                <label class="small">{{ __('maintenance_message') }}</label>
                                                <textarea class="form-control" rows="3"
                                                    v-model="remarks[s.key][lang.code]"
                                                    :placeholder="__('enter_maintenance_message')"></textarea>
                                            </div>

                                            <!-- Schedule shown once (language-independent). -->
                                            <template v-if="lang.is_default">
                                                <div class="form-group mt-2">
                                                    <label class="small">{{ __('schedule_start') }}</label>
                                                    <input type="datetime-local" class="form-control form-control-sm"
                                                        :min="nowLocal" v-model="form[s.key].start">
                                                </div>
                                                <div class="form-group mt-2">
                                                    <label class="small">{{ __('schedule_end') }}</label>
                                                    <input type="datetime-local" class="form-control form-control-sm"
                                                        :min="form[s.key].start || nowLocal" v-model="form[s.key].end">
                                                </div>
                                                <small class="text-muted d-block mt-1">{{ __('maintenance_schedule_hint') }}</small>
                                            </template>
                                        </div>
                                    </div>
                                </div>
                            </b-tab>
                        </b-tabs>
                    </div>
                    <div class="card-footer text-end">
                        <button class="btn btn-primary" :disabled="isLoading" @click="save">
                            {{ __('save') }}
                            <b-spinner v-if="isLoading" small></b-spinner>
                        </button>
                    </div>
                </div>
            </section>
        </div>
    </div>
</template>

<script>
import axios from 'axios';
import { ArrowLeft } from 'lucide-vue-next';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';

export default {
    name: 'MaintenanceSettings',
    mixins: [UnsavedChanges],
    components: { ArrowLeft },
    data() {
        return {
            isLoading: false,
            activeLangTab: 0,
            languages: [],
            // key = surface slug, toggle = the shared Setting variable.
            surfaces: [
                { key: 'web', toggle: 'website_mode', labelKey: 'website' },
                { key: 'customer', toggle: 'app_mode_customer', labelKey: 'customer_app' },
                { key: 'delivery_boy', toggle: 'app_mode_delivery_boy', labelKey: 'delivery_boy_app' },
            ],
            form: {
                web: { mode: 0, start: '', end: '' },
                customer: { mode: 0, start: '', end: '' },
                delivery_boy: { mode: 0, start: '', end: '' },
            },
            remarks: { web: {}, customer: {}, delivery_boy: {} },
        };
    },
    created() {
        this.loadLanguages().then(() => this.loadSettings());
    },
    computed: {
        // Local "YYYY-MM-DDTHH:mm" for the `min` attr — blocks picking past dates.
        nowLocal() {
            const p = n => String(n).padStart(2, '0');
            const d = new Date();
            return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
        },
    },
    methods: {
        // Tracked state for the UnsavedChanges guard (per-surface config + remarks).
        formState() {
            return { form: this.form, remarks: this.remarks };
        },
        loadLanguages() {
            return axios.get(this.$apiUrl + '/active_languages').then(res => {
                this.languages = res.data.data || [];
                // Seed empty remark maps for every language.
                this.surfaces.forEach(s => {
                    this.languages.forEach(l => {
                        if (this.remarks[s.key][l.code] === undefined) this.remarks[s.key][l.code] = '';
                    });
                });
            }).catch(() => { this.languages = []; });
        },
        // The admin edits in their LOCAL time, but the server/cron run in UTC — so
        // convert local <-> UTC. Stored form: "YYYY-MM-DD HH:mm:ss" (UTC).
        pad(n) { return String(n).padStart(2, '0'); },
        // Stored UTC -> local "YYYY-MM-DDTHH:mm" for the datetime-local input.
        toInput(v) {
            if (!v) return '';
            const d = new Date(String(v).replace(' ', 'T') + 'Z'); // parse as UTC
            if (isNaN(d.getTime())) return '';
            return `${d.getFullYear()}-${this.pad(d.getMonth() + 1)}-${this.pad(d.getDate())}T${this.pad(d.getHours())}:${this.pad(d.getMinutes())}`;
        },
        // Local "YYYY-MM-DDTHH:mm" -> UTC "YYYY-MM-DD HH:mm:ss" for storage.
        toServer(v) {
            if (!v) return '';
            const d = new Date(v); // interprets the value as LOCAL time
            if (isNaN(d.getTime())) return '';
            return `${d.getUTCFullYear()}-${this.pad(d.getUTCMonth() + 1)}-${this.pad(d.getUTCDate())} ${this.pad(d.getUTCHours())}:${this.pad(d.getUTCMinutes())}:00`;
        },
        loadSettings() {
            axios.get(this.$apiUrl + '/store_settings/maintenance_setting').then(res => {
                const d = res.data.data || {};
                this.surfaces.forEach(s => {
                    const row = d[s.key] || {};
                    this.form[s.key].mode = Number(row.mode) || 0;
                    this.form[s.key].start = this.toInput(row.start);
                    this.form[s.key].end = this.toInput(row.end);
                    const rk = row.remark || {};
                    this.languages.forEach(l => { this.remarks[s.key][l.code] = rk[l.code] || ''; });
                });
                // Snapshot the loaded settings as the "clean" baseline.
                this.captureFormBaseline();
            }).catch(() => { });
        },
        save() {
            this.isLoading = true;
            const fd = new FormData();
            this.surfaces.forEach(s => {
                fd.append(s.toggle, this.form[s.key].mode);
                fd.append(s.toggle + '_remark', JSON.stringify(this.remarks[s.key]));
                fd.append(s.toggle + '_start', this.toServer(this.form[s.key].start));
                fd.append(s.toggle + '_end', this.toServer(this.form[s.key].end));
            });
            axios.post(this.$apiUrl + '/store_settings/save_maintenance_setting', fd).then(res => {
                if (res.data.status === 1) {
                    // Mark clean after a successful save.
                    this.captureFormBaseline();
                    this.showMessage('success', res.data.message);
                } else this.showError(res.data.message);
            }).catch(err => {
                this.showError(err.response?.data?.message || __('something_went_wrong'));
            }).finally(() => { this.isLoading = false; });
        },
    },
};
</script>
