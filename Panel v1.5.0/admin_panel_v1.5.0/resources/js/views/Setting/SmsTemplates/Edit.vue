<template>
    <b-modal ref="modal" :title="modalTitle" @hidden="onModalHidden" no-fade static centered size="xl">
      <template #footer>
        <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        <b-button variant="primary" @click="saveRecord" :disabled="isLoading">
          {{ __('save') }}
          <b-spinner v-if="isLoading" small></b-spinner>
        </b-button>
      </template>

      <div v-if="record">

        <!-- Clickable placeholders: click to insert at cursor position in title/message -->
        <div v-if="placeholderKeys.length" class="py-2 mb-2 small">
          <strong>{{ __('placeholders') }}:</strong>
          {{ __('click_to_insert_at_cursor_location') }}
          <div class="mt-1">
            <button
              v-for="key in placeholderKeys"
              :key="key"
              type="button"
              class="btn btn-sm btn-primary mr-1 mb-1 me-1"
              @click="insertPlaceholder(key)"
              v-text="placeholderSyntax(key)"
            ></button>
          </div>
        </div>

        <b-tabs v-model="activeLanguageTab" content-class="mt-3" v-if="languages.length > 0" :nav-class="languages.length <= 1 ? 'd-none' : null">
          <b-tab v-for="(language, idx) in languages" :key="language.id" :lazy="idx > 0">
            <template #title>
              <span :class="{ 'text-primary font-weight-bold': language.is_default }">{{ language.name }}</span>
            </template>

            <div class="row" v-if="translations[language.id]">
              <div class="col-12 form-group">
                <label>{{ __('message') }}</label>
                <textarea
                  class="form-control"
                  rows="4"
                  v-model="translations[language.id].message"
                  :placeholder="messagePlaceholderHint"
                  @focus="setActiveField($event, language.id, 'message')"
                ></textarea>
              </div>

              <!-- Per-gateway DLT template ids (SMS-specific, not translated) -->
              <div class="col-md-6 form-group mb-0">
                <label>{{ __('msg91_dlt_template_id') }} <small class="text-muted">({{ __('optional') }})</small></label>
                <input type="text" class="form-control" v-model="translations[language.id].gateway_template_ids.msg91"
                  :placeholder="__('msg91_dlt_template_id_hint')">
              </div>
              <div class="col-md-6 form-group mb-0">
                <label>{{ __('fast2sms_dlt_template_id') }} <small class="text-muted">({{ __('optional') }})</small></label>
                <input type="text" class="form-control" v-model="translations[language.id].gateway_template_ids.fast2sms"
                  :placeholder="__('fast2sms_dlt_template_id_hint')">
              </div>
              <div class="col-md-6 form-group mb-0 mt-2">
                <label>{{ __('twofactor_dlt_template_name') }} <small class="text-muted">({{ __('optional') }})</small></label>
                <input type="text" class="form-control" v-model="translations[language.id].gateway_template_ids.twofactor"
                  :placeholder="__('twofactor_dlt_template_name_hint')">
              </div>
            </div>
          </b-tab>

          <!-- Translate control, inline with the language tabs. -->
          <template #tabs-end>
            <li class="nav-item ms-auto d-flex align-items-center">
              <TranslateLanguages :languages="languages" :default-language-id="defaultLanguageId" :busy="translating"
                :progress="translateProgress" @translate="runTranslate" />
            </li>
          </template>
        </b-tabs>
      </div>
    </b-modal>
  </template>

  <script>
  import axios from 'axios';
  import TranslationHelper from '../../../mixins/TranslationHelper.js';
  import UnsavedChanges from '../../../mixins/UnsavedChanges.js';

  export default {
    props: {
      record: {
        type: Object,
        default: null,
      },
    },
    mixins: [TranslationHelper, UnsavedChanges],
    data() {
      return {
        isLoading: false,
        activeLanguageTab: 0,
        languages: [],
        translations: {},
        translatableFields: ['message'],
        defaultLanguageId: null,
        activeFieldRef: null,
        activeFieldLangId: null,
        activeFieldName: null,
      };
    },
    computed: {
      modalTitle() {
        return this.__('edit') + ' - ' + (this.record ? (this.record.label || this.record.type) : '');
      },
      // Normalize placeholders: API may send array or JSON string
      placeholderKeys() {
        if (!this.record || !this.record.placeholders) return [];
        const p = this.record.placeholders;
        if (Array.isArray(p)) return p;
        try {
          const parsed = typeof p === 'string' ? JSON.parse(p) : p;
          return Array.isArray(parsed) ? parsed : [];
        } catch (_) {
          return [];
        }
      },
      placeholderSyntaxList() {
        const list = this.placeholderKeys;
        return list.map((key) => '{{' + key + '}}').join(', ') || '-';
      },
      titlePlaceholderHint() {
        if (!this.placeholderSyntaxList || this.placeholderSyntaxList === '-') return this.__('title');
        const first = this.placeholderKeys[0];
        return this.__('e.g.') + ' ... ' + (first ? '{{' + first + '}} ...' : this.placeholderSyntaxList);
      },
      messagePlaceholderHint() {
        if (!this.placeholderSyntaxList || this.placeholderSyntaxList === '-') return this.__('message');
        return this.__('e.g.') + ' ... ' + this.placeholderSyntaxList;
      },
    },
    watch: {
      record: {
        immediate: true,
        handler(val) {
          if (val) {
            this.loadData();
          }
        },
      },
    },
    mounted() {
      if (this.record) {
        this.$refs.modal.show();
        this.loadData();
      }
    },
    methods: {
      // Tracked state for the UnsavedChanges guard
      formState() {
        return this.translations;
      },
      placeholderSyntax(key) {
        return '{{' + key + '}}';
      },
      setActiveField(event, langId, fieldName) {
        this.activeFieldRef = event.target;
        this.activeFieldLangId = langId;
        this.activeFieldName = fieldName;
      },
      insertPlaceholder(key) {
        const syntax = '{{' + key + '}}';
        const el = this.activeFieldRef;
        const langId = this.activeFieldLangId;
        const fieldName = this.activeFieldName;

        if (!el || !document.contains(el) || !this.translations[langId]) {
          // No field focused: insert into default language message
          const defaultLang = this.languages.find((l) => l.is_default);
          if (defaultLang && this.translations[defaultLang.id]) {
            const current = this.translations[defaultLang.id].message || '';
            this.translations[defaultLang.id]['message'] = current + syntax;
          }
          return;
        }

        const start = el.selectionStart;
        const end = el.selectionEnd;
        const current = this.translations[langId][fieldName] || '';
        const before = current.substring(0, start);
        const after = current.substring(end);
        const newVal = before + syntax + after;

        this.translations[langId][fieldName] = newVal;
        this.$nextTick(() => {
          el.focus();
          const newPos = start + syntax.length;
          el.setSelectionRange(newPos, newPos);
        });
      },
      async loadData() {
        if (!this.record) return;
        try {
          const [langRes, tplRes] = await Promise.all([
            axios.get(this.$apiUrl + '/active_languages'),
            axios.get(this.$apiUrl + '/sms_templates/edit/' + this.record.id),
          ]);
          this.languages = langRes.data.data || [];
          const tpl = tplRes.data.data || {};

          this.translations = {};
          this.languages.forEach((lang) => {
            this.translations[lang.id] = {
              message: '',
              gateway_template_ids: { msg91: '', fast2sms: '', twofactor: '' },
            };
          });

          const defaultLang = this.languages.find((l) => l.is_default);
          if (defaultLang) {
            this.defaultLanguageId = defaultLang.id;
          }

          (tpl.translations || []).forEach((t) => {
            if (this.translations[t.language_id]) {
              const ids = t.gateway_template_ids || {};
              this.translations[t.language_id].message = t.message || '';
              this.translations[t.language_id].gateway_template_ids = {
                msg91: ids.msg91 || '',
                fast2sms: ids.fast2sms || '',
                twofactor: ids.twofactor || '',
              };
            }
          });

          // Fall back base message onto the default language when it has no translation yet.
          if (defaultLang && this.translations[defaultLang.id]) {
            if (!this.translations[defaultLang.id].message && tpl.message) this.translations[defaultLang.id].message = tpl.message;
          }
          // Snapshot the loaded translations as the "clean" baseline for the guard.
          this.captureFormBaseline();
        } catch (e) {
          console.error(e);
        }
      },
      validateDefaultLanguageForTranslation() {
        if (!this.defaultLanguageId) {
          this.showError(this.__('default_language_not_found'));
          return false;
        }
        const defaultTrans = this.translations[this.defaultLanguageId];
        if (!defaultTrans.message) {
          this.showError(this.__('please_fill_default_language_required_fields'));
          return false;
        }
        return true;
      },
      onModalHidden() {
        this.activeFieldRef = null;
        this.activeFieldLangId = null;
        this.activeFieldName = null;
        this.$emit('modalClose');
      },
      hideModal() {
        this.$refs.modal.hide();
      },
      saveRecord() {
        if (!this.record) return;
        if (!this.validateDefaultLanguageForTranslation()) return;

        this.isLoading = true;
        const promises = this.languages.map((lang) => {
          const t = this.translations[lang.id];
          const formData = new FormData();
          formData.append('id', this.record.id);
          formData.append('language_id', lang.id);
          formData.append('message', t.message || '');
          formData.append('gateway_template_ids', JSON.stringify(t.gateway_template_ids || {}));
          return axios.post(this.$apiUrl + '/sms_templates/update', formData);
        });
        Promise.all(promises)
          .then(() => {
            this.isLoading = false;
            // Mark clean so closing the modal doesn't trip the unsaved-changes guard.
            this.captureFormBaseline();
            this.hideModal();
            this.$eventBus.emit('SmsTemplatesSaved', this.__('sms_template_updated_successfully'));
          })
          .catch((error) => {
            this.isLoading = false;
            this.showError(error.response?.data?.message || error.message || this.__('something_went_wrong'));
          });
      },
    },
  };
  </script>
