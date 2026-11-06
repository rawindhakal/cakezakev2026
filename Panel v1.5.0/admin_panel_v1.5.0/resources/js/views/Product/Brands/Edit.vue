<template>
  <b-modal :key="id" ref="my-modal" :title="modal_title" @hide="onModalHide" @hidden="$emit('modalClose')" scrollable centered no-close-on-backdrop
    no-fade static>

    <template #footer>
      <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">
        {{ __('save') }}
        <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
      </b-button>
      <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
    </template>

    <form ref="my-form" @submit.prevent="saveRecord" novalidate>

      <!-- Language Tabs with lazy (same as Category Edit - only active tab in DOM to avoid "not focusable") -->
      <b-tabs :key="tabsKey" v-if="languages.length" v-model="activeTab" content-class="mt-3" :nav-class="languages.length <= 1 ? 'd-none' : null">
        <b-tab v-for="(lang, index) in languages" :key="lang.id" :title="lang.name" :active="lang.is_default == 1">

          <div class="row">
            <div class="form-group">
              <label>{{ __('name') }}</label>
              <i class="text-danger" v-if="lang.is_default">*</i>
              <input type="text" class="form-control" v-model="form[lang.id].name" :placeholder="__('enter_name')"
                :required="lang.is_default ? true : undefined">
            </div>

            <div v-if="lang.is_default">
              <FileUpload v-model="image" :label="__('image')" required accept="image/*"
                recommended-size="512x512px" :max-size-mb="2" :preview-url="image_url" />
            </div>

            <div class="form-group" v-if="id && lang.is_default">
              <label>{{ __('status') }}</label>
              <div class="col-md-9 text-left mt-1">
                <div class="btn-group btn-group-toggle" role="group">
                    <label class="btn btn-outline-primary" :class="{ active: status == 0 }">
                        <input type="radio" :value="0" v-model.number="status" autocomplete="off"> {{ __('deactivate') }}
                    </label>
                    <label class="btn btn-outline-primary" :class="{ active: status == 1 }">
                        <input type="radio" :value="1" v-model.number="status" autocomplete="off"> {{ __('activate') }}
                    </label>
                </div>
              </div>
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

      <button ref="dummy_submit" style="display:none;"></button>

    </form>
  </b-modal>
</template>

<script>
import axios from 'axios';
import TranslationHelper from '../../../mixins/TranslationHelper.js';
import UnsavedChanges from '../../../mixins/UnsavedChanges.js';

export default {
  mixins: [TranslationHelper, UnsavedChanges],
  props: ['record'],
  data() {
    return {
      id: null,
      status: 1,
      languages: [],
      defaultLanguageId: null,
      activeTab: 0,
      form: {},
      image: "",
      image_url: "",
      isLoading: false,
      tabsKey: 0,

      // Translate buttons
      translatableFields: ['name'],
    };
  },
  watch: {
    record: {
      immediate: true,
      deep: true,
      handler(newVal) {
        if (newVal && newVal.id) {
          this.id = newVal.id;
          this.resetForm();
          // Only load brand data if languages are already loaded
          if (this.languages.length > 0) {
            this.loadBrandWithTranslations();
          }
        } else {
          this.id = null;
          this.resetForm();
        }
      }
    }
  },
  computed: {
    modal_title() {
      return this.id ? __('edit_brand') : __('add_brand');
    }
  },
  methods: {
    // Tracked state for the UnsavedChanges guard (warn before leaving with edits).
    formState() {
      return { form: this.form, image: this.image, status: this.status };
    },
    // Intercept Cancel / X / esc modal close so unsaved edits also prompt (not just
    // route navigation and reload). The re-hide after "leave" bypasses via _ucAllowClose.
    onModalHide(bvEvt) {
      if (this._ucAllowClose) { this._ucAllowClose = false; return; }
      if (!this.isFormDirty) return;
      bvEvt.preventDefault();
      this._ucConfirmLeave().then(ok => {
        if (ok) { this._ucAllowClose = true; this.$refs['my-modal']?.hide(); }
      });
    },
    resetForm() {
      this.form = {};
      this.image = "";
      this.image_url = "";
      this.status = 1;
      this.activeTab = 0;

      // re-init empty translations
      this.languages.forEach(lang => {
        this.form[lang.id] = { name: '' };
      });
    }
    ,
    showModal() {
      this.$refs['my-modal'].show();
    },
    hideModal() {
      this.$refs['my-modal']?.hide();
    },
    initializeForm() {
      this.languages.forEach(lang => {
        if (!this.form[lang.id]) {
          this.form[lang.id] = { name: '' };
        }
      });
    },
    loadLanguages() {
      return axios.get(this.$apiUrl + '/active_languages')
        .then(res => {
          this.languages = res.data.data;

          const defaultLang = this.languages.find(l => l.is_default);
          this.defaultLanguageId = defaultLang?.id || null;

          // Initialize form for all languages
          this.initializeForm();

          // Load brand data if id exists (after languages are loaded)
          if (this.id) {
            return this.loadBrandWithTranslations();
          }
        });
    },
    loadBrandWithTranslations() {
      if (!this.id) return;

      // Ensure languages are loaded first - if not, wait for them
      if (!this.languages.length) {
        return this.loadLanguages();
      }

      return axios.get(this.$apiUrl + '/products/brands', { params: { id: this.id } }).then(res => {
        const brand = Array.isArray(res.data.data) ? res.data.data[0] : res.data.data;

        if (!brand) {
          console.error('Brand not found');
          return;
        }

        this.status = brand.status;
        this.image_url = brand.image_url || "";

        // Ensure all languages are initialized first
        this.initializeForm();

        // Process translations with fallback logic
        this.languages.forEach(lang => {
          const translation = Array.isArray(brand.translations)
            ? brand.translations.find(t => t.language_id === lang.id)
            : null;

          if (lang.is_default) {
            // For default language, use translation if exists, otherwise fallback to main table data
            this.form[lang.id] = {
              name: (translation && translation.name && translation.name.trim() !== '')
                ? translation.name
                : (brand.name || ''),
            };
          } else {
            // For other languages, use translation if exists, otherwise empty
            this.form[lang.id] = {
              name: (translation && translation.name) ? translation.name : '',
            };
          }
        });

        this.tabsKey++;
      });
    },
    validateDefaultLanguage() {
      if (!this.defaultLanguageId) {
        this.showError(__('default_language_not_found'));
        return false;
      }

      const defaultForm = this.form[this.defaultLanguageId];

      // Check required fields for default language
      if (!defaultForm.name || defaultForm.name.trim() === '') {
        this.showError(__('please_fill_name_in_default_language') || __('please_fill_name_in_default_language'));
        this.switchToDefaultLanguageTab();
        return false;
      }

      // Check image for new brands
      if (!this.id && !this.image && !this.image_url) {
        this.showError(__('please_upload_brand_image') || __('please_upload_image'));
        this.switchToDefaultLanguageTab();
        return false;
      }

      return true;
    },

    validateDefaultLanguageForTranslation() {
      const form = this.$refs['my-form'];
      if (form && !form.reportValidity()) {
        this.$nextTick(() => this.switchToDefaultLanguageTab());
        return false;
      }
      return this.validateDefaultLanguage();
    },

    switchToDefaultLanguageTab() {
      const defaultLangIndex = this.languages.findIndex(lang => lang.id === this.defaultLanguageId);
      if (defaultLangIndex !== -1) {
        this.showError(__('please_fill_default_language_required_fields'));
        this.activeTab = defaultLangIndex;
      }
    },

    saveRecord() {
      if (!this.validateDefaultLanguage()) return;
      const isUpdate = !!this.id; // check before saving
      this.isLoading = true;

      const languagesToSave = [];
      const defaultLang = this.languages.find(l => l.is_default);
      if (defaultLang) languagesToSave.push(defaultLang);

      this.languages.forEach(lang => {
        if (lang.is_default) return;
        const name = this.form[lang.id].name;
        if (name && name.trim() !== '') languagesToSave.push(lang);
      });

      const saveSequentially = async () => {
        let brandId = this.id;

        for (const lang of languagesToSave) {
          let fd = new FormData();
          if (brandId) fd.append('id', brandId);

          fd.append('language_id', lang.id);
          fd.append('name', this.form[lang.id].name);
          fd.append('status', this.status);

          if (lang.is_default && this.image) fd.append('image', this.image);

          const url = brandId
            ? this.$apiUrl + '/products/brands/update'
            : this.$apiUrl + '/products/brands/save';

          const res = await axios.post(url, fd);

          if (!res.data || res.data.status === 0 || res.data.status === false) {
            throw new Error(res.data?.message || __('something_went_wrong'));
          }

          if (!brandId && res.data.data?.id) brandId = res.data.data.id;
        }
        return brandId; //change
      };


      saveSequentially()
        .then((brandId) => {
          const message = isUpdate
            ? __('brand_updated_successfully')
            : __('brand_saved_successfully');

          // Mark clean so closing after save doesn't trip the unsaved-changes guard.
          this.captureFormBaseline();
          // Close the modal first; the parent tears this component down on `saved`,
          // so any ref access after the emit would hit a null ref.
          this.hideModal();
          this.$emit('saved', message, brandId);
        })
        .catch((err) => {
          this.showError(err?.response?.data?.message || err?.message || __('something_went_wrong'));
        })
        .finally(() => this.isLoading = false);
    }
  },
  mounted() {

    const loaded = this.loadLanguages();
    this.resetForm(); // here change 2
    this.showModal();
    // Data loaded — snapshot the clean baseline for the unsaved-changes guard.
    Promise.resolve(loaded).then(() => this.captureFormBaseline());
  }
};
</script>
<style scoped>
.image_preview {
  margin-top: 5px;
}
</style>