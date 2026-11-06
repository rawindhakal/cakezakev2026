<template>
    <b-modal ref="modal" :title="modalTitle" @hidden="onModalHidden" no-fade static centered size="xl">
      <template #footer>
        <b-button variant="primary" @click="saveRecord" :disabled="isLoading">
          {{ __('save') }}
          <b-spinner v-if="isLoading" small></b-spinner>
        </b-button>
        <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
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

            <div class="row">
              <div class="col-12 form-group">
                <label>{{ __('title') }}</label>
                <input
                  type="text"
                  class="form-control"
                  v-model="translations[language.id].title"
                  :placeholder="titlePlaceholderHint"
                  @focus="setActiveField($event, language.id, 'title')"
                />
              </div>
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
    data() {
      return {
        isLoading: false,
        activeLanguageTab: 0,
        languages: [],
        translations: {},
        translatableFields: ['title', 'message'],
        defaultLanguageId: null,
        activeFieldRef: null,
        activeFieldLangId: null,
        activeFieldName: null,
      };
    },
    mixins: [TranslationHelper, UnsavedChanges],
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
      // Placeholders in exact syntax to write in title/message: {{key1}}, {{key2}}
      placeholderSyntaxList() {
        const list = this.placeholderKeys;
        return list.map((key) => '{{' + key + '}}').join(', ') || '-';
      },
      // Example placeholder text for input so user knows the format
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
            this.loadLanguages();
          }
        },
      },
    },
    mounted() {
      if (this.record) {
        this.$refs.modal.show();
        this.loadLanguages();
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
          // No field focused: insert into default language title
          const defaultLang = this.languages.find((l) => l.is_default);
          if (defaultLang && this.translations[defaultLang.id]) {
            const current = this.translations[defaultLang.id].title || '';
            this.translations[defaultLang.id]['title'] = current + syntax;
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
      async loadLanguages() {
        if (!this.record) return;
        try {
          // Use active languages API (same as all other modules), not supported_languages
          const res = await axios.get(this.$apiUrl + '/active_languages');
          this.languages = res.data.data || [];
          this.translations = {};
          this.languages.forEach((lang) => {
            this.translations[lang.id] = { title: '', message: '' };
          });
          // Find default language
          const defaultLang = this.languages.find((l) => l.is_default);
          if (defaultLang) {
            this.defaultLanguageId = defaultLang.id;
          }
          if (this.record.translations && this.record.translations.length) {
            this.record.translations.forEach((t) => {
              if (this.translations[t.language_id]) {
                this.translations[t.language_id].title = t.title || '';
                this.translations[t.language_id].message = t.message || '';
              }
            });
          }
          if (this.record.title && this.languages.length) {
            if (defaultLang && this.translations[defaultLang.id]) {
              if (!this.translations[defaultLang.id].title) this.translations[defaultLang.id].title = this.record.title;
              if (!this.translations[defaultLang.id].message && this.record.message) this.translations[defaultLang.id].message = this.record.message;
            }
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
        if (!defaultTrans.title || !defaultTrans.message) {
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
          const payload = {
            notification_template_id: this.record.id,
            language_id: lang.id,
            title: this.translations[lang.id].title || '',
            message: this.translations[lang.id].message || '',
          };
          return axios.post(this.$apiUrl + '/notification_templates/update', payload);
        });
        Promise.all(promises)
          .then(() => {
            this.isLoading = false;
            // Mark clean so closing the modal doesn't trip the unsaved-changes guard.
            this.captureFormBaseline();
            this.hideModal();
            this.$emit('saved');
          })
          .catch(() => {
            this.isLoading = false;
            this.showMessage('error', this.__('something_went_wrong'));
          });
      },
    },
  };
  </script>
  