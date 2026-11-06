<template>
    <div>
        <div class="list-page">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('blogs') }}</h3>
                <button class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap ms-auto"
                    @click="openAddModal" v-if="$can('blog_create')">
                    <Plus :size="16" />
                    <span>{{ __('add_blog') }}</span>
                </button>
            </div>

            <div class="list-surface">
                <div class="list-toolbar">
                    <div class="list-toolbar-start">
                        <AppSelect v-model="selectedCategory" class="form-select list-select"
                            :options="categoryFilterOptions" @update:model-value="getBlogs()" />
                        <AppSelect v-model="statusFilter" class="form-select list-select"
                            :options="statusFilterOptions" :searchable="false" />
                    </div>

                    <div class="list-search">
                        <Search class="list-search-icon" />
                        <input id="filter-input" v-model="filter" type="search" class="form-control"
                            :placeholder="__('search')">
                    </div>

                    <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getBlogs()">
                        <RefreshCw :class="{ 'is-spinning': isLoading }" />
                    </button>
                </div>

                <div class="list-panel-body">
                    <div class="card-grid">
                        <EntityCardSkeleton v-if="isLoading" :count="perPage" />
                        <div v-else-if="!displayBlogs.length" class="card-grid-empty">
                            <Newspaper :size="34" />
                            <span>{{ __('no_records_found') }}</span>
                        </div>

                        <div v-else v-for="blog in displayBlogs" :key="blog.id" class="entity-card">
                            <div class="entity-card-media">
                                <img v-if="blog.image_url" :src="blog.image_url" :alt="blog.title" />
                                <div v-else class="entity-card-ph"><ImageIcon :size="30" /></div>
                                <span class="status-pill is-active" v-if="blog.status == 1">{{ __('active') }}</span>
                                <span class="status-pill is-inactive" v-else>{{ __('deactive') }}</span>
                            </div>
                            <div class="entity-card-body">
                                <p class="entity-card-title">{{ blog.title }}</p>
                                <div class="entity-card-meta">
                                    <div class="entity-meta-row">
                                        <Folder :size="14" />
                                        <span v-b-tooltip.hover :title="blog.category ? blog.category.name : ''">{{ blog.category ? blog.category.name : '-' }}</span>
                                    </div>
                                    <!-- Both come straight off the API (Blog model appends). -->
                                    <div class="entity-meta-row blog-stats">
                                        <span><Eye :size="14" /> {{ Number(blog.views_count || 0) }} {{ __('views') }}</span>
                                        <span v-if="blog.read_time"><Clock :size="14" /> {{ blog.read_time }}</span>
                                    </div>
                                </div>
                                <div class="entity-card-foot">
                                    <div class="list-actions">
                                        <button class="list-action-btn is-edit" @click="edit_record = blog"
                                            v-if="$can('blog_update')" v-b-tooltip.hover :title="__('edit')">
                                            <Pencil :size="15" />
                                        </button>
                                        <button class="list-action-btn is-delete" @click="deleteBlog(blog.id, blog.id)"
                                            v-if="$can('blog_delete')" v-b-tooltip.hover :title="__('delete')">
                                            <Trash2 :size="15" />
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="list-footer" v-if="!isLoading && totalRows > 0">
                    <div class="list-perpage">
                        <span>{{ __('per_page') }}</span>
                        <b-form-select id="per-page-select" v-model="perPage" :options="pageOptions" size="sm"
                            class="form-select"></b-form-select>
                    </div>

                    <b-pagination v-model="currentPage" :total-rows="totalRows" :per-page="perPage" size="sm"
                        class="mb-0 list-pagination"></b-pagination>
                </div>
            </div>
        </div>

        <!-- Create/Edit Blog Modal -->
        <b-modal v-model="create_new" :title="edit_record.id ? __('edit_blog') : __('add_blog')" size="xl" centered
            lazy @hide="resetForm" id="blog-modal">
            <template #footer>
                <button type="button" class="btn btn-secondary" @click="create_new = false; resetForm()">
                    {{ __('cancel') }}
                </button>
                <button type="submit" form="blog-form" class="btn btn-primary" :disabled="isSubmitting">
                    <span v-if="isSubmitting">{{ __('saving') }}...</span>
                    <span v-else>{{ __('save') }}</span>
                </button>
            </template>
            <form @submit.prevent="saveBlog" enctype="multipart/form-data" id="blog-form" novalidate>

                <b-tabs v-model="activeLanguageTab" v-if="languages.length" :nav-class="languages.length <= 1 ? 'd-none' : null">
                    <b-tab v-for="lang in languages" :key="lang.id" :id="'blog-lang-' + lang.id">
                        <template #title>
                            <span :class="{ 'text-primary': lang.is_default }">{{ lang.name }}</span>
                        </template>
                    </b-tab>
                    <template #tabs-end>
                        <li class="nav-item ms-auto d-flex align-items-center">
                            <TranslateLanguages :languages="languages" :default-language-id="defaultLanguageId"
                                :busy="translating" :progress="translateProgress" @translate="runTranslate" />
                        </li>
                    </template>
                </b-tabs>

                <div v-if="activeLanguage" :key="'blogform_' + activeLanguage.id" class="mt-3">
                    <!-- Default Language - Show All Fields -->
                    <template v-if="activeLanguage.is_default">
                        <!-- Basic Information Section -->
                        <div class="row">
                            <!-- Left Column -->
                            <div class="col-md-6">
                                <!-- Title -->
                                <div class="form-group">
                                    <label for="title">{{ __('title') }} <span class="text-danger">*</span></label>
                                    <input type="text" class="form-control" id="title"
                                        v-model="translations[activeLanguage.id].title" :placeholder="__('enter_blog_title')"
                                        @keyup="createSlug(activeLanguage.id)" required />
                                </div>

                                <!-- Category -->
                                <div class="form-group">
                                    <label for="category_id">{{ __('category') }} <span
                                            class="text-danger">*</span></label>
                                    <AppSelect class="form-control form-select" v-model="form.category_id"
                                        :options="translatedCategories" :placeholder="__('select_category')" />
                                </div>

                                <!-- Image (uses common file upload component) -->
                                <FileUpload v-model="form.image" :label="__('image')"
                                    :required="!edit_record.id || !form.image_url" accept="image/*"
                                    recommended-size="1200x630px" :max-size-mb="2"
                                    :preview-url="form.image_url" />
                            </div>

                            <!-- Right Column -->
                            <div class="col-md-6">
                                <!-- Slug -->
                                <div class="form-group">
                                    <label for="slug">{{ __('slug') }} <span class="text-danger">*</span></label>
                                    <input type="text" class="form-control" id="slug" v-model="form.slug"
                                        :placeholder="__('enter_slug')" required />
                                </div>

                                <!-- Status -->
                                <div class="form-group">
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
                            </div>
                        </div>

                        <!-- Content Description Section -->
                        <div class="row">
                            <div class="col-md-12">
                                <!-- Short Description with AI Button -->
                                <div class="form-group">
                                    <div class="d-flex justify-content-between align-items-center mb-1">
                                        <label class="mb-0" for="short_description">{{ __('short_description') }}
                                            <span class="text-danger">*</span></label>
                                        <button type="button" class="btn btn-sm btn-outline-primary"
                                            :disabled="aiLoading" @click="generateWithAI">
                                            <b-spinner v-if="aiLoading" small></b-spinner>
                                            <Sparkles v-else :size="15" /> {{ __('generate_with_ai') }}
                                        </button>
                                    </div>
                                    <div class="ai-wrap" :class="{ 'ai-generating': aiLoading }">
                                        <textarea class="form-control ai-field" id="short_description"
                                            v-model="translations[activeLanguage.id].short_description" rows="3"
                                            :placeholder="__('short_description')" required></textarea>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="row">
                            <div class="col-md-12">
                                <!-- Description -->
                                <div class="form-group">
                                    <label for="description">{{ __('description') }} <span
                                            class="text-danger">*</span></label>
                                    <div class="ai-wrap" :class="{ 'ai-generating': aiLoading }">
                                        <editor
                                            v-if="tinymceReady"
                                            v-model="translations[activeLanguage.id].description"
                                            :init="tinymceInit"
                                            tinymce-script-src="/assets/js/tinymce/tinymce.min.js?v=7922"
                                            license-key="gpl"
                                            :placeholder="__('enter_blog_description')" />
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Tags (default language: after description) -->
                        <div class="row">
                            <div class="col-md-12">
                                <div class="form-group">
                                    <label for="tags" class="control-label">
                                        {{ __('tags') }} ( {{ __('these_tags_help_you_in_search_result') }} )
                                    </label>
                                    <AppSelect :key="'blog-tags-' + activeLanguage.id" multiple taggable
                                        :model-value="getTagIdsForLang(activeLanguage.id)"
                                        @update:model-value="setTagIdsForLang(activeLanguage.id, $event)"
                                        :options="getTagsOptionsForLang(activeLanguage.id)" label-key="text"
                                        track-by="value" :placeholder="__('select_tags')" />

                                    <div v-if="getTagsOptionsForLang(activeLanguage.id).length === 0"
                                        class="text-muted small mt-1">{{ __('no_tags_available') ||
                                            'No tags available for this language.' }}</div>
                                </div>
                            </div>
                        </div>

                        <!-- SEO section -->
                        <div class="row">
                            <SeoSection :translation="translations[activeLanguage.id]" :is-default="true" :uid="activeLanguage.id"
                                :context="{ name: translations[activeLanguage.id].title, description: translations[activeLanguage.id].short_description, context: 'blog article' }" />
                        </div>
                    </template>

                    <!-- Other Languages - Show Only Translatable Fields -->
                    <template v-else>
                        <div class="row">
                            <div class="col-md-12">
                                <div class="form-group">
                                    <label for="title">{{ __('title') }}</label>
                                    <input type="text" class="form-control" id="title"
                                        v-model="translations[activeLanguage.id].title"
                                        :placeholder="__('enter_blog_title')" />
                                </div>
                            </div>
                        </div>

                        <div class="row">
                            <div class="col-md-12">
                                <div class="form-group">
                                    <label for="short_description">{{ __('short_description') }}</label>
                                    <textarea class="form-control" id="short_description"
                                        v-model="translations[activeLanguage.id].short_description" rows="3"
                                        :placeholder="__('short_description')"></textarea>
                                </div>
                            </div>
                        </div>

                        <div class="row">
                            <div class="col-md-12">
                                <div class="form-group">
                                    <label for="description">{{ __('description') }}</label>
                                    <div>
                                        <editor
                                            v-if="tinymceReady"
                                            v-model="translations[activeLanguage.id].description"
                                            :init="tinymceInit"
                                            tinymce-script-src="/assets/js/tinymce/tinymce.min.js?v=7922"
                                            license-key="gpl" />
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Tags (other languages: after description) -->
                        <div class="row">
                            <div class="col-md-12">
                                <div class="form-group">
                                    <label for="tags" class="control-label">
                                        {{ __('tags') }} ( {{ __('these_tags_help_you_in_search_result') }} )
                                    </label>
                                    <AppSelect :key="'blog-tags-' + activeLanguage.id" multiple taggable
                                        :model-value="getTagIdsForLang(activeLanguage.id)"
                                        @update:model-value="setTagIdsForLang(activeLanguage.id, $event)"
                                        :options="getTagsOptionsForLang(activeLanguage.id)" label-key="text"
                                        track-by="value" :placeholder="__('select_tags')" />
                                    <div v-if="getTagsOptionsForLang(activeLanguage.id).length === 0"
                                        class="text-muted small mt-1">{{ __('no_tags_available') ||
                                            'No tags available for this language.' }}</div>
                                </div>
                            </div>
                        </div>

                        <!-- SEO section (translatable fields only) -->
                        <div class="row">
                            <SeoSection :translation="translations[activeLanguage.id]" :is-default="false" :uid="activeLanguage.id" />
                        </div>
                    </template>
                </div>

            </form>
        </b-modal>
    </div>
</template>

<script>
import Editor from '@tinymce/tinymce-vue'
import axios from 'axios';
import TranslationHelper from '../../mixins/TranslationHelper.js';
import { tinymceInit as buildTinymceInit } from '../../utils/tinymce.js';
import { Search, RefreshCw, Plus, Pencil, Trash2, Sparkles, Newspaper, Folder, Eye, Clock, Image as ImageIcon } from 'lucide-vue-next';

export default {
    mixins: [TranslationHelper],
    name: 'Blogs',
    components: {
        Editor,
        Eye,
        Clock,
        Search,
        RefreshCw,
        Plus,
        Pencil,
        Trash2,
        Sparkles,
        Newspaper,
        Folder,
        ImageIcon
    },
    data() {

        return {
            languages: [],
            activeLanguageTab: 0,
            languagesKey: 0,
            blogs: [],
            categories: [],
            create_new: false,
            edit_record: {},
            aiLoading: false,
            aiPrompt: '',
            form: {
                title: '',
                slug: '',
                category_id: '',
                image: null,
                image_url: '',
                description: '',
                short_description: '',
                meta_title: '',
                // meta_keywords: '',
                // meta_description: '',
                status: 1,
                translations: {},
                currentLanguageId: null,
                activeLanguages: []
            },
            tags: [],
            /** Tags per language so dropdown options are ready when switching tabs: { [languageId]: [{ id, name }] } */
            tagsByLanguage: {},
            /** Tag IDs per language: { [languageId]: ['1','2'] } so each tab keeps its own selection */
            tagIdsByLanguage: {},
            // Start loading so the spinner shows on first paint, not the empty
            // state (which flashed before getBlogs() flipped this to true).
            isLoading: true,
            isSubmitting: false,
            filter: '',
            filterOn: ['title', 'description'],
            sortBy: 'id',
            sortDesc: true,
            sortDirection: 'desc',
            selectedCategory: '',
            statusFilter: '',
            fields: [
                { key: 'id', label: __('id'), sortable: true, class: 'text-center' },
                { key: 'image', label: __('image'), sortable: false, class: 'text-center' },
                { key: 'title', label: __('title'), sortable: false, class: 'text-center' },
                { key: 'category', label: __('category'), sortable: false, class: 'text-center' },
                { key: 'status', label: __('status'), sortable: true, class: 'text-center' },
                { key: 'actions', label: __('actions'), sortable: false, class: 'text-center' }
            ],
            perPage: 30,
            currentPage: 1,
            totalRows: 0,
            pageOptions: this.$pageOptions,
            descriptionValidation: '',
            translations: {},
            translatableFields: ['title', 'short_description', 'description', 'meta_title', 'meta_keywords', 'meta_description'],
            // Load the TinyMCE script once up-front, then render editors — prevents the
            // race where the per-language editors each try to load the script concurrently
            // (content randomly missing / "insertBefore" errors).
            tinymceReady: false,
            // Shared TinyMCE config (utils/tinymce.js) + the description-validation hook.
            tinymceInit: buildTinymceInit({
                setup: (editor) => {
                    editor.on('change', () => { this.updateDescriptionValidation(); });
                },
            }),
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
        categoryFilterOptions() {
            return [{ id: '', name: __('all_categories') }].concat(this.translatedCategories || []);
        },
        defaultLanguageId() {
            const d = this.languages.find(l => l.is_default);
            return d ? d.id : null;
        },
        activeLanguage() {
            const v = this.activeLanguageTab;
            const m = String(v ?? '').match(/^blog-lang-(\d+)$/);
            if (m) return this.languages.find(l => l.id === parseInt(m[1], 10)) || null;
            if (typeof v === 'number') return this.languages[v] || null;
            return this.languages[0] || null;
        },
        translatedCategories() {
            if (!this.currentLanguageId || !Array.isArray(this.categories)) {
                return this.categories;
            }

            return this.categories.map(cat => {
                const c = { ...cat };

                if (Array.isArray(cat.translations)) {
                    const tr = cat.translations.find(
                        t => t.language_id === this.currentLanguageId
                    );

                    if (tr?.name?.trim()) {
                        c.name = tr.name;
                    }
                }

                return c;
            });
        },

        translatedBlogs() {
            if (!this.currentLanguageId || !Array.isArray(this.blogs)) {
                return this.blogs;
            }

            return this.blogs.map(blog => {
                const translatedBlog = { ...blog };

                // Translate blog fields
                if (Array.isArray(blog.translations)) {
                    const tr = blog.translations.find(
                        t => t.language_id === this.currentLanguageId
                    );
                    if (tr?.title) translatedBlog.title = tr.title;
                }

                // Attach translated category name
                if (blog.category) {
                    const catTr = blog.category.translations?.find(
                        t => t.language_id === this.currentLanguageId
                    );
                    translatedBlog.category = {
                        ...blog.category,
                        name: catTr?.name || blog.category.name || '-'
                    };
                }

                return translatedBlog;
            });
        },


        // Blogs shown in the grid: server page filtered client-side by status + search text.
        displayBlogs() {
            let list = this.translatedBlogs || [];
            if (this.statusFilter !== '') {
                list = list.filter(b => String(b.status) === String(this.statusFilter));
            }
            const q = (this.filter || '').trim().toLowerCase();
            if (q) {
                list = list.filter(b =>
                    (b.title || '').toLowerCase().includes(q) ||
                    (b.category && b.category.name ? b.category.name.toLowerCase().includes(q) : false)
                );
            }
            return list;
        },

    },
    mounted() {
        this.loadTinymce();
        this.getLanguages();
        this.fetchActiveLanguages().then(() => {
            this.getBlogs();
            this.getCategories();
        });

        this.getTags();
    },
    methods: {
        // Ensure window.tinymce exists before any <editor> mounts (single script load).
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
        /*--------------------generateWithAI------------------------*/
        async generateWithAI() {
            // Get title from default language
            const defaultLang = this.languages.find(l => l.is_default);
            if (!defaultLang) {
                this.showError(__('default_language_not_found'));
                return;
            }

            const defaultTitle = this.translations[defaultLang.id]?.title || '';
            if (!defaultTitle) {
                this.showError(__('please_fill_default_language_required_fields'));
                return;
            }

            this.aiLoading = true;

            try {
                const response = await axios.post(this.$apiUrl + '/google_gemini', {
                    title: defaultTitle,
                    source: 'web'
                });

                if (response.data.status === 1) {
                    const data = response.data.data;

                    // Update default language translations
                    if (data.title) {
                        this.translations[defaultLang.id].title = data.title;
                    }
                    if (data.short_description) {
                        this.translations[defaultLang.id].short_description = data.short_description;
                    }
                    if (data.description) {
                        this.translations[defaultLang.id].description = data.description;
                    }

                    // Create slug from default language title
                    this.createSlug(defaultLang.id);
                    this.updateDescriptionValidation();
                } else {
                    this.showError(response.data.message || 'AI failed');
                }

            } catch (e) {
                this.showError('AI generation failed');
            } finally {
                this.aiLoading = false;
            }
        },

        // Get category name helper method
        getCategoryName(categoryId) {
            const category = this.translatedCategories.find(cat => cat.id === categoryId);
            return category ? category.name : '';
        },

        // Fetch active languages
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

        // Initialize translations for all languages
        initTranslations() {
            const newTranslations = {};
            this.languages.forEach(lang => {
                newTranslations[lang.id] = {
                    title: '',
                    description: '',
                    short_description: '',
                    meta_title: '',
                    meta_keywords: '',
                    meta_description: '',
                    schema_markup: ''
                };
            });
            this.translations = newTranslations;
        },

        // Open add modal - reset form and initialize translations
        openAddModal() {
            this.resetForm();
            this.initTranslations();
            this.initTagIdsByLanguage();
            this.activeLanguageTab = this.defaultTabId();
            this.languagesKey++;
            this.create_new = true;
            this.$nextTick(() => {
                this.getAllTagsForModal();
                this.loadTagIdsFromSession();
            });
        },

        // Get all blogs
        async getBlogs() {
            this.isLoading = true;
            try {
                const params = {
                    limit: this.perPage,
                    page: this.currentPage
                };

                if (this.selectedCategory) {
                    params.category_id = this.selectedCategory;
                }

                const response = await axios.post(
                    this.$apiUrl + '/blogs',
                    params
                );

                if (response.data.status === 1) {
                    this.blogs = response.data.data;
                    this.totalRows = response.data.total;
                } else {
                    this.showError(response.data.message);
                }
            } catch (error) {
                this.showError(__('something_went_wrong'));
            } finally {
                this.isLoading = false;
            }
        },

        async getLanguages() {
            try {
                const res = await axios.get(this.$apiUrl + '/active_languages');
                if (res.data.status === 1) {
                    this.languages = res.data.data;
                    this.initTranslations();
                }
            } catch (e) {
                console.error('Error loading languages', e);
            }
        },

        async getCategories() {
            const res = await axios.get(this.$apiUrl + '/blog_categories/dropdown');
            if (res.data.status === 1) {
                this.categories = res.data.data;
            }
        },
        /** Fetch tags for one language (used when modal is closed, e.g. list view). */
        async getTags(languageId) {
            try {
                const lid = languageId ?? this.languages[this.activeLanguageTab]?.id ?? this.currentLanguageId ?? null;
                const url = lid ? `${this.$apiUrl}/blog_tags?language_id=${lid}` : `${this.$apiUrl}/blog_tags`;
                const response = await axios.get(url);
                if (response.data.status === 1) {
                    this.tags = response.data.data;
                }
            } catch (error) {
                console.error('Error fetching blog tags:', error);
            }
        },
        /** Load all tags and group by language_id so every tab has options ready and selection persists when switching tabs */
        async getAllTagsForModal() {
            if (!this.languages.length) return;
            try {
                const res = await axios.get(`${this.$apiUrl}/blog_tags?all=1`);
                if (res.data.status !== 1 || !Array.isArray(res.data.data)) return;
                const byLang = {};
                this.languages.forEach(lang => {
                    byLang[lang.id] = res.data.data.filter(t => t.language_id === lang.id);
                });
                this.tagsByLanguage = byLang;
            } catch (e) {
                console.error('Error fetching all tags for modal:', e);
            }
        },
        /** Options for one language (for Tags multi-select). Returns { value, text } for b-form-select. */
        getTagsOptionsForLang(langId) {
            if (!langId) return [];
            const list = (this.create_new && this.tagsByLanguage[langId]) ? this.tagsByLanguage[langId] : this.tags;
            const baseOptions = list.length ? list.map(tag => ({ value: String(tag.id), text: tag?.name ?? String(tag.id) })) : [];
            if (!this.create_new) return baseOptions;
            const selectedIds = this.getTagIdsForLang(langId);
            const existingIds = new Set(baseOptions.map(o => o.value));
            selectedIds.forEach(sid => {
                const id = String(sid);
                if (id && !existingIds.has(id)) {
                    existingIds.add(id);
                    baseOptions.push({ value: id, text: id });
                }
            });
            return baseOptions;
        },
        /** Tag options for one language as { value, text } — feeds AppSelect (label-key=text, track-by=value). */
        /** Selected tag IDs for one language (AppSelect :model-value). Each tab has its own list. */
        getTagIdsForLang(langId) {
            const list = this.tagIdsByLanguage[langId];
            if (Array.isArray(list)) return list;
            if (list != null && list !== '') return [].concat(list);
            return [];
        },
        /** Set tag IDs for one language (AppSelect @update:model-value). Kept per-tab; persisted to sessionStorage. */
        setTagIdsForLang(langId, value) {
            const arr = Array.isArray(value) ? value : (value ? [value] : []);
            const trimmed = arr.map(id => id != null ? String(id).trim() : '').filter(Boolean);
            if (trimmed.length === 0) {
                const currentLangId = this.languages[this.activeLanguageTab]?.id;
                if (currentLangId !== langId) return;
            }
            this.tagIdsByLanguage[langId] = trimmed;
            this.saveTagIdsToSession();
        },
        /** Init tag IDs per language so each tab has its own array. */
        initTagIdsByLanguage() {
            const newTagIds = {};
            this.languages.forEach(lang => {
                newTagIds[lang.id] = [];
            });
            this.tagIdsByLanguage = newTagIds;
        },
        /** SessionStorage key for tag selections (add vs edit so they don't mix). */
        getBlogTagsSessionKey() {
            return (this.edit_record && this.edit_record.id) ? `blog_form_tag_ids_${this.edit_record.id}` : 'blog_form_tag_ids_new';
        },
        /** Persist current tag selections to sessionStorage so they survive tab switches. */
        saveTagIdsToSession() {
            if (!this.create_new) return;
            try {
                const key = this.getBlogTagsSessionKey();
                sessionStorage.setItem(key, JSON.stringify(this.tagIdsByLanguage));
            } catch (e) { /* ignore */ }
        },
        /** Restore tag selections from sessionStorage (e.g. after tab switch). */
        loadTagIdsFromSession() {
            if (!this.create_new || !this.languages.length) return;
            try {
                const key = this.getBlogTagsSessionKey();
                const raw = sessionStorage.getItem(key);
                if (!raw) return;
                const parsed = JSON.parse(raw);
                if (parsed && typeof parsed === 'object') {
                    this.languages.forEach(lang => {
                        const val = parsed[lang.id] ?? parsed[String(lang.id)];
                        if (Array.isArray(val)) {
                            this.tagIdsByLanguage[lang.id] = val.map(id => String(id));
                        }
                    });
                }
            } catch (e) { /* ignore */ }
        },
        /** Clear sessionStorage for tag selections (after save or reset). */
        clearTagIdsSession() {
            try {
                sessionStorage.removeItem('blog_form_tag_ids_new');
                if (this.edit_record && this.edit_record.id) {
                    sessionStorage.removeItem(`blog_form_tag_ids_${this.edit_record.id}`);
                }
            } catch (e) { /* ignore */ }
        },

        // b-tabs model is the tab id string; fall back to 0 before languages load.
        defaultTabId() {
            return this.defaultLanguageId ? 'blog-lang-' + this.defaultLanguageId : 0;
        },

        switchToDefaultLanguageTab() {
            if (this.defaultLanguageId) {
                this.showError(__('please_fill_default_language_required_fields'));
                this.activeLanguageTab = this.defaultTabId();
            }
        },

        async saveBlog(event) {
            this.updateDescriptionValidation();

            // Validate required fields for default language
            const defaultLang = this.languages.find(l => l.is_default);
            if (defaultLang) {
                const defaultTranslation = this.translations[defaultLang.id];

                // Validate title
                if (!defaultTranslation?.title || !defaultTranslation.title.trim()) {
                    this.showError(__('please_fill_default_language_required_fields'));
                    // this.activeLanguageTab = this.defaultTabId();
                    this.switchToDefaultLanguageTab();
                    return;
                }

                // Validate short description
                if (!defaultTranslation?.short_description || !defaultTranslation.short_description.trim()) {
                    this.showError(__('please_fill_default_language_required_fields'));
                    this.activeLanguageTab = this.defaultTabId();
                    return;
                }

                // Validate description (strip HTML tags for validation)
                const descriptionText = (defaultTranslation?.description || '').replace(/<[^>]*>/g, '').trim();
                if (!descriptionText) {
                    this.showError(__('please_fill_default_language_required_fields'));
                    this.activeLanguageTab = this.defaultTabId();
                    return;
                }
            }

            const formEl = event.target;
            if (!formEl.checkValidity()) {
                const firstInvalid = formEl.querySelector(':invalid');
                if (firstInvalid) {
                    firstInvalid.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    setTimeout(() => {
                        firstInvalid.focus();
                        firstInvalid.reportValidity();
                    }, 100);
                } else {
                    formEl.reportValidity();
                }
                return;
            }

            this.isSubmitting = true;

            try {
                const formData = new FormData();

                // Get default language translation for main blog fields
                const defaultLang = this.languages.find(l => l.is_default);
                const defaultTranslation = defaultLang ? this.translations[defaultLang.id] : null;

                // Basic fields
                formData.append('slug', this.form.slug);
                formData.append('category_id', this.form.category_id);
                formData.append('status', this.form.status);

                // Image
                if (this.form.image) {
                    formData.append('image', this.form.image);
                }

                // Tags: send per-language so backend can create new tags with correct language_id
                this.languages.forEach(lang => {
                    const ids = this.getTagIdsForLang(lang.id);
                    const str = Array.isArray(ids) ? ids.filter(Boolean).map(String).join(',') : (ids || '');
                    if (str) formData.append(`tag_ids_by_language[${lang.id}]`, str);
                });

                // Send only translations that have actual data (not empty)
                // This prevents storing empty translation records
                Object.keys(this.translations).forEach(langId => {
                    const tr = this.translations[langId];

                    // Check if translation has any meaningful data
                    const hasData = (tr.title && tr.title.trim() !== '') ||
                        (tr.description && tr.description.trim() !== '') ||
                        (tr.short_description && tr.short_description.trim() !== '') ||
                        (tr.meta_title && tr.meta_title.trim() !== '') ||
                        (tr.meta_keywords && tr.meta_keywords.trim() !== '') ||
                        (tr.meta_description && tr.meta_description.trim() !== '') ||
                        (tr.schema_markup && tr.schema_markup.trim() !== '');

                    // Only send translations that have data
                    if (hasData) {
                        formData.append(`translations[${langId}][title]`, tr.title || '');
                        formData.append(`translations[${langId}][description]`, tr.description || '');
                        formData.append(`translations[${langId}][short_description]`, tr.short_description || '');
                        formData.append(`translations[${langId}][meta_title]`, tr.meta_title || '');
                        formData.append(`translations[${langId}][meta_keywords]`, tr.meta_keywords || '');
                        formData.append(`translations[${langId}][meta_description]`, tr.meta_description || '');
                        formData.append(`translations[${langId}][schema_markup]`, tr.schema_markup || '');
                    }
                });

                let response;
                if (this.edit_record.id) {
                    response = await axios.post(
                        `${this.$apiUrl}/blogs/update/${this.edit_record.id}`,
                        formData,
                        { headers: { 'Content-Type': 'multipart/form-data' } }
                    );
                } else {
                    response = await axios.post(
                        `${this.$apiUrl}/blogs/save`,
                        formData,
                        { headers: { 'Content-Type': 'multipart/form-data' } }
                    );
                }

                if (response.data.status === 1) {
                    this.showMessage('success', response.data.message);
                    this.create_new = false;
                    this.resetForm();
                    this.getBlogs();
                    this.getAllTagsForModal();
                } else {
                    this.showError(response.data.message);
                }

            } catch (error) {
                console.error('saveBlog error:', error);
                this.showError(__('something_went_wrong'));
            } finally {
                this.isSubmitting = false;
            }
        },

        async deleteBlog(index, id) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('you_will_not_be_able_to_revert_this'),
                confirmButtonText: __('yes_sure'),
                cancelButtonText: __('cancel'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (result.value) {
                    this.isLoading = true;
                    axios.post(this.$apiUrl + `/blogs/delete/${id}`)
                        .then((response) => {
                            this.isLoading = false;
                            if (response.data.status === 1) {
                                this.showMessage('success', response.data.message);
                                this.getBlogs();
                            } else {
                                this.showError(response.data.message);
                            }
                        })
                        .catch(error => {
                            this.isLoading = false;
                            this.showError(__('something_went_wrong'));
                        });
                }
            });
        },

        resetForm() {
            this.clearTagIdsSession();
            this.form = {
                title: '',
                slug: '',
                category_id: '',
                image: null,
                image_url: '',
                description: '',
                short_description: '',
                meta_title: '',
                meta_keywords: '',
                meta_description: '',
                status: 1
            };
            this.edit_record = {};
            this.tagIdsByLanguage = {};
            this.descriptionValidation = '';
            this.initTranslations();
            if (this.languages.length) this.initTagIdsByLanguage();
        },

        // Create slug from title (for default language only)
        createSlug(langId) {
            // Only create slug from default language title
            if (langId) {
                const defaultLang = this.languages.find(l => l.is_default);
                if (defaultLang && defaultLang.id === langId) {
                    const title = this.translations[langId]?.title || '';
                    if (title !== "") {
                        let slug = title.toLowerCase()
                            .replace(/[^\w ]+/g, '')
                            .replace(/ +/g, '-');
                        this.form.slug = slug;
                    }
                }
            } else {
                // Fallback for old code that doesn't pass langId
                const defaultLang = this.languages.find(l => l.is_default);
                if (defaultLang && this.translations[defaultLang.id]?.title) {
                    const title = this.translations[defaultLang.id].title;
                    if (title !== "") {
                        let slug = title.toLowerCase()
                            .replace(/[^\w ]+/g, '')
                            .replace(/ +/g, '-');
                        this.form.slug = slug;
                    }
                }
            }
        },

        updateDescriptionValidation() {
            const defaultLang = this.languages.find(l => l.is_default);
            if (!defaultLang) return;

            const html = this.translations[defaultLang.id]?.description || '';
            this.descriptionValidation = html.replace(/<[^>]*>/g, '').trim();
        },
        normalizeTagIds(tagValue) {
            if (Array.isArray(tagValue)) {
                return tagValue
                    .map(tagId => {
                        if (tagId === null || tagId === undefined) {
                            return '';
                        }
                        return tagId.toString().trim();
                    })
                    .filter(tagId => tagId !== '');
            }

            if (typeof tagValue === 'string') {
                return tagValue
                    .split(',')
                    .map(tagId => tagId.trim())
                    .filter(tagId => tagId !== '');
            }

            return [];
        }
    },
    watch: {
        edit_record: {
            handler(newVal) {
                if (!newVal.id) return;

                this.form = {
                    slug: newVal.slug || '',
                    category_id: newVal.category_id || '',
                    status: newVal.status,
                    image: null,
                    image_url: newVal.image_url || ''
                };

                this.initTranslations();
                this.initTagIdsByLanguage();

                // Populate tags per language: fetch all tags, group by language for dropdown, and split blog.tags into each tab
                axios.get(`${this.$apiUrl}/blog_tags?all=1`).then(res => {
                    if (res.data.status === 1 && Array.isArray(res.data.data)) {
                        const allTags = res.data.data;
                        const byLang = {};
                        this.languages.forEach(lang => {
                            byLang[lang.id] = allTags.filter(t => t.language_id === lang.id);
                        });
                        this.tagsByLanguage = byLang;
                        if (newVal.tags && newVal.tags.trim()) {
                            const idToLang = {};
                            allTags.forEach(t => { idToLang[String(t.id)] = t.language_id; });
                            const blogTagIds = newVal.tags.split(',').map(id => id.trim()).filter(Boolean);
                            blogTagIds.forEach(tid => {
                                const langId = idToLang[String(tid)];
                                if (langId != null) {
                                    const list = this.getTagIdsForLang(langId);
                                    const sid = String(tid);
                                    if (!list.includes(sid)) this.setTagIdsForLang(langId, list.concat(sid));
                                }
                            });
                        }
                        this.saveTagIdsToSession();
                    }
                }).catch(() => { });

                // Tab switch watcher will restore from session when user changes tabs

                // Get default language for fallback
                const defaultLang = this.languages.find(l => l.is_default);

                // Load translations from API response - only populate languages that have translations
                if (Array.isArray(newVal.translations) && newVal.translations.length > 0) {
                    newVal.translations.forEach(tr => {
                        if (this.translations[tr.language_id]) {
                            // Only populate if translation has data
                            const hasData = (tr.title && tr.title.trim() !== '') ||
                                (tr.description && tr.description.trim() !== '') ||
                                (tr.short_description && tr.short_description.trim() !== '');

                            if (hasData) {
                                this.translations[tr.language_id] = {
                                    title: tr.title || '',
                                    description: tr.description || '',
                                    short_description: tr.short_description || '',
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
                    const defaultTranslation = this.translations[defaultLang.id];

                    // Check if default language translation is missing or empty
                    const isMissing = !defaultTranslation ||
                        (!defaultTranslation.title && !defaultTranslation.description && !defaultTranslation.short_description);

                    if (isMissing) {
                        // Use main table data as fallback only for default language
                        this.translations[defaultLang.id] = {
                            title: newVal.title || '',
                            description: newVal.description || '',
                            short_description: newVal.short_description || '',
                            meta_title: newVal.meta_title || '',
                            meta_keywords: newVal.meta_keywords || '',
                            meta_description: newVal.meta_description || '',
                            schema_markup: newVal.schema_markup || ''
                        };
                    } else {
                        // Fill in any empty fields in default language translation with main table data
                        this.translations[defaultLang.id] = {
                            title: defaultTranslation.title || newVal.title || '',
                            description: defaultTranslation.description || newVal.description || '',
                            short_description: defaultTranslation.short_description || newVal.short_description || '',
                            meta_title: defaultTranslation.meta_title || newVal.meta_title || '',
                            meta_keywords: defaultTranslation.meta_keywords || newVal.meta_keywords || '',
                            meta_description: defaultTranslation.meta_description || newVal.meta_description || '',
                            schema_markup: defaultTranslation.schema_markup || newVal.schema_markup || ''
                        };
                    }
                }

                // Bump the editor key BEFORE opening: setting create_new first mounts
                // the editor on the old key, then this remounts it — the transient
                // instance collides with the previous open's (not-yet-removed)
                // TinyMCE editor, so the content shows only every other open.
                this.activeLanguageTab = this.defaultTabId();
                this.languagesKey++;
                this.create_new = true;
                this.$nextTick(() => { this.updateDescriptionValidation(); });
            },
            deep: true
        },
        activeLanguageTab() {
            if (this.create_new && this.languages.length) {
                this.saveTagIdsToSession();
                this.loadTagIdsFromSession();
            }
        },
        currentPage() {
            this.getBlogs();
        },

        perPage() {
            this.currentPage = 1;
            this.getBlogs();
        }
    }
}
</script>

<style scoped>
/* Views + reading time under the category on a blog card. */
.blog-stats {
    display: flex;
    flex-wrap: wrap;
    gap: .15rem .9rem;
}

.blog-stats > span {
    display: inline-flex;
    align-items: center;
    gap: .3rem;
}
</style>
