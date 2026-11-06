<template>
    <b-modal ref="wizard" :title="isEdit ? __('edit_setup') : __('new_home_layout')" size="xl" centered scrollable static no-fade
        no-close-on-backdrop modal-class="hb-wizard-modal" @hidden="$emit('close')">

        <!-- Step progress -->
        <div class="hb-wizard-steps mb-4">
            <div v-for="(s, i) in steps" :key="s" class="hb-wizard-step"
                :class="{ done: i < currentIndex, active: i === currentIndex, clickable: canJumpTo(i) }"
                role="button" tabindex="0"
                @click="goToStep(i)" @keydown.enter.prevent="goToStep(i)" @keydown.space.prevent="goToStep(i)">
                <span class="hb-wizard-dot">{{ i + 1 }}</span>
                <span class="hb-wizard-label">{{ stepLabel(s) }}</span>
            </div>
        </div>

        <!-- Step: home type -->
        <div v-if="current === 'type'">
            <h6 class="mb-3">{{ __('what_kind_of_home_layout') }}</h6>
            <div class="row g-3">
                <div class="col-md-6" v-for="opt in homeTypeOptions" :key="opt.value">
                    <div class="hb-choice-card" :class="{ selected: form.home_type === opt.value }"
                        @click="form.home_type = opt.value">
                        <component :is="opt.icon" :size="22" />
                        <strong>{{ opt.label }}</strong>
                        <small>{{ opt.help }}</small>
                    </div>
                </div>
            </div>
        </div>

        <!-- Step: channel / mode -->
        <div v-if="current === 'mode'">
            <h6 class="mb-3">{{ __('which_channel') }}</h6>
            <div class="row g-3">
                <div class="col-md-6" v-for="opt in modeOptions" :key="opt.value">
                    <div class="hb-choice-card hb-choice-card--compact"
                        :class="{ selected: form.mode === opt.value, disabled: modeLocked }"
                        @click="!modeLocked && (form.mode = opt.value)">
                        <strong>{{ opt.label }}</strong>
                    </div>
                </div>
            </div>
            <p v-if="modeLocked" class="text-muted small mt-2 mb-0">
                <Lock :size="14" /> {{ __('default_layout_channel_locked') }}
            </p>

            <!-- Channel button label (multi-language) -->
            <hr class="my-3">
            <h6 class="mb-1">{{ __('channel_button_label') }}</h6>
            <p class="text-muted small mb-2">{{ __('channel_button_label_help') }}</p>
            <!-- Single language: no tabs, render the field directly (always visible). -->
            <TranslatableInput v-if="languages.length === 1"
                :label="modeLabel + ' *'"
                v-model="form.channel_label"
                :languages="languages"
                :active-lang="languages[0].id"
                :placeholder="modeLabel" />
            <b-tabs v-else-if="languages.length > 1" v-model="langTabIndex" content-class="mt-2" class="hb-block-lang-tabs">
                <b-tab v-for="lang in languages" :key="lang.id">
                    <template #title>
                        <span :class="{ 'text-primary fw-bold': lang.is_default }">{{ lang.name }}</span>
                    </template>
                    <TranslatableInput
                        :label="modeLabel + ' *'"
                        v-model="form.channel_label"
                        :languages="languages"
                        :active-lang="lang.id"
                        :placeholder="modeLabel" />
                </b-tab>

                <!-- Translate control, inline with the language tabs. -->
                <template #tabs-end>
                    <li class="nav-item ms-auto d-flex align-items-center">
                        <TranslateLanguages :languages="languages" :default-language-id="defaultLanguageId"
                            :busy="translating" :progress="translateProgress" @translate="runTranslate" />
                    </li>
                </template>
            </b-tabs>
        </div>

        <!-- Step: categories -->
        <div v-if="current === 'categories'">
            <div class="d-flex justify-content-between align-items-center gap-2 mb-1 flex-wrap">
                <h6 class="mb-0">{{ __('select_categories') }}</h6>
                <input type="search" class="form-control" style="max-width:280px"
                    v-model="categorySearch" :placeholder="__('search_category')">
            </div>
            <p class="text-muted small">{{ __('select_at_least_one_category') }}</p>

            <div class="hb-check-grid">
                <label v-for="c in filteredCategories" :key="c.id" class="hb-check-item">
                    <input type="checkbox" :value="c.id" v-model="form.category_ids">
                    <span>{{ c.name }}</span>
                </label>
            </div>
            <p v-if="!filteredCategories.length" class="text-muted">{{ __('no_records_found') }}</p>

            <hr class="my-3">
            <div class="d-flex justify-content-between align-items-center mb-2">
                <h6 class="mb-0">{{ __('custom_category') }}</h6>
                <button type="button" class="btn btn-sm btn-outline-primary" @click="startCustom()">
                    <Plus :size="14" /> {{ __('add_custom_category') }}
                </button>
            </div>

            <div v-if="form.custom_tabs.length" class="hb-custom-list mb-2">
                <template v-for="t in form.custom_tabs" :key="t.key">
                    <div class="hb-custom-row" :class="{ 'is-editing': editingKey === t.key }">
                        <img v-if="t.icon_url" :src="t.icon_url" class="hb-custom-icon" alt="">
                        <span class="flex-grow-1 text-truncate">{{ customLabel(t) }}</span>
                        <span class="badge bg-info-subtle text-info">{{ __('custom') }}</span>
                        <button type="button" class="btn btn-xs p-1" :title="__('edit')" @click="startCustom(t)">
                            <Pencil :size="14" />
                        </button>
                        <button type="button" class="btn btn-xs text-danger p-1" :title="__('delete')" @click="removeCustom(t.key)">
                            <Trash2 :size="14" />
                        </button>
                    </div>
                    <!-- Edit opens right under its own row, not at the bottom of the list. -->
                    <div v-if="editingKey === t.key" class="hb-custom-editor">
                        <label class="form-label small fw-bold">{{ __('category_name') }}</label>
                        <TranslatableInput v-if="languages.length === 1"
                            v-model="customDraft.name" :languages="languages" :active-lang="languages[0].id"
                            :placeholder="__('category_name') + ' *'" />
                        <template v-else>
                            <ul class="nav nav-tabs hb-block-lang-tabs mb-2">
                                <li class="nav-item" v-for="(lang, idx) in languages" :key="'wcce-' + lang.id">
                                    <a class="nav-link" href="javascript:void(0)"
                                        :class="{ active: customLangTabIndex === idx }" @click="customLangTabIndex = idx">
                                        <span :class="{ 'text-primary fw-bold': lang.is_default }">{{ lang.name }}</span>
                                    </a>
                                </li>
                            </ul>
                            <template v-for="(lang, idx) in languages" :key="'wccp-' + lang.id">
                                <div v-show="customLangTabIndex === idx">
                                    <TranslatableInput v-model="customDraft.name" :languages="languages" :active-lang="lang.id"
                                        :placeholder="__('category_name') + (lang.is_default ? ' *' : '')" />
                                </div>
                            </template>
                        </template>
                        <HbImageUpload :label="__('category_icon')" :model-value="customDraft.icon_url"
                            @update:model-value="customDraft.icon_url = $event" />
                        <small class="text-muted d-block mt-1">{{ __('custom_category_tab_hint') }}</small>
                        <div class="d-flex justify-content-end gap-2 mt-2">
                            <button type="button" class="btn btn-sm btn-secondary" @click="customDraft = null; editingKey = null">{{ __('cancel') }}</button>
                            <button type="button" class="btn btn-sm btn-primary" :disabled="!customDraftValid" @click="saveCustom">
                                {{ __('done') }}
                            </button>
                        </div>
                    </div>
                </template>
            </div>

            <div v-if="customDraft && !editingKey" class="hb-custom-editor">
                <label class="form-label small fw-bold">{{ __('category_name') }}</label>
                <TranslatableInput v-if="languages.length === 1"
                    v-model="customDraft.name" :languages="languages" :active-lang="languages[0].id"
                    :placeholder="__('category_name') + ' *'" />
                <template v-else>
                    <ul class="nav nav-tabs hb-block-lang-tabs mb-2">
                        <li class="nav-item" v-for="(lang, idx) in languages" :key="'wccn-' + lang.id">
                            <a class="nav-link" href="javascript:void(0)"
                                :class="{ active: customLangTabIndex === idx }" @click="customLangTabIndex = idx">
                                <span :class="{ 'text-primary fw-bold': lang.is_default }">{{ lang.name }}</span>
                            </a>
                        </li>
                    </ul>
                    <template v-for="(lang, idx) in languages" :key="'wccnp-' + lang.id">
                        <div v-show="customLangTabIndex === idx">
                            <TranslatableInput v-model="customDraft.name" :languages="languages" :active-lang="lang.id"
                                :placeholder="__('category_name') + (lang.is_default ? ' *' : '')" />
                        </div>
                    </template>
                </template>
                <HbImageUpload :label="__('category_icon')" :model-value="customDraft.icon_url"
                    @update:model-value="customDraft.icon_url = $event" />
                <small class="text-muted d-block mt-1">{{ __('custom_category_tab_hint') }}</small>
                <div class="d-flex justify-content-end gap-2 mt-2">
                    <button type="button" class="btn btn-sm btn-secondary" @click="customDraft = null; editingKey = null">{{ __('cancel') }}</button>
                    <button type="button" class="btn btn-sm btn-primary" :disabled="!customDraftValid" @click="saveCustom">
                        {{ __('done') }}
                    </button>
                </div>
            </div>
        </div>

        <!-- Step: zone -->
        <div v-if="current === 'zone'">
            <h6 class="mb-3">{{ __('where_does_this_apply') }}</h6>
            <div class="row g-3 mb-3">
                <div class="col-md-6" v-for="opt in zoneScopeOptions" :key="opt.value">
                    <div class="hb-choice-card"
                        :class="{ selected: form.zone_scope === opt.value, disabled: opt.disabled }"
                        @click="!opt.disabled && (form.zone_scope = opt.value)">
                        <strong>{{ opt.label }}</strong>
                        <small>{{ opt.help }}</small>
                        <span v-if="opt.badge" class="badge bg-light-danger text-danger mt-1">
                            {{ opt.badge }}
                        </span>
                    </div>
                </div>
            </div>
            <p v-if="modeLocked" class="text-muted small mt-1 mb-2">
                <Lock :size="14" /> {{ __('default_layout_scope_locked') }}
            </p>
            <!-- A layout targets exactly ONE zone; use the clone action to reuse a
                 design across zones. -->
            <div v-if="form.zone_scope === 'zone'" class="hb-check-grid">
                <label v-for="z in filteredZones" :key="z.id" class="hb-check-item hb-zone-item"
                    :class="{ disabled: takenZoneIds.includes(z.id) }">
                    <div class="hb-zone-top">
                        <input type="radio" :value="z.id" v-model="form.zone_id"
                            :disabled="takenZoneIds.includes(z.id)">
                        <span class="hb-zone-name" :title="z.name">{{ z.name }}</span>
                        <span v-if="z.sales_channel === 'both'" class="badge bg-light-info text-info">
                            {{ __('both') }}
                        </span>
                    </div>
                    <small v-if="takenZoneIds.includes(z.id)" class="text-danger hb-zone-flag">
                        {{ __('zone_already_used') }}
                    </small>
                </label>
                <p v-if="!filteredZones.length" class="text-muted">{{ __('no_records_found') }}</p>
            </div>
        </div>

        <!-- Step: name -->
        <div v-if="current === 'name'">
            <h6 class="mb-3">{{ __('name_your_layout') }}</h6>
            <input type="text" class="form-control" v-model="form.name" :placeholder="__('enter_name')">
            <ul class="list-unstyled small text-muted mt-3 hb-summary">
                <li><b>{{ __('home_type') }}:</b> {{ homeTypeLabel }}</li>
                <li><b>{{ __('channel') }}:</b> {{ form.mode }}</li>
                <li><b>{{ __('zone') }}:</b> {{ form.zone_scope === 'global' ? __('default_layout') : (zoneNameById(form.zone_id) || __('not_selected')) }}</li>
            </ul>
            <div v-if="setupChanged" class="alert alert-warning d-flex align-items-start gap-2 mt-2 py-2 px-3 mb-0">
                <AlertTriangle :size="16" class="mt-1" />
                <span class="small">{{ __('changing_layout_removes_existing_setup') }}</span>
            </div>
        </div>

        <template #footer>
            <div class="hb-wizard-footer">
                <div>
                    <button class="btn btn-light" @click="back" v-if="currentIndex > 0">{{ __('back') }}</button>
                </div>
                <div class="d-flex gap-2">
                    <button class="btn btn-secondary" @click="hide">{{ __('cancel') }}</button>
                    <button class="btn" :class="saveBtnDanger ? 'btn-warning' : 'btn-primary'"
                        @click="next" :disabled="!canAdvance">
                        <AlertTriangle v-if="saveBtnDanger" :size="14" class="me-1" />
                        {{ saveBtnLabel }}
                    </button>
                </div>
            </div>
        </template>
    </b-modal>
</template>

<script>
import axios from 'axios';
import { emptyConfig, genId } from '../homeBuilderHelpers.js';
import TranslatableInput from './TranslatableInput.vue';
import HbImageUpload from './HbImageUpload.vue';
import TranslationHelper from '../../../mixins/TranslationHelper.js';
import { Square, ListChecks, Lock, AlertTriangle, Plus, Pencil, Trash2 } from 'lucide-vue-next';

export default {
    name: 'HomeBuilderWizard',
    mixins: [TranslationHelper],
    components: { TranslatableInput, HbImageUpload, Square, ListChecks, Lock, AlertTriangle, Plus, Pencil, Trash2 },
    props: {
        // All existing layouts — used to enforce one default + one layout per zone per channel.
        existingLayouts: { type: Array, default: () => [] },
        // When set, wizard runs in edit mode: prefills form, keeps existing id,
        // does NOT touch draft_json / category_layouts_draft on save.
        initialLayout: { type: Object, default: null },
    },
    emits: ['complete', 'close'],
    data() {
        return {
            currentIndex: 0,
            catTab: 'quick',
            categories: [],
            categorySearch: '',
            // Custom (non-system) tabs created during setup.
            customDraft: null,
            editingKey: null,
            customLangTabIndex: 0,
            zones: [],
            languages: [],
            langTabIndex: 0,
            activeLang: null,
            form: {
                name: '',
                home_type: 'single',
                mode: 'quick',
                channel_label: {},
                category_scope: 'same',
                category_ids: [],
                custom_tabs: [],
                category_ids_quick: [],
                category_ids_ecommerce: [],
                zone_scope: 'global',
                zone_id: null,
            },
        };
    },
    computed: {
        // The channel label is the only translatable field in the wizard.
        translatableFields() {
            return ['channel_label'];
        },
        customDraftValid() {
            const n = this.customDraft && this.customDraft.name;
            return !!(n && String(n[this.defaultLanguageId] || '').trim());
        },
        defaultLanguageId() {
            const def = (this.languages || []).find(l => l.is_default == 1);
            return def ? def.id : null;
        },
        isEdit() {
            return !!(this.initialLayout && this.initialLayout.id);
        },
        // A default (global) layout's channel is locked so each channel always keeps
        // a fallback default layout — only its content/zone can change, not the mode.
        modeLocked() {
            return this.isEdit && this.initialLayout && this.initialLayout.zone_scope === 'global';
        },
        steps() {
            const s = ['type', 'mode'];
            if (this.form.home_type === 'category_wise') {
                // "All tab" is no longer a setup step — use a custom category tab instead.
                s.push('categories');
            }
            // Branch users are fixed to their own zone — skip the zone-selection step.
            if (!this.isBranchUser) {
                s.push('zone');
            }
            s.push('name');
            return s;
        },
        isBranchUser() {
            return typeof this.$isBranchUser === 'function' && this.$isBranchUser();
        },
        current() {
            return this.steps[this.currentIndex];
        },
        homeTypeOptions() {
            return [
                { value: 'single', icon: 'Square', label: __('single_layout'), help: __('single_layout_help') },
                { value: 'category_wise', icon: 'ListChecks', label: __('category_wise_layout'), help: __('category_wise_layout_help') },
            ];
        },
        modeOptions() {
            return [
                { value: 'quick', label: __('quick'), help: __('quick_commerce') },
                { value: 'ecommerce', label: __('ecommerce'), help: __('ecommerce') },
            ];
        },
        modeLabel() {
            const o = this.modeOptions.find(x => x.value === this.form.mode);
            return o ? o.label : this.form.mode;
        },
        categoryScopeOptions() {
            return [
                { value: 'same', label: __('same_for_both'), help: __('same_category_list_help') },
                { value: 'split', label: __('split_per_channel'), help: __('split_category_list_help') },
            ];
        },
        zoneScopeOptions() {
            return [
                {
                    value: 'global',
                    label: __('default_layout'),
                    help: __('default_layout_help'),
                    disabled: this.defaultTaken,
                    badge: this.defaultTaken ? __('default_layout_taken') : '',
                },
                {
                    value: 'zone',
                    label: __('specific_zone'),
                    help: __('specific_zone_help'),
                    // A default layout must stay global so the channel keeps a fallback.
                    disabled: this.modeLocked,
                },
            ];
        },
        // Layouts on the same channel as the chosen mode.
        overlappingLayouts() {
            const mode = this.form.mode;
            return this.existingLayouts.filter(l => l.mode === mode);
        },
        // True when a default layout already exists for this channel.
        defaultTaken() {
            return this.overlappingLayouts.some(l => l.zone_scope === 'global');
        },
        // Zone ids already bound to a layout on this channel.
        zoneNameById() {
            return id => (this.zones.find(z => Number(z.id) === Number(id)) || {}).name || '';
        },
        takenZoneIds() {
            const ids = [];
            this.overlappingLayouts.forEach(l => {
                if (l.zone_scope === 'zone' && l.zone_id) {
                    ids.push(Number(l.zone_id));
                }
            });
            return ids;
        },
        homeTypeLabel() {
            const o = this.homeTypeOptions.find(x => x.value === this.form.home_type);
            return o ? o.label : '';
        },
        // In edit mode, changing the layout structure (home type, channel mode, or
        // category split) reshapes where sections are stored — the existing built
        // sections no longer fit and are dropped. Used to warn before saving.
        setupChanged() {
            if (!this.isEdit) return false;
            const l = this.initialLayout;
            return this.form.home_type !== (l.home_type || 'single')
                || (this.form.home_type === 'category_wise'
                    && this.form.category_scope !== (l.category_scope || 'same'));
        },
        // Warn-styled save button only on the final step when the change is destructive.
        saveBtnDanger() {
            return this.currentIndex === this.steps.length - 1 && this.setupChanged;
        },
        saveBtnLabel() {
            if (this.currentIndex !== this.steps.length - 1) return __('next');
            if (this.setupChanged) return __('save_and_reset_layout');
            return this.isEdit ? __('save') : __('create');
        },
        // Zones filtered by the chosen channel (all countries — no global filter).
        filteredZones() {
            const countryId = 0;
            // A 'both' zone serves either channel, so it qualifies for both modes.
            return this.zones.filter(z =>
                (z.sales_channel === this.form.mode || z.sales_channel === 'both')
                && (!countryId || Number(z.country_id) === countryId));
        },
        // Categories filtered by the search box.
        filteredCategories() {
            const q = (this.categorySearch || '').trim().toLowerCase();
            if (!q) return this.categories;
            return this.categories.filter(c => (c.name || '').toLowerCase().includes(q));
        },
        // Proxy for the split-category checkbox list, bound to the active channel tab.
        splitCatModel: {
            get() {
                return this.catTab === 'quick' ? this.form.category_ids_quick : this.form.category_ids_ecommerce;
            },
            set(val) {
                if (this.catTab === 'quick') this.form.category_ids_quick = val;
                else this.form.category_ids_ecommerce = val;
            },
        },
        canAdvance() {
            return this.stepValid(this.current);
        },
    },
    watch: {
        // Mode change can flip what's "taken" — drop to zone scope if the
        // default is no longer available for the new channel.
        defaultTaken(taken) {
            if (taken && this.form.zone_scope === 'global') {
                this.form.zone_scope = 'zone';
            }
        },
        takenZoneIds(taken) {
            if (this.form.zone_id && taken.includes(Number(this.form.zone_id))) {
                this.form.zone_id = null;
            }
        },
    },
    mounted() {
        this.$refs.wizard.show();
        if (this.isEdit) this.prefillFromLayout();
        this.loadCategories();
        this.loadZones();
        this.loadLanguages();
        if (!this.isEdit && this.defaultTaken) this.form.zone_scope = 'zone';
        // Branch users are locked to their own branch's zone.
        if (this.isBranchUser) {
            this.form.zone_scope = 'zone';
            this.form.zone_id = window.BranchZoneId || this.form.zone_id;
        }
    },
    methods: {
        // `channel_label` is a { langId: text } map, not the mixin's default shape.
        getTranslateSource() {
            return {
                channel_label: (this.form.channel_label || {})[this.defaultLanguageId] || '',
            };
        },
        applyTranslated(lang, translated) {
            if (translated.channel_label == null) return;
            this.form.channel_label = {
                ...(this.form.channel_label || {}),
                [lang.id]: translated.channel_label,
            };
        },
        stepLabel(s) {
            const map = {
                type: __('type'), mode: __('channel'), category_scope: __('categories'),
                categories: __('categories'), zone: __('zone'), name: __('name'),
            };
            return map[s] || s;
        },
        loadCategories() {
            axios.get(this.$apiUrl + '/categories', { params: { status: 1 } })
                .then(res => { this.categories = res.data?.data || []; })
                .catch(() => { this.categories = []; });
        },
        loadZones() {
            axios.get(this.$apiUrl + '/zones')
                .then(res => { this.zones = res.data?.data || []; })
                .catch(() => { this.zones = []; });
        },
        loadLanguages() {
            axios.get(this.$apiUrl + '/active_languages')
                .then(res => {
                    this.languages = res.data?.data || [];
                    const def = this.languages.find(l => l.is_default) || this.languages[0];
                    this.activeLang = def ? def.id : null;
                    // Seed a default button label when not editing.
                    if (!this.isEdit && this.activeLang && !this.form.channel_label[this.activeLang]) {
                        this.form.channel_label = { ...this.form.channel_label, [this.activeLang]: 'Quick' };
                    }
                })
                .catch(() => { this.languages = []; });
        },
        back() {
            if (this.currentIndex > 0) this.currentIndex -= 1;
        },
        // Validity of any step, not just the current one — jumping ahead has to check
        // every step it would skip over.
        stepValid(step) {
            if (step === 'mode') {
                return Object.values(this.form.channel_label || {}).some(v => v && v.trim());
            }
            if (step === 'categories') {
                return (this.form.category_ids.length + this.form.custom_tabs.length) >= 1;
            }
            if (step === 'zone') {
                if (this.form.zone_scope === 'global') return !this.defaultTaken;
                return !!this.form.zone_id;
            }
            if (step === 'name') {
                return this.form.name.trim() !== '';
            }
            return true;
        },
        // First step between current and target that isn't satisfied, or null.
        firstBlockingStep(targetIndex) {
            for (let i = this.currentIndex; i < targetIndex; i++) {
                if (!this.stepValid(this.steps[i])) return this.steps[i];
            }
            return null;
        },
        canJumpTo(index) {
            return index <= this.currentIndex || this.firstBlockingStep(index) === null;
        },
        // Clicking the progress bar jumps straight to a step. Going back is always
        // allowed; going forward only once everything in between is filled in.
        goToStep(index) {
            if (index === this.currentIndex) return;
            if (index < this.currentIndex) {
                this.currentIndex = index;
                return;
            }
            const blocked = this.firstBlockingStep(index);
            if (blocked) {
                this.currentIndex = this.steps.indexOf(blocked);
                return;
            }
            this.currentIndex = index;
        },
        next() {
            if (!this.canAdvance) return;
            if (this.currentIndex === this.steps.length - 1) {
                this.finish();
                return;
            }
            this.currentIndex += 1;
        },
        hide() {
            this.$refs.wizard.hide();
        },
        customLabel(t) {
            const n = t && t.name ? t.name : {};
            return String(n[this.defaultLanguageId] || Object.values(n).find(v => v && String(v).trim()) || '').trim()
                || __('custom_category');
        },
        // One inline editor, used for both "add" and "edit" so the step stays a single screen.
        startCustom(tab = null) {
            this.customLangTabIndex = 0;
            // editingKey = the row the form belongs under; null while adding a new one,
            // so the form renders at the end of the list instead.
            this.editingKey = tab ? tab.key : null;
            this.customDraft = tab
                ? { key: tab.key, kind: 'custom', name: { ...(tab.name || {}) }, icon_url: tab.icon_url || '' }
                : { key: 'custom-' + genId('cat'), kind: 'custom', name: {}, icon_url: '' };
        },
        saveCustom() {
            if (!this.customDraftValid) return;
            const draft = JSON.parse(JSON.stringify(this.customDraft));
            const i = this.form.custom_tabs.findIndex(t => t.key === draft.key);
            if (i >= 0) this.form.custom_tabs.splice(i, 1, draft);
            else this.form.custom_tabs.push(draft);
            this.customDraft = null;
            this.editingKey = null;
        },
        removeCustom(key) {
            this.form.custom_tabs = this.form.custom_tabs.filter(t => t.key !== key);
            if (this.customDraft && this.customDraft.key === key) this.customDraft = null;
        },
        /**
         * Ordered tab list for the layout: existing tabs keep their order, deselected
         * system tabs drop out, newly picked ones are appended, and custom tabs come
         * from this step. Never emitted for single-type layouts.
         */
        buildCategoryTabs() {
            const selected = this.form.category_ids.map(Number);
            const customByKey = new Map(this.form.custom_tabs.map(t => [t.key, t]));
            const existing = (this.initialLayout && this.initialLayout.category_tabs_draft) || [];

            const tabs = [];
            const seenSystem = new Set();
            existing.forEach(t => {
                if (!t) return;
                if (t.kind === 'custom') {
                    // Kept only while it still exists in this step (it may have been removed).
                    if (customByKey.has(t.key)) {
                        tabs.push(JSON.parse(JSON.stringify(customByKey.get(t.key))));
                        customByKey.delete(t.key);
                    }
                    return;
                }
                const id = Number(t.category_id);
                if (selected.includes(id) && !seenSystem.has(id)) {
                    seenSystem.add(id);
                    tabs.push({ key: String(id), kind: 'system', category_id: id });
                }
            });

            selected.forEach(id => {
                if (seenSystem.has(id)) return;
                seenSystem.add(id);
                tabs.push({ key: String(id), kind: 'system', category_id: id });
            });
            customByKey.forEach(t => tabs.push(JSON.parse(JSON.stringify(t))));

            return tabs;
        },
        prefillFromLayout() {
            const l = this.initialLayout;
            this.form.name = l.name || '';
            this.form.home_type = l.home_type || 'single';
            this.form.mode = l.mode || 'quick';
            this.form.channel_label = l.channel_label || {};
            this.form.category_scope = l.category_scope || 'same';
            // Same for the selected system categories: fall back to the tab list when the
            // legacy id array was not kept in step with it.
            const systemIds = []
                .concat(l.category_tabs_draft || [], l.category_tabs_published || [])
                .filter(t => t && t.kind !== 'custom')
                .map(t => Number(t.category_id ?? t.key))
                .filter(id => Number.isFinite(id) && id > 0);
            this.form.category_ids = (l.category_ids || []).length
                ? (l.category_ids || []).map(Number)
                : [...new Set(systemIds)];
            this.form.category_ids_quick = (l.category_ids_quick || []).map(Number);
            this.form.category_ids_ecommerce = (l.category_ids_ecommerce || []).map(Number);
            this.form.zone_scope = l.zone_scope || 'global';
            this.form.zone_id = l.zone_id ? Number(l.zone_id) : null;
            // Custom tabs live alongside the system ones in the tab list — and the editor
            // writes to whichever snapshot is open, so a tab added while editing the
            // published layout is only in category_tabs_published. Read both, unique by
            // key, or a custom category vanishes from this modal.
            const seen = new Set();
            this.form.custom_tabs = []
                .concat(l.category_tabs_draft || [], l.category_tabs_published || [])
                .filter(t => t && t.kind === 'custom' && !seen.has(String(t.key)) && seen.add(String(t.key)))
                .map(t => ({ key: t.key, kind: 'custom', name: { ...(t.name || {}) }, icon_url: t.icon_url || '' }));
        },
        finish() {
            const f = this.form;
            // Per-channel layouts only — no "both", so category lists are never split.
            const payload = {
                name: f.name.trim(),
                home_type: f.home_type,
                mode: f.mode,
                channel_label: f.channel_label,
                zone_scope: f.zone_scope,
                zone_id: f.zone_scope === 'zone' ? f.zone_id : null,
                category_scope: 'same',
                category_ids: f.home_type === 'category_wise' ? f.category_ids : [],
                category_ids_quick: [],
                category_ids_ecommerce: [],
                category_build_method: 'independent',
                is_active: 1,
            };
            // The builder reads category_tabs_draft first, so custom tabs picked here
            // must travel with the layout — otherwise only the system ids survive.
            if (f.home_type === 'category_wise') {
                payload.category_tabs_draft = this.buildCategoryTabs();
            }
            if (this.isEdit) {
                payload.id = this.initialLayout.id;
                // Do NOT overwrite draft_json / category_layouts_* on edit —
                // backend save() only updates fields present in the request.
            } else {
                payload.draft_json = emptyConfig();
                payload.category_layouts_draft = {};
            }
            this.$emit('complete', payload);
        },
    },
};
</script>

<style scoped>
/* Custom category list + inline editor inside the categories step. */
.hb-custom-row {
    display: flex;
    align-items: center;
    gap: .5rem;
    padding: .4rem .6rem;
    border: 1px solid var(--app-card-border);
    border-radius: .5rem;
    margin-bottom: .35rem;
    font-size: .85rem;
}
.hb-custom-icon { width: 24px; height: 24px; object-fit: cover; border-radius: .25rem; flex-shrink: 0; }
.hb-custom-editor {
    border: 1px dashed var(--app-card-border);
    border-radius: .5rem;
    padding: .75rem;
    background: var(--app-thead-bg);
}
.hb-wizard-steps {
    display: flex;
    gap: .25rem;
    flex-wrap: wrap;
}
.hb-wizard-step {
    display: flex;
    align-items: center;
    gap: .35rem;
    font-size: .8rem;
    color: #9aa0ac;
    flex: 1;
    min-width: 90px;
}

/* Steps are navigable; a step you can't reach yet stays visibly inert. */
.hb-wizard-step.clickable {
    cursor: pointer;
}

.hb-wizard-step:not(.clickable) {
    cursor: not-allowed;
}

.hb-wizard-step.clickable:hover .hb-wizard-label {
    color: var(--bs-primary);
}

.hb-wizard-step:focus-visible {
    outline: 2px solid var(--bs-primary);
    outline-offset: 2px;
    border-radius: 6px;
}
.hb-wizard-dot {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    background: #e9ecef;
    color: #6c757d;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 600;
    font-size: .75rem;
}
.hb-wizard-step.active .hb-wizard-dot,
.hb-wizard-step.done .hb-wizard-dot {
    background: var(--bs-primary);
    color: #fff;
}
.hb-wizard-step.active .hb-wizard-label {
    color: var(--bs-primary);
    font-weight: 600;
}
.hb-toggle-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    border: 1.5px solid #e9ecef;
    border-radius: .6rem;
    padding: .75rem 1rem;
    margin-bottom: .6rem;
    cursor: pointer;
    transition: border-color .15s ease, background .15s ease;
}
.hb-toggle-row:hover {
    border-color: var(--bs-primary);
}
.hb-toggle-row.on {
    border-color: var(--bs-primary);
    background: rgba(var(--bs-primary-rgb), .06);
}
.hb-toggle-text {
    display: flex;
    flex-direction: column;
    line-height: 1.25;
}
.hb-toggle-title {
    font-weight: 600;
    font-size: .9rem;
}
.hb-toggle-row .form-switch .form-check-input {
    width: 2.4em;
    height: 1.3em;
    cursor: pointer;
}
.hb-choice-card {
    border: 2px solid #e9ecef;
    border-radius: .6rem;
    padding: 1rem;
    cursor: pointer;
    display: flex;
    flex-direction: column;
    gap: .25rem;
    height: 100%;
    transition: border-color .15s, background .15s;
}
.hb-choice-card:hover {
    border-color: rgba(var(--bs-primary-rgb), .5);
}
.hb-choice-card.selected {
    border-color: var(--bs-primary);
    background: rgba(var(--bs-primary-rgb), .06);
}
.hb-choice-card.disabled {
    opacity: .55;
    cursor: not-allowed;
    background: #f8f9fa;
}
.hb-choice-card.disabled:hover {
    border-color: #e9ecef;
}
.hb-check-item.disabled {
    opacity: .55;
    cursor: not-allowed;
    background: #f8f9fa;
}
.hb-choice-card i {
    font-size: 1.4rem;
    color: var(--bs-primary);
}
.hb-choice-card small {
    color: #9aa0ac;
}
.hb-check-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: .5rem;
    max-height: 360px;
    overflow-y: auto;
    padding: .25rem;
}
.hb-check-item {
    display: flex;
    align-items: center;
    gap: .4rem;
    padding: .4rem .6rem;
    border: 1px solid #e9ecef;
    border-radius: .4rem;
    cursor: pointer;
    font-size: .85rem;
    margin: 0;
    min-width: 0;
}
.hb-check-item > span {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
    flex: 1;
}
.hb-zone-item {
    flex-direction: column;
    align-items: stretch;
    gap: .25rem;
}
.hb-zone-top {
    display: flex;
    align-items: center;
    gap: .4rem;
    min-width: 0;
}
.hb-zone-name {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}
.hb-zone-flag {
    font-size: .7rem;
    line-height: 1.1;
    display: block;
    white-space: normal;
}
.hb-wizard-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
}
.hb-summary li {
    padding: .15rem 0;
}
.hb-custom-row.is-editing { border-color: var(--bs-primary); background: rgba(var(--bs-primary-rgb), .06); }
</style>

<style>
.hb-wizard-modal .modal-dialog {
    max-width: 1100px;
}
.hb-wizard-modal .modal-body {
    min-height: 380px;
}
</style>
