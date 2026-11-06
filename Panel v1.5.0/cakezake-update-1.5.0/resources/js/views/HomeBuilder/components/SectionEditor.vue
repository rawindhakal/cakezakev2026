<template>
    <div class="hb-section-card" :class="{ collapsed: !bodyOpen, 'is-panel': panel }">
        <div v-if="!panel" class="hb-section-head">
            <span class="hb-drag-handle" :title="__('drag_to_reorder')" @click="open = !open">
                <span class="hb-grip text-muted"><GripVertical :size="16" /></span>
                <span class="hb-section-icon"><component :is="typeIcon" :size="15" /></span>
                <span class="hb-section-title">
                    {{ typeLabel }}
                    <small class="text-muted">#{{ index + 1 }}</small>
                </span>
            </span>
            <div class="ms-auto d-flex gap-1">
                <button type="button" class="btn btn-xs btn-light" :title="__('save_as_template')"
                    @click="$emit('save-template', section)">
                    <Bookmark :size="14" />
                </button>
                <button type="button" class="btn btn-xs btn-light" @click="open = !open">
                    <component :is="open ? 'ChevronUp' : 'ChevronDown'" :size="14" />
                </button>
                <button type="button" class="btn btn-xs btn-light text-danger" @click="$emit('remove')">
                    <Trash2 :size="14" />
                </button>
            </div>
        </div>

        <div v-if="bodyOpen" class="hb-section-body">

            <!-- Language tabs (only when the section has translatable text + multi-lang). -->
            <template v-if="showLangTabs">
                <ul class="nav nav-tabs hb-block-lang-tabs mb-2 align-items-center">
                    <li class="nav-item" v-for="(lang, idx) in languages" :key="'lt-' + lang.id">
                        <a class="nav-link" href="javascript:void(0)"
                            :class="{ active: langTabIndex === idx }" @click="langTabIndex = idx">
                            <span :class="{ 'text-primary fw-bold': lang.is_default }">{{ lang.name }}</span>
                        </a>
                    </li>
                    <!-- Translate control, inline with the language tabs. -->
                    <li class="nav-item ms-auto d-flex align-items-center">
                        <TranslateLanguages :languages="languages" :default-language-id="defaultLanguageId"
                            :busy="translating" :progress="translateProgress" @translate="runTranslate" />
                    </li>
                </ul>
            </template>

            <div v-show="onDefaultLangTab" :class="{ 'mt-2': showLangTabs }">
                <BlockEditor :block="section.blocks[0]" :languages="languages" :active-lang="defaultLang"
                    :all-products="allProducts" :all-categories="allCategories"
                    :scoped-categories="scopedCategories" :all-brands="allBrands" :all-pages="allPages" />
            </div>

            <template v-if="showLangTabs">
                <template v-for="(lang, idx) in languages" :key="'lp-' + lang.id">
                    <div v-if="!lang.is_default" v-show="langTabIndex === idx" class="hb-translation-only mt-2">
                        <p class="text-muted small mb-2">{{ __('translate_these_fields_into') }} {{ lang.name }}</p>
                        <TranslatableInput v-for="t in translationTargets" :key="t.key + '-' + lang.id"
                            class="mb-2" :label="t.label" :model-value="t.map"
                            @update:model-value="t.set($event)"
                            :languages="languages" :active-lang="lang.id" :type="t.type" />
                    </div>
                </template>
            </template>

            <hr class="my-3">
            <div class="row g-3">
                <div class="col-md-6">
                    <CornerRadiusInput :label="__('border_radius')" :hint="__('border_radius_hint')" :min="0" :max="50"
                        :model-value="section.border_radius" :custom="section.border_radius_custom === true"
                        @update:model-value="section.border_radius = $event"
                        @update:custom="section.border_radius_custom = $event" />
                </div>
                <div class="col-md-6">
                    <label class="hb-lbl d-block mb-1">{{ __('margin') }}</label>
                    <div class="hb-box">
                        <DimensionSlider :label="__('margin_top')" :min="0" :max="100"
                            :model-value="section.margin_top" @update:model-value="section.margin_top = $event" />
                        <DimensionSlider :label="__('margin_bottom')" :min="0" :max="100"
                            :model-value="section.margin_bottom" @update:model-value="section.margin_bottom = $event" />
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import BlockEditor from './BlockEditor.vue';
import TranslatableInput from './TranslatableInput.vue';
import DimensionSlider from './DimensionSlider.vue';
import CornerRadiusInput from './CornerRadiusInput.vue';
import TranslationHelper from '../../../mixins/TranslationHelper.js';
import { SECTION_TYPES, newBlock, blockHasTitle, blockHasSubtitle } from '../homeBuilderHelpers.js';
import {
    GripVertical, Bookmark, ChevronUp, ChevronDown, Trash2, Info,
    Images, LayoutGrid, Package, PanelTop, Tags, Grid3x3, Image as ImageIcon, Heading,
} from 'lucide-vue-next';

export default {
    name: 'SectionEditor',
    mixins: [TranslationHelper],
    components: {
        BlockEditor, TranslatableInput, DimensionSlider, CornerRadiusInput,
        GripVertical, Bookmark, ChevronUp, ChevronDown, Trash2, Info,
        Images, LayoutGrid, Package, PanelTop, Tags, Grid3x3, ImageIcon, Heading,
    },
    props: {
        section: { type: Object, required: true },
        index: { type: Number, required: true },
        languages: { type: Array, default: () => [] },
        defaultLang: { type: [Number, String], default: null },
        allProducts: { type: Array, default: () => [] },
        allCategories: { type: Array, default: () => [] },
        // Category subtree for the active category-wise tab — used by the category
        // target dropdowns (category section + product-slider by-category). Falls
        // back to the full list when not provided.
        scopedCategories: { type: Array, default: () => [] },
        allBrands: { type: Array, default: () => [] },
        allPages: { type: Array, default: () => [] },
        // While a drag is in progress the parent collapses every section so the
        // list is short and easy to reorder; the user's own open state is kept.
        forceCollapsed: { type: Boolean, default: false },
        panel: { type: Boolean, default: false },
    },
    emits: ['remove', 'save-template'],
    data() {
        return { open: true, sectionTypes: SECTION_TYPES, langTabIndex: 0 };
    },
    created() {
        // Open the default language's tab first so its fields show without a click.
        const idx = this.languages.findIndex(l => l.is_default === 1 || l.is_default === '1');
        if (idx >= 0) this.langTabIndex = idx;
    },
    computed: {
        // sectionTypes holds untranslated keys; AppSelect needs { id, name }.
        sectionTypeOptions() {
            return (this.sectionTypes || []).map(t => ({ id: t.value, name: __(t.value) }));
        },
        bodyOpen() {
            return this.panel || (this.open && !this.forceCollapsed);
        },
        typeMeta() {
            return SECTION_TYPES.find(t => t.value === this.section.type) || SECTION_TYPES[0];
        },
        typeIcon() {
            return this.typeMeta.icon;
        },
        typeLabel() {
            return __(this.section.type);
        },
        block() {
            return this.section.blocks[0];
        },
        cfg() {
            return this.block ? this.block.config : {};
        },
        // Shared with BlockEditor, which draws the fields these tabs translate.
        hasTitle() {
            return blockHasTitle(this.block);
        },
        hasSubtitle() {
            return blockHasSubtitle(this.block);
        },
        hasTranslatable() {
            return this.translationTargets.length > 0;
        },
        showLangTabs() {
            return this.hasTranslatable && this.languages.length > 1;
        },
        // With no tabs — or on the default language's tab — the block editor shows.
        onDefaultLangTab() {
            if (!this.showLangTabs) {
                return true;
            }
            const lang = this.languages[this.langTabIndex];
            return !lang || !!lang.is_default;
        },
        /**
         * Every piece of shopper-facing text this section holds, as one flat list:
         * the section title and subtitle, each tab's label, and the heading behind a
         * "product list with filters" redirect (block level and per banner).
         *
         * The language tabs, the per-language panes and the Translate button all
         * read this list, so a new translatable field is added in one place and
         * cannot end up editable in the default language only.
         */
        translationTargets() {
            const out = [];
            const push = (key, label, holder, field, type) => {
                if (!holder) return;
                out.push({
                    key,
                    label,
                    type: type || 'input',
                    map: (holder[field] && typeof holder[field] === 'object') ? holder[field] : {},
                    set: (value) => { holder[field] = value; },
                });
            };

            const cfg = this.cfg || {};
            if (this.hasTitle) push('section_title', __('section_title'), cfg, 'section_title');
            if (this.hasSubtitle) push('section_subtitle', __('subtitle'), cfg, 'section_subtitle', 'textarea');

            const block = this.block || {};
            if (block.type === 'product_tabs') {
                (block.items || []).forEach((tab, i) => {
                    push('tab_title_' + i, `${__('tab_title')} ${i + 1}`, tab, 'title');
                });
            }

            // Only a filtered-listing redirect carries a heading.
            const heading = (holder, key, label) => {
                if (!holder || holder.redirect_type !== 'products') return;
                push(key, label, holder.redirect_filters, 'title');
            };
            heading(cfg, 'listing_heading', __('listing_heading'));
            if (['banner_slider', 'grid_banner'].includes(block.type)) {
                (block.items || []).forEach((item, i) => {
                    heading(item, 'listing_heading_' + i,
                        `${__('listing_heading')} — ${__('banner')} ${i + 1}`);
                });
            }

            return out;
        },
        // `defaultLang` is this component's name for it; the mixin/control expect
        // `defaultLanguageId`.
        defaultLanguageId() {
            return this.defaultLang;
        },
        // Only the fields this block actually renders.
        translatableFields() {
            return this.translationTargets.map(t => t.key);
        },
    },
    methods: {
        // Field model here is a { langId: text } map per field, not translations[langId].
        getTranslateSource() {
            const source = {};
            this.translationTargets.forEach((t) => {
                source[t.key] = (t.map && t.map[this.defaultLang]) || '';
            });
            return source;
        },
        applyTranslated(lang, translated) {
            this.translationTargets.forEach((t) => {
                const val = translated[t.key];
                if (val == null) return;
                // Replace the map so Vue picks the change up on the child input.
                t.set({ ...(t.map || {}), [lang.id]: val });
            });
        },
        onTypeChange(e) {
            const newType = e.target.value;
            this.section.type = newType;
            // A section hosts one block of the matching type — rebuild it.
            this.section.blocks = [newBlock(newType)];
        },
    },
};
</script>

<style scoped>
.hb-section-card {
    border: 1px solid var(--app-card-border);
    border-radius: .6rem;
    background: var(--app-card-bg);
    margin-bottom: .65rem;
    box-shadow: 0 1px 2px rgba(0, 0, 0, .04);
}
.hb-section-head {
    display: flex;
    align-items: center;
    gap: .5rem;
    padding: .55rem .7rem;
}
.hb-section-card:not(.collapsed) .hb-section-head {
    border-bottom: 1px solid #f1f1f1;
}
/* The whole left region is grabbable, so dragging is easy. */
.hb-drag-handle {
    display: flex;
    align-items: center;
    gap: .5rem;
    flex: 1;
    min-width: 0;
    cursor: grab;
    user-select: none;
    padding: .15rem 0;
}
.hb-drag-handle:active {
    cursor: grabbing;
}
.hb-grip {
    display: inline-flex;
    flex-shrink: 0;
}
.hb-section-icon {
    width: 28px;
    height: 28px;
    border-radius: .4rem;
    background: rgba(var(--bs-primary-rgb), .1);
    color: var(--bs-primary);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: .8rem;
}
.hb-section-title {
    font-weight: 600;
    font-size: .88rem;
    cursor: pointer;
}
.hb-section-body {
    padding: .75rem .7rem;
}
.hb-lbl {
    font-size: .75rem;
    color: var(--app-muted);
    margin-bottom: .15rem;
    display: block;
}
.hb-info {
    display: inline-block;
    color: var(--app-muted);
    cursor: help;
    vertical-align: -2px;
}
.hb-info:hover {
    color: var(--bs-primary);
}
.hb-spacing {
    display: flex;
    flex-direction: column;
    gap: .6rem;
}
.hb-box {
    display: flex;
    flex-direction: column;
    gap: .4rem;
    border: 1px solid var(--app-card-border);
    border-radius: .4rem;
    padding: .5rem;
    background: var(--app-thead-bg);
}
.btn-xs {
    padding: .12rem .4rem;
    font-size: .72rem;
    line-height: 1.2;
}
.hb-section-card.is-panel { border: none; padding: 0; background: transparent; box-shadow: none; }
.hb-section-card.is-panel .hb-section-body { padding: 0; }
</style>
