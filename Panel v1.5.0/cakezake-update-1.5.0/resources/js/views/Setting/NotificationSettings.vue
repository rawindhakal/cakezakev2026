<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('notification_settings') }}</h3>
                <router-link to="/settings"
                    class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <section class="section">
                <div class="card">
                    <div class="card-body">
                        <p class="text-muted">{{ __('notification_settings_hint') }}</p>

                        <!-- Only worth showing when a courier is actually installed: a
                             courier texts the customer itself, so this decides whether we
                             text them too. -->
                        <div v-if="hasShippingProvider" class="border rounded p-3 mb-3">
                            <div class="row g-3">
                                <div class="col-lg-6">
                                    <label class="form-label mb-1">{{ __('courier_customer_notifications') }}</label>
                                    <AppSelect v-model="courierMode" :options="courierModeOptions"
                                        :searchable="false" @update:modelValue="saveCourierMode" />
                                    <small class="text-muted d-block mt-1">
                                        {{ __('courier_customer_notifications_hint') }}
                                    </small>
                                </div>

                                <!-- A parcel the courier brings back is a cancellation that
                                     happened at the carrier, so this decides whether it settles
                                     itself or waits for someone to open the box. -->
                                <div class="col-lg-6">
                                    <label class="form-label mb-1">{{ __('courier_rto_action') }}</label>
                                    <AppSelect v-model="rtoAction" :options="rtoActionOptions"
                                        :searchable="false" @update:modelValue="saveRtoAction" />
                                    <small class="text-muted d-block mt-1">{{ __('courier_rto_action_hint') }}</small>
                                </div>
                            </div>
                        </div>

                        <!-- Filters: audience left, search right (category = the accordion). -->
                        <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
                            <div style="min-width: 220px; max-width: 280px;">
                                <AppSelect v-model="filters.audience" :options="audienceOptions"
                                    :searchable="false" :placeholder="__('all_audiences')" />
                            </div>
                            <div style="min-width: 220px; max-width: 320px;">
                                <input type="search" class="form-control" v-model="filters.search"
                                    :placeholder="__('search')">
                            </div>
                        </div>

                        <div v-if="isLoading" class="text-center py-4"><b-spinner></b-spinner></div>

                        <!-- Category accordion -->
                        <div v-else class="ns-accordion">
                            <div v-for="grp in groupedEvents" :key="grp.category" class="ns-acc-item">
                                <button type="button" class="ns-acc-head" @click="toggleCat(grp.category)">
                                    <span>{{ grp.category }}</span>
                                    <span class="d-flex align-items-center gap-2">
                                        <span class="badge bg-light text-dark">{{ grp.events.length }}</span>
                                        <ChevronDown :size="16" class="ns-caret" :class="{ open: isOpen(grp.category) }" />
                                    </span>
                                </button>
                                <div v-show="isOpen(grp.category)" class="ns-acc-body table-responsive">
                                    <table class="table table-sm align-middle mb-0 ns-table">
                                        <thead>
                                            <tr>
                                                <th>{{ __('notification') }}</th>
                                                <th>{{ __('audience') }}</th>
                                                <th class="text-center">{{ __('mail') }}</th>
                                                <th class="text-center">{{ __('sms') }}</th>
                                                <th class="text-center">{{ __('push') }}</th>
                                                <th class="text-end">{{ __('action') }}</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <tr v-for="ev in grp.events" :key="ev.key + ev.audience">
                                                <td>{{ ev.label }}</td>
                                                <td><span class="badge" :class="audienceBadge(ev.audience)">{{ audienceLabel(ev.audience) }}</span></td>
                                                <td v-for="ch in ['mail', 'sms', 'push']" :key="ch" class="text-center">
                                                    <div v-if="ev.channels[ch]" class="form-check form-switch d-inline-block m-0">
                                                        <input class="form-check-input" type="checkbox" role="switch"
                                                            v-model="ev.channels[ch].enabled"
                                                            @change="quickToggle(ev, ch, ev.channels[ch].enabled)">
                                                    </div>
                                                    <span v-else class="text-muted">—</span>
                                                </td>
                                                <td class="text-end">
                                                    <button class="btn btn-sm btn-outline-primary" @click="openEditor(ev)">
                                                        <Pencil :size="14" /> {{ __('edit') }}
                                                    </button>
                                                </td>
                                            </tr>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                            <div v-if="!groupedEvents.length" class="text-center text-muted py-3">{{ __('no_data_found') }}</div>
                        </div>
                    </div>
                </div>
            </section>
        </div>

        <!-- Editor modal: all channels for one event -->
        <b-modal v-model="editor.show" size="xl" :title="editor.data ? editor.data.label : ''" centered
            :ok-title="__('save')" :cancel-title="__('cancel')" :ok-disabled="editor.saving"
            @ok.prevent="saveEditor">
            <div v-if="editor.loading" class="text-center py-4"><b-spinner></b-spinner></div>
            <div v-else-if="editor.data">
                <div v-for="(chData, ch) in editor.data.channels" :key="ch" class="card mb-3">
                    <div class="card-header d-flex justify-content-between align-items-center py-2">
                        <strong>{{ __(ch) }}</strong>
                        <div class="form-check form-switch m-0">
                            <input class="form-check-input" type="checkbox" role="switch" v-model="chData.enabled">
                            <label class="form-check-label small">{{ chData.enabled ? __('enabled') : __('disabled') }}</label>
                        </div>
                    </div>
                    <div class="card-body">
                        <!-- Channel-wise placeholders: click to insert into the focused field. -->
                        <div v-if="chData.placeholders && chData.placeholders.length" class="mb-2 small">
                            <span class="text-muted me-1">{{ __('click_to_insert_at_cursor_location') }}:</span>
                            <button v-for="p in chData.placeholders" :key="p" type="button"
                                class="btn btn-sm btn-outline-primary py-0 px-1 me-1 mb-1"
                                @click="insertPlaceholder(p)" v-text="ph(p)"></button>
                        </div>

                        <b-tabs content-class="mt-3"
                            :nav-class="editor.data.languages.length <= 1 ? 'd-none' : null">
                            <b-tab v-for="(lang, idx) in editor.data.languages" :key="lang.id" :lazy="idx > 0">
                                <template #title>
                                    <span :class="{ 'fw-bold text-primary': lang.is_default }">{{ lang.name }}</span>
                                </template>
                                <div v-if="chData.has_title" class="form-group mb-2">
                                    <label class="small text-muted">{{ __('subject') }}</label>
                                    <!-- Email subject: rich editor too (HTML stripped on send). -->
                                    <editor v-if="ch === 'mail' && tinymceReady"
                                        :init="tinymceSubjectInit"
                                        tinymce-script-src="/assets/js/tinymce/tinymce.min.js?v=7922"
                                        license-key="gpl"
                                        v-model="cell(chData, lang.id).title" />
                                    <input v-else type="text" class="form-control form-control-sm"
                                        :placeholder="__('title')" v-model="cell(chData, lang.id).title"
                                        @focus="onFieldFocus($event)">
                                </div>
                                <label v-if="ch === 'mail'" class="small text-muted">{{ __('message') }}</label>
                                <!-- Email: rich TinyMCE editor. Others: plain textarea. -->
                                <editor v-if="ch === 'mail' && tinymceReady"
                                    :init="tinymceInit"
                                    tinymce-script-src="/assets/js/tinymce/tinymce.min.js?v=7922"
                                    license-key="gpl"
                                    v-model="cell(chData, lang.id).message" />
                                <textarea v-else class="form-control form-control-sm" rows="3"
                                    :placeholder="__('message')" v-model="cell(chData, lang.id).message"
                                    @focus="onFieldFocus($event)"></textarea>
                            </b-tab>
                        </b-tabs>
                    </div>
                </div>
            </div>
        </b-modal>
    </div>
</template>
<script>
import axios from 'axios';
import { ArrowLeft, Pencil, ChevronDown } from 'lucide-vue-next';
import Editor from '@tinymce/tinymce-vue';
import { tinymceInit as buildTinymceInit } from '../../utils/tinymce.js';

export default {
    name: 'NotificationSettings',
    components: { ArrowLeft, Pencil, ChevronDown, editor: Editor },
    data() {
        const vm = this;
        const focusHook = (ed) => ed.on('focus', () => { vm.activeEditor = ed; vm.lastFocus = 'editor'; });
        return {
            isLoading: true,
            events: [],
            // Courier notification mode, and whether any courier is installed at all.
            courierMode: 'delivered_only',
            rtoAction: 'settle',
            rtoActions: {},
            courierModes: {},
            hasShippingProvider: false,
            categories: [],
            audiences: [],
            filters: { audience: '', search: '' },
            openCats: {},
            editor: { show: false, loading: false, saving: false, data: null },
            tinymceReady: false,
            // Track the focused field so placeholder chips insert into the right place.
            activeEl: null,
            activeEditor: null,
            lastFocus: null,
            tinymceInit: buildTinymceInit({ height: 250, setup: focusHook }),
            // Compact single-line-ish editor for the subject (no menubar/formatting noise).
            tinymceSubjectInit: buildTinymceInit({ height: 90, menubar: false, toolbar: false, statusbar: false, setup: focusHook }),
        };
    },
    computed: {
        /** The modes core offers, labelled through its own language keys. */
        rtoActionOptions() {
            return Object.entries(this.rtoActions).map(([id, labelKey]) => ({ id, name: __(labelKey) }));
        },
        courierModeOptions() {
            return Object.entries(this.courierModes).map(([id, labelKey]) => ({ id, name: __(labelKey) }));
        },
        filteredEvents() {
            return this.events.filter(e => {
                if (this.filters.audience && e.audience !== this.filters.audience) return false;
                if (this.filters.search) {
                    const s = this.filters.search.toLowerCase();
                    if (!e.label.toLowerCase().includes(s) && !e.key.toLowerCase().includes(s)) return false;
                }
                return true;
            });
        },
        audienceOptions() {
            return [{ id: '', name: __('all_audiences') }]
                .concat(this.audiences.map(a => ({ id: a, name: this.audienceLabel(a) })));
        },
        groupedEvents() {
            const byCat = {};
            this.filteredEvents.forEach(e => {
                (byCat[e.category] = byCat[e.category] || []).push(e);
            });
            return this.categories
                .filter(c => byCat[c] && byCat[c].length)
                .map(c => ({ category: c, events: byCat[c] }));
        },
    },
    created() {
        this.loadEvents();
        this.loadTinymce();
    },
    methods: {
        audienceLabel(a) { return { customer: __('customer'), delivery_boy: __('delivery_boy'), admin: __('admin') }[a] || a; },
        audienceBadge(a) { return { customer: 'bg-primary', delivery_boy: 'bg-info', admin: 'bg-secondary' }[a] || 'bg-light'; },
        isOpen(cat) { return !!this.openCats[cat]; },
        toggleCat(cat) { this.openCats[cat] = !this.openCats[cat]; },
        cell(chData, langId) {
            if (!chData.translations[langId]) chData.translations[langId] = { title: '', message: '' };
            return chData.translations[langId];
        },
        ph(p) { return '{' + '{' + p + '}' + '}'; },
        onFieldFocus(e) { this.activeEl = e.target; this.lastFocus = 'el'; },
        insertPlaceholder(key) {
            const token = '{{' + key + '}}';
            if (this.lastFocus === 'editor' && this.activeEditor && !this.activeEditor.destroyed) {
                this.activeEditor.insertContent(token);
                return;
            }
            const el = this.activeEl;
            if (this.lastFocus === 'el' && el && document.contains(el)) {
                const s = el.selectionStart ?? el.value.length;
                const en = el.selectionEnd ?? el.value.length;
                el.value = el.value.slice(0, s) + token + el.value.slice(en);
                el.dispatchEvent(new Event('input')); // sync v-model
                this.$nextTick(() => { el.focus(); const p = s + token.length; el.setSelectionRange(p, p); });
                return;
            }
            this.showError(__('click_a_field_first'));
        },
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
            s.addEventListener('error', done);
        },
        /** Saved as soon as it changes, like the mode above it. */
        saveRtoAction(action) {
            const fd = new FormData();
            fd.append('action', action || this.rtoAction);
            axios.post(this.$apiUrl + '/notification_settings/save_courier_rto_action', fd)
                .then(res => {
                    const d = res.data;
                    d.status === 1 ? this.showMessage('success', d.message) : this.showError(d.message);
                })
                .catch(err => this.showError(err?.response?.data?.message || __('something_went_wrong')));
        },
        /** Saved as soon as it changes: one select, no form to submit. */
        saveCourierMode(mode) {
            const fd = new FormData();
            fd.append('mode', mode || this.courierMode);
            axios.post(this.$apiUrl + '/notification_settings/save_courier_notifications', fd)
                .then(res => {
                    const d = res.data;
                    d.status === 1 ? this.showMessage('success', d.message) : this.showError(d.message);
                })
                .catch(err => this.showError(err?.response?.data?.message || __('something_went_wrong')));
        },
        loadEvents() {
            this.isLoading = true;
            axios.get(this.$apiUrl + '/notification_settings/events').then(res => {
                const d = res.data.data || {};
                this.events = d.events || [];
                this.categories = d.categories || [];
                this.audiences = d.audiences || [];
                this.courierMode = d.courier_customer_notifications || 'delivered_only';
                this.courierModes = d.courier_notification_modes || {};
                this.rtoAction = d.courier_rto_action || 'settle';
                this.rtoActions = d.courier_rto_actions || {};
                this.hasShippingProvider = !!d.has_shipping_provider;
                // Open every category by default.
                this.categories.forEach((c) => { this.openCats[c] = true; });
            }).catch(() => { this.showError(__('something_went_wrong')); })
                .finally(() => { this.isLoading = false; });
        },
        quickToggle(ev, channel, checked) {
            // v-model already applied the change optimistically (smooth). Persist in
            // the background; revert just this toggle on failure — no full reload.
            const fd = new FormData();
            fd.append('key', ev.key);
            fd.append('audience', ev.audience);
            fd.append('channel', channel);
            fd.append('is_enabled', checked ? 1 : 0);
            axios.post(this.$apiUrl + '/notification_settings/toggle', fd).then(res => {
                if (res.data.status === 1) {
                    this.showMessage('success', res.data.message);
                } else {
                    ev.channels[channel].enabled = !checked;
                    this.showError(res.data.message);
                }
            }).catch(() => {
                ev.channels[channel].enabled = !checked;
                this.showError(__('something_went_wrong'));
            });
        },
        openEditor(ev) {
            this.editor = { show: true, loading: true, saving: false, data: null };
            axios.get(this.$apiUrl + '/notification_settings/event', { params: { key: ev.key, audience: ev.audience } })
                .then(res => {
                    const d = res.data.data;
                    Object.keys(d.channels).forEach(ch => {
                        const c = d.channels[ch];
                        const tr = {};
                        d.languages.forEach(l => {
                            const ex = c.translations[l.id] || c.translations[String(l.id)] || {};
                            tr[l.id] = { title: ex.title || (l.is_default ? c.base_title : ''), message: ex.message || (l.is_default ? c.base_message : '') };
                        });
                        c.translations = tr;
                    });
                    this.editor.data = d;
                }).catch(() => { this.showError(__('something_went_wrong')); this.editor.show = false; })
                .finally(() => { this.editor.loading = false; });
        },
        saveEditor() {
            const d = this.editor.data;
            if (!d) return;
            this.editor.saving = true;
            const payload = { key: d.key, audience: d.audience, channels: {} };
            Object.keys(d.channels).forEach(ch => {
                const c = d.channels[ch];
                payload.channels[ch] = { enabled: c.enabled, translations: c.translations };
            });
            axios.post(this.$apiUrl + '/notification_settings/save_event', payload).then(res => {
                if (res.data.status === 1) {
                    this.showMessage('success', res.data.message);
                    this.editor.show = false;
                    this.loadEvents();
                } else {
                    this.showError(res.data.message);
                }
            }).catch(err => {
                this.showError(err.response?.data?.message || __('something_went_wrong'));
            }).finally(() => { this.editor.saving = false; });
        },
    },
};
</script>
<style scoped>
.ns-accordion { border: 1px solid var(--app-card-border); border-radius: 8px; overflow: hidden; }
.ns-acc-item + .ns-acc-item { border-top: 1px solid var(--app-card-border); }
.ns-acc-head {
    width: 100%; display: flex; justify-content: space-between; align-items: center;
    background: var(--app-card-bg); border: 0; padding: .7rem 1rem; font-weight: 600;
    cursor: pointer; color: var(--app-ink);
}
.ns-acc-head:hover { background: rgba(var(--bs-primary-rgb), .04); }
.ns-caret { transition: transform .18s ease; }
.ns-caret.open { transform: rotate(180deg); }
.ns-acc-body { padding: .25rem 1rem 1rem; }

/* Fixed layout so every category table lines up identically; min-width forces
   horizontal scroll on small screens (wrapper is .table-responsive). */
.ns-table { table-layout: fixed; min-width: 620px; }
.ns-table th:nth-child(1), .ns-table td:nth-child(1) { width: 32%; }
.ns-table th:nth-child(2), .ns-table td:nth-child(2) { width: 14%; }
/* Channels: no fixed px — they split the remaining space, so the toggles
   spread out evenly instead of bunching on the right. */
.ns-table th:nth-child(6), .ns-table td:nth-child(6) { width: 12%; }
.ns-table td:nth-child(1) { white-space: normal; word-break: break-word; }
</style>
