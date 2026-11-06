<template>
  <div>
    <div class="list-page">
      <div class="page-head">
        <h3 class="page-head-title">{{ __('blog_categories') }}</h3>
        <button class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
          @click="openAddModal" v-if="$can('blog_category_create')">
          <Plus :size="16" />
          <span>{{ __('add_category') }}</span>
        </button>
      </div>

      <div class="list-surface">
        <div class="list-toolbar">
          <div class="list-toolbar-start">
            <AppSelect v-model="statusFilter" class="form-select list-select"
              :options="statusFilterOptions" :searchable="false" />
          </div>

          <div class="list-search">
            <Search class="list-search-icon" />
            <input id="filter-input" v-model="filter" type="search" class="form-control" :placeholder="__('search')"
              @input="currentPage = 1; getBlogCategories()">
          </div>

          <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getBlogCategories()">
            <RefreshCw :class="{ 'is-spinning': isLoading }" />
          </button>
        </div>

        <MazerDatatable responsive :items="displayCategories" :fields="fields" v-model:sort-by="sortBy" v-model:sort-desc="sortDesc"
          :sort-direction="sortDirection" :busy="isLoading" stacked="md" show-empty small>

          <template #cell(status)="row">
            <span class="status-pill is-active" v-if="row.item.status == 1">{{ __('active') }}</span>
            <span class="status-pill is-inactive" v-if="row.item.status == 0">{{ __('deactive') }}</span>
          </template>

          <template #cell(blogs_count)="row">
            <span class="badge bg-info">{{ row.item.active_blogs_count || 0 }}</span>
          </template>

          <template #cell(actions)="row">
            <div class="list-actions">
              <button class="list-action-btn is-edit" @click="edit_record = row.item"
                v-if="$can('blog_category_update')" v-b-tooltip.hover :title="__('edit')">
                <Pencil :size="15" />
              </button>
              <button class="list-action-btn is-delete" @click="deleteCategory(row.item.id)"
                v-if="$can('blog_category_delete')" v-b-tooltip.hover :title="__('delete')">
                <Trash2 :size="15" />
              </button>
            </div>
          </template>

        </MazerDatatable>

        <div class="list-footer">
          <div class="list-perpage">
            <span>{{ __('per_page') }}</span>
            <b-form-select id="per-page-select" v-model="perPage" :options="pageOptions" size="sm"
              class="form-select"></b-form-select>
            <span class="list-range">{{ __('total_records') }} : {{ totalRows }}</span>
          </div>

          <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage" size="sm"
            class="mb-0 list-pagination"></b-pagination>
        </div>
      </div>
    </div>

    <!-- Create/Edit Category Modal -->
    <b-modal v-model="create_new" :title="edit_record.id ? __('edit_category') : __('add_category')" size="lg" centered
      @hidden="onModalHidden">
      <template #footer>
        <button type="button" class="btn btn-secondary" @click="create_new = false; resetForm()">
          {{ __('cancel') }}
        </button>
        <button type="submit" form="blog-category-form" class="btn btn-primary" :disabled="isSubmitting">
          <span v-if="isSubmitting">{{ __('saving') }}...</span>
          <span v-else>{{ __('save') }}</span>
        </button>
      </template>
      <form @submit.prevent="saveCategory" novalidate id="blog-category-form">

        <b-tabs :key="tabsKey" v-model="activeLangTab" content-class="mt-3" :nav-class="languages.length <= 1 ? 'd-none' : null">
          <b-tab v-for="(lang, index) in languages" :key="lang.id">
            <template #title>
              <span :class="{ 'text-primary': lang.is_default }">
                {{ lang.name }}
              </span>
            </template>

            <!-- Category Name and Slug in flex layout (only for default language) -->
            <div v-if="lang.is_default" class="d-flex align-items-end mb-3">
              <div class="form-group flex-grow-1 me-2">
                <label>{{ __('category_name') }}</label>
                <i class="text-danger">*</i>
                <input type="text" class="form-control" required v-model="form.translations[lang.id].name"
                  :placeholder="__('enter_category_name')" @keyup="createSlug(lang.id)" />
              </div>
              <div class="form-group flex-grow-1">
                <label>{{ __('slug') }}</label>
                <i class="text-danger">*</i>
                <input type="text" class="form-control" :placeholder="__('enter_slug')" v-model="form.slug" required>
              </div>
            </div>

            <!-- Category Name (for other languages) -->
            <div class="form-group" v-if="!lang.is_default">
              <label>{{ __('category_name') }}</label>
              <input type="text" class="form-control" v-model="form.translations[lang.id].name"
                :placeholder="__('enter_category_name')" />
            </div>

            <!-- SEO section -->
            <div class="row">
              <SeoSection :translation="form.translations[lang.id]" :is-default="!!lang.is_default" :uid="lang.id"
                :context="{ name: form.translations[lang.id].name, context: 'blog category' }" />
            </div>

            <!-- Status (only show for default language) -->
            <div class="form-group" v-if="lang.is_default">
              <label>{{ __('status') }}</label>
              <div class="col-md-9 text-left mt-1">
                <div class="btn-group btn-group-toggle" role="group">
                    <label class="btn btn-outline-primary" :class="{ active: form.status == 0 }">
                        <input type="radio" :value="0" v-model.number="form.status" autocomplete="off"> {{ __('deactivate') }}
                    </label>
                    <label class="btn btn-outline-primary" :class="{ active: form.status == 1 }">
                        <input type="radio" :value="1" v-model.number="form.status" autocomplete="off"> {{ __('activate') }}
                    </label>
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

      </form>
    </b-modal>
  </div>
</template>

<script>
import axios from 'axios';
import TranslationHelper from '../../mixins/TranslationHelper.js';
import { Search, RefreshCw, Plus, Pencil, Trash2 } from 'lucide-vue-next';

export default {
  mixins: [TranslationHelper],
  name: 'BlogCategories',
  components: { Search, RefreshCw, Plus, Pencil, Trash2 },
  data() {
    return {
      tabsKey: 0,
      isLoadingData: true,
      categories: [],
      activeLangTab: 0,
      languages: [],
      create_new: false,
      edit_record: {},
      isSubmitting: false,

      form: {
        slug: '',
        status: 1,
        translations: {}
      },
      isLoading: false,
      isSubmitting: false,
      filter: '',
      statusFilter: '',
      filterOn: ['id', 'name', 'slug', 'status'],
      sortBy: 'id',
      sortDesc: true,
      sortDirection: 'desc',
      fields: [
        { key: 'id', label: __('id'), sortable: true, class: 'text-center' },
        { key: 'name', label: __('name'), sortable: false, class: 'text-center' },
        { key: 'slug', label: __('slug'), sortable: false, class: 'text-center' },
        { key: 'blogs_count', label: __('blogs_count'), sortable: false, class: 'text-center' },
        { key: 'status', label: __('status'), sortable: true, class: 'text-center' },
        { key: 'actions', label: __('actions'), sortable: false, class: 'text-center' }
      ],
      perPage: 30,
      currentPage: 1,
      totalRows: 0,
      currentLanguageId: null,
      activeLanguages: [],

      translatableFields: ['name', 'meta_title', 'meta_keywords', 'meta_description'],

      pageOptions: this.$pageOptions
    }
  },
  computed: {
    // Fixed option set — no search box needed. Values stay strings so the
    // existing filter comparisons keep working.
    statusFilterOptions() {
      return [
        { id: '', name: __('all_status') },
        { id: '1', name: __('active') },
        { id: '0', name: __('deactive') },
      ];
    },
    defaultLanguageId() {
      const d = this.languages.find(l => l.is_default === 1);
      return d ? d.id : null;
    },
    translations() {
      return this.form.translations || {};
    },
    translatedCategories() {
      if (!this.currentLanguageId || !Array.isArray(this.categories)) {
        return this.categories;
      }

      return this.categories.map(category => {
        const translated = { ...category };

        if (Array.isArray(category.translations)) {
          const tr = category.translations.find(
            t => t.language_id === this.currentLanguageId
          );

          if (tr) {
            if (tr.name?.trim()) translated.name = tr.name;
            if (tr.meta_title?.trim()) translated.meta_title = tr.meta_title;
            if (tr.meta_keywords?.trim()) translated.meta_keywords = tr.meta_keywords;
            if (tr.meta_description?.trim()) translated.meta_description = tr.meta_description;
          }
        }

        return translated;
      });
    },
    // Status-filtered view for the table.
    displayCategories() {
      const list = this.translatedCategories || [];
      if (this.statusFilter === '') return list;
      return list.filter(c => String(c.status) === String(this.statusFilter));
    }
  },
  mounted() {
    this.fetchActiveLanguages().then(() => {
      this.getBlogCategories();
    });

    if (!this.languages.length) {
      this.getLanguages();
    }
  },
  methods: {
    async fetchActiveLanguages() {
      try {
        const res = await axios.get(this.$apiUrl + '/active_languages');

        if (res.data.status === 1 && Array.isArray(res.data.data)) {
          this.activeLanguages = res.data.data;

          const appLocale = window.appLocale || 'en';

          const currentLang = this.activeLanguages.find(
            l => l.code === appLocale
          );

          if (currentLang) {
            this.currentLanguageId = currentLang.id;
          } else {
            const def = this.activeLanguages.find(l => l.is_default === 1);
            if (def) this.currentLanguageId = def.id;
          }
        }
      } catch (e) {
        console.error('Language load failed', e);
      }
    },

    onModalHidden() {
      this.resetForm();
      this.edit_record = {};
      this.activeLangTab = this.getDefaultLangIndex();
      this.tabsKey++;
    },
    // change 
    getDefaultLangIndex() {
      const index = this.languages.findIndex(l => l.is_default === 1);
      return index !== -1 ? index : 0;
    },
    //change 
    openAddModal() {
      this.edit_record = {};
      this.resetForm();
      this.activeLangTab = this.getDefaultLangIndex();
      this.tabsKey++;
      this.create_new = true;
    },

    async getLanguages() {
      const res = await axios.get(this.$apiUrl + '/active_languages');

      // Remove duplicates by ID
      const unique = [];
      const map = new Set();

      res.data.data.forEach(lang => {
        if (!map.has(lang.id)) {
          map.add(lang.id);
          unique.push(lang);
        }
      });

      this.languages = unique;

      this.initTranslations();
    }

    ,
    generateSlug(langId) {
      const name = this.form.translations[langId].name;
      if (!name) return;

      this.form.slug = name
        .toLowerCase()
        .replace(/[^\w ]+/g, '')
        .replace(/ +/g, '-');
    },


    async getBlogCategories() {
      this.isLoading = true;
      try {
        const params = {
          offset: (this.currentPage - 1) * this.perPage,
          limit: this.perPage,
          search: this.filter
        };

        const response = await axios.get(this.$apiUrl + '/blog_categories', { params });
        if (response.data.status === 1) {
          this.categories = response.data.data;
          this.totalRows = response.data.total;
        } else {
          this.showMessage("error", response.data.message);
        }
      } catch (error) {
        this.showError(__('something_went_wrong'));
      } finally {
        this.isLoading = false;
      }
    },

    createSlug(langId) {
      const name = this.form.translations[langId].name;
      if (!name) return;

      this.form.slug = name
        .toLowerCase()
        .replace(/[^\w ]+/g, '')
        .replace(/ +/g, '-');
    },


    openCreateModal() {
      this.resetForm();
      this.showModal = true;
    },
    openEditModal(item) {
      this.editId = item.id;
      this.form.status = item.status;

      item.translations.forEach(t => {
        this.form.translations[t.language_id] = {
          name: t.name,
          meta_title: t.meta_title,
          meta_keywords: t.meta_keywords,
          meta_description: t.meta_description,
          schema_markup: t.schema_markup
        };
      });

      this.showModal = true;
    },


    async saveCategory() {
      // Validate default language name
      const defaultLang = this.languages.find(l => l.is_default);
      if (!defaultLang) {
        this.showError(__('default_language_not_found'));
        this.isSubmitting = false;
        return;
      }

      const defaultTranslation = this.form.translations[defaultLang.id];
      if (!defaultTranslation || !defaultTranslation.name || defaultTranslation.name.trim() === '') {
        this.showError(__('please_fill_default_language_required_fields'));
        this.activeLangTab = this.getDefaultLangIndex();
        this.isSubmitting = false;
        return;
      }

      this.isSubmitting = true;

      // Filter translations to only include those with actual data
      // Ensure language IDs are sent as integers to match backend expectations
      const filteredTranslations = {};

      // First, always add default language translation (it's required)
      filteredTranslations[defaultLang.id] = {
        name: defaultTranslation.name.trim() || '',
        meta_title: defaultTranslation.meta_title || '',
        meta_keywords: defaultTranslation.meta_keywords || '',
        meta_description: defaultTranslation.meta_description || '',
        schema_markup: defaultTranslation.schema_markup || ''
      };

      // Then add other languages that have data
      Object.keys(this.form.translations).forEach(langId => {
        const langIdInt = parseInt(langId);

        // Skip default language as we already added it
        if (langIdInt === defaultLang.id) {
          return;
        }

        const tr = this.form.translations[langId];

        // Check if translation has any meaningful data
        const hasData = (tr.name && tr.name.trim() !== '') ||
          (tr.meta_title && tr.meta_title.trim() !== '') ||
          (tr.meta_keywords && tr.meta_keywords.trim() !== '') ||
          (tr.meta_description && tr.meta_description.trim() !== '') ||
          (tr.schema_markup && tr.schema_markup.trim() !== '');

        if (hasData) {
          filteredTranslations[langIdInt] = {
            name: tr.name || '',
            meta_title: tr.meta_title || '',
            meta_keywords: tr.meta_keywords || '',
            meta_description: tr.meta_description || '',
            schema_markup: tr.schema_markup || ''
          };
        }
      });

      // Final validation: Ensure default language translation exists with name
      if (!filteredTranslations[defaultLang.id] || !filteredTranslations[defaultLang.id].name || filteredTranslations[defaultLang.id].name.trim() === '') {
        this.showError(__('please_fill_default_language_required_fields'));
        this.activeLangTab = this.getDefaultLangIndex();
        this.isSubmitting = false;
        return;
      }

      const payload = {
        id: this.edit_record.id || null,
        slug: this.form.slug,
        status: this.form.status,
        translations: filteredTranslations
      };

      const url = this.edit_record.id
        ? '/blog_categories/update'
        : '/blog_categories/save';

      try {
        const res = await axios.post(this.$apiUrl + url, payload);

        if (res.data.status === 1) {
          this.$toast.success(res.data.message);
          this.create_new = false;
          this.getBlogCategories();
          this.resetForm();
        } else {
          this.showError(res.data.message);
        }
      } catch (e) {
        this.showError(__('something_went_wrong'));
      } finally {
        this.isSubmitting = false;
      }
    }
    ,
    deleteCategory(id) {
      this.$swal.fire({
        title: __('are_you_sure'),
        text: __('you_want_be_able_to_revert_this'),
        confirmButtonText: __('yes_sure'),
        cancelButtonText: __('cancel'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: window.adminThemeColor || '#435ebe',
        cancelButtonColor: '#d33',
      }).then(async (result) => {
        if (!result.value) return;
        try {
          const res = await axios.post(
            this.$apiUrl + '/blog_categories/delete/' + id
          );
          if (res.data.status === 1) {
            this.$toast.success(res.data.message);
            this.getBlogCategories();
          } else {
            this.$toast.error(res.data.message);
          }
        } catch (e) {
          this.showError(__('something_went_wrong'));
        }
      });
    },
    initTranslations() {
      this.form.translations = {};

      this.languages.forEach(lang => {
        this.form.translations[lang.id] = {
          name: '',
          meta_title: '',
          meta_keywords: '',
          meta_description: '',
          schema_markup: ''
        };
      });
    }
    ,

    resetForm() {
      this.form.slug = '';
      this.form.status = 1;

      Object.keys(this.form.translations).forEach(id => {
        this.form.translations[id].name = '';
        this.form.translations[id].meta_title = '';
        this.form.translations[id].meta_keywords = '';
        this.form.translations[id].meta_description = '';
        this.form.translations[id].schema_markup = '';
      });

      this.edit_record = {};
    },

    closeModal() {
      this.showModal = false;
      this.resetForm();
    },

  },
  watch: {
    edit_record(val) {
      if (!val?.id) return;
      this.tabsKey++;
      this.form.slug = val.slug;
      this.form.status = val.status;

      // Get default language for fallback
      const defaultLang = this.languages.find(l => l.is_default);

      // Load translations from API response - only populate languages that have translations
      if (Array.isArray(val.translations) && val.translations.length > 0) {
        val.translations.forEach(tr => {
          if (this.form.translations[tr.language_id]) {
            // Only populate if translation has data
            const hasData = tr.name && tr.name.trim() !== '';

            if (hasData) {
              this.form.translations[tr.language_id] = {
                name: tr.name || '',
                meta_title: tr.meta_title || '',
                meta_keywords: tr.meta_keywords || '',
                meta_description: tr.meta_description || '',
                schema_markup: tr.schema_markup || ''
              };
            }
          }
        });
      }

      // Apply fallback only for default language if no translation exists
      // Other languages will remain empty if no translation exists
      if (defaultLang) {
        const defaultTranslation = this.form.translations[defaultLang.id];

        // Check if default language translation is missing or empty
        const isMissing = !defaultTranslation ||
          (!defaultTranslation.name || defaultTranslation.name.trim() === '');

        if (isMissing) {
          // Use main table data as fallback only for default language
          this.form.translations[defaultLang.id] = {
            name: val.name || '',
            meta_title: val.meta_title || '',
            meta_keywords: val.meta_keywords || '',
            meta_description: val.meta_description || '',
            schema_markup: val.schema_markup || ''
          };
        } else {
          // Fill in any empty fields in default language translation with main table data
          this.form.translations[defaultLang.id] = {
            name: defaultTranslation.name || val.name || '',
            meta_title: defaultTranslation.meta_title || val.meta_title || '',
            meta_keywords: defaultTranslation.meta_keywords || val.meta_keywords || '',
            meta_description: defaultTranslation.meta_description || val.meta_description || '',
            schema_markup: defaultTranslation.schema_markup || val.schema_markup || ''
          };
        }
      }

      this.activeLangTab = this.getDefaultLangIndex();
      this.create_new = true;
    },
    currentPage() {
      this.getBlogCategories();
    },
    perPage() {
      this.getBlogCategories();
    }
  }



}
</script>