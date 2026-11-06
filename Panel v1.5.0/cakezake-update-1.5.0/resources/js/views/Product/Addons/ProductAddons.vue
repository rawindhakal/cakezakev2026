<template>
    <div class="list-page">
        <div class="page-head" v-if="!embedded">
            <div>
                <h3 class="page-head-title mb-0">{{ __('addon_setup') }}</h3>
                <small class="text-muted">{{ productName }}</small>
            </div>
            <div class="d-flex gap-2">
                <button class="btn btn-outline-secondary d-inline-flex align-items-center gap-2" @click="back">
                    <ArrowLeft :size="15" /> {{ __('back') }}
                </button>
                <button class="btn btn-primary d-inline-flex align-items-center gap-2" :disabled="isSaving" @click="save">
                    <Save :size="15" /> {{ __('save') }}
                    <b-spinner v-if="isSaving" small></b-spinner>
                </button>
            </div>
        </div>

        <p class="text-muted small mb-2">{{ __('addon_setup_hint') }}</p>
        <p class="text-muted small mb-3">{{ __('addon_option_type_hint') }}</p>

        <!-- The product endpoint is heavy; without this the page would flash
             "not a food item" before the answer arrives. -->
        <div v-if="!isLoaded" class="list-surface p-4">
            <div class="skel mb-2" style="height:38px;border-radius:.5rem"></div>
            <div class="skel mb-2" style="height:120px;border-radius:.5rem"></div>
            <div class="skel" style="height:120px;border-radius:.5rem"></div>
        </div>

        <!-- Toggling "Food item" in the form does not reach the database until the
             product is saved, and addons hang off the saved product. Say which of the two
             situations this is, instead of claiming the product is not food. -->
        <div v-else-if="!isFood && isFoodProp === 1" class="alert alert-warning d-flex gap-2 py-2 px-3 small">
            <TriangleAlert :size="18" class="flex-shrink-0" style="margin-top:1px" />
            <div>{{ __('save_the_product_before_adding_addons') }}</div>
        </div>

        <div v-else-if="!isFood" class="alert alert-warning d-flex gap-2 py-2 px-3 small">
            <TriangleAlert :size="18" class="flex-shrink-0" style="margin-top:1px" />
            <div>{{ __('addons_only_for_food_products') }}</div>
        </div>

        <template v-else-if="isFood">

            <!-- Which branch's prices the rows below are showing. Money is per branch
                 because each country charges in its own currency. -->
            <div class="list-surface p-3 mb-3">
                <div class="d-flex flex-wrap align-items-center gap-2">
                    <span class="small text-muted">{{ __('pricing_for_branch') }}</span>
                    <button v-for="st in branches" :key="'sp-' + st.id" type="button" class="btn btn-sm"
                        :class="st.id === activeBranchId ? 'btn-primary' : 'btn-outline-secondary'"
                        @click="activeBranchId = st.id">{{ st.name }}</button>

                    <span class="vr mx-2 d-none d-md-inline"></span>

                    <button type="button" class="btn btn-sm btn-outline-primary" @click="copyOpen = true">
                        <Copy :size="14" /> {{ __('copy_addons_from_product') }}
                    </button>
                    <button type="button" class="btn btn-sm btn-outline-primary" :disabled="!groups.length"
                        @click="applyOpen = true">
                        <Share2 :size="14" /> {{ __('apply_addons_to_products') }}
                    </button>

                </div>
            </div>

            <!-- Names are per language; prices and rules are not, so the other tabs show
                 only the fields a translator actually fills in. -->
            <ul class="nav nav-tabs mb-3 align-items-center" v-if="languages.length > 1 && groups.length">
                <li class="nav-item" v-for="l in languages" :key="'lang-' + l.id">
                    <a class="nav-link" href="#" :class="{ active: Number(l.id) === Number(activeLanguageId) }"
                        @click.prevent="activeLanguageId = l.id">{{ l.name }}</a>
                </li>
                <li class="nav-item ms-auto d-flex align-items-center">
                    <TranslateLanguages :languages="languages" :default-language-id="defaultLanguageId"
                        :busy="translating" :progress="translateProgress" @translate="runTranslate" />
                </li>
            </ul>
            <p v-if="!isDefaultLanguage" class="text-muted small">{{ __('add_or_translate_values') }}</p>

            <div v-for="(g, gi) in groups" :key="g.key" class="list-surface p-3 mb-3">
                <div class="d-flex flex-wrap align-items-end gap-2 mb-3">
                    <div class="form-group mb-0" style="min-width:16rem;flex:1">
                        <label class="small text-muted d-flex align-items-baseline gap-2">
                            <span class="flex-shrink-0">{{ __('name') }} <i class="text-danger">*</i></span>
                            <!-- Written by the rules below, not by hand, so it can never
                                 contradict them. Refreshes when the group is saved. It rides
                                 on the label rather than under the field: below the input it
                                 pushed this group's rows out of line with every other group. -->
                            <span v-if="g.selection_text && isDefaultLanguage" class="addon-rule-hint text-truncate"
                                :title="__('customers_will_see') + ': ' + g.selection_text">
                                {{ __('customers_will_see') }}: {{ g.selection_text }}
                            </span>
                        </label>
                        <input type="text" class="form-control form-control-sm" v-model="g.i18n[activeLanguageId].name">
                    </div>

                    <template v-if="isDefaultLanguage">
                        <div class="form-group mb-0" style="width:10rem">
                            <label class="small text-muted">{{ __('addon_input_type') }}</label>
                            <AppSelect class="form-control form-select form-select-sm" v-model="g.input_type"
                                :options="inputTypeOptions" :searchable="false" :allow-empty="false" />
                        </div>
                        <div class="form-group mb-0" style="width:7rem">
                            <label class="small text-muted d-block">{{ __('is_required') }}</label>
                            <div class="form-check form-switch m-0 ps-0 addon-switch-cell">
                                <input class="form-check-input m-0 float-none" type="checkbox" role="switch"
                                    v-model="g.is_required">
                            </div>
                        </div>
                        <div class="ms-auto d-flex gap-1">
                            <button type="button" class="list-action-btn" :disabled="gi === 0" @click="moveGroup(gi, -1)"
                                v-b-tooltip.hover :title="__('move_up')"><ChevronUp :size="15" /></button>
                            <button type="button" class="list-action-btn" :disabled="gi === groups.length - 1"
                                @click="moveGroup(gi, 1)" v-b-tooltip.hover :title="__('move_down')"><ChevronDown :size="15" /></button>
                            <button type="button" class="list-action-btn is-delete" @click="removeGroup(gi)"
                                v-b-tooltip.hover :title="__('delete')"><Trash2 :size="15" /></button>
                        </div>
                    </template>
                </div>

                <!-- A "pick one" group is exactly one choice, so its range fields would
                     be noise and a stepper would make no sense. -->
                <div class="row g-2 mb-3" v-if="isDefaultLanguage && g.input_type === 'checkbox'">
                    <div class="col-sm-4">
                        <label class="small text-muted">{{ __('min_select') }}</label>
                        <input type="number" min="0" class="form-control form-control-sm" v-model.number="g.min_select">
                        <small class="text-muted">{{ __('min_select_hint') }}</small>
                    </div>
                    <div class="col-sm-4">
                        <label class="small text-muted">{{ __('max_select') }}</label>
                        <input type="number" min="0" class="form-control form-control-sm" v-model.number="g.max_select">
                        <small class="text-muted">{{ __('max_select_hint') }}</small>
                    </div>
                    <div class="col-sm-4">
                        <label class="small text-muted">{{ __('max_qty_per_option') }}</label>
                        <input type="number" min="1" max="50" class="form-control form-control-sm" v-model.number="g.max_qty_per_option">
                        <small class="text-muted">{{ __('max_qty_per_option_hint') }}</small>
                    </div>
                </div>

                <!-- One grid for every option, whatever its type. A custom option
                     keeps the product columns as empty spacers so the rows below never
                     stagger against each other. -->
                <!-- Columns appear per GROUP, not per row: a group of plain options
                     shows no product columns at all, and a group whose prices follow the
                     catalogue shows no money columns. Rows inside a group therefore still
                     line up, without empty cells standing around in every other group. -->
                <div class="addon-opt-grid" :class="{ 'has-source': hasLinked(g) }">
                <div class="addon-opt-head row g-2 small text-muted mb-1" v-if="g.options.length">
                    <div class="col-auto ao-cell ao-type" v-if="isDefaultLanguage">{{ __('option_type') }}</div>
                    <div class="col-auto ao-cell ao-img" v-if="isDefaultLanguage">{{ __('image') }}</div>
                    <div class="col-auto ao-cell ao-diet" v-if="isDefaultLanguage">{{ __('product_type') }}</div>
                    <div class="col ao-cell ao-name addon-name-col">{{ hasLinked(g) ? __('option_name') + ' / ' + __('linked_product') : __('option_name') }}</div>
                    <template v-if="isDefaultLanguage">
                        <div class="col-auto ao-cell ao-pricing">{{ __('addon_pricing') }}</div>
                        <div class="col-auto ao-cell ao-source" v-if="hasLinked(g)">{{ __('addon_price_source') }}</div>
                        <template v-if="hasOwnPrice(g)">
                            <div class="col-auto text-center ao-cell ao-offered">{{ __('offered') }}</div>
                            <div class="col-auto ao-cell ao-price">{{ __('price') }}</div>
                            <div class="col-auto ao-cell ao-disc">{{ __('discounted_price') }}</div>
                        </template>
                        <div class="col-auto ao-cell ao-del"></div>
                    </template>
                </div>

                <div v-for="o in g.options" :key="o.key" class="row g-2 align-items-center mb-2 addon-opt-row">
                    <div class="col-auto ao-cell ao-type" v-if="isDefaultLanguage">
                        <span class="ao-label">{{ __('option_type') }}</span>
                        <AppSelect class="form-control form-select form-select-sm" v-model="o.type"
                            :options="optionTypeOptions" :searchable="false" :allow-empty="false"
                            @update:model-value="onOptionTypeChange(o)" />
                    </div>

                    <!-- Optional, and a linked option has nothing to upload: it wears
                         the picture of the product it points at. -->
                    <div class="col-auto ao-cell ao-img" v-if="isDefaultLanguage">
                        <span class="ao-label">{{ __('image') }}</span>
                        <div class="addon-img" :class="{ 'is-readonly': o.type === 'linked' }"
                            v-b-tooltip.hover
                            :title="o.type === 'linked' ? __('addon_image_from_product') : __('addon_option_image_hint')"
                            @click="o.type === 'custom' && pickImage(o)">
                            <b-spinner v-if="o.uploading" small></b-spinner>
                            <img v-else-if="optionImage(o)" :src="optionImage(o)" alt="">
                            <ImageIcon v-else :size="16" class="text-muted" />
                            <button v-if="o.type === 'custom' && o.image && !o.uploading" type="button"
                                class="addon-img-clear" @click.stop="clearImage(o)">&times;</button>
                        </div>
                    </div>

                    <!-- Veg / non-veg, on the same scale the product form uses. A linked
                         option shows what its product already says rather than asking
                         again, exactly as it does for the picture. -->
                    <div class="col-auto ao-cell ao-diet" v-if="isDefaultLanguage">
                        <span class="ao-label">{{ __('product_type') }}</span>
                        <AppSelect v-if="o.type === 'custom'" class="form-control form-select form-select-sm"
                            v-model="o.product_type" :options="dietOptions" :searchable="false"
                            :allow-empty="false" />
                        <span v-else class="small text-muted d-block text-truncate" v-b-tooltip.hover
                            :title="__('addon_type_from_product')">{{ dietLabel(o) }}</span>
                    </div>

                    <div class="col ao-cell ao-name addon-name-col">
                        <span class="ao-label">{{ hasLinked(g) ? __('option_name') + ' / ' + __('linked_product') : __('option_name') }}</span>
                        <input v-if="o.type === 'custom' || !isDefaultLanguage" type="text"
                            class="form-control form-control-sm" v-model="o.i18n[activeLanguageId].name"
                            :placeholder="__('option_name')">
                        <template v-else>
                            <AppSelect class="form-control form-select form-select-sm" v-model="o.linked_variant_id"
                                :options="linkableOptions" :placeholder="__('select')"
                                :internal-search="false" :loading="linkableLoading"
                                @search-change="searchLinkable"
                                @update:model-value="onLinkPicked(o)" />
                            <small v-if="taxWarning(o)" class="text-warning d-block">{{ __('addon_linked_tax_warning') }}</small>
                        </template>
                    </div>

                    <template v-if="isDefaultLanguage">
                        <!-- Free costs nothing wherever it is offered, so the money
                             columns below drop out for that row. -->
                        <div class="col-auto ao-cell ao-pricing">
                            <span class="ao-label">{{ __('addon_pricing') }}</span>
                            <AppSelect class="form-control form-select form-select-sm" v-model="o.is_free"
                                :options="pricingOptions" :searchable="false" :allow-empty="false"
                                @update:modelValue="onPriceSourceChange(o)" />
                        </div>
                        <div class="col-auto ao-cell ao-source" v-if="hasLinked(g)">
                            <span class="ao-label" v-if="o.type === 'linked'">{{ __('addon_price_source') }}</span>
                            <AppSelect v-if="o.type === 'linked'"
                                class="form-control form-select form-select-sm"
                                v-model="o.price_source" :options="priceSourceOptions" :searchable="false"
                                :allow-empty="false" :disabled="isFreeOption(o)"
                                @update:modelValue="onPriceSourceChange(o)" />
                        </div>

                        <!-- Money for the branch selected above. A linked option that
                             follows the catalogue has no price of its own to set. -->
                        <template v-if="hasOwnPrice(g)">
                            <div class="col-auto d-flex justify-content-center ao-cell ao-offered">
                                <span class="ao-label me-2"
                                    v-if="o.price_source !== 'product' && activeBranch">{{ __('offered') }}</span>
                                <div class="form-check form-switch m-0 ps-0 addon-switch-cell"
                                    v-if="o.price_source !== 'product' && activeBranch">
                                    <input class="form-check-input m-0 float-none" type="checkbox" role="switch"
                                        v-model="branchRow(o, activeBranchId).is_available">
                                </div>
                            </div>
                            <div class="col-auto ao-cell ao-price">
                                <span class="ao-label"
                                    v-if="o.price_source !== 'product' && activeBranch">{{ __('price') }}</span>
                                <div class="input-group input-group-sm" v-if="o.price_source !== 'product' && activeBranch">
                                    <span class="input-group-text px-2">{{ activeBranch.currency || $currency }}</span>
                                    <input type="number" step="0.01" min="0" class="form-control"
                                        v-model.number="branchRow(o, activeBranchId).price"
                                        :disabled="!branchRow(o, activeBranchId).is_available || isFreeOption(o)">
                                </div>
                            </div>
                            <div class="col-auto ao-cell ao-disc">
                                <span class="ao-label"
                                    v-if="o.price_source !== 'product' && activeBranch">{{ __('discounted_price') }}</span>
                                <div class="input-group input-group-sm" v-if="o.price_source !== 'product' && activeBranch">
                                    <span class="input-group-text px-2">{{ activeBranch.currency || $currency }}</span>
                                    <input type="number" step="0.01" min="0" class="form-control"
                                        :class="{ 'is-invalid': offerAbovePrice(o, activeBranchId) }"
                                        v-model.number="branchRow(o, activeBranchId).discounted_price"
                                        :disabled="!branchRow(o, activeBranchId).is_available || isFreeOption(o)"
                                        :placeholder="__('optional')">
                                </div>
                            </div>
                        </template>

                        <div class="col-auto text-end ao-cell ao-del">
                            <button type="button" class="btn btn-sm btn-outline-danger"
                                @click="removeOption(g, g.options.indexOf(o))"
                                v-b-tooltip.hover :title="__('delete')"><Trash2 :size="14" /></button>
                        </div>
                    </template>
                </div>

                </div>

                <div class="d-flex gap-2 mt-2" v-if="isDefaultLanguage">
                    <button type="button" class="btn btn-sm btn-outline-primary" @click="addOption(g)">
                        <Plus :size="14" /> {{ __('add_addon_option') }}
                    </button>
                    <button type="button" class="btn btn-sm btn-outline-secondary" @click="copyBranchToAll(g)"
                        v-if="branches.length > 1 && hasOwnPrice(g)">
                        <Copy :size="14" /> {{ __('copy_this_branch_to_all') }}
                    </button>
                </div>
            </div>

            <div class="d-flex flex-wrap gap-2">
                <button v-if="isDefaultLanguage" type="button" class="btn btn-outline-primary" @click="addGroup">
                    <Plus :size="15" /> {{ __('add_addon_group') }}
                </button>
            </div>
        </template>

        <!-- One input for every row; which option it is filling is held in imageTarget,
             so the page carries a single file picker rather than one per option. -->
        <input ref="addonImageInput" type="file" class="d-none"
            accept="image/jpeg,image/png,image/gif,image/webp" @change="onImagePicked">

        <!-- Copy from another product -->
        <b-modal v-model="copyOpen" :title="__('copy_addons_from_product')" centered no-fade
            @ok.prevent="runCopy" :ok-title="__('copy')" :cancel-title="__('cancel')">
            <AppSelect class="form-control form-select" v-model="copySourceId" :options="sourceOptions"
                :placeholder="__('select')" :internal-search="false" :loading="sourcesLoading"
                @search-change="searchSources" />
            <!-- Being food is not enough to be a source: there has to be something to copy. -->
            <small v-if="!sourcesLoading && !sources.length" class="text-muted d-block mt-2">
                {{ __('addon_no_copy_sources') }}
            </small>
            <div class="form-check mt-3">
                <input class="form-check-input" type="checkbox" id="copy-replace" v-model="copyReplace">
                <label class="form-check-label" for="copy-replace">{{ __('replace_existing_addons') }}</label>
            </div>
        </b-modal>

        <!-- Apply this setup to other products -->
        <b-modal v-model="applyOpen" :title="__('apply_addons_to_products')" centered no-fade
            @ok.prevent="runApply" :ok-title="__('apply')" :cancel-title="__('cancel')">
            <AppSelect class="form-control form-select" multiple v-model="applyTargets"
                :options="foodProductOptions" :placeholder="__('select')"
                :internal-search="false" :loading="foodLoading"
                @search-change="searchFoodProducts" />
            <div class="form-check mt-3">
                <input class="form-check-input" type="checkbox" id="apply-replace" v-model="applyReplace">
                <label class="form-check-label" for="apply-replace">{{ __('replace_existing_addons') }}</label>
            </div>
            <small class="text-muted d-block mt-2">{{ __('addons_food_only_note') }}</small>
        </b-modal>
    </div>
</template>

<script>
import { ArrowLeft, Save, Plus, Trash2, Copy, Share2, TriangleAlert, ChevronUp, ChevronDown, Image as ImageIcon } from 'lucide-vue-next';
import TranslationHelper from '../../../mixins/TranslationHelper.js';
import UnsavedChanges from '../../../mixins/UnsavedChanges.js';

let keySeq = 1;
const nextKey = () => 'k' + (keySeq++);

export default {
    mixins: [TranslationHelper, UnsavedChanges],
    components: { ArrowLeft, Save, Plus, Trash2, Copy, Share2, TriangleAlert, ChevronUp, ChevronDown, ImageIcon },
    props: {
        // Rendered inside the product form's modal rather than as its own page, so the
        // operator never loses an unsaved form by navigating away.
        embedded: { type: Boolean, default: false },
        productIdProp: { type: [Number, String], default: null },
        // What the form currently has toggled, which may differ from what is saved.
        isFoodProp: { type: Number, default: null },
    },
    data() {
        return {
            productId: Number(this.productIdProp || this.$route?.params?.id) || 0,
            productName: '',
            isFood: false,
            productTaxCategoryId: null,
            isSaving: false,
            isLoaded: false,
            groups: [],
            branches: [],
            activeBranchId: null,
            languages: [],
            defaultLanguageId: null,
            activeLanguageId: null,
            linkable: [],
            linkableLoading: false,
            linkableSearchTimer: null,
            foodProducts: [],
            foodLoading: false,
            foodSearchTimer: null,
            sources: [],
            sourcesLoading: false,
            sourcesSearchTimer: null,
            // The option row the file picker is currently filling.
            imageTarget: null,
            copyOpen: false, copySourceId: null, copyReplace: true,
            applyOpen: false, applyTargets: [], applyReplace: false,
        };
    },
    computed: {
        activeBranch() { return this.branches.find(s => s.id === this.activeBranchId) || null; },
        isDefaultLanguage() { return Number(this.activeLanguageId) === Number(this.defaultLanguageId); },
        languageOptions() { return this.languages.map(l => ({ id: l.id, name: l.name })); },
        inputTypeOptions() {
            return [{ id: 'radio', name: __('addon_input_radio') }, { id: 'checkbox', name: __('addon_input_checkbox') }];
        },
        optionTypeOptions() {
            return [{ id: 'custom', name: __('option_type_custom') }, { id: 'linked', name: __('option_type_linked') }];
        },
        pricingOptions() {
            return [{ id: 0, name: __('addon_paid') }, { id: 1, name: __('addon_free') }];
        },
        /**
         * products.product_type's scale, minus the two values no food can be: 3 chemical
         * and 5 medical. The numbers stay the product form's so a linked option can be
         * read off its product without translation.
         */
        dietOptions() {
            return [
                { id: 0, name: __('none') },
                { id: 1, name: __('veg') },
                { id: 2, name: __('non_veg') },
                { id: 4, name: __('eggetarian') },
            ];
        },
        priceSourceOptions() {
            return [
                { id: 'product', name: __('addon_price_source_product') },
                { id: 'custom', name: __('addon_price_source_custom') },
            ];
        },
        /**
         * Every translatable string on the page, flattened into one key per field, so the
         * whole menu is translated in a single request instead of one per name. The key
         * encodes where the value came from: g2 is the third group, g2o1 its second option.
         */
        translatableFields() {
            return Object.keys(this.translateFlatSource());
        },
        linkableOptions() {
            return this.linkable.map(v => ({
                id: v.id,
                name: this.linkedLabel(v),
            }));
        },
        foodProductOptions() {
            return this.foodProducts.filter(p => Number(p.id) !== this.productId)
                .map(p => ({ id: p.id, name: p.name }));
        },
        sourceOptions() {
            return this.sources.map(p => ({ id: p.id, name: p.name }));
        },
    },
    created() {
        this.bootstrap();
    },
    watch: {
        groups(list) {
            if (!list.length) this.activeLanguageId = this.defaultLanguageId;
        },
    },
    methods: {
        back() { this.$router.push('/products'); },

        /** UnsavedChanges hook: what the guard compares against its baseline. */
        formState() {
            return this.payload();
        },
        /** UnsavedChanges hook: lets the dialog offer "Save changes" as a way out. */
        async submitForm() {
            const ok = await this.save();
            return ok !== false;
        },
        /** Asked by the host modal before it closes. True = safe to close. */
        confirmClose() {
            return this._ucConfirmLeave();
        },

        translateFlatSource() {
            const src = {};
            if (!this.defaultLanguageId) return src;
            this.groups.forEach((g, gi) => {
                const name = g.i18n?.[this.defaultLanguageId]?.name;
                if (name && name.trim()) src['g' + gi] = name;
                (g.options || []).forEach((o, oi) => {
                    const on = o.i18n?.[this.defaultLanguageId]?.name;
                    if (on && on.trim()) src['g' + gi + 'o' + oi] = on;
                });
            });
            return src;
        },
        /** TranslationHelper hook: what to send. */
        getTranslateSource() {
            return this.translateFlatSource();
        },
        /** TranslationHelper hook: where each answer belongs. */
        applyTranslated(lang, translated) {
            Object.entries(translated || {}).forEach(([key, value]) => {
                const m = /^g(\d+)(?:o(\d+))?$/.exec(key);
                if (!m) return;
                const group = this.groups[Number(m[1])];
                if (!group) return;
                if (m[2] === undefined) {
                    if (group.i18n[lang.id]) group.i18n[lang.id].name = value;
                    return;
                }
                const option = group.options[Number(m[2])];
                if (option && option.i18n[lang.id]) option.i18n[lang.id].name = value;
            });
        },

        bootstrap() {
            Promise.all([this.fetchLanguages(), this.fetchBranches(), this.fetchProduct(), this.fetchLinkable()])
                .then(() => this.fetchGroups())
                .then(() => {
                    this.isLoaded = true;
                    // Tells the host modal whether a Save button means anything here.
                    this.$emit('ready', this.isFood);
                    this.$nextTick(() => this.captureFormBaseline());
                    return Promise.all([this.fetchFoodProducts(), this.fetchSources()]);
                })
                .catch(() => { this.isLoaded = true; this.$emit('ready', false); });
        },
        fetchLanguages() {
            return axios.get(this.$apiUrl + '/active_languages').then(r => {
                this.languages = r.data.data || [];
                const def = this.languages.find(l => l.is_default) || this.languages[0];
                this.defaultLanguageId = def ? def.id : null;
                this.activeLanguageId = this.defaultLanguageId;
            });
        },
        fetchBranches() {
            return axios.get(this.$apiUrl + '/branches/for_channel', { params: { sales_channel: 'both' } })
                .then(r => {
                    const all = r.data?.data?.branches || [];
                    /* A branch user prices only their own branch — showing the others would
                       offer pills they cannot save and name shops that are not theirs.
                       The API scopes the rows to match. */
                    const own = window.BranchId ? Number(window.BranchId) : null;
                    this.branches = own ? all.filter(st => Number(st.id) === own) : all;
                    if (this.branches.length) this.activeBranchId = this.branches[0].id;
                }).catch(() => { this.branches = []; });
        },
        fetchProduct() {
            return axios.get(this.$apiUrl + '/products/edit/' + this.productId).then(r => {
                const d = r.data.data || {};
                this.productName = d.name || '';
                this.isFood = Number(d.is_food) === 1;
                this.productTaxCategoryId = d.tax_category_id || null;
            }).catch(() => {});
        },
        fetchLinkable(search = '') {
            this.linkableLoading = true;
            return axios.get(this.$apiUrl + '/products/addons/linkable', {
                params: { product_id: this.productId, search },
            })
                .then(r => { this.linkable = this.keepLinkedAmong(r.data.data || []); })
                .catch(() => { this.linkable = this.keepLinkedAmong([]); })
                .finally(() => { this.linkableLoading = false; });
        },
        /**
         * The endpoint answers with one page of matches, so a search replaces the list.
         * Anything a group already links to has to survive that, or the picker would show
         * a blank label and the next save would drop the link.
         */
        keepLinkedAmong(rows) {
            const seen = new Set(rows.map(r => Number(r.id)));
            const kept = [];
            this.groups.forEach(g => (g.options || []).forEach(o => {
                const id = Number(o.linked_variant_id);
                if (!id || seen.has(id)) return;
                const existing = this.linkable.find(x => Number(x.id) === id);
                if (existing) { kept.push(existing); seen.add(id); }
            }));
            return [...rows, ...kept];
        },
        /**
         * Searching in the browser would only ever see the page already loaded, so the
         * catalogue beyond it was unreachable. Ask the server instead, debounced.
         */
        searchLinkable(query) {
            clearTimeout(this.linkableSearchTimer);
            this.linkableSearchTimer = setTimeout(() => this.fetchLinkable(String(query || '').trim()), 300);
        },
        fetchFoodProducts(search = '') {
            this.foodLoading = true;
            return axios.get(this.$apiUrl + '/products', { params: { limit: 200, is_food: 1, search } })
                .then(r => {
                    // This endpoint answers {data: {products: [...], categories: [...]}},
                    // not a bare array — reading data[] left the picker permanently empty.
                    const rows = (r.data.data?.products || [])
                        .filter(p => Number(p.is_food) === 1);
                    this.foodProducts = this.keepChosenFood(rows);
                })
                .catch(() => { this.foodProducts = this.keepChosenFood([]); })
                .finally(() => { this.foodLoading = false; });
        },
        /**
         * Products that have something to copy. A food product with no groups would copy
         * nothing, so it is not offered as a source.
         */
        fetchSources(search = '') {
            this.sourcesLoading = true;
            return axios.get(this.$apiUrl + '/products/addons/sources', {
                params: { product_id: this.productId, search },
            })
                .then(r => { this.sources = this.keepChosenSource(r.data.data || []); })
                .catch(() => { this.sources = this.keepChosenSource([]); })
                .finally(() => { this.sourcesLoading = false; });
        },
        /** A search replaces the list; the chosen source has to survive it. */
        keepChosenSource(rows) {
            const id = Number(this.copySourceId);
            if (!id || rows.some(r => Number(r.id) === id)) return rows;
            const existing = this.sources.find(p => Number(p.id) === id);
            return existing ? [...rows, existing] : rows;
        },
        searchSources(query) {
            clearTimeout(this.sourcesSearchTimer);
            this.sourcesSearchTimer = setTimeout(() => this.fetchSources(String(query || '').trim()), 300);
        },
        /**
         * A search replaces the list, so anything already chosen has to survive it or the
         * picker would show a blank label and the copy would lose its target.
         */
        keepChosenFood(rows) {
            const seen = new Set(rows.map(r => Number(r.id)));
            const chosen = this.applyTargets.map(Number);
            const kept = [];
            chosen.forEach(id => {
                if (!id || seen.has(id)) return;
                const existing = this.foodProducts.find(p => Number(p.id) === id);
                if (existing) { kept.push(existing); seen.add(id); }
            });
            return [...rows, ...kept];
        },
        /**
         * The list is one page of food products, so filtering in the browser could only
         * ever reach what was already loaded. Ask the server instead, debounced.
         */
        searchFoodProducts(query) {
            clearTimeout(this.foodSearchTimer);
            this.foodSearchTimer = setTimeout(() => this.fetchFoodProducts(String(query || '').trim()), 300);
        },
        fetchGroups() {
            return axios.get(this.$apiUrl + '/products/addons', { params: { product_id: this.productId } })
                .then(r => {
                    const raw = r.data.data || [];
                    this.ensureLinkedAreSelectable(raw);
                    this.groups = raw.map(g => this.hydrateGroup(g));
                })
                .catch(() => { this.groups = []; });
        },
        /**
         * The picker only holds a page of candidates, so a variant that is already linked
         * may not be among them — and an empty picker would silently drop the link on the
         * next save. Each option carries its own linked variant, so add any that is
         * missing to the list.
         */
        ensureLinkedAreSelectable(groups) {
            groups.forEach(g => (g.options || []).forEach(o => {
                const v = o.linked_variant;
                if (!o.linked_variant_id || !v) return;
                if (this.linkable.some(x => Number(x.id) === Number(o.linked_variant_id))) return;
                this.linkable.push({
                    id: Number(o.linked_variant_id),
                    product_name: v.name || o.name,
                    variant_name: '',
                    tax_category_id: null,
                    image_url: o.image_url || null,
                });
            }));
        },

        // ---- shaping between the API and the form ----
        blankI18n(seed = {}) {
            const map = {};
            this.languages.forEach(l => {
                map[l.id] = { name: seed.name || '' };
            });
            return map;
        },
        hydrateGroup(g) {
            const i18n = this.blankI18n();
            this.languages.forEach(l => {
                const t = (g.translations || []).find(x => Number(x.language_id) === Number(l.id));
                i18n[l.id] = {
                    name: t && t.name ? t.name : (Number(l.id) === Number(this.defaultLanguageId) ? (g.name || '') : ''),
                };
            });
            return {
                key: nextKey(), id: g.id, i18n,
                selection_text: g.selection_text || '',
                input_type: g.input_type || 'radio',
                is_required: !!g.is_required,
                min_select: Number(g.min_select || 0),
                max_select: Number(g.max_select || 0),
                max_qty_per_option: Math.max(1, Number(g.max_qty_per_option || 1)),
                status: Number(g.status ?? 1),
                options: (g.options || []).map(o => this.hydrateOption(o)),
            };
        },
        hydrateOption(o) {
            const i18n = this.blankI18n();
            this.languages.forEach(l => {
                const t = (o.translations || []).find(x => Number(x.language_id) === Number(l.id));
                i18n[l.id] = {
                    name: t && t.name ? t.name : (Number(l.id) === Number(this.defaultLanguageId) ? (o.name || '') : ''),
                };
            });
            const branches = {};
            (o.branch_prices || []).forEach(sp => {
                branches[sp.branch_id] = {
                    is_available: sp.is_available === undefined ? true : !!sp.is_available,
                    price: Number(sp.price || 0),
                    discounted_price: Number(sp.discounted_price || 0),
                };
            });
            return {
                key: nextKey(), id: o.id, i18n, branches,
                // `image` is the stored path this form posts back; `image_url` is only
                // for showing, and for a linked option it is the product's own picture.
                image: o.image || null,
                image_url: o.image_url || '',
                uploading: false,
                product_type: Number(o.product_type || 0),
                // What a linked option inherits, resolved by the server.
                resolved_product_type: Number(o.resolved_product_type || 0),
                type: o.linked_variant_id ? 'linked' : 'custom',
                linked_variant_id: o.linked_variant_id || null,
                is_free: Number(o.is_free ?? 0) === 1 ? 1 : 0,
                price_source: o.price_source || 'custom',
                status: Number(o.status ?? 1),
            };
        },

        // ---- editing ----
        addGroup() {
            this.groups.push({
                key: nextKey(), id: null, i18n: this.blankI18n(), selection_text: '',
                input_type: 'radio', is_required: false,
                min_select: 0, max_select: 0, max_qty_per_option: 1,
                status: 1, options: [],
            });
            this.addOption(this.groups[this.groups.length - 1]);
        },
        removeGroup(i) { this.groups.splice(i, 1); },
        moveGroup(i, delta) {
            const j = i + delta;
            if (j < 0 || j >= this.groups.length) return;
            const [row] = this.groups.splice(i, 1);
            this.groups.splice(j, 0, row);
        },
        addOption(g) {
            // A brand new option starts offered everywhere at zero — that is an explicit
            // act by the operator, unlike merely viewing a branch's tab.
            const branches = {};
            this.branches.forEach(st => {
                branches[st.id] = { is_available: true, price: 0, discounted_price: 0 };
            });
            g.options.push({
                key: nextKey(), id: null, i18n: this.blankI18n(), branches,
                image: null, image_url: '', uploading: false,
                product_type: 0, resolved_product_type: 0,
                type: 'custom', linked_variant_id: null, is_free: 0,
                price_source: 'custom', status: 1,
            });
        },
        removeOption(g, i) { g.options.splice(i, 1); },
        /** What a linked option inherits: the picked product's mark, else the saved one. */
        dietLabel(o) {
            const picked = this.linkable.find(x => Number(x.id) === Number(o.linked_variant_id));
            const value = picked ? Number(picked.product_type || 0) : Number(o.resolved_product_type || 0);
            const found = this.dietOptions.find(d => d.id === value);

            return found ? found.name : __('none');
        },
        /**
         * An option that starts pricing itself has to be offered somewhere.
         *
         * A brand new custom option is seeded offered everywhere by addOption. One that
         * only BECOMES custom - linked, then switched to "Set here" or to Free - is not:
         * the save deletes a catalogue-priced option's branch rows, and branchRow() creates
         * them switched off so that merely opening a branch's tab never puts an item on
         * sale there. The two together saved an option offered in no branch at all, which
         * drops it from the menu with nothing on screen to say why.
         *
         * Only linked options need this; a custom one always carries the rows it loaded.
         */
        ensureOfferedSomewhere(o) {
            if (o.type !== 'linked') return;
            if (Object.values(o.branches || {}).some(r => r.is_available)) return;
            this.branches.forEach(st => { this.branchRow(o, st.id).is_available = true; });
        },
        onPriceSourceChange(o) {
            if (o.price_source !== 'product' || this.isFreeOption(o)) {
                this.ensureOfferedSomewhere(o);
            }
        },
        onOptionTypeChange(o) {
            if (o.type === 'custom') {
                o.linked_variant_id = null;
                o.price_source = 'custom';
            } else {
                // A linked option takes its picture from its product, so any upload of
                // its own is released — the save drops the file once nothing holds it.
                o.image = null;
                o.image_url = '';
                // Following the catalogue is the sane default for a real product.
                o.price_source = 'product';
            }
        },
        onLinkPicked(o) {
            const v = this.linkable.find(x => Number(x.id) === Number(o.linked_variant_id));
            if (!v) return;

            o.i18n[this.defaultLanguageId].name = this.linkedLabel(v);
        },

        linkedLabel(v) {
            const product = String(v.product_name || '').trim();
            const variant = String(v.variant_name || '').trim();
            if (!variant) return product;

            return variant.toLowerCase().startsWith(product.toLowerCase())
                ? variant
                : `${product} — ${variant}`;
        },
        taxWarning(o) {
            if (o.type !== 'linked' || !o.linked_variant_id) return false;
            const v = this.linkable.find(x => Number(x.id) === Number(o.linked_variant_id));
            return v && this.productTaxCategoryId && Number(v.tax_category_id) !== Number(this.productTaxCategoryId);
        },
        /**
         * The row backing the price fields for one branch, created on first touch.
         *
         * It is created NOT offered on purpose. Switching to a branch tab must never put
         * the option on sale there — an India-only topping would otherwise become a free
         * topping in Dubai just because someone looked at that tab.
         */
        /** Does any option in this group point at a catalogue product? */
        hasLinked(g) {
            return (g.options || []).some(o => o.type === 'linked');
        },
        /** Does any option in this group set its own price, rather than follow one? */
        hasOwnPrice(g) {
            return (g.options || []).some(o => o.price_source !== 'product');
        },
        /**
         * What to show in the row's image cell.
         *
         * A linked option follows the product it points at, so the picker's row is the
         * live answer — the saved `image_url` only covers the case where that variant is
         * not in the loaded page of candidates.
         */
        optionImage(o) {
            if (o.type === 'linked') {
                const v = this.linkable.find(x => Number(x.id) === Number(o.linked_variant_id));
                return (v && v.image_url) || o.image_url || '';
            }
            return o.image_url || '';
        },
        pickImage(o) {
            this.imageTarget = o;
            this.$refs.addonImageInput?.click();
        },
        /**
         * Upload on pick and keep the path.
         *
         * The menu is saved as one JSON document, so the file goes up on its own and only
         * its path travels with the payload. An upload the operator never saves is left
         * for the media sweep, which reclaims anything untouched for a day.
         */
        onImagePicked(event) {
            const file = event.target.files && event.target.files[0];
            const option = this.imageTarget;
            event.target.value = '';
            this.imageTarget = null;
            if (!file || !option) return;

            const form = new FormData();
            form.append('image', file);
            option.uploading = true;
            axios.post(this.$apiUrl + '/products/addons/upload_image', form)
                .then(r => {
                    if (!r.data || Number(r.data.status) === 0) {
                        this.showError(r.data?.message || __('something_went_wrong'));
                        return;
                    }
                    option.image = r.data.data?.path || null;
                    option.image_url = r.data.data?.url || '';
                })
                .catch(e => this.showError(e.response?.data?.message || __('something_went_wrong')))
                .finally(() => { option.uploading = false; });
        },
        /** Drop the picture from this option; the file goes on the next save. */
        clearImage(o) {
            o.image = null;
            o.image_url = '';
        },
        /** Free is stored as 0/1, but the select hands back whatever the option carries. */
        isFreeOption(o) {
            return Number(o.is_free) === 1;
        },
        /** Groups and options both need a name in the default language. */
        missingNames() {
            const out = [];
            this.groups.forEach((g, gi) => {
                const gName = (g.i18n?.[this.defaultLanguageId]?.name || '').trim();
                if (!gName) out.push(__('group') + ' ' + (gi + 1));
                (g.options || []).forEach((o, oi) => {
                    if (!(o.i18n?.[this.defaultLanguageId]?.name || '').trim()) {
                        out.push((gName || __('group') + ' ' + (gi + 1)) + ' \u2192 ' + __('option') + ' ' + (oi + 1));
                    }
                });
            });
            return out;
        },
        /** An offer above the list price would charge the wrong amount. */
        offerAbovePrice(o, branchId) {
            const row = o.branches?.[branchId];
            if (!row || !row.is_available || this.isFreeOption(o)) return false;
            return Number(row.discounted_price || 0) > Number(row.price || 0);
        },
        /** Every option/branch pair whose offer is above its price, named for the message. */
        invalidPriceRows() {
            const bad = [];
            this.groups.forEach(g => (g.options || []).forEach(o => {
                Object.keys(o.branches || {}).forEach(branchId => {
                    if (!this.offerAbovePrice(o, branchId)) return;
                    const branch = this.branches.find(st => Number(st.id) === Number(branchId));
                    bad.push({
                        option: o.i18n?.[this.defaultLanguageId]?.name || '',
                        branch: branch ? branch.name : branchId,
                    });
                });
            }));
            return bad;
        },
        branchRow(o, branchId) {
            if (!o.branches[branchId]) {
                o.branches[branchId] = { is_available: false, price: 0, discounted_price: 0 };
            }
            return o.branches[branchId];
        },
        // Most menus charge the same within a currency; the operator still checks the
        // branches that price in another one.
        copyBranchToAll(g) {
            if (!this.activeBranchId) return;
            let n = 0;
            g.options.forEach(o => {
                const src = this.branchRow(o, this.activeBranchId);
                this.branches.forEach(st => {
                    if (st.id === this.activeBranchId) return;
                    const dst = this.branchRow(o, st.id);
                    dst.is_available = src.is_available;
                    dst.price = src.price;
                    dst.discounted_price = src.discounted_price;
                });
                n++;
            });
            this.showMessage('success', String(__('copied_to_branches')).replace(':count', this.branches.length - 1));
        },

        // ---- saving ----
        payload() {
            return {
                product_id: this.productId,
                groups: this.groups.map(g => ({
                    id: g.id,
                    name: g.i18n[this.defaultLanguageId].name,
                    input_type: g.input_type,
                    is_required: g.is_required ? 1 : 0,
                    min_select: Number(g.min_select) || 0,
                    max_select: Number(g.max_select) || 0,
                    max_qty_per_option: Math.min(50, Math.max(1, Number(g.max_qty_per_option) || 1)),
                    status: g.status,
                    translations: this.translationMap(g.i18n, ['name']),
                    options: g.options.map(o => ({
                        id: o.id,
                        name: o.i18n[this.defaultLanguageId].name,
                        // A linked option branches no image of its own; it reads its
                        // product's, so there is nothing here that could disagree with it.
                        image: o.type === 'linked' ? null : (o.image || null),
                        // Null for a linked option: its product's mark is the only answer.
                        product_type: o.type === 'linked' ? null : (Number(o.product_type) || 0),
                        linked_variant_id: o.type === 'linked' ? o.linked_variant_id : null,
                        is_free: this.isFreeOption(o) ? 1 : 0,
                        price_source: o.type === 'linked' && !this.isFreeOption(o) ? o.price_source : 'custom',
                        status: o.status,
                        translations: this.translationMap(o.i18n, ['name']),
                        // Every branch this option has a row for, offered or not. A
                        // withdrawn branch is kept switched off rather than dropped, so
                        // the price the operator typed survives the withdrawal and
                        // comes back when they offer it again. Only a branch that was
                        // never touched has no row at all, which is what says "this
                        // option does not exist here".
                        branches: Object.entries(o.branches).map(([branchId, row]) => ({
                            branch_id: Number(branchId),
                            is_available: row.is_available ? 1 : 0,
                            price: Number(row.price) || 0,
                            discounted_price: Number(row.discounted_price) || 0,
                        })),
                    })),
                })),
            };
        },
        translationMap(i18n, fields) {
            const out = {};
            this.languages.forEach(l => {
                if (Number(l.id) === Number(this.defaultLanguageId)) return;
                const entry = {};
                let filled = false;
                fields.forEach(f => {
                    entry[f] = i18n[l.id][f] || '';
                    if (entry[f]) filled = true;
                });
                if (filled) out[l.id] = entry;
            });
            return out;
        },
        save() {
            const missing = this.missingNames();
            if (missing.length) {
                this.activeLanguageId = this.defaultLanguageId;
                this.showError(__('name_is_required') + ' (' + missing.join(', ') + ')');
                return Promise.resolve(false);
            }

            const bad = this.invalidPriceRows();
            if (bad.length) {
                // Jump to the offending branch so the red field is actually on screen.
                const first = this.branches.find(st => st.name === bad[0].branch);
                if (first) this.activeBranchId = first.id;
                this.showError(__('discounted_price_cannot_be_greater_than_price')
                    + ' (' + bad.map(b => (b.option || '?') + ' \u2014 ' + b.branch).join(', ') + ')');
                return Promise.resolve(false);
            }

            this.isSaving = true;
            return axios.post(this.$apiUrl + '/products/addons/save', this.payload())
                .then(r => {
                    /* A rejected save still answers 200 with status 0 — that is how this
                       API reports validation. Treating any 200 as success announced
                       "saved", closed the modal and threw the edits away on a failure. */
                    if (!r.data || Number(r.data.status) === 0) {
                        this.showError(r.data?.message || __('something_went_wrong'));
                        return false;
                    }
                    this.showMessage('success', r.data.message);
                    this.$emit('saved');
                    return this.fetchGroups().then(() => {
                        this.$nextTick(() => this.captureFormBaseline());
                        return true;
                    });
                })
                .catch((e) => {
                    this.showError(e.response?.data?.message || __('something_went_wrong'));
                    return false;
                })
                .finally(() => { this.isSaving = false; });
        },
        runCopy() {
            if (!this.copySourceId) return;
            axios.post(this.$apiUrl + '/products/addons/copy', {
                product_id: this.productId, source_id: this.copySourceId, replace: this.copyReplace ? 1 : 0,
            }).then(r => {
                if (!r.data || Number(r.data.status) === 0) {
                    this.showError(r.data?.message || __('something_went_wrong'));
                    return;
                }
                this.showMessage('success', r.data.data?.message || r.data.message);
                this.copyOpen = false;
                return this.fetchGroups().then(() => this.$nextTick(() => this.captureFormBaseline()));
            });
        },
        runApply() {
            if (!this.applyTargets.length) return;
            axios.post(this.$apiUrl + '/products/addons/apply', {
                product_id: this.productId, target_ids: this.applyTargets, replace: this.applyReplace ? 1 : 0,
            }).then(r => {
                if (!r.data || Number(r.data.status) === 0) {
                    this.showError(r.data?.message || __('something_went_wrong'));
                    return;
                }
                const d = r.data.data || {};
                this.showMessage('success', d.message || r.data.message);
                if ((d.skipped || []).length) {
                    this.showError(__('addons_food_only_note') + ' ' + d.skipped.join(', '));
                }
                this.applyOpen = false;
            });
        },
    },
};
</script>

<style scoped>
/* Match the height of a form-control-sm beside it so a switch lines up with the inputs
   rather than floating between their rows. */
/* Smaller than the label it sits beside, and clipped rather than wrapped, so a long
   rule line can never add a second row and shift the group out of alignment. */
.addon-rule-hint {
    font-size: .7rem;
    opacity: .85;
    min-width: 0;
}

/* One option is a table row when there is room for one and a small card when there
   is not. The question is how wide the PANEL is, not the window: this page sits
   beside a sidebar the operator can collapse, so the same window shows very
   different room. Hence a container query rather than a breakpoint. */
.addon-opt-grid {
    container-type: inline-size;
    container-name: addonopts;
}

/* Stacked is the default, so a browser without container queries gets the layout
   that works at every width rather than the one that clips. */
.addon-opt-head {
    display: none;
}

.ao-label {
    display: block;
    font-size: .7rem;
    line-height: 1.2;
    opacity: .7;
    margin-bottom: .15rem;
}

/* Without the border the fields of two options run together and it stops being
   obvious which row you are editing. */
.addon-opt-row {
    border: 1px solid var(--bs-border-color, #dee2e6);
    border-radius: .5rem;
    padding: .75rem;
    margin-bottom: .75rem !important;
}

/* Grows to fill the line, but only so far: a dropdown of four short words reads
   worse stretched across a tablet than sitting at its own size. */
.addon-opt-row > .ao-cell {
    flex: 1 1 9rem;
    min-width: 0;
    max-width: 16rem;
}

/* Each of these is as wide as its content and no wider: a picture box, a switch
   and a delete button gain nothing from a share of the row. */
.addon-opt-row > .ao-img,
.addon-opt-row > .ao-offered,
.addon-opt-row > .ao-del {
    flex: 0 0 auto;
}

/* The one field with no natural width. It takes a line of its own so a long
   product name is readable instead of clipped to a few characters. */
.addon-opt-row > .ao-name {
    flex: 1 1 100%;
}

.addon-opt-row > .ao-del {
    margin-left: auto;
}

.addon-opt-row > .ao-offered {
    align-items: center;
}

/* What the row needs: the fixed columns (49rem), their gaps and a name field still
   wide enough to read (12rem). A group with linked options carries the extra "Price
   from" column, so it needs ~10rem more before the same row fits — hence two
   thresholds rather than one that is wrong for half the groups. Below its own
   threshold a group stays stacked, which is why nothing is ever clipped. */
@container addonopts (min-width: 66rem) {
    .addon-opt-head {
        display: flex;
    }

    .ao-label {
        display: none;
    }

    .addon-opt-row {
        border: 0;
        padding: 0;
        margin-bottom: .5rem !important;
    }

    .addon-opt-row > .ao-cell {
        flex: 0 0 auto;
        max-width: none;
    }

    .addon-opt-row > .ao-name {
        flex: 1 1 12rem;
        max-width: 34rem;
    }

    .addon-opt-row > .ao-del {
        margin-left: 0;
    }

    .ao-type    { width: 8rem; }
    .ao-img     { width: 4rem; }
    .ao-diet    { width: 7rem; }
    .ao-pricing { width: 7rem; }
    .ao-source  { width: 10.5rem; }
    .ao-offered { width: 5.5rem; }
    .ao-price   { width: 8rem; }
    .ao-disc    { width: 8rem; }
    .ao-del     { width: 2.5rem; }
}

/* The group that shows "Price from" needs that column's width on top before its row
   fits, so it stays stacked for longer. */
.addon-opt-grid.has-source .addon-opt-head { display: none; }
.addon-opt-grid.has-source .ao-label { display: block; }

.addon-opt-grid.has-source .addon-opt-row {
    border: 1px solid var(--bs-border-color, #dee2e6);
    padding: .75rem;
    margin-bottom: .75rem !important;
}

.addon-opt-grid.has-source .addon-opt-row > .ao-cell {
    flex: 1 1 9rem;
    max-width: 16rem;
}

.addon-opt-grid.has-source .addon-opt-row > .ao-img,
.addon-opt-grid.has-source .addon-opt-row > .ao-offered,
.addon-opt-grid.has-source .addon-opt-row > .ao-del {
    flex: 0 0 auto;
}

.addon-opt-grid.has-source .addon-opt-row > .ao-name {
    flex: 1 1 100%;
}

.addon-opt-grid.has-source .addon-opt-row > .ao-del { margin-left: auto; }

@container addonopts (min-width: 79rem) {
    .addon-opt-grid.has-source .addon-opt-head { display: flex; }
    .addon-opt-grid.has-source .ao-label { display: none; }

    .addon-opt-grid.has-source .addon-opt-row {
        border: 0;
        padding: 0;
        margin-bottom: .5rem !important;
    }

    .addon-opt-grid.has-source .addon-opt-row > .ao-cell {
        flex: 0 0 auto;
        max-width: none;
    }

    .addon-opt-grid.has-source .addon-opt-row > .ao-name {
        flex: 1 1 12rem;
        max-width: 34rem;
    }

    .addon-opt-grid.has-source .addon-opt-row > .ao-del { margin-left: 0; }
}

/* Keeps the name column from running the full width of a wide modal. It sits on the
   column, not on the field inside it, so a linked row and a custom row in the same group
   are always the same width. */
.addon-name-col {
    max-width: 34rem;
}

/* A square the size of the inputs beside it, so an image cell never changes a row's
   height whether it holds a picture, a spinner or nothing at all. */
.addon-img {
    position: relative;
    width: 2.25rem;
    height: 2.25rem;
    border: 1px dashed var(--bs-border-color, #ced4da);
    border-radius: .375rem;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    cursor: pointer;
    background: var(--bs-tertiary-bg, #f8f9fa);
}

.addon-img.is-readonly {
    cursor: default;
    border-style: solid;
}

.addon-img img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.addon-img-clear {
    position: absolute;
    top: -.35rem;
    right: -.35rem;
    width: 1.1rem;
    height: 1.1rem;
    line-height: 1;
    padding: 0;
    border: 0;
    border-radius: 50%;
    background: var(--bs-danger, #dc3545);
    color: #fff;
    font-size: .75rem;
}

.addon-switch-cell {
    height: calc(1.5em + .5rem + 2px);
    display: flex;
    align-items: center;
}
</style>
