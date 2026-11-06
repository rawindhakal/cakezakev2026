<template>
  <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" size="xl" centered scrollable
    no-close-on-backdrop no-fade static>
    <template #footer>
      <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">
        {{ __('save') }}
        <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
      </b-button>
      <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
    </template>

    <form ref="my-form" @submit.prevent="saveRecord">
      <b-tabs v-model="activeLanguageTab" content-class="mt-3" v-if="languages.length > 0" :nav-class="languages.length <= 1 ? 'd-none' : null">
        <b-tab v-for="language in languages" :key="language.id" :title="language.name" lazy>
          <template #title>
            <span :class="{ 'text-primary font-weight-bold': language.is_default }">
              {{ language.name }}
            </span>
          </template>

          <div class="row">
            <div class="form-group col-md-6 mt-0" v-if="language.is_default">
              <label>{{ __("SEO Page") }}</label>
              <AppSelect v-model="page_type" class="form-control form-select" :options="pageOptions"
                :allow-empty="false" />
            </div>

            <div class="form-group col-md-6" v-if="language.is_default">
              <label>{{ __('zone') }}</label>
              <AppSelect v-model="zone_id" class="form-control form-select" :options="zoneOptions"
                :allow-empty="false" :disabled="!hasDefaultForPage" />
              <small v-if="!hasDefaultForPage" class="text-warning">{{ __('add_default_seo_for_this_page_first') }}</small>
              <small v-else class="text-muted">{{ __('seo_zone_hint') }}</small>
            </div>

            <!-- Shared SEO section (meta_keyword is singular here) -->
            <SeoSection :translation="translations[language.id]" :is-default="!!language.is_default"
              keyword-field="meta_keyword" :uid="language.id"
              :context="{ name: page_type, context: 'website page' }" />

            <FileUpload v-if="language.is_default" v-model="og_image" :label="__('og_image')" required
              accept="image/*" recommended-size="1200x630px" :max-size-mb="2" :preview-url="og_image_url" />
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

      <button ref="dummy_submit" style="display: none;"></button>
    </form>
  </b-modal>
</template>

<script>
import axios from 'axios';
import TranslationHelper from '../../../mixins/TranslationHelper.js';
import UnsavedChanges from '../../../mixins/UnsavedChanges.js';

export default {
  props: { 'record': Object },
  emits: ['saved', 'modalClose'],
  mixins: [TranslationHelper, UnsavedChanges],

  data() {
    return {
      isLoading: false,
      languages: [],
      activeLanguageTab: 0,
      defaultLanguageId: null,

      id: this.record?.id || null,
      page_type: this.record?.page_type || 'Home',
   
      zone_id: this.record ? Number(this.record.zone_id || 0) : 0,
      zones: [],
      // page_type values that already have a default (zone_id 0) entry — a zone can
      // only be picked for a page once its default SEO exists.
      pageTypesWithDefault: [],

      translations: {},
      og_image: null,
      og_image_url: this.record ? this.record.og_image_url : null,

      translatableFields: ['meta_title', 'meta_keyword', 'schema_markup', 'meta_description'],

      pages: [
        { id: 1, name: 'Home', value: 'Home' },
        { id: 2, name: 'About us', value: 'About us' },
        { id: 3, name: 'Contact us', value: 'Contact us' },
        { id: 4, name: 'Faqs', value: 'Faqs' },
        { id: 5, name: 'Term condition', value: 'Term condition' },
        { id: 6, name: 'Product listing page', value: 'Product listing page' },
        { id: 7, name: 'Privacy policy', value: 'Privacy policy' },
        { id: 8, name: 'Return exchange policy', value: 'Return exchange policy' },
        { id: 9, name: 'Shipping policy', value: 'Shipping policy' },
        { id: 10, name: 'Cancellation policy', value: 'Cancellation policy' },
        { id: 11, name: 'blog_listing_page', value: 'Blog Listing Page' }
      ]
    };
  },

  computed: {
    // Does the selected page already have its default (zone_id 0) SEO? Editing an
    // existing default row counts as having it.
    hasDefaultForPage() {
      if (this.id && Number(this.zone_id) === 0) return true;
      return this.pageTypesWithDefault.includes(this.page_type);
    },
    zoneOptions() {
      // Until the page's default exists, only "Default" is selectable.
      if (!this.hasDefaultForPage) {
        return [{ id: 0, name: __('default') }];
      }
      return [{ id: 0, name: __('default') }]
        .concat((this.zones || []).map(z => ({ id: Number(z.id), name: z.name })));
    },
    // pages hold untranslated name keys; AppSelect needs { id, name }.
    pageOptions() {
      return (this.pages || []).map(p => ({ id: p.value, name: __(p.name) }));
    },
    modal_title: function () {
      return this.id ? __('edit_seo_setting') : __('add_seo_setting');

    }
  },

  methods: {
    // Tracked state for the UnsavedChanges guard
    formState() {
      return {
        translations: this.translations,
        page_type: this.page_type,
        zone_id: this.zone_id,
        og_image: this.og_image,
      };
    },
    showModal() {
      this.$refs['my-modal'].show();
    },

    hideModal() {
      this.$refs['my-modal'].hide();
    },

    validateDefaultLanguageForTranslation() {
      const defaultData = this.translations[this.defaultLanguageId];
      const requiredFields = ['meta_title', 'meta_keyword', 'schema_markup', 'meta_description'];
      const missingFields = requiredFields.filter(
        (f) => !defaultData?.[f] || String(defaultData[f]).trim() === ''
      );
      if (missingFields.length > 0) {
        this.showError(__('please_fill_default_language_required_fields') || 'Please fill SEO fields in default language');
        this.$nextTick(() => this.switchToDefaultLanguageTab());
        return false;
      }

      const form = this.$refs['my-form'];
      if (form && !form.reportValidity()) {
        this.$nextTick(() => this.switchToDefaultLanguageTab());
        return false;
      }
      return true;
    },

    switchToDefaultLanguageTab() {
      const index = this.languages.findIndex(lang => lang.id === this.defaultLanguageId);
      if (index !== -1) this.activeLanguageTab = index;
    },

    fetchLanguages() {
      return axios.get(this.$apiUrl + '/active_languages')
        .then(res => {
          this.languages = res.data.data || [];


          const obj = {};
          this.languages.forEach(l => {
            obj[l.id] = {
              meta_title: '',
              meta_keyword: '',
              schema_markup: '',
              meta_description: ''
            };
          });

          this.translations = obj;

          this.defaultLanguageId =
            this.languages.find(l => l.is_default)?.id || null;
        });
    }
    ,

    initTranslations() {
      const obj = {};
      this.languages.forEach(l => {
        obj[l.id] = {
          meta_title: '',
          meta_keyword: '',
          schema_markup: '',
          meta_description: ''
        };
      });
      this.translations = obj;
    },

    loadSeoTranslations() {
      if (!this.record) return;

      const updatedTranslations = { ...this.translations };

      if (Array.isArray(this.record.translations)) {
        this.record.translations.forEach(t => {
          updatedTranslations[t.language_id] = {
            meta_title: t.meta_title || '',
            meta_keyword: t.meta_keyword || '',
            schema_markup: t.schema_markup || '',
            meta_description: t.meta_description || ''
          };
        });
      }


      this.languages.forEach(language => {
        const langId = language.id;
        const tr = updatedTranslations[langId];

        const isEmpty =
          !tr ||
          (!tr.meta_title &&
            !tr.meta_keyword &&
            !tr.schema_markup &&
            !tr.meta_description);

        if (language.is_default && isEmpty) {
          updatedTranslations[langId] = {
            meta_title: this.record.meta_title || '',
            meta_keyword: this.record.meta_keyword || '',
            schema_markup: this.record.schema_markup || '',
            meta_description: this.record.meta_description || ''
          };
        }
      });


      this.translations = updatedTranslations;
    },

    loadZones() {
      axios.get(this.$apiUrl + '/zones')
        .then(res => { this.zones = res.data?.data || []; })
        .catch(() => { this.zones = []; });
    },

    // Which page types already have a default (zone_id 0) SEO entry.
    loadDefaults() {
      axios.get(this.$apiUrl + '/seo_settings', { params: { limit: 0 } })
        .then(res => {
          const rows = res.data?.data || [];
          this.pageTypesWithDefault = rows
            .filter(r => Number(r.zone_id) === 0)
            .map(r => r.page_type);
        })
        .catch(() => { this.pageTypesWithDefault = []; });
    },

    async saveRecord() {
      if (!this.validateDefaultLanguageForTranslation()) return;
      // OG image required when creating new SEO setting
      if (!this.id && !this.og_image) {
        this.showError(__('please_upload_og_image') || 'Please upload OG image');
        this.$nextTick(() => this.switchToDefaultLanguageTab());
        return;
      }
      this.isLoading = true;
      let seoId = this.id;

      try {
        const langs = [
          ...this.languages.filter(l => l.is_default),
          ...this.languages.filter(l => !l.is_default)
        ];

        for (const lang of langs) {
          const fd = new FormData();

          if (seoId) fd.append('id', seoId);

          fd.append('language_id', lang.id);
          fd.append('page_type', this.page_type);
          fd.append('zone_id', this.zone_id ?? 0);

          Object.entries(this.translations[lang.id] || {})
            .forEach(([k, v]) => fd.append(k, v || ''));

          if (lang.is_default && this.og_image) {
            fd.append('og_image', this.og_image);
          }

          const url = this.$apiUrl +
            (seoId ? '/seo_settings/update' : '/seo_settings/save');

          const res = await axios.post(url, fd);

          if (res?.data?.status === 0) {
            this.showError(res.data.message || __('something_went_wrong'));
            this.$nextTick(() => this.switchToDefaultLanguageTab());
            return;
          }

          if (!seoId && res?.data?.data?.id) {
            seoId = res.data.data.id;
          }
        }

        // Mark clean so closing the modal doesn't trip the unsaved-changes guard.
        this.captureFormBaseline();
        this.$emit('saved', __('seo_setting_saved_successfully'));
        this.hideModal();

      } catch (e) {
        console.error(e);
        const msg = e?.response?.data?.message || __('something_went_wrong');
        this.showError ? this.showError(msg) : alert(msg);
      } finally {
        this.isLoading = false;
      }
    }

  },


  watch: {
    // Switching to a page with no default forces the zone back to Default.
    page_type() {
      if (!this.hasDefaultForPage) this.zone_id = 0;
    },
  },

  mounted() {
    this.showModal();
    this.loadZones();
    this.loadDefaults();
    this.fetchLanguages()
      .then(() => {
        this.initTranslations();
        this.loadSeoTranslations();
        // Snapshot the loaded form as the "clean" baseline for the guard.
        this.captureFormBaseline();
      });
  }

};
</script>

<style scoped>
.image_preview {
  margin-top: 5px;
}
</style>
