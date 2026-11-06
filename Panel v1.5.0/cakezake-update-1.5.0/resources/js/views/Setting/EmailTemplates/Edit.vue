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

        <!-- Clickable placeholders: click to insert at cursor in the focused editor -->
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
                <label>{{ __('subject') }}</label>
                <editor v-if="tinymceReady"
                  :init="tinymceSubjectInit"
                  tinymce-script-src="/assets/js/tinymce/tinymce.min.js?v=7922"
                  license-key="gpl"
                  v-model="translations[language.id].title" />
              </div>
              <div class="col-12 form-group">
                <label>{{ __('message') }}</label>
                <editor v-if="tinymceReady"
                  :init="tinymceInit"
                  tinymce-script-src="/assets/js/tinymce/tinymce.min.js?v=7922"
                  license-key="gpl"
                  v-model="translations[language.id].message" />
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
  import Editor from '@tinymce/tinymce-vue';
  import { tinymceInit as buildTinymceInit } from '../../../utils/tinymce.js';
  import TranslationHelper from '../../../mixins/TranslationHelper.js';
  import UnsavedChanges from '../../../mixins/UnsavedChanges.js';

  export default {
    components: { editor: Editor },
    props: {
      record: {
        type: Object,
        default: null,
      },
    },
    data() {
      const vm = this;
      return {
        isLoading: false,
        activeLanguageTab: 0,
        languages: [],
        translations: {},
        translatableFields: ['title', 'message'],
        defaultLanguageId: null,
        tinymceReady: false,
        activeEditor: null,
        // Capture the focused editor so placeholder buttons insert into the right one.
        tinymceInit: buildTinymceInit({ height: 260, setup: (ed) => ed.on('focus', () => { vm.activeEditor = ed; }) }),
        tinymceSubjectInit: buildTinymceInit({ height: 90, menubar: false, toolbar: false, statusbar: false, setup: (ed) => ed.on('focus', () => { vm.activeEditor = ed; }) }),
      };
    },
    mixins: [TranslationHelper, UnsavedChanges],
    computed: {
      modalTitle() {
        return this.__('edit') + ' - ' + (this.record ? (this.record.label || this.record.type) : '');
      },
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
      this.loadTinymce();
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
      insertPlaceholder(key) {
        const syntax = '{{' + key + '}}';
        if (this.activeEditor && !this.activeEditor.destroyed) {
          this.activeEditor.insertContent(syntax);
          return;
        }
        // No editor focused: append to the default language subject.
        const defaultLang = this.languages.find((l) => l.is_default);
        if (defaultLang && this.translations[defaultLang.id]) {
          this.translations[defaultLang.id].title = (this.translations[defaultLang.id].title || '') + syntax;
        }
      },
      async loadLanguages() {
        if (!this.record) return;
        try {
          const res = await axios.get(this.$apiUrl + '/active_languages');
          this.languages = res.data.data || [];
          this.translations = {};
          this.languages.forEach((lang) => {
            this.translations[lang.id] = { title: '', message: '' };
          });
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
        this.activeEditor = null;
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
            email_template_id: this.record.id,
            language_id: lang.id,
            title: this.translations[lang.id].title || '',
            message: this.translations[lang.id].message || '',
          };
          return axios.post(this.$apiUrl + '/email_templates/update_translation', payload);
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
