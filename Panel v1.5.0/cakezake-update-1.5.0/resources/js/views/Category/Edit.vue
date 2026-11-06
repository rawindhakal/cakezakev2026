<template>
    <div>
        <!-- Standalone (non-modal): title + back sit OUTSIDE the card. -->
        <div v-if="!asModal" class="page-head">
            <h3 class="page-head-title">{{ modal_title }}</h3>
            <router-link to="/manage_categories"
                class="btn btn-outline-secondary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap">
                <ArrowLeft :size="16" /> {{ __('back_to_categories') }}
            </router-link>
        </div>

        <component
            :is="asModal ? modalComponent : 'div'"
            v-bind="asModal ? modalBindings : { class: 'card' }"
            v-on="asModal ? { hide: onModalHide, hidden: onModalHidden } : {}">

            <div :class="asModal ? '' : 'card-body'">

        <!-- Loading overlay while fetching translation data -->
        <div v-if="isLoadingData" class="d-flex justify-content-center align-items-center">
            <b-spinner></b-spinner>
        </div>

        <form v-else ref="my-form" @submit.prevent="saveRecord" novalidate>
            <!-- Language Tabs with lazy rendering -->
            <b-tabs v-model="activeLanguageTab" content-class="mt-3" v-if="languages.length > 0" :nav-class="languages.length <= 1 ? 'd-none' : null">
                <b-tab v-for="language in languages" :key="language.id" :title="language.name" lazy>
                    <template #title>
                        <span :class="{ 'text-primary font-weight-bold': language.is_default }">
                            {{ language.name }}
                        </span>
                    </template>

                    <div class="row">
                        <!-- Parent Category (only show in default language tab) -->
                        <div class="col-md-6">
                            <div class="form-group" v-if="language.is_default">
                                <label>{{ __("parent_category") }}</label>
                                <AppSelect class="form-control form-select" v-model="parent_id"
                                    :options="parentCategoryOptions" :placeholder="__('select_category')" />
                                <small class="text-warning d-block mt-1" v-if="move_parent_products">
                                    {{ __('parent_products_will_be_moved_here_on_save') }}
                                </small>
                            </div>
                        </div>

                        <div class="col-md-6">
                            <div class="form-group" :class="{ required: language.is_default }">
                                <label>{{ __('category_name') }}</label>
                                <i class="text-danger" v-if="language.is_default">*</i>
                                <input type="text" class="form-control"
                                    v-model="translations[language.id].name" :placeholder="__('enter_category_name')"
                                    @keyup="language.is_default ? createSlug() : null">
                            </div>
                        </div>

                        <!-- Slug (only show for default language) -->
                        <div class="col-md-6" v-if="language.is_default">
                            <div class="form-group">
                                <label>{{ __('slug') }}</label>
                                <i class="text-danger">*</i>
                                <input type="text" class="form-control" :placeholder="__('enter_slug')"
                                    v-model="slug">
                            </div>
                        </div>

                        <div class="col-md-6" v-if="language.is_default">
                            <FileUpload v-model="image" :label="__('image')" required accept="image/*"
                                :recommended-text="__('please_choose_square_image_of_larger_than_350px_350px_and_smaller_than_550px_550px')"
                                :max-size-mb="2" :preview-url="image_url" />
                        </div>

                        <div class="col-md-6" v-if="id && language.is_default">
                            <div class="form-group">
                                <label>{{ __('status') }}</label>
                                <div class="text-left mt-1">
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

                        <!-- Attributes (default language only) -->
                        <div class="col-12 form-group" v-if="language.is_default">
                            <hr>
                            <div class="d-flex justify-content-between align-items-center mb-2">
                                <h5 class="mb-0">{{ __('attributes') }}</h5>
                                <button type="button" class="btn btn-sm btn-outline-primary" @click="quickAddAttribute = true">
                                    <i class="fa fa-plus"></i> {{ __('add_attribute') }}
                                </button>
                            </div>
                            <p class="text-muted small">{{ __('attributes_help') }}</p>

                            <div v-if="inheritedAttributes.length" class="mb-3">
                                <label class="d-block">{{ __('inherited_from_parent') }}</label>
                                <div v-for="attr in inheritedAttributes" :key="'inh-' + attr.id" class="form-check form-check-inline me-3">
                                    <input class="form-check-input" type="checkbox" :id="'inh-attr-' + attr.id"
                                        :checked="!inheritedOffAttributeIds.includes(attr.id)"
                                        @change="toggleInheritedAttr(attr.id, $event.target.checked)">
                                    <label class="form-check-label" :for="'inh-attr-' + attr.id">
                                        {{ attrLabel(attr) }}
                                    </label>
                                </div>
                            </div>

                            <label class="d-block">{{ __('select_attributes') }}</label>
                            <div class="row attribute-pick-grid">
                                <div v-for="attr in selectableAttributes" :key="'sel-' + attr.id" class="col-md-4 col-sm-6 mb-1">
                                    <div class="attribute-pick-row d-flex align-items-center justify-content-between"
                                         :class="{ 'is-selected': isAttrSelected(attr.id) }"
                                         @click="toggleAttr(attr.id, !isAttrSelected(attr.id))">
                                        <div class="form-check mb-0">
                                            <input class="form-check-input" type="checkbox"
                                                :checked="isAttrSelected(attr.id)"
                                                @click.stop
                                                @change="toggleAttr(attr.id, $event.target.checked)">
                                            <label class="form-check-label" @click.prevent>
                                                {{ attrLabel(attr) }}
                                            </label>
                                        </div>
                                        <span class="badge attribute-vals-badge">{{ attrValueCount(attr) }} {{ __('vals') }}</span>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Custom Sections -->
                        <div class="col-12 form-group">
                            <hr>
                            <h5>{{ __('custom_sections') }}</h5>
                            <p class="text-muted small">{{ __('custom_sections_help') }}</p>
                            <p class="text-muted small" v-if="!language.is_default">{{ __('translate_custom_field_labels') }}</p>

                            <div v-if="language.is_default && inheritedCustomSections.length" class="mb-3">
                                <label class="d-block">{{ __('inherited_from_parent') }}</label>
                                <div v-for="s in inheritedCustomSections" :key="'inhs-' + s.id" class="form-check form-check-inline me-3">
                                    <input class="form-check-input" type="checkbox" :id="'inhs-' + s.id"
                                        :checked="!inheritedOffSectionNames.includes(s.name)"
                                        @change="toggleInheritedSection(s.name, $event.target.checked)">
                                    <label class="form-check-label" :for="'inhs-' + s.id">
                                        {{ sectionLabel(s) }}
                                    </label>
                                </div>
                            </div>

                            <draggable
                                v-model="customSections"
                                :item-key="(s) => 'sec-' + (s.id || s.tmpKey)"
                                handle=".section-drag-handle"
                                :animation="180"
                                ghost-class="dragging-ghost"
                                :disabled="!language.is_default">
                                <template #item="{ element: section, index: sIdx }">
                                    <div class="custom-section-card mb-3 p-3 border rounded">
                                        <div class="row align-items-center mb-2">
                                            <div class="col-auto" v-if="language.is_default">
                                                <span class="section-drag-handle text-muted" v-b-tooltip.hover :title="__('drag_to_reorder')">
                                                    <i class="fa fa-grip-vertical"></i>
                                                </span>
                                            </div>
                                            <div class="col">
                                                <input type="text" class="form-control"
                                                    v-model="section.names[language.id]"
                                                    :placeholder="__('section_name')">
                                            </div>
                                            <div class="col-auto" v-if="language.is_default">
                                                <button type="button" class="btn btn-outline-danger btn-sm"
                                                    @click="removeSection(sIdx)" v-b-tooltip.hover :title="__('delete')">
                                                    <i class="fa fa-times"></i>
                                                </button>
                                            </div>
                                        </div>

                                        <draggable
                                            v-model="section.fields"
                                            :item-key="(f) => 'fld-' + (f.id || f.tmpKey)"
                                            handle=".field-drag-handle"
                                            :animation="180"
                                            ghost-class="dragging-ghost"
                                            :disabled="!language.is_default">
                                            <template #item="{ element: field, index: fIdx }">
                                                <div class="row align-items-end mb-2 p-2 border rounded bg-light">
                                                    <div class="col-auto" v-if="language.is_default">
                                                        <span class="field-drag-handle text-muted" v-b-tooltip.hover :title="__('drag_to_reorder')">
                                                            <i class="fa fa-grip-vertical"></i>
                                                        </span>
                                                    </div>
                                                    <div class="col-md-5">
                                                        <label class="text-uppercase small text-muted">{{ __('field_name') }}</label>
                                                        <input type="text" class="form-control"
                                                            v-model="field.labels[language.id]"
                                                            :placeholder="__('field_name')">
                                                    </div>
                                                    <div class="col-md-3" v-if="language.is_default">
                                                        <label class="text-uppercase small text-muted">{{ __('type') }}</label>
                                                        <AppSelect class="form-control form-select" v-model="field.field_type" :options="field_typeOptions" :searchable="false" />
                                                    </div>
                                                    <div class="col-md-2" v-if="language.is_default">
                                                        <label class="text-uppercase small text-muted">{{ __('required') }}</label>
                                                        <AppSelect class="form-control form-select" v-model="field.is_required" :options="is_requiredOptions" :searchable="false" />
                                                    </div>
                                                    <div class="col-md-1" v-if="language.is_default">
                                                        <button type="button" class="btn btn-outline-danger btn-sm"
                                                            @click="removeFieldFromSection(sIdx, fIdx)" v-b-tooltip.hover :title="__('delete')">
                                                            <i class="fa fa-times"></i>
                                                        </button>
                                                    </div>

                                                    <div class="col-12 mt-2" v-if="['dropdown','checkbox'].includes(field.field_type)">
                                                        <div class="d-flex justify-content-between align-items-center mb-1">
                                                            <label class="text-uppercase small text-muted mb-0">{{ __('options') }}</label>
                                                            <button type="button" v-if="language.is_default"
                                                                class="btn btn-outline-secondary btn-sm"
                                                                @click="openAttrPicker(sIdx, fIdx)">
                                                                <i class="fa fa-list"></i> {{ __('pick_from_attributes') }}
                                                            </button>
                                                        </div>
                                                        <div v-for="(opt, oIdx) in (field.optionsByLang[language.id] || [])" :key="'opt-' + oIdx"
                                                            class="row mb-1 align-items-center">
                                                            <div class="col-md-10">
                                                                <input type="text" class="form-control" v-model="field.optionsByLang[language.id][oIdx]"
                                                                    :placeholder="__('option_label')">
                                                            </div>
                                                            <div class="col-md-2" v-if="language.is_default">
                                                                <button type="button" class="btn btn-outline-danger btn-sm"
                                                                    @click="removeOption(sIdx, fIdx, oIdx)" v-b-tooltip.hover :title="__('delete')">
                                                                    <i class="fa fa-times"></i>
                                                                </button>
                                                            </div>
                                                        </div>
                                                        <button type="button" v-if="language.is_default"
                                                            class="btn btn-outline-primary btn-sm mt-1" @click="addOption(sIdx, fIdx)">
                                                            <i class="fa fa-plus"></i> {{ __('add_option') }}
                                                        </button>
                                                    </div>
                                                </div>
                                            </template>
                                        </draggable>

                                        <button type="button" v-if="language.is_default" class="btn btn-outline-secondary btn-sm w-100 mt-2"
                                            @click="addFieldToSection(sIdx)">
                                            <i class="fa fa-plus"></i> {{ __('add_field') }}
                                        </button>
                                    </div>
                                </template>
                            </draggable>

                            <button type="button" v-if="language.is_default" class="btn btn-outline-primary btn-sm mt-2" @click="addSection">
                                <i class="fa fa-plus"></i> {{ __('add_section') }}
                            </button>
                        </div>

                        <!-- SEO section (kept last, below Custom Sections) -->
                        <SeoSection :translation="translations[language.id]" :is-default="!!language.is_default"
                            :uid="language.id"
                            :context="{ name: translations[defaultLanguageId] && translations[defaultLanguageId].name }" />
                    </div>
                </b-tab>

                <!-- Translate control, inline with the language tabs. -->
                <template #tabs-end>
                    <li class="nav-item ms-auto d-flex align-items-center">
                        <TranslateLanguages :languages="languages" :default-language-id="defaultLanguageId"
                            :busy="translating" :progress="translateProgress" @translate="runTranslate" />
                    </li>
                </template>
            </b-tabs>

            <!-- Loading state -->
            <div v-else class="text-center p-5">
                <b-spinner label="Loading languages..."></b-spinner>
                <p class="mt-2">{{ __('loading_languages') }}</p>
            </div>
            <button ref="dummy_submit" style="display:none;"></button>


        </form>

            </div>
            <div v-if="!asModal" class="card-footer text-end">
                <button type="button" class="btn btn-primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">
                    {{ __('save') }}
                    <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                </button>
            </div>
            <template v-if="asModal" #footer>
                <b-button variant="secondary" @click="closeModal" :disabled="isLoading">{{ __('cancel') }}</b-button>
                <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">
                    {{ __('save') }}
                    <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                </b-button>
            </template>
        </component>

        <!-- Selected parent still holds products: decide before continuing. -->
        <b-modal v-model="parentConfirm.show" :title="__('parent_category_has_products')" centered no-fade
            no-close-on-backdrop no-close-on-esc hide-header-close>
            <p class="mb-2">
                <strong>{{ parentConfirm.name }}</strong> {{ __('has') }}
                <strong>{{ parentConfirm.count }}</strong> {{ __('products') }}.
                {{ __('products_can_only_belong_to_child_categories') }}
            </p>
            <p class="mb-0">
                {{ __('move_these_products_into') }} <strong>{{ currentCategoryName }}</strong>?
            </p>
            <template #footer>
                <b-button variant="secondary" @click="cancelMoveProducts">{{ __('no_choose_another_parent') }}</b-button>
                <b-button variant="primary" @click="confirmMoveProducts">{{ __('yes_move_products') }}</b-button>
            </template>
        </b-modal>

        <attribute-edit
            v-if="quickAddAttribute"
            :record="quickAddAttribute === true ? null : quickAddAttribute"
            @modalClose="quickAddAttribute = false"
            @saved="onAttributeQuickAdded"
        ></attribute-edit>

        <b-modal v-model="attrPickerOpen" :title="__('pick_from_attributes')" hide-footer centered scrollable size="md" no-fade>
            <div class="mb-3">
                <input type="text" class="form-control" v-model="attrPickerSearch" :placeholder="__('search_by_label_code_or_type')">
            </div>
            <div class="attr-picker-list">
                <div v-for="attr in filteredAttrPicker" :key="'pick-' + attr.id"
                     class="attribute-pick-row d-flex align-items-center justify-content-between"
                     @click="pickAttribute(attr)">
                    <span>{{ attrLabel(attr) }}</span>
                    <span class="badge attribute-vals-badge">{{ attrValueCount(attr) }} {{ __('values') }}</span>
                </div>
                <div v-if="!filteredAttrPicker.length" class="text-muted text-center py-3 small">
                    {{ __('no_attributes_found') }}
                </div>
            </div>
            <div class="text-muted small mt-3 pt-2 border-top">
                {{ __('click_attribute_to_fill_options') }}
            </div>
        </b-modal>
    </div>
</template>

<script>
import axios from 'axios';
import draggable from 'vuedraggable';
import { BModal } from 'bootstrap-vue-next';
import TranslationHelper from '../../mixins/TranslationHelper.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';
import AttributeEdit from './Attributes/Edit.vue';
import { ArrowLeft } from 'lucide-vue-next';


export default {
    components: { 'attribute-edit': AttributeEdit, draggable, BModal, ArrowLeft },
    props: {
        asModal: { type: Boolean, default: false },
        prefilledParentId: { type: [Number, String], default: 0 },
    },
    emits: ['modalClose', 'saved'],
    data: function () {
        const routeId = !this.asModal && this.$route && this.$route.params && this.$route.params.id ? Number(this.$route.params.id) : null;
        return {
            isLoading: false,
            isLoadingData: true, // Start with loading state
            image: null,
            modalVisible: true,

            // Basic fields
            id: routeId,
            slug: null,
            image_url: null,
            status: 1,
            parent_id: Number(this.prefilledParentId) || 0,

            // Flat active-category list (id, name, parent_id, translations) for the tree picker.
            parentCategories: [],

            // Multi-language support
            activeLanguageTab: 0,
            translations: {},
            defaultLanguageId: null,
            languages: [],

            translatableFields: ['name', 'meta_title', 'meta_keywords', 'schema_markup', 'meta_description'],

            // Attributes & Custom Sections
            availableAttributes: [],
            inheritedAttributes: [],
            inheritedCustomSections: [],
            selectedAttributes: [], // [{ attribute_id }]
            inheritedOffAttributeIds: [],
            inheritedOffSectionNames: [],
            // [{ id?, names: {langId:''}, fields: [{ id?, field_type, labels:{langId:''}, optionsByLang:{langId:[...]}, is_required, sort_order }], sort_order }]
            customSections: [],
            quickAddAttribute: false,
            attrPickerOpen: false,
            attrPickerTarget: null,
            attrPickerSearch: '',
            parentInitialized: false,
            // Parent-with-products confirmation.
            move_parent_products: false,
            parentConfirm: { show: false, name: '', count: 0, prevParentId: 0 },
        };
    },
    mixins: [TranslationHelper, UnsavedChanges],

    created() {


        this.$apiUrl = '/api';
    },

    computed: {
        // Parent-category picker: flat list rendered as an indented tree. Every node is
        // selectable (a category may be parented under any other), only visually nested.
        parentCategoryOptions() {
            const list = (this.parentCategories || []).map(c => {
                const t = Array.isArray(c.translations)
                    ? c.translations.find(x => Number(x.language_id) === Number(this.defaultLanguageId))
                    : null;
                return {
                    id: Number(c.id),
                    parent_id: Number(c.parent_id || 0),
                    name: (t && t.name && t.name.trim()) ? t.name : c.name,
                };
            });
            const idSet = new Set(list.map(c => c.id));
            const byParent = {};
            list.forEach(c => {
                const pid = idSet.has(c.parent_id) ? c.parent_id : 0; // orphan -> root
                (byParent[pid] = byParent[pid] || []).push(c);
            });
            const INDENT = '\u00A0\u00A0\u00A0\u00A0'; // nbsp — plain spaces collapse in the dropdown
            const out = [{ id: 0, name: __('select_category') }];
            const walk = (parentId, depth) => {
                (byParent[parentId] || []).forEach(c => {
                    out.push({ id: c.id, name: (depth ? INDENT.repeat(depth) + '↳ ' : '') + c.name });
                    walk(c.id, depth + 1);
                });
            };
            walk(0, 0);
            return out;
        },
        // Fixed option set — no search box needed.
        field_typeOptions() {
            return [
                { id: 'text', name: (__('text')) },
                { id: 'number', name: (__('number')) },
                { id: 'textarea', name: (__('textarea')) },
                { id: 'dropdown', name: (__('dropdown')) },
                { id: 'checkbox', name: (__('checkbox')) },
                { id: 'boolean', name: (__('boolean')) },
                { id: 'date', name: (__('date')) },
            ];
        },
        // Fixed option set — no search box needed.
        is_requiredOptions() {
            return [
                { id: 0, name: (__('not_required')) },
                { id: 1, name: (__('required')) },
            ];
        },
        currentCategoryName() {
            const t = this.defaultLanguageId ? this.translations[this.defaultLanguageId] : null;
            const n = t && t.name ? String(t.name).trim() : '';
            return n !== '' ? n : __('this_category');
        },
        modal_title: function () {
            let title = this.id ? __('edit_category') : __('add_category');
            return title;
        },
        modalComponent() { return BModal; },
        modalBindings() {
            return {
                modelValue: this.modalVisible,
                'onUpdate:modelValue': v => { this.modalVisible = v; },
                title: this.modal_title,
                size: 'xl',
                scrollable: true,
                centered: true,
                noCloseOnBackdrop: true,
            };
        },
        filteredAttrPicker() {
            const q = (this.attrPickerSearch || '').toLowerCase().trim();
            if (!q) return this.availableAttributes;
            return this.availableAttributes.filter(a => {
                const label = (this.attrLabel(a) || '').toLowerCase();
                const slug = (a.slug || '').toLowerCase();
                return label.includes(q) || slug.includes(q);
            });
        },
        selectableAttributes() {
            const inheritedIds = (this.inheritedAttributes || []).map(a => a.id);
            return (this.availableAttributes || []).filter(a => !inheritedIds.includes(a.id));
        },
    },

    watch: {
        parent_id(newVal, oldVal) {
            // A parent holding products needs the admin's decision: move its products
            // into this category, or pick another parent (products live on leaves only).
            this.checkParentProducts(newVal, oldVal);

            if (!this.languages.length) return;
            if (!this.id) {
                this.loadSchema();
                return;
            }
            // Edit: don't reload on initial set from server. Refresh inherited only on user change.
            if (this.parentInitialized) {
                this.loadInheritedFromParent();
            } else if (oldVal !== undefined) {
                this.parentInitialized = true;
            }
        },
    },

    methods: {
        // Tracked state for the UnsavedChanges guard (warn before leaving with edits).
        formState() {
            return {
                translations: this.translations,
                slug: this.slug,
                status: this.status,
                parent_id: this.parent_id,
                image: this.image,
                selectedAttributes: this.selectedAttributes,
                inheritedOffAttributeIds: this.inheritedOffAttributeIds,
                inheritedOffSectionNames: this.inheritedOffSectionNames,
                customSections: this.customSections,
            };
        },
        closeModal() { this.modalVisible = false; },

        // Intercept Cancel / X / esc modal close (asModal mode) so unsaved edits also
        // prompt. The re-close after "leave" bypasses via _ucAllowClose.
        onModalHide(bvEvt) {
            if (this._ucAllowClose) { this._ucAllowClose = false; return; }
            if (!this.isFormDirty) return;
            if (bvEvt && typeof bvEvt.preventDefault === 'function') bvEvt.preventDefault();
            this._ucConfirmLeave().then(ok => {
                if (ok) { this._ucAllowClose = true; this.modalVisible = false; }
            });
        },

        checkParentProducts(newVal, oldVal) {
            this.move_parent_products = false;
            const pid = Number(newVal) || 0;
            if (pid <= 0 || this.parentConfirm.show) return;
            // Skip the initial programmatic set while editing (server value).
            if (this.id && !this.parentInitialized) return;
            axios.get(this.$apiUrl + '/categories/parent_check', { params: { id: pid } })
                .then(r => {
                    const d = r.data.data || {};
                    if ((d.product_count || 0) > 0) {
                        this.parentConfirm = {
                            show: true,
                            name: d.name || '',
                            count: d.product_count,
                            prevParentId: Number(oldVal) || 0,
                        };
                    }
                })
                .catch(() => {});
        },
        confirmMoveProducts() {
            // Products of the selected parent will be moved into THIS category on save.
            this.move_parent_products = true;
            this.parentConfirm.show = false;
        },
        cancelMoveProducts() {
            // Revert the selection: the parent keeps its products; the admin must
            // move/remove them first to use it as a parent.
            this.move_parent_products = false;
            const prev = this.parentConfirm.prevParentId;
            this.parentConfirm.show = false;
            this.parent_id = prev;
            this.showMessage('info', __('remove_products_from_category_first_to_use_as_parent'));
        },
        onModalHidden() { this.$emit('modalClose'); },

        // Used by TranslationHelper mixin (Translate buttons). Validates default language is filled.
        validateDefaultLanguageForTranslation() {
            return this.validateDefaultLanguage();
        },

        deferDataLoad() {
            this.isLoadingData = true;

            // Load languages and parent categories in parallel
            Promise.all([
                this.fetchActiveLanguages(),
                this.getParentCategories(),
                this.fetchAvailableAttributes()
            ])
                .then(() => {
                    // Find default language
                    const defaultLang = this.languages.find(lang => lang.is_default === 1);
                    if (defaultLang) {
                        this.defaultLanguageId = defaultLang.id;
                    }

                    // Initialize translations efficiently (single operation)
                    this.initializeTranslations();

                    // Load translations only if editing
                    if (this.id) {
                        return this.loadCategoryWithTranslations()
                            .then(() => this.loadSchema())
                            .then(() => { this.parentInitialized = true; });
                    } else {
                        // For new category, no translations to load
                        return this.loadSchema().finally(() => { this.isLoadingData = false; });
                    }
                })
                .then(() => {
                    this.isLoadingData = false;
                    // Data loaded — snapshot the clean baseline for the unsaved-changes guard.
                    this.captureFormBaseline();
                })
                .catch(error => {
                    console.error('Error loading data:', error);
                    this.isLoadingData = false;
                });
        },

        fetchAvailableAttributes() {
            return axios.get(this.$apiUrl + '/attributes/dropdown').then(res => {
                this.availableAttributes = res.data.data || [];
            }).catch(() => {});
        },

        loadSchema() {
            if (!this.id && !this.parent_id) {
                this.inheritedAttributes = [];
                this.inheritedCustomSections = [];
                this.selectedAttributes = [];
                this.inheritedOffAttributeIds = [];
                this.customSections = [];
                this.inheritedOffSectionNames = [];
                return Promise.resolve();
            }

            const ownPromise = this.id
                ? axios.get(this.$apiUrl + '/categories/schema', { params: { id: this.id } })
                : Promise.resolve(null);
            const parentPromise = this.parent_id
                ? axios.get(this.$apiUrl + '/categories/schema', { params: { parent_id: this.parent_id } })
                : Promise.resolve(null);

            return Promise.all([ownPromise, parentPromise]).then(([selfRes, parentRes]) => {
                if (selfRes) {
                    const data = selfRes.data.data || {};
                    const own = data.own || {};
                    const allSections = data.custom_sections || [];
                    const ownAttrIds = own.attribute_ids || [];
                    const offAttrIds = own.overridden_off_attribute_ids || [];

                    this.inheritedOffAttributeIds = offAttrIds;
                    this.selectedAttributes = ownAttrIds
                        .filter(aId => !offAttrIds.includes(aId))
                        .map(aId => ({ attribute_id: aId }));

                    this.inheritedOffSectionNames = own.overridden_off_section_names || [];
                    const ownSectionIds = own.custom_section_ids || [];
                    this.customSections = allSections
                        .filter(s => ownSectionIds.includes(s.id) && !s.is_overridden_off)
                        .map(s => this.hydrateSection(s));
                } else {
                    this.selectedAttributes = [];
                    this.inheritedOffAttributeIds = [];
                    this.customSections = [];
                    this.inheritedOffSectionNames = [];
                }

                if (parentRes) {
                    const pdata = parentRes.data.data || {};
                    const parentAttrs = pdata.attributes || [];
                    const parentSections = pdata.custom_sections || [];
                    const ownAttrIdsSet = new Set(this.selectedAttributes.map(a => a.attribute_id));
                    const ownSectionIdsSet = new Set(this.customSections.map(s => s.id).filter(Boolean));
                    this.inheritedAttributes = parentAttrs.filter(a => !ownAttrIdsSet.has(a.id));
                    this.inheritedCustomSections = parentSections.filter(s => !ownSectionIdsSet.has(s.id));
                } else {
                    this.inheritedAttributes = [];
                    this.inheritedCustomSections = [];
                }
            }).catch(() => {});
        },

        loadInheritedFromParent() {
            const params = {};
            if (this.parent_id) params.parent_id = this.parent_id;
            else {
                this.inheritedAttributes = [];
                this.inheritedCustomSections = [];
                this.inheritedOffAttributeIds = [];
                this.inheritedOffSectionNames = [];
                return Promise.resolve();
            }
            return axios.get(this.$apiUrl + '/categories/schema', { params }).then(res => {
                const data = res.data.data || {};
                const allAttrs = data.attributes || [];
                const allSections = data.custom_sections || [];
                const ownAttrIds = this.selectedAttributes.map(a => a.attribute_id);
                const ownSectionIds = (this.customSections || []).map(s => s.id).filter(Boolean);
                this.inheritedAttributes = allAttrs.filter(a => !ownAttrIds.includes(a.id));
                this.inheritedCustomSections = allSections.filter(s => !ownSectionIds.includes(s.id));
                this.inheritedOffAttributeIds = [];
                this.inheritedOffSectionNames = [];
            }).catch(() => {});
        },

        hydrateSection(s) {
            const names = {};
            this.languages.forEach(l => { names[l.id] = ''; });
            if (this.defaultLanguageId) names[this.defaultLanguageId] = s.name || '';
            if (Array.isArray(s.translations)) {
                s.translations.forEach(t => { if (t.name) names[t.language_id] = t.name; });
            }
            const fields = Array.isArray(s.fields) ? s.fields.map(f => this.hydrateField(f)) : [];
            return {
                id: s.id,
                tmpKey: s.id ? null : this.nextTmpKey(),
                names,
                sort_order: s.sort_order || 0,
                fields,
            };
        },

        hydrateField(f) {
            const labels = {};
            const optionsByLang = {};
            this.languages.forEach(l => {
                labels[l.id] = '';
                optionsByLang[l.id] = Array.isArray(f.options) ? [...f.options] : [];
            });
            if (this.defaultLanguageId) labels[this.defaultLanguageId] = f.field_label || '';
            if (Array.isArray(f.translations)) {
                f.translations.forEach(t => {
                    if (t.field_label) labels[t.language_id] = t.field_label;
                    if (Array.isArray(t.options)) optionsByLang[t.language_id] = [...t.options];
                });
            }
            return {
                id: f.id,
                tmpKey: f.id ? null : this.nextTmpKey(),
                field_type: f.field_type,
                is_required: f.is_required ? 1 : 0,
                sort_order: f.sort_order || 0,
                labels,
                optionsByLang,
            };
        },

        attrLabel(attr) {
            const t = Array.isArray(attr.translations)
                ? attr.translations.find(x => Number(x.language_id) === Number(this.defaultLanguageId))
                : null;
            return (t && t.name && t.name.trim()) ? t.name : (attr.name || '');
        },

        attrValueCount(attr) {
            if (Array.isArray(attr.values)) return attr.values.length;
            if (Array.isArray(attr.active_values)) return attr.active_values.length;
            return 0;
        },

        openAttrPicker(sIdx, fIdx) {
            this.attrPickerTarget = { sIdx, fIdx };
            this.attrPickerSearch = '';
            this.attrPickerOpen = true;
        },

        pickAttribute(attr) {
            if (!this.attrPickerTarget) return;
            const { sIdx, fIdx } = this.attrPickerTarget;
            const field = this.customSections[sIdx]?.fields?.[fIdx];
            if (!field) { this.attrPickerOpen = false; return; }

            const values = Array.isArray(attr.values)
                ? attr.values
                : (Array.isArray(attr.active_values) ? attr.active_values : []);

            this.languages.forEach(lang => {
                const opts = values.map(v => {
                    const t = Array.isArray(v.translations)
                        ? v.translations.find(x => Number(x.language_id) === Number(lang.id))
                        : null;
                    return (t && t.value && t.value.trim()) ? t.value : (v.value || '');
                });
                field.optionsByLang[lang.id] = opts;
            });

            this.attrPickerOpen = false;
            this.attrPickerTarget = null;
        },

        sectionLabel(s) {
            const t = Array.isArray(s.translations)
                ? s.translations.find(x => Number(x.language_id) === Number(this.defaultLanguageId))
                : null;
            return (t && t.name && t.name.trim()) ? t.name : (s.name || '');
        },

        isAttrSelected(id) { return this.selectedAttributes.some(a => a.attribute_id === id); },
        toggleAttr(id, on) {
            if (on) {
                if (!this.isAttrSelected(id)) {
                    this.selectedAttributes.push({ attribute_id: id });
                }
            } else {
                this.selectedAttributes = this.selectedAttributes.filter(a => a.attribute_id !== id);
            }
        },
        toggleInheritedAttr(id, on) {
            if (on) {
                this.inheritedOffAttributeIds = this.inheritedOffAttributeIds.filter(x => x !== id);
            } else if (!this.inheritedOffAttributeIds.includes(id)) {
                this.inheritedOffAttributeIds.push(id);
            }
        },
        toggleInheritedSection(name, on) {
            if (on) {
                this.inheritedOffSectionNames = this.inheritedOffSectionNames.filter(x => x !== name);
            } else if (!this.inheritedOffSectionNames.includes(name)) {
                this.inheritedOffSectionNames.push(name);
            }
        },

        // Section + field manipulators
        addSection() {
            const names = {};
            this.languages.forEach(l => { names[l.id] = ''; });
            this.customSections.push({
                id: null,
                tmpKey: this.nextTmpKey(),
                names,
                sort_order: this.customSections.length,
                fields: [this.makeBlankField()],
            });
        },
        removeSection(sIdx) { this.customSections.splice(sIdx, 1); },
        nextTmpKey() {
            this._tmpCounter = (this._tmpCounter || 0) + 1;
            return 't_' + Date.now() + '_' + this._tmpCounter;
        },
        makeBlankField() {
            const labels = {};
            const optionsByLang = {};
            this.languages.forEach(l => { labels[l.id] = ''; optionsByLang[l.id] = []; });
            return {
                id: null,
                tmpKey: this.nextTmpKey(),
                field_type: 'text',
                is_required: 0,
                sort_order: 0,
                labels,
                optionsByLang,
            };
        },
        addFieldToSection(sIdx) {
            const f = this.makeBlankField();
            f.sort_order = this.customSections[sIdx].fields.length;
            this.customSections[sIdx].fields.push(f);
        },
        removeFieldFromSection(sIdx, fIdx) {
            this.customSections[sIdx].fields.splice(fIdx, 1);
        },
        addOption(sIdx, fIdx) {
            this.languages.forEach(l => {
                const f = this.customSections[sIdx].fields[fIdx];
                if (!f.optionsByLang[l.id]) f.optionsByLang[l.id] = [];
                f.optionsByLang[l.id].push('');
            });
        },
        removeOption(sIdx, fIdx, oIdx) {
            this.languages.forEach(l => {
                const arr = this.customSections[sIdx].fields[fIdx].optionsByLang[l.id];
                if (arr) arr.splice(oIdx, 1);
            });
        },
        onAttributeQuickAdded(message) {
            this.showMessage('success', message);
            const prevIds = this.availableAttributes.map(a => a.id);
            this.fetchAvailableAttributes().then(() => {
                const fresh = this.availableAttributes.find(a => !prevIds.includes(a.id));
                if (fresh) this.toggleAttr(fresh.id, true);
                this.quickAddAttribute = false;
            });
        },

        fetchActiveLanguages() {
            return new Promise((resolve, reject) => {
                // Fetch from API directly - no caching
                axios.get(this.$apiUrl + '/active_languages')
                    .then(response => {
                        if (response.data.data) {
                            this.languages = response.data.data;
                            resolve(this.languages);
                        } else {
                            reject(new Error('No languages found'));
                        }
                    })
                    .catch(error => {
                        reject(error);
                    });
            });
        },

        initializeTranslations() {
            // Create all translations in one object assignment
            const allTranslations = {};
            this.languages.forEach(language => {
                allTranslations[language.id] = {
                    name: '',
                    meta_title: '',
                    meta_keywords: '',
                    schema_markup: '',
                    meta_description: '',
                };
            });
            // Single reactive assignment
            this.translations = allTranslations;
        },

        loadCategoryWithTranslations() {
            return axios.get(this.$apiUrl + '/categories', {
                params: {
                    id: this.id
                }
            })
                .then(response => {
                    if (response.data.data) {
                        // Response is now an array of categories, get the first one (filtered by id)
                        const categories = Array.isArray(response.data.data) ? response.data.data : [response.data.data];
                        const category = categories.length > 0 ? categories[0] : null;

                        if (!category) {
                            this.isLoadingData = false;
                            return;
                        }

                        // Load base data
                        this.slug = category.slug;
                        this.parent_id = category.parent_id;
                        this.image_url = category.image_url;
                        this.status = category.status;

                        // Load translations from the category object
                        const updatedTranslations = { ...this.translations };

                        if (category.translations && Array.isArray(category.translations)) {
                            category.translations.forEach(trans => {
                                const langId = trans.language_id;
                                updatedTranslations[langId] = {
                                    name: trans.name || '',
                                    meta_title: trans.meta_title || '',
                                    meta_keywords: trans.meta_keywords || '',
                                    schema_markup: trans.schema_markup || '',
                                    meta_description: trans.meta_description || '',
                                };
                            });
                        }

                        this.languages.forEach(language => {
                            if (!updatedTranslations[language.id] || !updatedTranslations[language.id].name) {
                                if (language.is_default) {
                                    updatedTranslations[language.id] = {
                                        name: category.name || '',
                                        meta_title: category.meta_title || '',
                                        meta_keywords: category.meta_keywords || '',
                                        schema_markup: category.schema_markup || '',
                                        meta_description: category.meta_description || '',
                                    };
                                }
                            }
                        });

                        // Single assignment for reactivity
                        this.translations = updatedTranslations;
                    }
                    this.isLoadingData = false;
                })
                .catch(error => {
                    this.isLoadingData = false;
                    throw error;
                });
        },

        createSlug() {
            if (!this.defaultLanguageId) return;

            const name = this.translations[this.defaultLanguageId].name;
            if (name !== "") {
                let slug = name.toLowerCase()
                    .replace(/[^\w ]+/g, '')
                    .replace(/ +/g, '-');

                // Check for uniqueness
                axios.get(this.$apiUrl + `/categories/check-slug/${slug}`)
                    .then(response => {
                        if (response.data.unique) {
                            this.slug = slug;
                        } else {
                            this.slug = slug + '-' + response.data.count;
                        }
                    })
                    .catch(error => {
                        console.error('Error checking slug uniqueness: ' + error);
                    });
            }
        },

        getParentCategories() {
            return axios.get(this.$apiUrl + '/categories/options_data', {
                params: {
                    exclude_id: this.id || 0
                }
            })
                .then((response) => {
                    this.parentCategories = response.data.data || [];
                });
        },

        validateDefaultLanguage() {
            if (!this.defaultLanguageId) {
                this.showError(__('default_language_not_found'));
                return false;
            }

            const defaultTranslation = this.translations[this.defaultLanguageId];

            // Check required fields for default language - show generic message for any missing field
            if (!defaultTranslation.name || defaultTranslation.name.trim() === '') {
                this.switchToDefaultLanguageTab();
                this.showError(__('please_fill_default_language_required_fields'));
                return false;
            }


            if (!this.slug || this.slug.trim() === '') {
                this.switchToDefaultLanguageTab();
                this.showError(__('please_fill_default_language_required_fields'));
                return false;
            }

            if (!this.id && !this.image && !this.image_url) {
                this.switchToDefaultLanguageTab();
                this.showError(__('please_fill_default_language_required_fields'));
                return false;
            }

            const activeInheritedCount = (this.inheritedAttributes || [])
                .filter(a => !this.inheritedOffAttributeIds.includes(a.id)).length;
            const totalAttrs = (this.selectedAttributes || []).length + activeInheritedCount;
            if (totalAttrs === 0) {
                this.switchToDefaultLanguageTab();
                this.showError(__('at_least_one_attribute_required'));
                return false;
            }

            return true;
        },



        // Switches to default language tab so user sees the required fields. Caller shows the specific error.
        switchToDefaultLanguageTab() {
            const defaultLangIndex = this.languages.findIndex(lang => lang.id === this.defaultLanguageId);
            if (defaultLangIndex !== -1) {
                this.activeLanguageTab = defaultLangIndex;
            }
        },

        saveRecord: function () {
            if (!this.validateDefaultLanguage()) return;

            let vm = this;

            this.isLoading = true;

            const languagesToSave = [];
            const defaultLang = this.languages.find(lang => lang.is_default);

            // Add default language first
            if (defaultLang) {
                languagesToSave.push(defaultLang);
            }

            // Add other languages that have data
            this.languages.forEach(language => {
                if (language.is_default) return; // Skip default, already added

                const translation = this.translations[language.id];
                const hasData = this.translatableFields.some(field => {
                    const val = translation[field];
                    return val != null && String(val).trim() !== '';
                });

                if (hasData || this.id) {
                    languagesToSave.push(language);
                }
            });

            // Save sequentially: default language first, then others
            const saveSequentially = async () => {
                let categoryId = this.id; // For edit mode
                let apiMessage = '';

                for (let i = 0; i < languagesToSave.length; i++) {
                    const language = languagesToSave[i];
                    const translation = this.translations[language.id];

                    let formData = new FormData();

                    // Basic fields
                    if (categoryId) {
                        formData.append('id', categoryId);
                    }
                    formData.append('language_id', language.id);
                    formData.append('slug', this.slug);
                    formData.append('status', this.status);
                    formData.append('parent_id', this.parent_id);
                    formData.append('move_parent_products', this.move_parent_products ? 1 : 0);

                    // Translatable fields
                    formData.append('name', translation.name || '');
                    formData.append('meta_title', translation.meta_title || '');
                    formData.append('meta_keywords', translation.meta_keywords || '');
                    formData.append('schema_markup', translation.schema_markup || '');
                    formData.append('meta_description', translation.meta_description || '');

                    // Image (only send with default language)
                    if (language.is_default && this.image) {
                        formData.append('image', this.image);
                    }

                    // Attributes only on default language
                    if (language.is_default) {
                        formData.append('attributes', JSON.stringify(this.selectedAttributes));
                        formData.append('inherited_off_attribute_ids', JSON.stringify(this.inheritedOffAttributeIds));
                        formData.append('inherited_off_section_names', JSON.stringify(this.inheritedOffSectionNames));
                    }

                    // Custom sections payload (per-language labels/options)
                    const customSectionsPayload = this.customSections.map((s, sIdx) => ({
                        id: s.id || undefined,
                        name: s.names[language.id] || s.names[this.defaultLanguageId] || '',
                        sort_order: sIdx,
                        fields: (s.fields || []).map((f, fIdx) => ({
                            id: f.id || undefined,
                            field_label: f.labels[language.id] || '',
                            field_type: f.field_type,
                            options: (['dropdown','checkbox'].includes(f.field_type)) ? (f.optionsByLang[language.id] || []) : null,
                            is_required: f.is_required ? 1 : 0,
                            sort_order: fIdx,
                        })),
                    }));
                    formData.append('custom_sections', JSON.stringify(customSectionsPayload));

                    let url = this.$apiUrl + '/categories/save';
                    if (categoryId) {
                        url = this.$apiUrl + '/categories/update';
                    }

                    try {
                        const response = await axios.post(url, formData, {
                            headers: {
                                'Content-Type': 'multipart/form-data'
                            }
                        });

                        // If this was the first save (default language), get the category ID
                        if (!categoryId && response.data.data && response.data.data.id) {
                            categoryId = response.data.data.id;
                        }
                        if (response.data && response.data.message) {
                            apiMessage = response.data.message;
                        }
                    } catch (error) {
                        console.error('Save failed:', error);
                        throw error;
                    }
                }

                return { categoryId, apiMessage };
            };

            // Execute sequential save
            saveSequentially()
                .then(({ categoryId, apiMessage }) => {
                    const message = apiMessage || __('category_saved_successfully');
                    // Mark clean so the post-save redirect/close doesn't trip the unsaved-changes guard.
                    vm.captureFormBaseline();
                    vm.showMessage('success', message);
                    if (vm.$eventBus) vm.$eventBus.emit('categorySaved');
                    if (vm.asModal) {
                        vm.isLoading = false;
                        vm.$emit('saved', { id: categoryId, parent_id: vm.parent_id });
                        vm.closeModal();
                    } else {
                        vm.$router.push({ path: '/manage_categories' });
                    }
                })
                .catch(error => {
                    vm.isLoading = false;
                    if (error.response && error.response.data && error.response.data.message) {
                        vm.showError(error.response.data.message);
                    } else if (error.request && error.request.statusText) {
                        vm.showError(error.request.statusText);
                    } else if (error.message) {
                        vm.showError(error.message);
                    } else {
                        vm.showError(__('something_went_wrong'));
                    }
                });
        },
    },
    mounted() {
        this.$nextTick(() => {
            this.deferDataLoad();
        });
    },
}
</script>

<style scoped>
.image_preview {
    margin-top: 5px;
}
.section-drag-handle,
.field-drag-handle {
    cursor: grab;
    user-select: none;
    padding: 4px 6px;
    font-size: 1rem;
}
.section-drag-handle:active,
.field-drag-handle:active {
    cursor: grabbing;
}
.dragging-ghost {
    opacity: 0.4;
    background: var(--app-thead-bg);
}
.attribute-pick-row {
    padding: 0.5rem 0.75rem;
    border: 1px solid var(--app-control-border);
    border-radius: 0.4rem;
    background: var(--app-card-bg);
    cursor: pointer;
    /* Matches the product attribute chips: a bordered control, with the primary
       tint reserved for hover/selected rather than being the only affordance. */
    transition: background-color .15s ease, border-color .15s ease, color .15s ease;
    user-select: none;
}
.attribute-pick-row:hover {
    border-color: var(--bs-primary);
}
.attribute-pick-row.is-selected {
    background: rgba(var(--bs-primary-rgb), 0.10);
    border-color: var(--bs-primary);
    color: var(--bs-primary);
}
.attribute-pick-row .form-check-label {
    cursor: pointer;
    margin-left: 0.25rem;
}
.attribute-vals-badge {
    background: rgba(var(--bs-primary-rgb), 0.15);
    color: var(--bs-primary);
    font-weight: 500;
    font-size: 0.75rem;
    padding: 0.35rem 0.6rem;
    border-radius: 0.35rem;
    white-space: nowrap;
}
.attribute-pick-row:hover .attribute-vals-badge,
.attribute-pick-row.is-selected .attribute-vals-badge {
    background: rgba(var(--bs-primary-rgb), 0.15);
}
.attr-picker-list {
    max-height: 50vh;
    overflow-y: auto;
}
.attr-picker-list .attribute-pick-row {
    padding: 0.65rem 0.75rem;
}
</style>