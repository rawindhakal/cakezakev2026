<template>
    <div class="hb-editor">
        <!-- ===== Top bar ===== -->
        <div class="hb-topbar">
            <div class="d-flex align-items-center gap-2">
                <router-link to="/page_builder" class="btn btn-sm btn-light">
                    <ArrowLeft :size="16" />
                </router-link>
                <input type="text" class="form-control form-control-sm hb-name-input" v-model="name"
                    :placeholder="__('enter_page_name')">
                <span class="badge" :class="status === 'published' ? 'bg-success' : 'bg-warning'">
                    {{ status === 'published' ? __('published') : __('draft') }}
                </span>
            </div>
            <div class="d-flex align-items-center gap-2">
                <div class="btn-group btn-group-sm me-1" role="group">
                    <button type="button" class="btn"
                        :class="previewSource === 'draft' ? 'btn-secondary' : 'btn-outline-secondary'"
                        @click="setSource('draft')">{{ __('edit_draft') }}</button>
                    <button type="button" class="btn"
                        :class="previewSource === 'published' ? 'btn-secondary' : 'btn-outline-secondary'"
                        @click="setSource('published')">{{ __('edit_published') }}</button>
                </div>
                <button v-if="previewSource === 'draft'" class="btn btn-sm btn-outline-primary"
                    @click="saveDraft" :disabled="saving || publishing">
                    <b-spinner small v-if="saving"></b-spinner>
                    <Save :size="15" v-else />
                    {{ __('save_draft') }}
                </button>
                <!-- Publish: draft mode promotes the draft; published mode pushes the live edits. -->
                <button class="btn btn-sm btn-primary" @click="publish" :disabled="saving || publishing"
                    v-if="$can('page_builder_publish')">
                    <b-spinner small v-if="publishing"></b-spinner>
                    <Rocket :size="15" v-else />
                    {{ previewSource === 'published' ? __('publish_changes') : __('publish') }}
                </button>
            </div>
        </div>

        <!-- Loading skeleton in the same 3-column shape so the layout doesn't jump. -->
        <div v-if="loading" class="hb-grid hb-skel">
            <div class="hb-col hb-col-list">
                <div class="skel skel-line" style="width:55%;height:.9rem;margin-bottom:1rem"></div>
                <div v-for="n in 6" :key="'pbskl-' + n" class="hb-skel-row">
                    <div class="skel hb-skel-grip"></div>
                    <div class="skel skel-line mb-0" style="flex:1"></div>
                    <div class="skel hb-skel-dot"></div>
                </div>
                <div class="skel hb-skel-add"></div>
            </div>
            <div class="hb-col hb-col-preview">
                <div class="skel hb-skel-preview"></div>
            </div>
            <div class="hb-col hb-col-config">
                <div class="hb-skel-config">
                    <div class="skel skel-line" style="width:50%;height:.95rem;margin-bottom:1.1rem"></div>
                    <div v-for="n in 5" :key="'pbskc-' + n" class="hb-skel-field">
                        <div class="skel skel-line" style="width:35%;margin-bottom:.5rem"></div>
                        <div class="skel hb-skel-input"></div>
                    </div>
                </div>
            </div>
        </div>

        <div v-else class="hb-grid">
            <!-- ===== Col 1: page settings row + sections ===== -->
            <div class="hb-col hb-col-list">
                <div class="hb-subhead">
                    <div class="alert py-2 px-3 mb-2 small d-flex align-items-center gap-2"
                        :class="previewSource === 'published' ? 'alert-info' : 'alert-secondary'">
                        <component :is="previewSource === 'published' ? 'Rocket' : 'Pen'" :size="14" />
                        {{ previewSource === 'published' ? __('editing_published_page') : __('editing_draft_page') }}
                    </div>
                </div>

                <!-- Page settings — selectable; its form opens in the right panel. -->
                <div class="hb-sec-row hb-header-row" :class="{ active: selectedIsSettings }" @click="selectSettings">
                    <span class="hb-sec-row-icon"><Settings :size="15" /></span>
                    <span class="hb-sec-row-title">{{ __('page_settings') }}</span>
                </div>

                <div class="d-flex align-items-center justify-content-between my-2">
                    <h6 class="mb-0 fw-bold">{{ __('sections') }}</h6>
                    <button type="button" class="btn btn-sm btn-primary d-inline-flex align-items-center gap-1"
                        @click="addSectionOpen = true">
                        <Plus :size="15" /> {{ __('add') }}
                    </button>
                </div>

                <div class="hb-sections">
                    <draggable v-model="draftConfig.sections" item-key="id" handle=".hb-row-grip"
                        :animation="180" ghost-class="hb-drag-ghost">
                        <template #item="{ element: section, index }">
                            <div class="hb-sec-row" :class="{ active: section.id === selectedSectionId, inactive: !section.active }"
                                @click="selectSection(section.id)">
                                <span class="hb-row-grip" :title="__('drag_to_reorder')"><GripVertical :size="15" /></span>
                                <span class="hb-sec-row-icon"><component :is="iconFor(section.type)" :size="15" /></span>
                                <span class="hb-sec-row-title">{{ __(section.type) }} <small class="text-muted">#{{ index + 1 }}</small></span>
                                <div class="form-check form-switch m-0 ms-auto" @click.stop
                                    v-b-tooltip.hover :title="section.active ? __('active') : __('inactive')">
                                    <input type="checkbox" class="form-check-input" v-model="section.active">
                                </div>
                                <div class="dropdown hb-row-menu" @click.stop>
                                    <button type="button" class="btn btn-xs p-1 text-muted" data-bs-toggle="dropdown"
                                        data-bs-container="body" aria-expanded="false" :title="__('actions')">
                                        <MoreVertical :size="15" />
                                    </button>
                                    <ul class="dropdown-menu dropdown-menu-end">
                                        <li><a class="dropdown-item d-flex align-items-center gap-2" href="#"
                                            @click.prevent="cloneSection(index)"><Copy :size="14" /> {{ __('clone') }}</a></li>
                                        <li><a class="dropdown-item d-flex align-items-center gap-2 text-danger" href="#"
                                            @click.prevent="removeSection(index)"><Trash2 :size="14" /> {{ __('delete') }}</a></li>
                                    </ul>
                                </div>
                            </div>
                        </template>
                    </draggable>

                    <p v-if="!draftConfig.sections.length" class="text-muted text-center py-3">
                        {{ __('no_sections_yet') }}
                    </p>
                </div>
            </div>

            <!-- ===== Col 2: live preview ===== -->
            <div class="hb-col hb-col-preview">
                <div class="hb-preview-sticky">
                    <LivePreview :config="draftConfig" :languages="languages" :active-lang="activeLang"
                        :default-lang="defaultLang" :all-products="allProducts" :all-categories="allCategories"
                        :all-brands="allBrands"
                        :platform="previewPlatform" @update:platform="previewPlatform = $event"
                        variant="page" :page-title="previewTitle"
                        :header-color="headerColor" :title-color="titleColor"
                        :selected-section-id="selectedSectionId"
                        @edit-section="selectSection" />
                </div>
            </div>

            <!-- ===== Col 3: config panel (page settings OR selected section) ===== -->
            <div class="hb-col hb-col-config">
                <div class="hb-config-panel">
                    <template v-if="selectedIsSettings">
                        <div class="hb-config-head">
                            <Settings :size="16" />
                            <strong class="text-truncate">{{ __('page_settings') }}</strong>
                        </div>
                        <div class="mb-3">
                            <label class="form-label small text-muted mb-1">{{ __('name') }}</label>
                            <input type="text" class="form-control form-control-sm" v-model="name"
                                :placeholder="__('enter_page_name')">
                            <small class="text-muted">{{ __('page_name_hint') }}</small>
                        </div>
                        <div class="mb-3">
                            <label class="form-label small text-muted mb-1">{{ __('slug') }}</label>
                            <div class="input-group input-group-sm">
                                <input type="text" class="form-control form-control-sm" v-model="slug" placeholder="diwali-sale">
                                <button type="button" class="btn btn-outline-secondary" @click="regenerateSlug"
                                    v-b-tooltip.hover :title="__('generate_from_name')"><RefreshCw :size="13" /></button>
                            </div>
                            <small class="text-muted">{{ __('page_slug_hint') }}</small>
                        </div>
                        <div class="mb-3">
                            <TranslatableInput v-if="languages.length === 1" :label="__('page_title')"
                                v-model="title" :languages="languages" :active-lang="languages[0].id" />
                            <template v-else>
                                <label class="form-label small text-muted mb-1">{{ __('page_title') }}</label>
                                <ul class="nav nav-tabs hb-block-lang-tabs mb-2">
                                    <li class="nav-item" v-for="(lang, idx) in languages" :key="'pt-' + lang.id">
                                        <a class="nav-link" href="javascript:void(0)"
                                            :class="{ active: langTabIndex === idx }" @click="langTabIndex = idx">
                                            <span :class="{ 'text-primary fw-bold': lang.is_default }">{{ lang.name }}</span>
                                        </a>
                                    </li>
                                </ul>
                                <template v-for="(lang, idx) in languages" :key="'pp-' + lang.id">
                                    <div v-show="langTabIndex === idx" class="mt-2">
                                        <TranslatableInput v-model="title" :languages="languages" :active-lang="lang.id" />
                                    </div>
                                </template>
                            </template>
                            <small class="text-muted">{{ __('page_title_hint') }}</small>
                        </div>
                        <div class="row g-2 mb-3">
                            <div class="col-md-6">
                                <label class="form-label small text-muted mb-1">{{ __('page_header_color') }}</label>
                                <ColorInput show-hex placeholder="#FFFFFF" :model-value="headerColor"
                                    @update:model-value="headerColor = $event" />
                                <small class="text-muted">{{ __('page_header_color_hint') }}</small>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label small text-muted mb-1">{{ __('page_title_color') }}</label>
                                <ColorInput show-hex placeholder="#111111" :model-value="titleColor"
                                    @update:model-value="titleColor = $event" />
                                <small class="text-muted">{{ __('page_title_color_hint') }}</small>
                            </div>
                        </div>
                        <div class="form-check form-switch hb-switch-row">
                            <label class="form-check-label small text-muted" for="pb-active">{{ __('active') }}</label>
                            <input class="form-check-input" type="checkbox" role="switch" id="pb-active"
                                v-model="isActive" :disabled="status !== 'published'"
                                v-b-tooltip.hover :title="status !== 'published' ? __('only_published_page_can_be_activated') : ''">
                        </div>
                    </template>
                    <template v-else-if="selectedSection">
                        <div class="hb-config-head">
                            <span class="hb-sec-row-icon"><component :is="iconFor(selectedSection.type)" :size="16" /></span>
                            <strong class="text-truncate">{{ __(selectedSection.type) }}</strong>
                            <div class="hb-plat-toggles ms-auto" v-b-tooltip.hover :title="__('show_on_platforms')">
                                <button v-for="p in platformOptions" :key="p.value" type="button"
                                    class="hb-plat-btn" :class="{ on: platformOn(selectedSection, p.value) }"
                                    :disabled="platformOn(selectedSection, p.value) && onlyPlatformLeft(selectedSection)"
                                    @click="togglePlatform(selectedSection, p.value)">
                                    {{ p.text }}
                                </button>
                            </div>
                            <button type="button" class="btn btn-sm btn-outline-secondary"
                                @click="onSaveTemplate(selectedSection)" v-b-tooltip.hover :title="__('save_as_template')">
                                <Bookmark :size="14" />
                            </button>
                        </div>
                        <SectionEditor panel :section="selectedSection" :index="selectedSectionIndex"
                            :languages="languages" :default-lang="defaultLang" :all-products="allProducts"
                            :all-categories="allCategories" :all-brands="allBrands" :all-pages="allPages"
                            @save-template="onSaveTemplate" />
                    </template>
                    <div v-else class="hb-config-empty text-muted text-center">
                        <MousePointerClick :size="30" class="mb-2 opacity-50" />
                        <div>{{ __('select_a_section_to_edit') }}</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Add Section modal: section types + templates -->
        <b-modal v-model="addSectionOpen" :title="__('add_section')" hide-footer centered size="lg">
            <p class="text-muted small mb-2">{{ __('add_section_hint') }}</p>
            <div class="row g-2">
                <div class="col-6 col-md-4" v-for="t in sectionTypes" :key="t.value">
                    <SectionTypeCard :type="t.value" :icon="t.icon" @pick="addSection" />
                </div>
            </div>
            <hr>
            <button type="button" class="btn btn-primary w-100 d-inline-flex align-items-center justify-content-center gap-1"
                @click="addSectionOpen = false; templatePickerOpen = true">
                <Sparkles :size="15" /> {{ __('use_template') }}
            </button>
        </b-modal>

        <TemplatePicker v-if="templatePickerOpen" :default-lang="defaultLang"
            @close="templatePickerOpen = false" @pick="onTemplatePick" />
    </div>
</template>

<script>
import axios from 'axios';
import draggable from 'vuedraggable';
import SectionEditor from '../HomeBuilder/components/SectionEditor.vue';
import LivePreview from '../HomeBuilder/components/preview/LivePreview.vue';
import TemplatePicker from '../HomeBuilder/components/TemplatePicker.vue';
import SectionTypeCard from '../HomeBuilder/components/SectionTypeCard.vue';
import TranslatableInput from '../HomeBuilder/components/TranslatableInput.vue';
import {
    ArrowLeft, Settings, Save, Rocket, Copy, Sparkles, Pen,
    Images, LayoutGrid, Package, Tags, Grid3x3, Image as ImageIcon, Heading, PanelTop,
    GripVertical, Plus, Trash2, MousePointerClick, Bookmark, MoreVertical, RefreshCw,
} from 'lucide-vue-next';
import ColorInput from '../HomeBuilder/components/ColorInput.vue';
import {
    SECTION_TYPES, emptyConfig, newSection, normalizeConfig, cloneAndReidSection, pageOptions,
} from '../HomeBuilder/homeBuilderHelpers.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';

/**
 * Page Builder editor: the Home Builder's 3-column shell (sections | preview |
 * config) over a single global tree of sections. No zone/channel, no category
 * tabs, no header background — a page is just its sections plus a title.
 */
export default {
    name: 'PageBuilderEditor',
    mixins: [UnsavedChanges],
    // Page images upload to their own folder (page_builder/), see HbImageUpload.
    provide: { hbUploadEndpoint: '/page_layouts/upload_image' },
    components: {
        draggable, SectionEditor, LivePreview, TemplatePicker, TranslatableInput, SectionTypeCard, ColorInput,
        ArrowLeft, Settings, Save, Rocket, Copy, Sparkles, Pen,
        Images, LayoutGrid, Package, Tags, Grid3x3, ImageIcon, Heading, PanelTop,
        GripVertical, Plus, Trash2, MousePointerClick, Bookmark, MoreVertical, RefreshCw,
    },
    data() {
        return {
            pageId: null,
            page: null,
            name: '',
            slug: '',
            title: {},                 // {langId: text}
            headerColor: '#FFFFFF',
            titleColor: '',
            isActive: true,
            status: 'draft',
            languages: [],
            activeLang: null,
            langTabIndex: 0,
            defaultLang: null,
            draftConfig: emptyConfig(),
            allProducts: [],
            allCategories: [],
            allBrands: [],
            allPages: [],
            previewPlatform: 'app',
            previewSource: 'draft',     // draft | published
            sectionTypes: SECTION_TYPES,
            loading: true,
            saving: false,
            publishing: false,
            templatePickerOpen: false,
            selectedSectionId: null,
            selectedIsSettings: false,
            addSectionOpen: false,
            platformOptions: [
                { value: 'app', text: 'App' },
                { value: 'tablet', text: 'Tablet' },
                { value: 'web', text: 'Web' },
            ],
        };
    },
    computed: {
        selectedSectionIndex() {
            return this.draftConfig.sections.findIndex(s => s.id === this.selectedSectionId);
        },
        selectedSection() {
            return this.selectedSectionIndex >= 0 ? this.draftConfig.sections[this.selectedSectionIndex] : null;
        },
        hasPublished() {
            const j = this.page && this.page.published_json;
            return !!(j && Array.isArray(j.sections) && j.sections.length);
        },
        // Title in the preview's language, falling back to the default language, then the name.
        previewTitle() {
            const t = this.title || {};
            return t[this.activeLang] || t[this.defaultLang] || Object.values(t).find(v => v) || this.name;
        },
    },
    created() {
        this.pageId = this.$route.params.id;
        if (!this.pageId) {
            this.$router.replace('/page_builder');
            return;
        }
        this.init();
    },
    mounted() {
        // Collapse the admin sidebar while editing for more canvas width; restore on leave.
        const sb = document.getElementById('sidebar');
        this._sidebarWasActive = sb ? sb.classList.contains('active') : false;
        if (sb) sb.classList.remove('active');
        window.dispatchEvent(new Event('resize'));
    },
    beforeUnmount() {
        const sb = document.getElementById('sidebar');
        if (sb && this._sidebarWasActive) sb.classList.add('active');
        window.dispatchEvent(new Event('resize'));
    },
    methods: {
        // Tracked state for the UnsavedChanges guard.
        formState() {
            return {
                name: this.name, slug: this.slug, title: this.title, isActive: this.isActive,
                headerColor: this.headerColor, titleColor: this.titleColor, draftConfig: this.draftConfig,
            };
        },
        async init() {
            try {
                const [langRes, pageRes, catRes, brandRes, prodRes, pagesRes] = await Promise.all([
                    axios.get(this.$apiUrl + '/active_languages'),
                    axios.get(this.$apiUrl + '/page_layouts/edit/' + this.pageId),
                    axios.get(this.$apiUrl + '/categories', { params: { status: 1 } }),
                    axios.get(this.$apiUrl + '/products/brands/get').catch(() => ({ data: { data: [] } })),
                    // Pages are global — every listed product is a candidate.
                    axios.get(this.$apiUrl + '/products', { params: { per_page: 1000, page: 1, is_draft: 0, listed_only: 1 } }),
                    axios.get(this.$apiUrl + '/page_layouts/options').catch(() => ({ data: { data: [] } })),
                ]);

                this.languages = langRes.data?.data || [];
                const def = this.languages.find(l => l.is_default) || this.languages[0];
                this.defaultLang = def ? def.id : null;
                this.activeLang = this.defaultLang;

                this.allCategories = (catRes.data?.data || []).map(c => ({
                    id: c.id,
                    name: c.name,
                    image_url: c.image_url || '',
                    parent_id: c.parent_id ? Number(c.parent_id) : 0,
                }));
                this.allProducts = (prodRes.data?.data?.products || []).map(p => ({
                    id: p.id, name: p.name, image_url: p.image_url || '',
                    category_id: p.category ? p.category.id : null,
                    sales_channel: (p.sales_channel || 'both').toString().toLowerCase(),
                    min_price: Number(p.min_price) || 0,
                    max_price: Number(p.max_price) || 0,
                    min_discounted: Number(p.min_discounted) || 0,
                }));
                this.allBrands = (brandRes.data?.data || []).map(b => ({
                    id: b.id, name: b.name, image_url: b.image_url || '',
                }));
                // A page may link to another page, never to itself.
                this.allPages = pageOptions(pagesRes.data?.data || []).filter(p => String(p.id) !== String(this.pageId));

                this.page = pageRes.data?.data;
                if (!this.page) {
                    this.showError(__('page_not_found'));
                    this.$router.replace('/page_builder');
                    return;
                }
                this.name = this.page.name;
                this.slug = this.page.slug || '';
                this.title = { ...(this.page.title || {}) };
                this.headerColor = this.page.header_color || '#FFFFFF';
                this.titleColor = this.page.title_color || '';
                this.isActive = !!this.page.is_active;
                this.status = this.page.status;
                // Default to editing the published snapshot when one exists.
                this.previewSource = this.hasPublished ? 'published' : 'draft';
                this.loadSource(this.previewSource);
                this.selectSettings();
                this.captureFormBaseline();
            } catch (e) {
                this.showError(__('something_went_wrong'));
            } finally {
                this.loading = false;
            }
        },
        // Server-side slugify of the current name (same rule products use).
        regenerateSlug() {
            const text = (this.name || '').trim();
            if (!text) return;
            axios.get(this.$apiUrl + '/create_slug/' + encodeURIComponent(text))
                .then(res => { this.slug = res.data?.data || this.slug; })
                .catch(() => {});
        },
        // Load a source (draft | published) into the editable working buffer.
        loadSource(source) {
            const j = source === 'published' ? this.page.published_json : this.page.draft_json;
            this.draftConfig = normalizeConfig(j ? JSON.parse(JSON.stringify(j)) : emptyConfig());
        },
        setSource(source) {
            if (this.previewSource === source) return;
            this.previewSource = source;
            this.loadSource(source);
            // The toggle alone must not read as an unsaved edit.
            this.captureFormBaseline();
        },
        iconFor(type) {
            const t = SECTION_TYPES.find(x => x.value === type);
            return t ? t.icon : 'LayoutGrid';
        },
        selectSection(id) {
            this.selectedSectionId = id;
            this.selectedIsSettings = false;
        },
        selectSettings() {
            this.selectedIsSettings = true;
            this.selectedSectionId = null;
        },
        addSection(type) {
            const s = newSection(type);
            this.draftConfig.sections.push(s);
            this.selectSection(s.id);
            this.addSectionOpen = false;
        },
        onTemplatePick(section) {
            this.draftConfig.sections.push(section);
            this.selectSection(section.id);
            this.templatePickerOpen = false;
            this.showMessage('success', __('template_added'));
        },
        onSaveTemplate(section) {
            this.$swal.fire({
                title: __('save_as_template'),
                input: 'text',
                inputLabel: __('template_name'),
                inputPlaceholder: __('enter_template_name'),
                showCancelButton: true,
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
                confirmButtonText: __('save'),
                cancelButtonText: __('cancel'),
                inputValidator: (val) => !val || !val.trim() ? __('required') : null,
            }).then((result) => {
                if (!result.isConfirmed) return;
                const sectionType = SECTION_TYPES.find(t => t.value === section.type) || {};
                const form = new FormData();
                form.append('name', result.value.trim());
                form.append('section_type', section.type);
                form.append('icon', sectionType.icon || '');
                form.append('section_json', JSON.stringify(section));
                axios.post(this.$apiUrl + '/home_layout_templates/save', form)
                    .then(() => { this.showMessage('success', __('template_saved')); })
                    .catch(err => { this.showError(err.response?.data?.message || __('something_went_wrong')); });
            });
        },
        platformOn(section, key) {
            return !section.platforms || section.platforms[key] !== false;
        },
        onlyPlatformLeft(section) {
            return this.platformOptions.filter(p => this.platformOn(section, p.value)).length === 1;
        },
        togglePlatform(section, key) {
            const next = { ...(section.platforms || {}) };
            next[key] = !this.platformOn(section, key);
            // A section on no platform at all is just a hidden section — keep one on.
            if (!next.app && !next.tablet && !next.web) return;
            section.platforms = next;
        },
        cloneSection(index) {
            const source = this.draftConfig.sections[index];
            if (!source) return;
            const copy = cloneAndReidSection(source);
            this.draftConfig.sections.splice(index + 1, 0, copy);
            this.selectSection(copy.id);
        },
        removeSection(index) {
            const removed = this.draftConfig.sections[index];
            if (!removed) return;
            this.$swal.fire({
                title: __('are_you_sure'), text: __('you_want_be_able_to_revert_this'),
                icon: 'warning', showCancelButton: true,
                confirmButtonText: __('yes_sure'), cancelButtonText: __('cancel'),
            }).then(r => {
                if (!r.value) return;
                // Re-find by id: the confirm is async, so the index may have moved.
                const i = this.draftConfig.sections.findIndex(x => x.id === removed.id);
                if (i < 0) return;
                this.draftConfig.sections.splice(i, 1);
                if (removed.id === this.selectedSectionId) this.selectedSectionId = null;
            });
        },
        // `source` decides which snapshot the working buffer is written into.
        buildPayload(source = this.previewSource) {
            const payload = {
                id: this.pageId,
                name: this.name.trim() || this.page.name,
                slug: this.slug.trim(),
                title: this.title || {},
                header_color: this.headerColor || '#FFFFFF',
                title_color: this.titleColor || '',
                is_active: this.isActive ? 1 : 0,
            };
            payload[source === 'published' ? 'published_json' : 'draft_json'] = { sections: this.draftConfig.sections };
            return payload;
        },
        saveDraft() {
            this.saving = true;
            axios.post(this.$apiUrl + '/page_layouts/save', this.buildPayload())
                .then(res => {
                    if (res.data?.status === 0) {
                        this.showError(res.data?.message || __('something_went_wrong'));
                        return;
                    }
                    if (res.data?.data) {
                        this.status = res.data.data.status;
                        this.page = { ...this.page, ...res.data.data };
                    }
                    this.captureFormBaseline();
                    this.showMessage('success', __('page_saved_successfully'));
                })
                .catch(err => { this.showError(err.response?.data?.message || __('something_went_wrong')); })
                .finally(() => { this.saving = false; });
        },
        publish() {
            const live = this.previewSource === 'published';
            this.$swal.fire({
                title: live ? __('publish_changes') : __('publish_page'),
                text: live ? __('publish_changes_confirm') : __('publish_page_confirm'),
                icon: 'question',
                showCancelButton: true,
                confirmButtonText: live ? __('publish_changes') : __('publish'),
                cancelButtonText: __('cancel'),
            }).then(result => {
                if (!result.isConfirmed) return;
                this.publishing = true;
                const source = live ? 'published' : 'draft';
                axios.post(this.$apiUrl + '/page_layouts/save', this.buildPayload(source))
                    .then(res => {
                        if (res.data?.status === 0) throw new Error(res.data?.message);
                        const form = new FormData();
                        form.append('id', this.pageId);
                        form.append('from', source);
                        return axios.post(this.$apiUrl + '/page_layouts/publish', form);
                    })
                    .then(res => {
                        if (res.data?.status === 0) throw new Error(res.data?.message);
                        if (res.data?.data) {
                            this.status = res.data.data.status;
                            this.page = { ...this.page, ...res.data.data };
                        }
                        this.previewSource = 'published';
                        this.captureFormBaseline();
                        this.showMessage('success', __('page_published_successfully'));
                    })
                    .catch(err => {
                        this.showError(err.response?.data?.message || err.message || __('something_went_wrong'));
                    })
                    .finally(() => { this.publishing = false; });
            });
        },
    },
};
</script>

<style scoped src="../HomeBuilder/editorShell.css"></style>
<style scoped>
.hb-switch-row {
    display: flex;
    align-items: center;
    gap: .4rem;
    padding-left: 0;
}
.hb-switch-row .form-check-input {
    float: none;
    margin: 0;
}
</style>
