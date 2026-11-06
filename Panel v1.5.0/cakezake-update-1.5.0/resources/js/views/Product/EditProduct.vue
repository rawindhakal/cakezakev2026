<template>
    <div>
        <div class="page-head">
            <h3 class="page-head-title">{{ pageTitle }}</h3>
            <router-link to="/products"
                class="btn btn-outline-secondary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap">
                <ArrowLeft :size="16" /> {{ __('back_to_products') }}
            </router-link>
        </div>

        <div class="card">
            <div class="card-body">
                <!-- Form skeleton while the product + steps load. -->
                <div v-if="isLoadingData">
                    <div class="d-flex gap-2 mb-4">
                        <div v-for="n in 5" :key="'epstep-' + n" class="skel" style="flex:1;height:44px;border-radius:.5rem"></div>
                    </div>
                    <div class="skel skel-line" style="width:28%;height:1rem;margin-bottom:1.2rem"></div>
                    <div class="row g-3">
                        <div v-for="n in 6" :key="'epfield-' + n" class="col-md-6">
                            <div class="skel skel-line" style="width:35%;margin-bottom:.5rem"></div>
                            <div class="skel" style="height:40px;border-radius:.4rem"></div>
                        </div>
                    </div>
                </div>

                <template v-else>
                    <ul class="step-indicator d-flex list-unstyled mb-4">
                        <li v-for="(s, idx) in steps" :key="s.id"
                            class="step-item flex-fill text-center p-2 border rounded mx-1" :class="{
                                'bg-primary text-white': currentStep === s.id,
                                'bg-success text-white': currentStep > s.id,
                                'bg-light text-muted': currentStep < s.id,
                                'cursor-pointer': currentStep > s.id,
                            }" @click="onStepClick(s.id)">
                            <span class="step-num me-1">{{ idx + 1 }}.</span>
                            <span class="step-label">{{ __(s.label) }}</span>
                        </li>
                    </ul>

                    <!-- STEP 1: CATEGORY (no language tabs needed) -->
                    <div v-if="currentStep === 1">
                        <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-2">
                            <h6 class="cat-level-label text-uppercase mb-0">
                                {{ __('category') }} <span class="text-danger">*</span>
                            </h6>

                            <div class="d-flex gap-2"
                                v-if="$can('category_create') || $can('attribute_create')">
                                <button type="button" class="btn btn-sm btn-outline-success"
                                    v-if="$can('category_create')" @click="openCategoryModal()">
                                    <Plus :size="15" /> {{ __('add_category') }}
                                </button>
                                <button type="button" class="btn btn-sm btn-outline-primary"
                                    v-if="$can('attribute_create')"
                                    :disabled="!effectiveCategoryId" @click="openAttributeModal(null)">
                                    <Plus :size="15" /> {{ __('add_attribute') }}
                                </button>
                            </div>
                        </div>

                        <div class="cat-picker mb-3">
                            <AppSelect class="form-control form-select" :options="categoryTreeOptions"
                                :model-value="effectiveCategoryId || ''" :searchable="true"
                                :placeholder="__('select_category')"
                                @update:model-value="pickCategoryFromTree" />
                            <small class="text-muted">{{ __('only_last_level_category_hint') }}</small>
                        </div>

                        <div v-if="selectedCategoryPath.length" class="cat-path mb-3">
                            <template v-for="(c, i) in selectedCategoryPath" :key="'cp-' + c.id">
                                <span v-if="i" class="cat-path-sep">›</span>
                                <span :class="{ 'cat-path-leaf': i === selectedCategoryPath.length - 1 }">
                                    {{ catLabel(c) }}
                                </span>
                            </template>
                        </div>
                        <div v-else-if="categoryLevelsLoading" class="skel skel-line cat-path-skel mb-3"></div>

                        <div v-if="effectiveCategoryId" class="mt-4">
                            <h6 class="mb-2">{{ __('attributes_from_category') }}</h6>
                            <p class="text-muted small mb-2">{{ __('attributes_will_be_used_to_build_variants') }}</p>
                            <div v-if="categoryAttributes.length === 0" class="text-muted small p-3 border rounded">
                                {{ __('no_attributes_in_selected_category') }}
                            </div>
                            <div v-else class="row">
                                <div v-for="attr in categoryAttributes" :key="'ca-' + attr.id" class="col-md-6 mb-2">
                                    <div
                                        class="attr-card p-2 border rounded d-flex justify-content-between align-items-center text-start">
                                        <div class="text-start">
                                            <div class="fw-bold">{{ attrLabel(attr) }}</div>
                                            <div class="small text-muted">
                                                {{ valueCount(attr) }} {{ __('values') }}:
                                                <span v-for="(v, vi) in (attr.values || []).slice(0, 5)"
                                                    :key="'vp-' + attr.id + '-' + v.id">
                                                    {{ valueLabel(v) }}<span
                                                        v-if="vi < Math.min(4, (attr.values || []).length - 1)">,
                                                    </span>
                                                </span>
                                                <span v-if="(attr.values || []).length > 5">…</span>
                                            </div>
                                        </div>
                                        <button type="button" class="btn btn-sm btn-outline-secondary"
                                            v-if="$can('attribute_update')" @click="openAttributeModal(attr)">
                                            <Pencil :size="15" /> {{ __('manage_values') }}
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <b-tabs v-show="(currentStep === 2 || currentStep === 4) && languages.length > 0" v-model="activeLanguageTab"
                        content-class="mt-3" :nav-class="languages.length <= 1 ? 'd-none' : null">
                        <b-tab v-for="lang in languages" :key="lang.id" :title="lang.name">
                            <template #title>
                                <span :class="{ 'text-primary font-weight-bold': lang.is_default }">{{ lang.name
                                    }}</span>
                            </template>

                            <!-- STEP 2: PRODUCT DETAILS -->
                            <div v-if="currentStep === 2">
                                <h5>{{ __('product_details') }}</h5>
                                <div class="row">
                                    <div class="col-md-6 col-lg-4">
                                        <div class="form-group">
                                            <label>{{ __('product_name') }} <span v-if="lang.is_default" class="text-danger">*</span></label>
                                            <input type="text" class="form-control"
                                                v-model="translations[lang.id].name"
                                                :placeholder="__('product_name')" />
                                        </div>
                                    </div>

                                    <div class="col-md-6 col-lg-4" v-if="lang.is_default">
                                        <div class="form-group">
                                            <div class="d-flex justify-content-between align-items-center mb-1">
                                                <label class="mb-0">{{ __('brand') }}</label>
                                                <a href="#" v-if="$can('brand_create')"
                                                    class="small text-primary d-inline-flex align-items-center gap-1 text-nowrap"
                                                    @click.prevent="openBrandModal">
                                                    <Plus :size="14" /> {{ __('add_brand') }}
                                                </a>
                                            </div>
                                            <AppSelect class="form-control form-select" v-model="basics.brand_id" :options="brands"
                                                :placeholder="__('select_brand')" />
                                        </div>
                                    </div>

                                    <div class="col-md-6 col-lg-4" v-if="lang.is_default">
                                        <div class="form-group">
                                            <label>{{ __('tax_category') }}</label>
                                            <AppSelect class="form-control form-select" v-model="basics.tax_category_id"
                                                :options="taxCategoryOptions" :placeholder="__('no_tax')" />
                                            <small class="text-muted d-block">{{ __('tax_category_product_hint') }}</small>
                                        </div>
                                    </div>

                                    <div class="col-md-6 col-lg-4" v-if="lang.is_default">
                                        <div class="form-group">
                                            <label>{{ __('product_type') }}</label>
                                            <AppSelect class="form-control form-select" v-model="basics.product_type" :options="product_typeOptions" :searchable="false" />
                                        </div>
                                    </div>

                                    <!-- Food is its own flag, not a product_type value: a food item is
                                         also veg or non-veg, so the two cannot share one column. -->
                                    <div class="col-md-6 col-lg-4" v-if="lang.is_default">
                                        <div class="form-group">
                                            <label class="d-block">{{ __('food_item_question') }}
                                                <Info :size="14" class="text-muted ms-1" v-b-tooltip.hover
                                                    :title="__('food_item_hint')" />
                                            </label>
                                            <div class="btn-group btn-group-toggle" role="group">
                                                <label class="btn btn-outline-primary" :class="{ active: basics.is_food == 0 }">
                                                    <input type="radio" :value="0" v-model.number="basics.is_food" autocomplete="off"> {{ __('no') }}
                                                </label>
                                                <label class="btn btn-outline-primary" :class="{ active: basics.is_food == 1 }">
                                                    <input type="radio" :value="1" v-model.number="basics.is_food" autocomplete="off"> {{ __('yes') }}
                                                </label>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Its own field, beside the answer it belongs to: the label
                                         carries the meaning so the button stays short. Addons open
                                         in a modal, never a new page — leaving the form would throw
                                         away everything unsaved — and they hang off a SAVED
                                         product, so the button waits for one to exist. -->
                                    <div class="col-md-6 col-lg-4" v-if="lang.is_default && basics.is_food == 1">
                                        <div class="form-group">
                                            <label class="d-block">{{ __('set_addons_for_this_product') }}
                                                <Info :size="14" class="text-muted ms-1" v-b-tooltip.hover
                                                    :title="__('addon_setup_hint')" />
                                            </label>
                                            <button type="button" class="btn btn-outline-primary"
                                                :disabled="!id && !canDraftSave()"
                                                v-b-tooltip.hover
                                                :title="(!id && !canDraftSave()) ? __('addons_need_category_and_name') : ''"
                                                @click="openAddons">
                                                <ListPlus :size="14" /> {{ __('addon_setup') }}
                                            </button>
                                        </div>
                                    </div>


                                    <!-- An item that exists only to ride along on another
                                         product's addon list: attachable, but never listed. -->
                                    <div class="col-md-6 col-lg-4" v-if="lang.is_default">
                                        <div class="form-group">
                                            <label class="d-block">{{ __('addon_only_item_question') }}
                                                <Info :size="14" class="text-muted ms-1" v-b-tooltip.hover
                                                    :title="__('addon_only_item_hint')" />
                                            </label>
                                            <div class="btn-group btn-group-toggle" role="group">
                                                <label class="btn btn-outline-primary" :class="{ active: basics.is_addon_only == 0 }">
                                                    <input type="radio" :value="0" v-model.number="basics.is_addon_only" autocomplete="off"> {{ __('no') }}
                                                </label>
                                                <label class="btn btn-outline-primary" :class="{ active: basics.is_addon_only == 1 }">
                                                    <input type="radio" :value="1" v-model.number="basics.is_addon_only" autocomplete="off"> {{ __('yes') }}
                                                </label>
                                            </div>
                                        </div>
                                    </div>


                                    <div class="col-md-6 col-lg-4" v-if="lang.is_default && basics.product_type === 5">
                                        <div class="form-group">
                                            <label class="d-block">{{ __('prescription_required') }}</label>
                                            <div class="btn-group btn-group-toggle" role="group">
                                                <label class="btn btn-outline-primary" :class="{ active: basics.is_prescription_required == 0 }">
                                                    <input type="radio" :value="0" v-model.number="basics.is_prescription_required" autocomplete="off"> {{ __('no') }}
                                                </label>
                                                <label class="btn btn-outline-primary" :class="{ active: basics.is_prescription_required == 1 }">
                                                    <input type="radio" :value="1" v-model.number="basics.is_prescription_required" autocomplete="off"> {{ __('yes') }}
                                                </label>
                                            </div>
                                            <small class="text-muted d-block mb-2">{{ __('prescription_required_hint')}}</small>
                                        </div>
                                    </div>

                                    <div class="col-md-6 col-lg-4">
                                        <div class="form-group">
                                            <label>{{ __('manufacturer') }}</label>
                                            <input type="text" class="form-control"
                                                v-model="translations[lang.id].manufacturer"
                                                :placeholder="__('enter_manufacturer')" />
                                        </div>
                                    </div>

                                    <div class="col-md-6 col-lg-4">
                                        <div class="form-group">
                                            <label>{{ __('tags') }}</label>
                                            <input type="text" class="form-control"
                                                v-model="translations[lang.id].tags"
                                                :placeholder="__('enter_comma_separated_tags')" />
                                            <small class="text-muted">{{ __('separate_tags_with_comma') }}</small>
                                        </div>
                                    </div>

                                    <div class="col-md-6 col-lg-4">
                                        <div class="form-group">
                                            <label>{{ __('made_in') }}</label>
                                            <input type="text" class="form-control"
                                                v-model="translations[lang.id].made_in"
                                                :placeholder="__('enter_country_name')">
                                        </div>
                                    </div>


                                    <div class="col-md-6 col-lg-4" v-if="lang.is_default">
                                        <div class="form-group">
                                            <label>{{ __('sales_channel') }}</label>
                                            <AppSelect class="form-control form-select" v-model="basics.sales_channel" :options="sales_channelOptions" :searchable="false" @update:model-value="onSalesChannelChange" />
                                            <small class="text-muted">{{ __('branches_listed_match_this_channel')
                                                }}</small>
                                        </div>
                                    </div>

                                    <div class="col-md-6 col-lg-4" v-if="lang.is_default">
                                        <div class="form-group">
                                            <label>{{ __('total_allowed_quantity_in_cart') }}</label>
                                            <input type="number" class="form-control"
                                                v-model.number="basics.total_allowed_quantity" min="0" />
                                            <small class="text-muted">{{ __('keep_0_for_no_limit') }}</small>
                                        </div>
                                    </div>

                                    <div class="col-md-6 col-lg-4" v-if="lang.is_default">
                                        <div class="form-group">
                                            <label class="d-block">{{ __('status') }}</label>
                                            <div class="btn-group btn-group-toggle" role="group">
                                                <label class="btn btn-outline-primary" :class="{ active: basics.status == 0 }">
                                                    <input type="radio" :value="0" v-model.number="basics.status" autocomplete="off"> {{ __('deactivate') }}
                                                </label>
                                                <label class="btn btn-outline-primary" :class="{ active: basics.status == 1 }">
                                                    <input type="radio" :value="1" v-model.number="basics.status" autocomplete="off"> {{ __('activate') }}
                                                </label>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="col-md-12">
                                        <div class="form-group">
                                            <div class="d-flex justify-content-between align-items-center mb-1">
                                                <label class="mb-0">{{ __('short_description') }} <small
                                                        class="text-muted">({{ __('optional')
                                                        }})</small></label>
                                                <button v-if="lang.is_default" type="button"
                                                    class="btn btn-sm btn-outline-primary"
                                                    :disabled="aiDescLoading" @click="startAiGenerate('desc', lang)">
                                                    <b-spinner v-if="aiDescLoading" small></b-spinner>
                                                    <Sparkles v-else :size="15" /> {{ __('generate_with_ai') }}
                                                </button>
                                            </div>
                                            <div class="ai-wrap" :class="{ 'ai-generating': aiDescLoading }">
                                                <textarea class="form-control ai-field" rows="2"
                                                    v-model="translations[lang.id].short_description"
                                                    :placeholder="__('enter_short_description')"></textarea>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="col-md-12">
                                        <div class="form-group required">
                                            <label>{{ __('description') }} <i class="text-danger">*</i></label>
                                            <div class="ai-wrap" :class="{ 'ai-generating': aiDescLoading }">
                                                <editor v-model="translations[lang.id].description" :init="tinymceInit"
                                                    tinymce-script-src="/assets/js/tinymce/tinymce.min.js?v=7922"
                                                    license-key="gpl" />
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <hr class="my-4" v-if="lang.is_default" />
                                <h5 v-if="lang.is_default">{{ __('return_and_cancellation_policy') }}</h5>
                                <div class="row" v-if="lang.is_default">
                                    <div class="col-md-4">
                                        <div class="form-group">
                                            <label>{{ __('return_status') }}</label>
                                            <AppSelect class="form-control form-select" v-model="basics.return_status" :options="return_statusOptions" :searchable="false" />
                                        </div>
                                    </div>
                                    <div class="col-md-4" v-if="basics.return_status === 1">
                                        <div class="form-group">
                                            <label>{{ __('return_days') }}</label>
                                            <input type="number" class="form-control"
                                                v-model.number="basics.return_days" min="0" />
                                        </div>
                                    </div>
                                    <div class="col-md-4">
                                        <div class="form-group">
                                            <label>{{ __('cancelable') }}</label>
                                            <AppSelect class="form-select form-select-sm" v-model="basics.cancelable_status" :options="cancelable_statusOptions" :searchable="false" />
                                        </div>
                                    </div>
                                    <div class="col-md-4" v-if="basics.cancelable_status === 1 && showQuickTill">
                                        <div class="form-group">
                                            <label>{{ __('cancellable_till') }} <span v-if="showEcomTill">({{ __('quick') }})</span></label>
                                            <AppSelect class="form-control form-select"
                                                v-model="basics.till_status_quick"
                                                :options="quickTillSelectOptions" :searchable="false" />
                                        </div>
                                    </div>
                                    <div class="col-md-4" v-if="basics.cancelable_status === 1 && showEcomTill">
                                        <div class="form-group">
                                            <label>{{ __('cancellable_till') }} <span v-if="showQuickTill">({{ __('ecommerce') }})</span></label>
                                            <AppSelect class="form-control form-select"
                                                v-model="basics.till_status_ecommerce"
                                                :options="ecomTillSelectOptions" :searchable="false" />
                                        </div>
                                    </div>
                                    <div class="col-md-4">
                                        <div class="form-group">
                                            <label>{{ __('cod_available') }}</label>
                                            <AppSelect class="form-select form-select-sm" v-model="basics.cod_allowed" :options="cod_allowedOptions" :searchable="false" />
                                        </div>
                                    </div>
                                </div>

                            </div>

                            <!-- STEP 4: SEO (per-language, inside the tabs) -->
                            <div v-if="currentStep === 4">
                                <div class="d-flex justify-content-between align-items-center mb-2">
                                    <h5 class="mb-0">{{ __('seo') }}</h5>
                                    <button v-if="lang.is_default" type="button"
                                        class="btn btn-sm btn-outline-primary"
                                        :disabled="aiSeoLoading" @click="startAiGenerate('seo', lang)">
                                        <b-spinner v-if="aiSeoLoading" small></b-spinner>
                                        <Sparkles v-else :size="15" /> {{ __('generate_seo_with_ai') }}
                                    </button>
                                </div>
                                <div class="row">
                                    <div class="col-md-6">
                                        <div class="form-group">
                                            <label>{{ __('meta_title') }}</label>
                                            <div class="ai-wrap" :class="{ 'ai-generating': aiSeoLoading }">
                                                <input type="text" class="form-control ai-field"
                                                    v-model="translations[lang.id].meta_title" />
                                            </div>
                                        </div>
                                    </div>
                                    <div class="col-md-6">
                                        <div class="form-group">
                                            <label>{{ __('meta_keywords') }}</label>
                                            <div class="ai-wrap" :class="{ 'ai-generating': aiSeoLoading }">
                                                <input type="text" class="form-control ai-field"
                                                    v-model="translations[lang.id].meta_keywords" />
                                            </div>
                                        </div>
                                    </div>
                                    <div class="col-md-6">
                                        <div class="form-group">
                                            <label>{{ __('meta_description') }}</label>
                                            <div class="ai-wrap" :class="{ 'ai-generating': aiSeoLoading }">
                                                <textarea class="form-control ai-field" rows="2"
                                                    v-model="translations[lang.id].meta_description"></textarea>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="col-md-6">
                                        <div class="form-group">
                                            <label>{{ __('schema_markup') }}</label>
                                            <textarea class="form-control" rows="2"
                                                v-model="translations[lang.id].schema_markup"></textarea>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- STEP 4: REVIEW -->
                        </b-tab>

                        <!-- Translate control, inline with the language tabs. -->
                        <template #tabs-end>
                            <li class="nav-item ms-auto d-flex align-items-center">
                                <TranslateLanguages :languages="languages" :default-language-id="defaultLanguageId"
                                    :busy="translating" :progress="translateProgress" @translate="runTranslate" />
                            </li>
                        </template>
                    </b-tabs>

                    <!-- STEP 4: REVIEW (outside language tabs) -->
                    <div v-show="currentStep === 5">
                        <div class="alert alert-info d-flex align-items-center review-banner">
                            <Info :size="16" class="me-2 flex-shrink-0" />
                            <span>{{ __('review_all_variations_help') }}</span>
                        </div>

                        <div class="review-summary d-flex flex-wrap mb-4">
                            <div class="review-summary-cell">
                                <div class="rs-label">{{ __('category') }}</div>
                                <div class="rs-value">{{ reviewCategoryName }}</div>
                            </div>
                            <div class="review-summary-cell">
                                <div class="rs-label">{{ __('subcategory') }}</div>
                                <div class="rs-value">{{ reviewSubCategoryName }}</div>
                            </div>
                            <div class="review-summary-cell">
                                <div class="rs-label">{{ __('brand') }}</div>
                                <div class="rs-value">{{ reviewBrandName }}</div>
                            </div>
                            <div class="review-summary-cell">
                                <div class="rs-label">{{ __('sales_channel') }}</div>
                                <div class="rs-value">{{ salesChannelLabel }}</div>
                            </div>
                            <div class="review-summary-cell">
                                <div class="rs-label">{{ __('products_to_create') }}</div>
                                <div class="rs-value text-primary fw-bold">{{ variants.length }}</div>
                            </div>
                        </div>

                        <div class="row">
                            <div class="col-lg-4" v-for="(v, idx) in variants" :key="'rvc-' + idx">
                                <div class="card review-variant-card">
                                    <div class="card-body d-flex">
                                        <div class="review-variant-media">
                                            <div class="rv-main">
                                                <img v-if="v.image_preview" :src="v.image_preview" alt="" />
                                                <div v-else class="review-variant-noimg">
                                                    <ImageIcon :size="28" />
                                                </div>
                                            </div>
                                            <div v-for="(g, gi) in reviewGallery(v)" :key="'rvg-' + idx + '-' + gi"
                                                class="rv-thumb">
                                                <video v-if="g.video" :src="g.url" controls muted playsinline></video>
                                                <img v-else :src="g.url" alt="" />
                                            </div>
                                        </div>
                                        <div class="review-variant-info flex-grow-1">
                                            <div class="d-flex align-items-baseline mb-2">
                                                <span class="text-muted me-2 flex-shrink-0">{{ __('variant') }} #{{ idx
                                                    + 1 }}</span>
                                                <h6 class="mb-0 rv-name">
                                                    {{ v.translations[defaultLanguageId]?.name || variantAttrSummary(v)
                                                    }}
                                                </h6>
                                            </div>
                                            <table class="rv-kv">
                                                <tbody>
                                                    <tr>
                                                        <td>{{ __('sku') }}</td>
                                                        <td>{{ v.sku || '—' }}</td>
                                                    </tr>
                                                    <tr>
                                                        <td>{{ __('hsn_code') }}</td>
                                                        <td>{{ v.hsn_code || '—' }}</td>
                                                    </tr>
                                                    <tr>
                                                        <td>{{ __('shipping') }}</td>
                                                        <td>{{ shippingSummary(v) }}</td>
                                                    </tr>
                                                    <tr>
                                                        <td>{{ __('selling') }}</td>
                                                        <td>{{ variantPriceSummary(v).sell }}</td>
                                                    </tr>
                                                    <tr>
                                                        <td>{{ __('purchase') }}</td>
                                                        <td>{{ variantPriceSummary(v).purchase }}</td>
                                                    </tr>
                                                    <tr>
                                                        <td>{{ __('listed_branches') }}</td>
                                                        <td>{{ variantPriceSummary(v).listedCount }}</td>
                                                    </tr>
                                                </tbody>
                                            </table>
                                            <div v-if="variantAttrChips(v).length" class="d-flex flex-wrap gap-2 mt-2">
                                                <span class="rv-attr-chip" v-for="(c, ci) in variantAttrChips(v)"
                                                    :key="'rvac-' + idx + '-' + ci">
                                                    <strong>{{ c.label }}:</strong> {{ c.value }}
                                                </span>
                                            </div>
                                            <div class="d-flex flex-wrap gap-2 mt-2">
                                                <span class="rv-tag">{{ basics.return_status ? __('returnable') :
                                                    __('no_returns') }}</span>
                                                <span class="rv-tag">{{ basics.cancelable_status ? __('cancelable') :
                                                    __('no_cancel')
                                                    }}</span>
                                                <span v-if="basics.cod_allowed" class="rv-tag rv-tag-cod">{{ __('cod')
                                                    }}</span>
                                            </div>
                                            <div v-for="(sec, si) in variantCustomSections(v)"
                                                :key="'rvcs-' + idx + '-' + si" class="rv-custom-section mt-2">
                                                <div class="rv-custom-title">{{ sec.name }}</div>
                                                <table class="rv-kv">
                                                    <tbody>
                                                        <tr v-for="(it, ii) in sec.items"
                                                            :key="'rvci-' + idx + '-' + si + '-' + ii">
                                                            <td>{{ it.label }}</td>
                                                            <td>{{ it.value }}</td>
                                                        </tr>
                                                    </tbody>
                                                </table>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- STEP 3: VARIANT MATRIX + DETAILS (outside language tabs) -->
                    <div v-show="currentStep === 3">
                        <div class="mb-4">
                            <h5>{{ __('variant_matrix') }}</h5>
                            <p class="text-muted small">{{ __('select_values_for_each_attribute_help') }}</p>
                            <div v-if="categoryAttributes.length === 0" class="text-muted">
                                {{ __('no_attributes_in_selected_category') }}
                            </div>

                            <div v-for="attr in categoryAttributes" :key="'attr-' + attr.id" class="mb-3 attr-block">
                                <div class="attr-head">
                                    <label class="fw-bold mb-0">{{ attrLabel(attr) }}</label>
                                    <span v-if="attrSelectedCount(attr)" class="attr-count">
                                        {{ attrSelectedCount(attr) }} {{ __('selected') }}
                                    </span>
                                </div>
                                <AppSelect class="form-control form-select" multiple
                                    :options="attrValueOptions(attr)"
                                    :model-value="selectedValuesByAttr[attr.id] || []"
                                    :placeholder="__('select_values')"
                                    @update:model-value="setAttrValues(attr.id, $event)" />
                            </div>

                            <div v-if="categoryAttributes.length > 0"
                                class="alert alert-info py-2 small mb-0 d-flex justify-content-between align-items-center">
                                <span>{{ __('total_variants_will_be_generated') }}: <strong>{{ generatedVariantCount
                                        }}</strong></span>
                                <button type="button" class="btn btn-sm btn-primary" @click="generateAllVariants">
                                    <Zap :size="15" /> {{ __('generate_all_variants') }}
                                </button>
                            </div>
                        </div>

                        <hr />

                        <div v-if="variants.length === 0" class="text-muted text-center p-4">
                            {{ __('no_variants_generated_select_attribute_values') }}
                        </div>

                        <template v-else>
                            <h5 class="mb-3">{{ __('product_variants') }}</h5>

                            <draggable v-model="variants" :item-key="variantKey" handle=".pv-grip"
                                :animation="180" ghost-class="pv-drag-ghost" tag="div"
                                class="d-flex flex-wrap gap-2 mb-3" @end="onVariantDragEnd">
                                <template #item="{ element: v, index: vIdx }">
                                    <div class="btn-group btn-group-sm">
                                        <span class="btn pv-grip"
                                            :class="activeVariantTab === vIdx ? 'btn-primary' : 'btn-outline-primary'"
                                            v-b-tooltip.hover :title="__('drag_to_reorder')">
                                            <GripVertical :size="14" />
                                        </span>
                                        <button type="button" class="btn"
                                            :class="activeVariantTab === vIdx ? 'btn-primary' : 'btn-outline-primary'"
                                            @click="activeVariantTab = vIdx">
                                            #{{ vIdx + 1 }} — {{ variantAttrSummary(v) ||
                                                v.translations[defaultLanguageId]?.name }}
                                        </button>
                                        <button type="button" class="btn"
                                            :class="activeVariantTab === vIdx ? 'btn-primary' : 'btn-outline-primary'"
                                            :title="__('remove_variant')" @click.stop="removeVariant(vIdx)">
                                            <X :size="15" />
                                        </button>
                                    </div>
                                </template>
                            </draggable>

                            <template v-for="(v, vIdx) in variants" :key="'vbody-' + (v.tmpKey || v.id)">
                                <div v-if="activeVariantTab === vIdx">
                                    <ul class="nav nav-tabs mb-3">
                                        <li class="nav-item" v-for="(lang, lidx) in languages"
                                            :key="'vlng-' + vIdx + '-' + lang.id">
                                            <button type="button" class="nav-link"
                                                :class="{ active: activeVariantLangTab === lidx }"
                                                @click="activeVariantLangTab = lidx">
                                                <span :class="{ 'text-primary font-weight-bold': lang.is_default }">{{
                                                    lang.name }}</span>
                                            </button>
                                        </li>
                                    </ul>

                                    <div class="mb-3" v-if="vIdx > 0">
                                        <button type="button" class="btn btn-sm btn-outline-secondary"
                                            @click="copyFromFirstVariant(vIdx)">
                                            <Copy :size="14" class="me-1" /> {{ __('copy_data_from_first_variant') }}
                                        </button>
                                    </div>

                                    <div class="row" v-if="currentVariantLang">
                                        <div :class="currentVariantLang.id === defaultLanguageId ? 'col-md-6' : 'col-md-12'">
                                            <div class="form-group required">
                                                <label>{{ __('variant_name') }} <i class="text-danger">*</i></label>
                                                <input type="text" class="form-control"
                                                    v-model="v.translations[currentVariantLang.id].name"
                                                    :placeholder="__('variant_name_placeholder')" />
                                            </div>
                                        </div>

                                        <template v-if="currentVariantLang.id === defaultLanguageId">
                                            <div class="col-md-3">
                                                <div class="form-group required">
                                                    <label>{{ __('sku') }} <i class="text-danger">*</i></label>
                                                    <input type="text" class="form-control"
                                                        :class="{ 'is-invalid': v.skuError }"
                                                        v-model="v.sku" @input="onSkuInput(v)" />
                                                    <small v-if="v.skuError" class="text-danger d-block mt-1">{{ v.skuError }}</small>
                                                </div>
                                            </div>
                                            <div class="col-md-3">
                                                <div class="form-group">
                                                    <label>{{ __('hsn_code') }}
                                                        <Info :size="14" class="text-muted ms-1" v-b-tooltip.hover
                                                            :title="__('hsn_code_hint')" />
                                                    </label>
                                                    <input type="text" class="form-control" v-model="v.hsn_code" />
                                                </div>
                                            </div>
                                            <!-- Shipping: what a courier quotes on. Optional — a
                                                 shipping integration falls back to its default box. -->
                                            <div class="col-md-3">
                                                <div class="form-group">
                                                    <label>{{ __('shipping_weight') }} ({{ __('kg') }})
                                                        <Info :size="14" class="text-muted ms-1" v-b-tooltip.hover
                                                            :title="__('shipping_weight_hint')" />
                                                    </label>
                                                    <input type="number" min="0" step="0.001" class="form-control"
                                                        v-model="v.weight" :placeholder="__('e_g_0_5')" />
                                                </div>
                                            </div>
                                            <div class="col-md-3">
                                                <div class="form-group">
                                                    <label>{{ __('package_size') }} ({{ __('cm') }})
                                                        <Info :size="14" class="text-muted ms-1" v-b-tooltip.hover
                                                            :title="__('package_size_hint')" />
                                                    </label>
                                                    <div class="d-flex gap-1">
                                                        <input type="number" min="0" step="0.01" class="form-control"
                                                            v-model="v.length" :placeholder="__('length_short')" />
                                                        <input type="number" min="0" step="0.01" class="form-control"
                                                            v-model="v.breadth" :placeholder="__('breadth_short')" />
                                                        <input type="number" min="0" step="0.01" class="form-control"
                                                            v-model="v.height" :placeholder="__('height_short')" />
                                                    </div>
                                                </div>
                                            </div>
                                            <div class="w-100"></div>
                                            <div class="col-md-12 col-lg-6">
                                                <FileUpload v-model="v.image_file" :label="__('main_image')" required
                                                    accept="image/*" recommended-size="800x800px"
                                                    :preview-url="v.image_url"
                                                    @change="onVariantMainImage($event, vIdx)" />
                                                <button type="button" class="btn btn-sm btn-outline-primary mt-1"
                                                    @click="openMediaPicker('main', vIdx)">
                                                    <ImageIcon :size="14" /> {{ __('choose_from_media') }}
                                                </button>
                                            </div>

                                            <div class="col-md-12 col-lg-6">
                                                <FileUpload :label="__('other_images')" :accept="galleryAccept"
                                                    multiple :recommended-text="galleryHint"
                                                    :max-size-mb="galleryMaxMb" :show-preview="false"
                                                    @change="onVariantGallery($event, vIdx)" />
                                                <button type="button" class="btn btn-sm btn-outline-primary mt-1"
                                                    @click="openMediaPicker('gallery', vIdx)">
                                                    <ImageIcon :size="14" /> {{ __('choose_from_media') }}
                                                </button>
                                                <div class="d-flex flex-wrap gap-2 mt-2">
                                                    <div v-for="(g, gIdx) in v.gallery_keep" :key="'gk-' + gIdx"
                                                        class="position-relative">
                                                        <video v-if="isVideoUrl(g.url)" :src="g.url" controls muted
                                                            playsinline style="max-height: 70px;"></video>
                                                        <img v-else :src="g.url" alt="" style="max-height: 70px;" />
                                                        <button type="button"
                                                            class="btn btn-sm btn-danger position-absolute top-0 end-0"
                                                            @click="removeKeptGalleryImage(vIdx, gIdx)">
                                                            <X :size="14" />
                                                        </button>
                                                    </div>
                                                    <div v-for="(p, pIdx) in v.gallery_previews" :key="'gp-' + pIdx"
                                                        class="position-relative">
                                                        <!-- previews and gallery_files stay index-aligned, so the
                                                             picked file's own MIME type decides the tag. A blob URL
                                                             carries no extension to read it off. -->
                                                        <video v-if="isVideoFile(v.gallery_files[pIdx])" :src="p"
                                                            controls muted playsinline
                                                            style="max-height: 70px;"></video>
                                                        <img v-else :src="p" alt="" style="max-height: 70px;" />
                                                        <button type="button"
                                                            class="btn btn-sm btn-danger position-absolute top-0 end-0"
                                                            @click="removeNewGalleryImage(vIdx, pIdx)">
                                                            <X :size="14" />
                                                        </button>
                                                    </div>
                                                    <div v-for="(m, mIdx) in v.gallery_media" :key="'gm-' + mIdx"
                                                        class="position-relative">
                                                        <video v-if="isVideoUrl(m.url)" :src="m.url" controls muted
                                                            playsinline style="max-height: 70px;"></video>
                                                        <img v-else :src="m.url" alt="" style="max-height: 70px;" />
                                                        <button type="button"
                                                            class="btn btn-sm btn-danger position-absolute top-0 end-0"
                                                            @click="v.gallery_media.splice(mIdx, 1)">
                                                            <X :size="14" />
                                                        </button>
                                                    </div>
                                                </div>
                                            </div>

                                            <div class="col-md-12" v-if="categoryCustomSections.length > 0">
                                                <hr />
                                                <h6 class="fw-bold mb-1">
                                                    {{ __('custom_sections') }}
                                                </h6>
                                                <template v-for="section in categoryCustomSections"
                                                    :key="'sec-' + section.id + '-' + vIdx">
                                                    <div class="custom-section mb-3 p-3 border rounded">
                                                        <h6 class="fw-bold mb-3">{{ sectionLabelForLang(section,
                                                            currentVariantLang.id) }}</h6>
                                                        <div class="row">
                                                            <template v-for="field in section.fields"
                                                                :key="'cf-' + field.id + '-' + vIdx">
                                                                <div class="col-md-6">
                                                                    <div class="form-group">
                                                                        <label>
                                                                            {{ fieldLabelForLang(field,
                                                                            currentVariantLang.id) }}
                                                                            <i v-if="field.is_required"
                                                                                class="text-danger">*</i>
                                                                        </label>
                                                                        <input v-if="field.field_type === 'text'"
                                                                            type="text" class="form-control"
                                                                            :value="rawCustomScalar(v, field, currentVariantLang)"
                                                                            @input="setCustomScalar(v, field, currentVariantLang, $event.target.value)" />
                                                                        <textarea
                                                                            v-else-if="field.field_type === 'textarea'"
                                                                            class="form-control" rows="2"
                                                                            :value="rawCustomScalar(v, field, currentVariantLang)"
                                                                            @input="setCustomScalar(v, field, currentVariantLang, $event.target.value)"></textarea>
                                                                        <input
                                                                            v-else-if="field.field_type === 'number'"
                                                                            type="number"
                                                                            class="form-control"
                                                                            :value="rawCustomScalar(v, field, defaultLangObj)"
                                                                            @input="setCustomScalar(v, field, defaultLangObj, $event.target.value)" />
                                                                        <DatePicker
                                                                            v-else-if="field.field_type === 'date'"
                                                                            :model-value="rawCustomScalar(v, field, defaultLangObj)"
                                                                            @update:model-value="setCustomScalar(v, field, defaultLangObj, $event)" />
                                                                        <AppSelect
                                                                            v-else-if="field.field_type === 'dropdown'"
                                                                            class="form-control form-select"
                                                                            :model-value="rawCustomScalar(v, field, defaultLangObj)"
                                                                            :options="scalarOptions(fieldOptionsForLang(field, currentVariantLang.id))"
                                                                            :placeholder="__('select')"
                                                                            @update:model-value="setCustomScalar(v, field, defaultLangObj, $event)" />
                                                                        <AppSelect
                                                                            v-else-if="field.field_type === 'boolean'"
                                                                            class="form-control form-select"
                                                                            :model-value="String(rawCustomScalar(v, field, defaultLangObj) ?? '')"
                                                                            :options="booleanFieldOptions" :searchable="false"
                                                                            :placeholder="__('select')"
                                                                            @update:model-value="setCustomScalar(v, field, defaultLangObj, $event)" />
                                                                        <div
                                                                            v-else-if="field.field_type === 'checkbox'">
                                                                            <div v-for="(opt, oi) in fieldOptionsForLang(field, currentVariantLang.id)"
                                                                                :key="'mopt-' + field.id + '-' + oi"
                                                                                class="form-check form-check-inline">
                                                                                <input class="form-check-input"
                                                                                    type="checkbox"
                                                                                    :id="'mopt-' + field.id + '-' + vIdx + '-' + oi"
                                                                                    :checked="customMultiValues(v, field).includes(opt)"
                                                                                    @change="toggleCustomMulti(v, field, opt)">
                                                                                <label class="form-check-label"
                                                                                    :for="'mopt-' + field.id + '-' + vIdx + '-' + oi">
                                                                                    {{ opt }}
                                                                                </label>
                                                                            </div>
                                                                        </div>
                                                                    </div>
                                                                </div>
                                                            </template>
                                                        </div>
                                                    </div>
                                                </template>
                                            </div>
                                            <!-- Branch-wise inventory (below images) -->
                                            <div class="col-md-12">
                                                <hr />
                                                <div class="d-flex align-items-center mb-3 gap-2">
                                                    <h6 class="fw-bold mb-0">
                                                        {{ __('branch_wise_inventory') }}
                                                        <small class="text-muted">— {{ channelBranches.length }} {{
                                                            __('branches_for_inventory') }}</small>
                                                    </h6>
                                                    <small :id="'siInfo-' + vIdx"
                                                        class="d-inline-flex px-2 py-1 text-muted bg-secondary bg-opacity-10 border border-secondary border-opacity-10 rounded-2"
                                                        style="cursor:pointer;">
                                                        <Info :size="14" />
                                                    </small>
                                                    <b-popover :target="'siInfo-' + vIdx" triggers="hover"
                                                        placement="bottom" body-class="branch-help-popover">
                                                        <div class="text-start">
                                                            <p class="mb-2">{{ __('branch_inventory_hint') }}</p>
                                                            <p class="mb-1"><strong>{{ __('listed') }}</strong> — {{
                                                                __('help_listed') }}</p>
                                                            <p class="mb-1"><strong>{{ __('stock_status') }}</strong> —
                                                                {{ __('help_stock_status') }}</p>
                                                            <p class="mb-1"><strong>{{ __('available') }}</strong> — {{
                                                                __('help_available') }}</p>
                                                            <p class="mb-1"><strong>{{ __('reserved') }}</strong> — {{
                                                                __('help_reserved') }}</p>
                                                            <p class="mb-0"><strong>{{ __('min_alert') }}</strong> — {{
                                                                __('help_min_alert') }}</p>
                                                        </div>
                                                    </b-popover>
                                                    <AppSelect v-if="czShowCountry" class="cz-sel ms-auto"
                                                        v-model="czCountryId" :options="czCountryOptions"
                                                        :searchable="czCountryOptions.length > 6" :allow-empty="false"
                                                        label-key="label" track-by="id" :placeholder="__('country')"
                                                        @update:model-value="czOnCountry">
                                                        <template #singleLabel="{ option }"><span class="cz-opt"><img
                                                                    v-if="option.logo_url" :src="option.logo_url"
                                                                    class="cz-flag" />{{ option.label }}</span></template>
                                                        <template #option="{ option }"><span class="cz-opt"><img
                                                                    v-if="option.logo_url" :src="option.logo_url"
                                                                    class="cz-flag" />{{ option.label }}</span></template>
                                                    </AppSelect>
                                                    <AppSelect v-if="czShowZoneDropdown" class="cz-sel"
                                                        :class="{ 'ms-auto': !czShowCountry }" v-model="czZoneId"
                                                        :options="czZoneOptions" :searchable="false" :allow-empty="false"
                                                        label-key="label" track-by="id" :placeholder="__('zone')"
                                                        @update:model-value="czOnZone" />
                                                    <input v-if="channelBranches.length" type="search"
                                                        class="form-control form-control-sm"
                                                        :class="{ 'ms-auto': !czShowCountry && !czShowZoneDropdown }"
                                                        style="max-width:260px;"
                                                        v-model="branchSearch"
                                                        :placeholder="__('search_branch')" />
                                                </div>

                                                <!-- Fill every other branch from the first card — most catalogues
                                                     price/stock identically across branches. -->
                                                <div class="mb-3" v-if="channelBranches.length > 1">
                                                    <button type="button" class="btn btn-sm btn-outline-primary"
                                                        @click="copyFirstBranchToOthers(v)">
                                                        <Copy :size="14" /> {{ __('copy_first_branch_to_all') }}
                                                    </button>
                                                    <small class="text-muted ms-2">{{ __('copy_first_branch_hint') }}</small>
                                                </div>

                                                <div v-if="!channelBranches.length" class="text-muted mb-3">
                                                    {{ __('no_branches_match_sales_channel') }}
                                                </div>
                                                <div v-else-if="!filteredChannelBranches.length" class="text-muted mb-3">
                                                    {{ __('no_records_found') }}
                                                </div>

                                                <div class="row g-3 justify-content-start text-start" v-else>
                                                    <div class="col-xl-6 col-lg-6 col-md-12 mb-1" v-for="st in filteredChannelBranches"
                                                        :key="'ss-' + vIdx + '-' + st.id">
                                                        <div class="branch-stock-card border rounded p-3 h-100"
                                                            :class="{ 'border-primary shadow-sm': branchStock(v, st.id).is_listed }">
                                                            <!-- Header: branch + listed toggle + currency -->
                                                            <div class="d-flex justify-content-between align-items-start mb-2">
                                                                <div class="text-truncate me-1">
                                                                    <span class="dot-listed"
                                                                        :class="branchStock(v, st.id).is_listed ? 'on' : 'off'"></span>
                                                                    <strong class="small">{{ st.name }}</strong>
                                                                    <div class="text-muted" style="font-size:11px;">
                                                                        {{ st.city || '-' }} · {{ st.fulfillment_type }}
                                                                    </div>
                                                                </div>
                                                                <div class="form-check form-switch d-flex align-items-center gap-2 m-0 ps-0 flex-shrink-0">
                                                                    <label class="form-check-label small mb-0"
                                                                        :for="'lst-' + vIdx + '-' + st.id">{{ __('listed') }}</label>
                                                                    <input class="form-check-input m-0 float-none" type="checkbox" role="switch"
                                                                        :id="'lst-' + vIdx + '-' + st.id"
                                                                        v-model="branchStock(v, st.id).is_listed">
                                                                </div>
                                                            </div>

                                                            <template v-if="branchStock(v, st.id).is_listed">
                                                                <!-- Branch-wise pricing (purchase first) -->
                                                                <div class="row g-2 mb-3">
                                                                    <div class="col-6">
                                                                        <label class="ss-mini-label">{{ __('purchase_price') }} <i class="text-danger">*</i></label>
                                                                        <div class="input-group input-group-sm">
                                                                            <span class="input-group-text px-2">{{ st.currency || $currency }}</span>
                                                                            <input type="number" min="0" step="0.01" class="form-control"
                                                                                v-model.number="branchStock(v, st.id).purchase_price"
                                                                                @input="autofillPurchasePrice(v, st)">
                                                                        </div>
                                                                    </div>
                                                                    <div class="col-6">
                                                                        <label class="ss-mini-label">{{ __('selling_price') }} <i class="text-danger">*</i></label>
                                                                        <div class="input-group input-group-sm">
                                                                            <span class="input-group-text px-2">{{ st.currency || $currency }}</span>
                                                                            <input type="number" min="0" step="0.01" class="form-control"
                                                                                v-model.number="branchStock(v, st.id).price">
                                                                        </div>
                                                                    </div>
                                                                    <div class="col-6">
                                                                        <label class="ss-mini-label">{{ __('discounted_price') }}</label>
                                                                        <div class="input-group input-group-sm">
                                                                            <span class="input-group-text px-2">{{ st.currency || $currency }}</span>
                                                                            <input type="number" min="0" step="0.01" class="form-control"
                                                                                :class="{ 'is-invalid': branchDiscountInvalid(branchStock(v, st.id)) }"
                                                                                v-model.number="branchStock(v, st.id).discounted_price">
                                                                        </div>
                                                                    </div>
                                                                    <div class="col-6">
                                                                        <label class="ss-mini-label">{{ __('customer_price') }}</label>
                                                                        <input type="text" class="form-control form-control-sm" disabled readonly
                                                                            :value="(st.currency || $currency) + branchCustomerPrice(branchStock(v, st.id)).toFixed(2)">
                                                                        <small class="text-muted d-block" style="font-size:10px;line-height:1.2;">{{ __('customer_price_app_note') }}</small>
                                                                    </div>
                                                                    <!-- Whether the entered price already contains tax is a property of
                                                                         the PRICE, not of today's rule, so the switch stays available for
                                                                         every branch once a tax category is picked. A branch that resolves
                                                                         to no rate says so underneath, instead of the field vanishing. -->
                                                                    <div class="col-6" v-if="basics.tax_category_id">
                                                                        <div class="d-flex align-items-center gap-2">
                                                                            <label class="ss-mini-label mb-0"
                                                                                :for="'ss-incl-' + vIdx + '-' + st.id">
                                                                                {{ __('price_includes_tax') }}
                                                                            </label>
                                                                            <div class="form-check form-switch mb-0 ps-0">
                                                                                <input class="form-check-input ms-0" type="checkbox"
                                                                                    :id="'ss-incl-' + vIdx + '-' + st.id"
                                                                                    v-model="branchStock(v, st.id).is_tax_inclusive">
                                                                            </div>
                                                                        </div>
                                                                        <small v-if="branchTaxRegionNote(st.id)" class="text-muted d-block"
                                                                            style="font-size:10px;line-height:1.2;">{{ branchTaxRegionNote(st.id) }}</small>
                                                                        <small v-else-if="branchTaxNote(st.id)" class="text-warning d-block"
                                                                            style="font-size:10px;line-height:1.2;">{{ branchTaxNote(st.id) }}</small>
                                                                    </div>
                                                                    <div class="col-6 small d-flex align-items-center"
                                                                        :class="branchMargin(branchStock(v, st.id)).amount >= 0 ? 'text-success' : 'text-danger'">
                                                                        {{ __('estimated_margin') }}: {{ st.currency || $currency }}{{ branchMargin(branchStock(v, st.id)).amount.toFixed(2) }}<span
                                                                            v-if="branchMargin(branchStock(v, st.id)).percent !== null">&nbsp;({{ branchMargin(branchStock(v, st.id)).percent.toFixed(2) }}%)</span>
                                                                    </div>
                                                                </div>

                                                                <!-- Quantity-based slab pricing (always visible; rows added on demand) -->
                                                                <div class="slab-card border rounded p-3 mb-2">
                                                                    <div class="d-flex justify-content-between align-items-start mb-2">
                                                                        <div>
                                                                            <div class="fw-bold text-uppercase small">{{ __('quantity_based_slab_pricing') }}</div>
                                                                            <div class="text-muted small">{{ __('slab_pricing_hint') }}</div>
                                                                        </div>
                                                                        <button type="button" class="btn btn-sm btn-outline-primary text-nowrap flex-shrink-0"
                                                                            @click="addBranchSlab(branchStock(v, st.id))">+ {{ __('add_slab') }}</button>
                                                                    </div>
                                                                    <template v-if="(branchStock(v, st.id).pricing_slabs || []).length">
                                                                        <!-- Header row (grid columns line up exactly with the inputs below) -->
                                                                        <div class="slab-grid mb-1 fw-bold small text-muted">
                                                                            <div>{{ __('min_qty') }}</div>
                                                                            <div>{{ __('max_qty') }}</div>
                                                                            <div>{{ __('price') }}</div>
                                                                            <div></div>
                                                                        </div>
                                                                        <template v-for="(s, si) in branchStock(v, st.id).pricing_slabs" :key="si">
                                                                            <div class="slab-grid align-items-center">
                                                                                <input type="number" min="2" class="form-control"
                                                                                    :class="{ 'is-invalid': slabMinInvalid(s) }"
                                                                                    :placeholder="__('e_g_2')" v-model.number="s.min_qty">
                                                                                <input type="number" min="0" class="form-control"
                                                                                    :class="{ 'is-invalid': slabMaxInvalid(s) }"
                                                                                    :placeholder="__('blank_unlimited')" v-model.number="s.max_qty">
                                                                                <input type="number" min="0" step="0.01" class="form-control"
                                                                                    :class="{ 'is-invalid': slabPriceInvalid(branchStock(v, st.id), s) }"
                                                                                    :placeholder="__('price_per_unit')" v-model.number="s.price">
                                                                                <button type="button" class="btn btn-outline-danger slab-remove-btn d-inline-flex align-items-center justify-content-center"
                                                                                    :title="__('remove')" @click="removeBranchSlab(branchStock(v, st.id), si)"><X :size="14" /></button>
                                                                            </div>
                                                                            <div v-if="slabRowError(branchStock(v, st.id), s)"
                                                                                class="text-danger mb-2" style="font-size:11px;line-height:1.3;">
                                                                                {{ slabRowError(branchStock(v, st.id), s) }}
                                                                            </div>
                                                                            <div v-else class="mb-2"></div>
                                                                        </template>
                                                                        <div class="text-muted small mt-1">{{ __('slab_pricing_footer') }}</div>
                                                                    </template>
                                                                </div>

                                                                <!-- Inventory. Stock limit is per branch: an unlimited
                                                                     branch never runs out, so its count fields are hidden
                                                                     (the stored values are kept for switching back). -->
                                                                <div class="border-top pt-2">
                                                                    <div class="row g-2">
                                                                        <div class="col-6">
                                                                            <label class="ss-mini-label">{{ __('stock_limit_type') }}</label>
                                                                            <AppSelect class="form-control form-select" v-model="branchStock(v, st.id).is_unlimited_stock" :options="is_unlimited_stockOptions" :searchable="false" />
                                                                        </div>
                                                                        <template v-if="branchStock(v, st.id).is_unlimited_stock !== 1">
                                                                            <div class="col-6">
                                                                                <label class="ss-mini-label">{{ __('stock_status') }}</label>
                                                                                <AppSelect class="form-select form-select-sm" v-model="branchStock(v, st.id).stock_status" :options="stockStatusOptionsFor(branchStock(v, st.id))" :searchable="false" />
                                                                            </div>
                                                                            <div class="col-6">
                                                                                <label class="ss-mini-label">{{ __('available') }}</label>
                                                                                <input type="number" min="0" class="form-control form-control-sm"
                                                                                    v-model.number="branchStock(v, st.id).available"
                                                                                    @input="onBranchAvailableInput(branchStock(v, st.id))">
                                                                            </div>
                                                                            <div class="col-6">
                                                                                <label class="ss-mini-label">{{ __('reserved') }}</label>
                                                                                <input type="number" min="0" class="form-control form-control-sm"
                                                                                    :value="branchStock(v, st.id).reserved" disabled readonly
                                                                                    :title="__('reserved_is_managed_automatically')">
                                                                            </div>
                                                                            <div class="col-6">
                                                                                <label class="ss-mini-label">{{ __('min_alert') }}</label>
                                                                                <input type="number" min="0" class="form-control form-control-sm" v-model.number="branchStock(v, st.id).min_alert">
                                                                            </div>
                                                                        </template>
                                                                        <div class="col-6 d-flex align-items-end" v-else>
                                                                            <small class="text-muted">{{ __('unlimited_stock_hint') }}</small>
                                                                        </div>
                                                                    </div>
                                                                </div>
                                                            </template>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>

                                        </template>

                                        <template v-else>
                                            <template v-for="section in categoryCustomSections"
                                                :key="'tsec-' + section.id + '-' + vIdx + '-' + currentVariantLang.id">
                                                <div v-if="hasTranslatableFields(section)" class="col-md-12 mt-3">
                                                    <div class="custom-section p-3 border rounded">
                                                        <h6 class="fw-bold mb-3">{{ sectionLabelForLang(section,
                                                            currentVariantLang.id) }}</h6>
                                                        <div class="row">
                                                            <template v-for="field in section.fields"
                                                                :key="'tcf-' + field.id + '-' + vIdx">
                                                                <div v-if="['text', 'textarea'].includes(field.field_type)"
                                                                    class="col-md-6">
                                                                    <div class="form-group">
                                                                        <label>
                                                                            {{ fieldLabelForLang(field,
                                                                            currentVariantLang.id) }}
                                                                            <i v-if="field.is_required"
                                                                                class="text-danger">*</i>
                                                                        </label>
                                                                        <input v-if="field.field_type === 'text'"
                                                                            type="text" class="form-control"
                                                                            :value="rawCustomScalar(v, field, currentVariantLang)"
                                                                            @input="setCustomScalar(v, field, currentVariantLang, $event.target.value)" />
                                                                        <textarea v-else class="form-control" rows="2"
                                                                            :value="rawCustomScalar(v, field, currentVariantLang)"
                                                                            @input="setCustomScalar(v, field, currentVariantLang, $event.target.value)"></textarea>
                                                                    </div>
                                                                </div>
                                                            </template>
                                                        </div>
                                                    </div>
                                                </div>
                                            </template>
                                        </template>
                                    </div>
                                </div>
                            </template>
                        </template>
                    </div>
                </template>
            </div>

            <div class="card-footer d-flex justify-content-between align-items-center">
                <button type="button" class="btn btn-outline-secondary" :disabled="currentStep === 1 || isLoading"
                    @click="prevStep">
                    <ArrowLeft :size="15" /> {{ __('previous') }}
                </button>
                <div class="d-flex gap-2 align-items-center">
                    <small v-if="autoSaveInFlight" class="text-muted">
                        <b-spinner small></b-spinner> {{ __('auto_saving') }}
                    </small>
                    <small v-else-if="lastAutoSavedAt" class="text-muted">
                        {{ __('auto_saved') }}: {{ formatAutoSavedAt(lastAutoSavedAt) }}
                    </small>
                    <button type="button" class="btn btn-outline-warning" :disabled="isLoading || !effectiveCategoryId"
                        @click="saveDraft">
                        <Save :size="15" /> {{ __('save_as_draft') }}
                    </button>
                    <button v-if="currentStep < 5" type="button" class="btn btn-primary" @click="nextStep"
                        :disabled="isLoading">
                        {{ __('next') }} <ArrowRight :size="15" />
                    </button>
                    <button v-else type="button" class="btn btn-success" @click="saveRecord" :disabled="isLoading">
                        <span v-if="isLoading">
                            <b-spinner small label="Spinning"></b-spinner>
                        </span>
                        <span v-else>{{ __('save_product') }}</span>
                    </button>
                </div>
            </div>
        </div>

        <attribute-edit v-if="attributeModal !== false" :record="attributeModal" @modalClose="attributeModal = false"
            @saved="onAttributeSaved" />

        <category-edit v-if="categoryModal" as-modal :prefilled-parent-id="categoryModalParentId"
            @modalClose="categoryModal = false" @saved="onCategorySaved" />

        <brand-edit v-if="brandModal" :record="true" @modalClose="onBrandModalClose" @saved="onBrandQuickSaved" />

        <!-- Media library picker for variant images (single = main, multiple = gallery) -->
        <MediaPicker :show="mediaPicker.show" :multiple="mediaPicker.target === 'gallery'"
            :allow-video="mediaPicker.target === 'gallery'"
            @select="onMediaSelect" @close="mediaPicker.show = false" />


    </div>

    <!-- The dish's addon setup. Its own save, so a menu can be edited without
         re-saving the whole product. -->
    <b-modal v-model="addonModalOpen" size="xl" dialog-class="addon-modal-dialog"
        :title="__('addon_setup')" scrollable centered no-close-on-backdrop static
        @hide="onAddonModalHide" @hidden="onAddonModalHidden">
        <ProductAddons ref="addonEditor" v-if="addonEditorMounted" embedded :product-id-prop="id"
            :is-food-prop="Number(basics.is_food)" @ready="addonEditorReady = $event"
            @saved="onAddonsSaved" />
        <template #footer>
            <!-- Nothing is editable until the product itself is saved, so offering a
                 Save there would only look broken. -->
            <template v-if="addonEditorReady">
                <b-button variant="secondary" @click="addonModalOpen = false">{{ __('close') }}</b-button>
                <b-button variant="primary" @click="saveAddons">{{ __('save') }}</b-button>
            </template>
            <b-button v-else variant="primary" @click="addonModalOpen = false">{{ __('ok') }}</b-button>
        </template>
    </b-modal>
</template>

<script>
import axios from 'axios';
import Editor from '@tinymce/tinymce-vue';
import ProductAddons from './Addons/ProductAddons.vue';
import { tinymceInit as buildTinymceInit } from '../../utils/tinymce.js';
import TranslationHelper from '../../mixins/TranslationHelper.js';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';
import AttributeEdit from '../Category/Attributes/Edit.vue';
import CategoryEdit from '../Category/Edit.vue';
import BrandEdit from './Brands/Edit.vue';
import DatePicker from '../../components/DatePicker.vue';
import MediaPicker from '../../components/MediaPicker.vue';
import { ArrowLeft, ArrowRight, GripVertical, Plus, Pencil, Sparkles, Info, Copy, Save, Zap, X, LoaderCircle, Image as ImageIcon , ListPlus} from 'lucide-vue-next';
import draggable from 'vuedraggable';

const GALLERY_MAX_MB = 5;
const GALLERY_ACCEPT = 'image/jpeg,image/png,image/gif,image/webp,image/svg+xml,video/mp4';
const GALLERY_TYPES = 'JPG, PNG, GIF, WEBP, SVG, MP4';

export default {
    components: { ProductAddons, AttributeEdit, CategoryEdit, BrandEdit, editor: Editor, DatePicker, MediaPicker, draggable, ArrowLeft, ArrowRight, GripVertical, Plus, Pencil, Sparkles, Info, Copy, Save, Zap, X, LoaderCircle, ImageIcon, ListPlus },
    mixins: [TranslationHelper, CountryZoneFilter, UnsavedChanges],
    data() {
        return {
            czAllowAll: true, // branch-wise inventory lists ALL countries' branches by default
            id: (this.$route?.params?.id && !this.$route?.params?.clone) ? Number(this.$route.params.id) : null,
            cloneSourceId: this.$route?.params?.clone ? Number(this.$route.params.id) : null,
            isClone: !!this.$route?.params?.clone,
            isLoading: false,
            isLoadingData: true,
            mediaPicker: { show: false, target: null, vIdx: null },

            autoSaveTimer: null,
            autoSaveDirty: false,
            autoSaveInFlight: false,
            autoSavePromise: null,
            lastAutoSavedAt: null,

            currentStep: 1,
            addonModalOpen: false,
            addonEditorReady: false,
            addonEditorMounted: false,
            maxReachedStep: 1,
            steps: [
                { id: 1, label: 'category' },
                { id: 2, label: 'product_details' },
                { id: 3, label: 'variants' },
                { id: 4, label: 'seo' },
                { id: 5, label: 'review' },
            ],

            languages: [],
            defaultLanguageId: null,
            activeLanguageTab: 0,
            activeVariantTab: 0,
            activeVariantLangTab: 0,
            // `tags` and `schema_markup` are deliberately excluded: tags are search keywords
            // and schema_markup is structured JSON — neither survives translation intact.
            translatableFields: ['name', 'manufacturer', 'made_in', 'short_description', 'description',
                'meta_title', 'meta_keywords', 'meta_description'],
            isDraft: false,

            categoryLevels: [],
            categoryLevelsLoading: false,
            // Every active category, flat, for the tree picker above the pill rows.
            allCategories: [],
            categoryAttributes: [],
            categoryCustomFields: [],
            categoryCustomSections: [],

            selectedValuesByAttr: {},
            basics: {
                brand_id: 0,
                tax_category_id: null,
                product_type: 0,
                is_food: 0,
                is_addon_only: 0,
                is_prescription_required: 0,
                made_in: '',
                return_status: 0,
                return_days: 0,
                cancelable_status: 0,
                till_status_quick: 0,
                till_status_ecommerce: 0,
                cod_allowed: 1,
                total_allowed_quantity: 0,
                status: 1,
                sales_channel: 'both',
            },
            channelBranches: [],
            branchSearch: '',
            translations: {},

            variants: [],

            brands: [],
            taxCategories: [],
            taxPreviewRates: {},
            branchTaxRates: {},
            countries: [],

            attributeModal: false,
            categoryModal: false,
            categoryModalParentId: 0,

            brandModal: false,
            aiDescLoading: false,
            aiSeoLoading: false,

            tinymceInit: buildTinymceInit({ height: 320 }),

            _tmpKeyCounter: 0,

            // Per-branch slab editors open-state, keyed "vIdx-branchId".
            openBranchSlabs: {},
        };
    },
    computed: {
        galleryAccept() {
            return GALLERY_ACCEPT;
        },
        galleryMaxMb() {
            return GALLERY_MAX_MB;
        },
        galleryHint() {
            return __('recommended_size', { size: '800x800px' }) + ' · '
                + __('allowed_types_and_max_size', { types: GALLERY_TYPES, size: GALLERY_MAX_MB + ' MB' });
        },
        // Fixed option set — no search box needed.
        product_typeOptions() {
            return [
                { id: 0, name: (__('none')) },
                { id: 1, name: (__('veg')) },
                { id: 2, name: (__('non_veg')) },
                { id: 3, name: (__('chemical')) },
                { id: 4, name: (__('eggetarian')) },
                { id: 5, name: (__('medical')) },
            ];
        },
        // Fixed option set — no search box needed.
        sales_channelOptions() {
            return [
                { id: 'quick', name: (__('quick_commerce')) },
                { id: 'ecommerce', name: (__('ecommerce')) },
                { id: 'both', name: (__('both')) },
            ];
        },
        // Fixed option set — no search box needed.
        return_statusOptions() {
            return [
                { id: 0, name: (__('not_returnable')) },
                { id: 1, name: (__('returnable')) },
            ];
        },
        // Fixed option set — no search box needed.
        cancelable_statusOptions() {
            return [
                { id: 0, name: (__('not_cancelable')) },
                { id: 1, name: (__('cancelable')) },
            ];
        },
        // Fixed option set — no search box needed.
        cod_allowedOptions() {
            return [
                { id: 0, name: (__('no')) },
                { id: 1, name: (__('yes')) },
            ];
        },
        // Fixed option set — no search box needed.
        is_unlimited_stockOptions() {
            return [
                { id: 0, name: (__('limited')) },
                { id: 1, name: (__('unlimited')) },
            ];
        },
        // AppSelect renders `name`. Categories carry no rate — showing one here would
        // be a lie the moment a second country is added.
        taxCategoryOptions() {
            return (this.taxCategories || []).map(c => ({ id: c.id, name: c.name }));
        },
        pageTitle() {
            return this.id ? __('edit_product') : __('add_product');
        },
        filteredChannelBranches() {
            const q = (this.branchSearch || '').trim().toLowerCase();
            if (!q) return this.channelBranches;
            return this.channelBranches.filter(st =>
                (st.name || '').toLowerCase().includes(q)
                || (st.city || '').toLowerCase().includes(q));
        },
        // "Cancellable till" options per channel (order-status ids).
        quickTillOptions() {
            return [
                { value: 2, label: 'received' },
                { value: 9, label: 'preparing' },
                { value: 10, label: 'ready_for_pickup' },
                { value: 11, label: 'picked_up' },
                { value: 5, label: 'out_for_delivery' },
            ];
        },
        ecomTillOptions() {
            return [
                { value: 2, label: 'received' },
                { value: 3, label: 'processed' },
                { value: 4, label: 'shipped' },
                { value: 5, label: 'out_for_delivery' },
            ];
        },
        // Custom boolean fields branch "1"/"0" as strings.
        booleanFieldOptions() {
            return [
                { id: '1', name: __('yes') },
                { id: '0', name: __('no') },
            ];
        },
        // The raw lists hold untranslated label keys; AppSelect needs { id, name }.
        quickTillSelectOptions() {
            return this.quickTillOptions.map(o => ({ id: o.value, name: __(o.label) }));
        },
        ecomTillSelectOptions() {
            return this.ecomTillOptions.map(o => ({ id: o.value, name: __(o.label) }));
        },
        showQuickTill() {
            const c = this.basics.sales_channel || 'both';
            return c === 'quick' || c === 'both';
        },
        showEcomTill() {
            const c = this.basics.sales_channel || 'both';
            return c === 'ecommerce' || c === 'both';
        },
        currentVariantLang() {
            return this.languages[this.activeVariantLangTab] || this.languages.find(l => l.id === this.defaultLanguageId) || null;
        },
        defaultLangObj() {
            return { id: this.defaultLanguageId, is_default: true };
        },
        categoryTreeOptions() {
            const list = (this.allCategories || []).map(c => {
                const out = { ...c, parent_id: Number(c.parent_id || 0) };
                const t = Array.isArray(c.translations)
                    ? c.translations.find(x => Number(x.language_id) === Number(this.defaultLanguageId)) : null;
                if (t && t.name && t.name.trim()) out.name = t.name;
                return out;
            });

            const ids = new Set(list.map(c => c.id));
            const byParent = {};
            list.forEach(c => {
                const pid = ids.has(c.parent_id) ? c.parent_id : 0;
                (byParent[pid] = byParent[pid] || []).push(c);
            });

            const INDENT = '\u00A0\u00A0\u00A0\u00A0'; // nbsp — plain spaces collapse in the dropdown
            const out = [];
            const walk = (parentId, depth) => {
                (byParent[parentId] || []).forEach(c => {
                    const hasChildren = (byParent[c.id] || []).length > 0;
                    out.push({
                        id: c.id,
                        name: (depth ? INDENT.repeat(depth) + '\u21B3 ' : '') + c.name,
                        $isDisabled: hasChildren,
                    });
                    walk(c.id, depth + 1);
                });
            };
            walk(0, 0);

            return out;
        },
        effectiveCategoryId() {
            if (this.categoryLevelsLoading) return null;
            const last = this.categoryLevels[this.categoryLevels.length - 1];
            if (!last || !last.selectedId) return null;
            return last.selectedId;
        },
        selectedCategoryPath() {
            const out = [];
            for (const lv of this.categoryLevels) {
                if (!lv.selectedId) break;
                const cat = (lv.items || []).find(c => c.id === lv.selectedId);
                if (cat) out.push(cat);
            }
            return out;
        },
        generatedVariantCount() {
            const attrs = this.categoryAttributes || [];
            let count = 0;
            for (const attr of attrs) {
                const selected = this.selectedValuesByAttr[attr.id] || [];
                if (selected.length === 0) continue;
                count = count === 0 ? selected.length : count * selected.length;
            }
            return count;
        },
        categoryPathLabel() {
            const parts = this.selectedCategoryPath.map(c => this.catLabel(c));
            return parts.length ? parts.join(' › ') : '—';
        },
        reviewCategoryName() {
            const p = this.selectedCategoryPath;
            return p.length ? this.catLabel(p[0]) : '—';
        },
        reviewSubCategoryName() {
            const p = this.selectedCategoryPath;
            return p.length > 1 ? this.catLabel(p[p.length - 1]) : '—';
        },
        reviewBrandName() {
            const b = (this.brands || []).find(x => x.id === this.basics.brand_id);
            return b ? b.name : '—';
        },
        salesChannelLabel() {
            const c = this.basics.sales_channel || 'both';
            if (c === 'quick') return __('quick_commerce_only');
            if (c === 'ecommerce') return __('ecommerce_only');
            return __('quick_and_ecommerce');
        },
        selectedValueRows() {
            return (this.categoryAttributes || [])
                .filter(a => (this.selectedValuesByAttr[a.id] || []).length > 0)
                .map(a => ({
                    attr_id: a.id,
                    attr_label: this.attrLabel(a),
                    value_labels: (this.selectedValuesByAttr[a.id] || []).map(vid => {
                        const v = (a.values || []).find(x => x.id === vid);
                        return v ? this.valueLabel(v) : '';
                    }),
                }));
        },
    },
    watch: {
        'basics.tax_category_id'(value) {
            this.fetchBranchTaxRates();

            (this.variants || []).forEach(v => {
                (v.branch_stocks || []).forEach(st => {
                    if (this.isUntouchedBranchRow(st)) st.is_tax_inclusive = !!value;
                });
            });
        },
        // Keep each channel's till_status valid for its option set.
        'basics.sales_channel'() {
            if (this.basics.cancelable_status !== 1) return;
            const q = this.quickTillOptions.map(o => o.value);
            const e = this.ecomTillOptions.map(o => o.value);
            if (!q.includes(this.basics.till_status_quick)) this.basics.till_status_quick = q[0];
            if (!e.includes(this.basics.till_status_ecommerce)) this.basics.till_status_ecommerce = e[0];
        },
        effectiveCategoryId(newVal, oldVal) {
            if (newVal !== oldVal && oldVal && !this.id) {
                this.clearAllSelections();
            }
            this.loadCategorySchema();
        },
        currentStep(newVal) {
            if (newVal === 3 && this.variants.length > 0) {
                const idx = this.activeVariantTab;
                this.activeVariantTab = -1;
                this.$nextTick(() => {
                    this.activeVariantTab = (idx >= 0 && idx < this.variants.length) ? idx : 0;
                });
            }
        },
        activeVariantTab() {
            const defIdx = this.languages.findIndex(l => l.is_default === 1);
            const target = defIdx >= 0 ? defIdx : 0;
            if (this.activeVariantLangTab !== target) {
                this.$nextTick(() => { this.activeVariantLangTab = target; });
            }
        },
        basics: { deep: true, handler() { this.markAutoSaveDirty(); } },
        translations: { deep: true, handler() { this.markAutoSaveDirty(); } },
        variants: { deep: true, handler() { this.markAutoSaveDirty(); } },
        selectedValuesByAttr: { deep: true, handler() { this.markAutoSaveDirty(); } },
    },
    created() {
        this.$apiUrl = '/api';
        this.czLoad(); // country/zone scope for the branch-wise inventory cards
    },
    mounted() {
        this.$nextTick(() => this.bootstrap());
        if (!this.id) {
            this.autoSaveTimer = setInterval(() => this.autoSaveTick(), 20000);
        }
    },
    beforeUnmount() {
        if (this.autoSaveTimer) {
            clearInterval(this.autoSaveTimer);
            this.autoSaveTimer = null;
        }
    },
    methods: {
        /** Enough filled in for the draft to be saveable — same test the auto-save uses. */
        canDraftSave() {
            if (!this.effectiveCategoryId) return false;
            const defId = this.defaultLanguageId;
            return !!(defId && this.translations[defId]
                && String(this.translations[defId].name || '').trim());
        },
        /**
         * Addon groups hang off a product id, so a brand-new product has nothing to hang
         * them on. The draft auto-saves itself, but only on a 20s tick — so rather than
         * making the operator wait for a timer they cannot see, save the draft now and
         * open straight away.
         */
        async openAddons() {
            if (!this.id) {
                if (!this.canDraftSave()) {
                    this.showError(__('addons_need_category_and_name'));
                    return;
                }
                await this.autoSaveSettled();
                if (!this.id) await this.autoSaveDraft();
                if (!this.id) {
                    this.showError(__('save_the_product_before_adding_addons'));
                    return;
                }
            } else if (this.autoSaveDirty || this.autoSaveInFlight) {
                /* The editor reads is_food from the SAVED product, so a food toggle that
                   is still only on screen would make it refuse to open. Flush whatever is
                   pending first — the auto-save would have done it anyway, just up to 20s
                   later, which is what made this look broken. */
                await this.autoSaveSettled();
                if (this.autoSaveDirty && this.canDraftSave()) await this.autoSaveDraft();
            }
            this.addonEditorReady = false;
            this.addonEditorMounted = true;
            this.addonModalOpen = true;
        },
        saveAddons() {
            // The editor owns its own save; the modal footer just triggers it.
            if (this.$refs.addonEditor) this.$refs.addonEditor.save();
        },
        /**
         * Closing the addon modal throws away whatever is unsaved in it, so ask first —
         * the editor saves separately from the product and nothing else would catch it.
         */
        onAddonModalHide(bvEvt) {
            if (this._addonAllowClose) { this._addonAllowClose = false; return; }
            const editor = this.$refs.addonEditor;
            if (!editor || !editor.isFormDirty) return;
            bvEvt.preventDefault();
            editor.confirmClose().then((ok) => {
                if (!ok) {
                    // Cancelled: the model was already flipped, so put it back and keep
                    // the editor mounted with its edits intact.
                    this.addonModalOpen = true;
                    return;
                }
                this._addonAllowClose = true;
                this.addonModalOpen = false;
                this.addonEditorMounted = false;
            });
        },
        /**
         * A successful save is the end of the job, so the modal gets out of the way.
         * The guard is skipped deliberately — there is nothing unsaved left to warn about.
         */
        onAddonsSaved() {
            this._addonAllowClose = true;
            this.addonModalOpen = false;
        },
        /** A clean close still has to tear the editor down, so the next open reloads. */
        onAddonModalHidden() {
            this.addonEditorMounted = false;
        },
        // Tracked state for the UnsavedChanges guard (warn before leaving with edits).
        formState() {
            return {
                basics: this.basics,
                translations: this.translations,
                variants: this.variants.map(v => ({
                    id: v.id ?? null,
                    sku: v.sku,
                    hsn_code: v.hsn_code,
                    weight: v.weight === '' ? null : v.weight,
                    length: v.length === '' ? null : v.length,
                    breadth: v.breadth === '' ? null : v.breadth,
                    height: v.height === '' ? null : v.height,
                    stock: v.stock,
                    translations: v.translations,
                    attribute_values: v.attribute_values,
                    image_path: v.image_path,
                    image_file: v.image_file,
                    gallery_files: v.gallery_files,
                    gallery_media: v.gallery_media,
                    gallery_delete_ids: v.gallery_delete_ids,
                    custom_by_field: v.custom_by_field,
                    branch_stocks: (v.branch_stocks || [])
                        .filter(st => !this.isUntouchedBranchRow(st))
                        .slice()
                        .sort((a, b) => Number(a.branch_id) - Number(b.branch_id)),
                })),
            };
        },

        /** A branch row the user never filled in — all defaults, nothing to save. */
        isUntouchedBranchRow(st) {
            if (!st) {
                return true;
            }
            if (st.is_listed) {
                return false;
            }
            if (Number(st.is_unlimited_stock) === 1 || Number(st.stock_status) === 1) {
                return false;
            }
            if ((st.pricing_slabs || []).length) {
                return false;
            }

            return ['available', 'reserved', 'min_alert', 'price', 'discounted_price', 'purchase_price']
                .every(field => !(Number(st[field]) || 0));
        },
        czOnFilter() { this.fetchChannelBranches(); },
        bootstrap() {
            this.isLoadingData = true;
            Promise.all([
                this.fetchActiveLanguages(),
                this.fetchAllCategories(),
                this.fetchBrands(),
                this.fetchTaxCategories(),
                this.fetchCountries(),
            ]).then(() => {
                this.fetchTaxPreviewRates();
                this.fetchBranchTaxRates();
                this.initTranslations();
                if (this.id) {
                    return this.loadProductForEdit();
                }
                if (this.cloneSourceId) {
                    return this.loadProductForClone();
                }
                this.fetchChannelBranches();
                // Empty create form — snapshot the clean baseline for the unsaved-changes guard.
                this.captureFormBaseline();
                return Promise.resolve();
            }).finally(() => {
                this.isLoadingData = false;
            });
        },

        fetchChannelBranches() {
            const params = {
                sales_channel: this.basics.sales_channel || 'both',
                country_id: this.czCountryParam,
                zone_id: this.czZoneParam,
            };
            const key = params.sales_channel + '|' + (params.country_id || '') + '|' + (params.zone_id || '');
            if (this._branchesKey === key && this._branchesReq) return this._branchesReq;
            this._branchesKey = key;
            this._branchesReq = axios.get(this.$apiUrl + '/branches/for_channel', { params }).then(r => {
                this.channelBranches = r.data?.data?.branches || [];
            }).catch(() => {
                this.channelBranches = [];
            });
            return this._branchesReq;
        },
        onSalesChannelChange() {
            this.fetchChannelBranches();
        },
        // Available drives the branch's stock status: 0 → Out of Stock, > 0 → In Stock.
        onBranchAvailableInput(row) {
            if (!row) return;
            row.stock_status = Number(row.available) > 0 ? 1 : 0;
        },
        // Stock-status options for a branch row. "In Stock" is disabled while the branch
        // has 0 available (an out-of-stock branch can't be marked In Stock).
        stockStatusOptionsFor(row) {
            const outOfStock = !row || !(Number(row.available) > 0);
            return [
                { id: 1, name: (__('in_stock')), $isDisabled: outOfStock },
                { id: 0, name: (__('out_of_stock')) },
            ];
        },
        branchStock(v, branchId) {
            if (!Array.isArray(v.branch_stocks)) v.branch_stocks = [];
            let row = v.branch_stocks.find(s => Number(s.branch_id) === Number(branchId));
            if (!row) {
                row = {
                    branch_id: Number(branchId),
                    is_listed: false,
                    // Stock limit is per branch now (0 = limited, 1 = unlimited).
                    is_unlimited_stock: 0,
                    stock_status: 0,
                    available: 0,
                    reserved: 0,
                    min_alert: 0,
                    // Branch-wise pricing (null until the branch is listed & priced).
                    price: null,
                    discounted_price: null,
                    is_tax_inclusive: !!this.basics.tax_category_id,
                    purchase_price: null,
                    pricing_slabs: [],
                };
                v.branch_stocks.push(row);
            }
            if (!Array.isArray(row.pricing_slabs)) row.pricing_slabs = [];
            return row;
        },

        variantTaxPercent() {
            const categoryId = Number(this.basics.tax_category_id || 0);
            if (!categoryId) return 0;
            return Number(this.taxPreviewRates[categoryId] || 0);
        },
        /**
         * This country's rules are region-wise, so the rule that fires is chosen from the
         * customer's address. Said even when the branch itself resolves to nothing: an
         * inter-state-only rule quotes 0 here yet still taxes an out-of-state customer, so
         * "no tax" would be the wrong thing to tell the admin.
         */
        branchTaxRegionNote(branchId) {
            const row = this.branchTaxRates[branchId];
            if (!this.basics.tax_category_id || !row || !row.region_wise) {
                return '';
            }

            return __('tax_depends_on_customer_region');
        },

        /**
         * Why this branch has no tax to include in its price. A branch resolves to 0% when
         * no rule matches its country/state for the selected category — e.g. the state has
         * only an inter-state rule, or the intra rule is switched off — and the admin has
         * no way to see that from the product form otherwise.
         */
        branchTaxNote(branchId) {
            if (!this.basics.tax_category_id) {
                return '';
            }
            const row = this.branchTaxRates[branchId];
            if (row && row.configured === false) {
                return __('no_tax_rule_for_branch');
            }

            return this.branchTaxRate(branchId) > 0 ? '' : __('tax_rate_zero_for_branch');
        },
        branchTaxRate(branchId) {
            const row = this.branchTaxRates[branchId];
            return row ? Number(row.rate) || 0 : this.variantTaxPercent();
        },
        // ---- Per-branch pricing helpers (price is per-branch / PVSS) ----
        branchMargin(row) {
            const sell = Number(row.discounted_price) > 0 ? Number(row.discounted_price) : Number(row.price) || 0;
            const cost = Number(row.purchase_price) || 0;
            const amount = sell - cost;
            const percent = cost > 0 ? (amount / cost) * 100 : (sell > 0 ? 100 : null);
            return { amount, percent };
        },

        branchCustomerPrice(row) {
            const base = Number(row.discounted_price) > 0 ? Number(row.discounted_price) : Number(row.price) || 0;
            const branchId = row && row.branch_id ? row.branch_id : null;
            if (row && row.is_tax_inclusive) return base;
            const pct = this.branchTaxRate(branchId);
            return base + (base * pct / 100);
        },
        branchDiscountInvalid(row) {
            return Number(row.discounted_price) > 0 && Number(row.discounted_price) > Number(row.price);
        },
        addBranchSlab(row) {
            if (!Array.isArray(row.pricing_slabs)) row.pricing_slabs = [];
            row.pricing_slabs.push({ min_qty: null, max_qty: null, price: null });
        },
        removeBranchSlab(row, i) {
            if (Array.isArray(row.pricing_slabs)) row.pricing_slabs.splice(i, 1);
        },
        /* --- slab pricing, checked while typing ---------------------------------
           A slab only makes sense above a single unit and below what one unit costs
           today, so the comparison base is the discounted price when there is one,
           otherwise the selling price. */
        slabFilled(v) {
            return v !== null && v !== '' && v !== undefined && !isNaN(v);
        },
        branchSlabBase(row) {
            const disc = Number(row?.discounted_price) || 0;
            return disc > 0 ? disc : (Number(row?.price) || 0);
        },
        slabMinInvalid(s) {
            return this.slabFilled(s.min_qty) && Number(s.min_qty) <= 1;
        },
        slabMaxInvalid(s) {
            return this.slabFilled(s.max_qty) && this.slabFilled(s.min_qty)
                && Number(s.max_qty) < Number(s.min_qty);
        },
        slabPriceInvalid(row, s) {
            if (!this.slabFilled(s.price)) return false;
            const price = Number(s.price);
            if (!(price > 0)) return true;
            const base = this.branchSlabBase(row);
            return base > 0 && price >= base;
        },
        /** The message under a slab row, '' when the row is fine. */
        slabRowError(row, s) {
            if (this.slabMinInvalid(s)) return __('slab_min_qty_must_be_above_one');
            if (this.slabMaxInvalid(s)) return __('slab_max_qty_below_min');
            if (this.slabFilled(s.price) && !(Number(s.price) > 0)) return __('slab_price_above_zero');
            if (this.slabPriceInvalid(row, s)) {
                const disc = Number(row?.discounted_price) || 0;
                return disc > 0 ? __('slab_price_below_discounted') : __('slab_price_below_selling');
            }
            return '';
        },
        // Validate a branch's quantity slabs. Returns a translation KEY on failure, null when OK.
        // Rules: a row with any value filled must have BOTH min_qty and price (max optional);
        // min_qty > 1, price > 0 and under the branch's current unit price, max_qty (if set)
        // >= min_qty; ranges must not overlap; an open-ended row (blank max = "and above")
        // must be the last one.
        validateBranchSlabs(slabs, row = null) {
            const filled = (x) => x !== null && x !== '' && x !== undefined && !isNaN(x);
            const norm = [];
            for (const s of (slabs || [])) {
                if (!s) continue;
                const hasMin = filled(s.min_qty);
                const hasMax = filled(s.max_qty);
                const hasPrice = filled(s.price);
                if (!hasMin && !hasMax && !hasPrice) continue; // fully empty row → ignore
                // qty ↔ price: both or neither.
                if (hasMin !== hasPrice) return 'slab_qty_and_price_both_required';
                const min = Number(s.min_qty);
                const price = Number(s.price);
                if (min <= 1) return 'slab_min_qty_at_least_two';
                if (!(price > 0)) return 'slab_price_must_be_positive';
                // A slab at or above the normal unit price would never apply.
                const base = this.branchSlabBase(row);
                if (base > 0 && price >= base) {
                    return (Number(row?.discounted_price) || 0) > 0
                        ? 'slab_price_must_be_below_discounted'
                        : 'slab_price_must_be_below_selling';
                }
                const max = hasMax ? Number(s.max_qty) : null;
                if (max !== null && max < min) return 'slab_max_less_than_min';
                norm.push({ min, max });
            }
            if (norm.length <= 1) return null;
            norm.sort((a, b) => a.min - b.min);
            for (let i = 0; i < norm.length; i++) {
                // Open-ended range must be last, else it overlaps everything after it.
                if (norm[i].max === null && i !== norm.length - 1) return 'slab_unlimited_row_must_be_last';
                if (i + 1 < norm.length) {
                    const curMax = norm[i].max === null ? Infinity : norm[i].max;
                    if (curMax >= norm[i + 1].min) return 'slab_ranges_overlap';
                }
            }
            return null;
        },
        toggleBranchSlabs(vIdx, branchId) {
            const key = vIdx + '-' + branchId;
            this.openBranchSlabs = { ...this.openBranchSlabs, [key]: !this.openBranchSlabs[key] };
        },
        isBranchSlabsOpen(vIdx, branchId) {
            return !!this.openBranchSlabs[vIdx + '-' + branchId];
        },
        // Branches in the SAME country share a cost — fill the purchase price into the
        // other same-country branches when one is entered (admin needn't repeat it).
        sameCountryBranchCount(st) {
            if (!st || st.country_id == null) return 1;
            return this.channelBranches.filter(x => x.country_id != null && Number(x.country_id) === Number(st.country_id)).length;
        },
        // Copy the first branch card's pricing + stock settings onto every other branch
        // for this variant. Only `branch_id` differs; slabs are deep-copied so the branches
        // don't end up sharing one array.
        copyFirstBranchToOthers(v) {
            const branches = this.filteredChannelBranches.length ? this.filteredChannelBranches : this.channelBranches;
            if (!branches || branches.length < 2) return;

            const src = this.branchStock(v, branches[0].id);
            let copied = 0;
            branches.forEach((st, i) => {
                if (i === 0) return;
                const dst = this.branchStock(v, st.id);
                dst.is_listed = src.is_listed;
                dst.is_unlimited_stock = src.is_unlimited_stock;
                dst.stock_status = src.stock_status;
                dst.available = src.available;
                dst.min_alert = src.min_alert;
                dst.price = src.price;
                dst.discounted_price = src.discounted_price;
                dst.purchase_price = src.purchase_price;
                dst.pricing_slabs = (src.pricing_slabs || []).map(x => ({ ...x }));
                // `reserved` is system-managed (cart holds) — never copied.
                copied++;
            });
            this.showMessage('success', String(__('copied_to_branches')).replace(':count', copied));
        },
        autofillPurchasePrice(v, st) {
            if (!st || st.country_id == null) return;
            const val = this.branchStock(v, st.id).purchase_price;
            if (val === null || val === '' || val === undefined) return;
            // Same country = same cost: propagate to every other branch in this country
            // in realtime as the admin types.
            this.channelBranches.forEach(x => {
                if (x.country_id == null) return;
                if (Number(x.country_id) !== Number(st.country_id)) return;
                if (Number(x.id) === Number(st.id)) return;
                this.branchStock(v, x.id).purchase_price = Number(val);
            });
        },
        // Review-step per-variant price summary (range across listed branches).
        variantPriceSummary(v) {
            const listed = (v.branch_stocks || []).filter(s => s.is_listed);
            const cur = this.$currency;
            if (!listed.length) {
                return { sell: '—', purchase: '—', listedCount: 0 };
            }
            const sells = listed.map(s => Number(s.discounted_price) > 0 ? Number(s.discounted_price) : Number(s.price) || 0);
            const purch = listed.map(s => Number(s.purchase_price) || 0);
            const range = (arr) => {
                const mn = Math.min(...arr), mx = Math.max(...arr);
                return mn === mx ? (cur + mn.toFixed(2)) : (cur + mn.toFixed(2) + ' – ' + cur + mx.toFixed(2));
            };
            return { sell: range(sells), purchase: range(purch), listedCount: listed.length };
        },
        // Realtime SKU validation: instant check against this product's other
        // variants, then a debounced server check against every other product.
        /** "0.5 kg · 10×8×4 cm", or a dash when nothing is filled in. */
        shippingSummary(v) {
            const parts = [];
            if (v.weight) parts.push(v.weight + ' ' + __('kg'));
            if (v.length && v.breadth && v.height) {
                parts.push(v.length + '×' + v.breadth + '×' + v.height + ' ' + __('cm'));
            }

            return parts.length ? parts.join(' · ') : '—';
        },
        onSkuInput(v) {
            const sku = (v.sku || '').trim();
            v.skuError = '';
            if (!sku) return;

            const dupLocal = this.variants.some(o => o !== v && (o.sku || '').trim().toLowerCase() === sku.toLowerCase());
            if (dupLocal) {
                v.skuError = __('sku_duplicate_in_variants') || 'This SKU is already used by another variant here.';
                return;
            }

            const key = v.tmpKey || v.id || sku;
            if (!this._skuTimers) this._skuTimers = {};
            clearTimeout(this._skuTimers[key]);
            this._skuTimers[key] = setTimeout(() => {
                axios.get(this.$apiUrl + '/products/check_sku', { params: { sku, product_id: this.id || 0 } })
                    .then(r => {
                        // Ignore stale responses if the field changed meanwhile.
                        if ((v.sku || '').trim() !== sku) return;
                        v.skuError = (r.data.data && r.data.data.available === false)
                            ? (__('sku_already_used') || 'This SKU is already used by another product.')
                            : '';
                    })
                    .catch(() => {});
            }, 400);
        },
        /** Stable key for the drag list; a brand new variant has no id yet. */
        variantKey(v) {
            return v.tmpKey || ('v_' + v.id);
        },

        onVariantDragEnd(evt) {
            const from = Number(evt?.oldIndex);
            const to = Number(evt?.newIndex);
            if (!Number.isInteger(from) || !Number.isInteger(to) || from === to) return;

            const open = this.activeVariantTab;
            if (open === from) this.activeVariantTab = to;
            else if (from < open && open <= to) this.activeVariantTab = open - 1;
            else if (to <= open && open < from) this.activeVariantTab = open + 1;
        },
        removeVariant(idx) {
            if (idx < 0 || idx >= this.variants.length) return;
            if (this.variants.length === 1) {
                this.showError(__('at_least_one_variant_required'));
                return;
            }
            const variant = this.variants[idx];
            // Saved variant → check whether any orders reference it, and warn.
            const usagePromise = variant && variant.id
                ? axios.get(this.$apiUrl + '/products/variant_usage', { params: { variant_id: variant.id } })
                    .then(r => Number(r.data.data?.order_count || 0)).catch(() => 0)
                : Promise.resolve(0);

            usagePromise.then(orderCount => {
                let text = __('confirm_remove_variant');
                if (orderCount > 0) {
                    const tpl = __('variant_in_use_warning') || 'This variant appears in :orders order(s). Removing it here (on save) detaches it from the product; existing orders keep their historical record.';
                    text = tpl.replace(':orders', orderCount);
                }
                this.$swal.fire({
                    title: __('are_you_sure'),
                    html: text,
                    icon: 'warning',
                    showCancelButton: true,
                    confirmButtonColor: window.adminThemeColor || '#435ebe',
                    cancelButtonColor: '#d33',
                    confirmButtonText: __('yes_remove'),
                    cancelButtonText: __('cancel'),
                }).then((result) => {
                    if (!result.isConfirmed) return;
                    this.variants.splice(idx, 1);
                    if (this.activeVariantTab >= this.variants.length) {
                        this.activeVariantTab = this.variants.length - 1;
                    }
                });
            });
        },
        copyFromFirstVariant(idx) {
            if (idx <= 0 || !this.variants[0]) return;
            const src = this.variants[0];
            const dst = this.variants[idx];
            dst.stock = src.stock;
            dst.status = src.status;
            // Pricing lives on branch_stocks now — copying stocks carries price/discounted/
            // purchase/slabs per branch too.
            dst.branch_stocks = (src.branch_stocks || []).map(s => ({
                ...s,
                pricing_slabs: (s.pricing_slabs || []).map(x => ({ ...x })),
            }));
            dst.custom_by_field = JSON.parse(JSON.stringify(src.custom_by_field || {}));
            this.showMessage('success', __('copied_from_first_variant'));
        },

        fetchActiveLanguages() {
            return axios.get(this.$apiUrl + '/active_languages').then(r => {
                this.languages = r.data.data || [];
                const defIdx = this.languages.findIndex(l => l.is_default === 1);
                const idx = defIdx >= 0 ? defIdx : 0;
                this.defaultLanguageId = this.languages[idx]?.id ?? null;
                this.activeVariantLangTab = idx;
                this.activeLanguageTab = idx;
            });
        },
        /**
         * Nothing chosen yet.
         *
         * This used to fetch the top-level categories, because the step opened on a row
         * of them to click. The picker lists the whole tree in one go now, so that call
         * fetched a list nothing rendered — the levels are only kept as the resolved
         * path behind the chosen category.
         */
        initCategoryLevels() {
            this.categoryLevels = [];
            return Promise.resolve();
        },
        fetchBrands() {
            return axios.get(this.$apiUrl + '/products/brands/get').then(r => {
                this.brands = r.data.data || r.data || [];
            }).catch(() => { });
        },
        fetchBranchTaxRates() {
            const categoryId = this.basics.tax_category_id;
            if (!categoryId) { this.branchTaxRates = {}; return Promise.resolve(); }
            return axios.get(this.$apiUrl + '/products/tax_rules/branch_rates', {
                params: { tax_category_id: categoryId },
            }).then(r => {
                const map = {};
                (r.data.data || []).forEach(row => { map[row.branch_id] = row; });
                this.branchTaxRates = map;
            }).catch(() => { this.branchTaxRates = {}; });
        },
        fetchTaxCategories() {
            return axios.get(this.$apiUrl + '/products/tax_categories', { params: { status: 1 } }).then(r => {
                this.taxCategories = r.data.data || r.data || [];
            }).catch(() => { });
        },
        fetchTaxPreviewRates() {
            return axios.get(this.$apiUrl + '/products/tax_rules', { params: { status: 1 } }).then(r => {
                const rules = r.data.data || [];
                const defaultCountry = (this.countries || []).find(c => c.is_default == 1) || (this.countries || [])[0];
                const countryId = defaultCountry ? Number(defaultCountry.id) : null;
                const rates = {};
                rules.forEach(rule => {
                    if (countryId && Number(rule.country_id) !== countryId) return;
                    if (!rule.tax_category_id) return;
                    if (rule.place_of_supply === 'inter') return; // intra/any already carries the total
                    rates[rule.tax_category_id] = Number(rule.total_rate) || 0;
                });
                this.taxPreviewRates = rates;
            }).catch(() => { });
        },
        fetchCountries() {
            return axios.get(this.$apiUrl + '/countries').then(r => {
                this.countries = r.data.data || r.data || [];
            }).catch(() => { });
        },

        openBrandModal() {
            this.brandModal = true;
        },
        onBrandModalClose() {
            this.brandModal = false;
        },
        onBrandQuickSaved(message, id) {
            this.showMessage('success', message || __('brand_saved_successfully'));
            Promise.resolve(this.fetchBrands()).then(() => {
                if (id && (this.brands || []).some(b => Number(b.id) === Number(id))) {
                    this.basics.brand_id = Number(id);
                }
                this.brandModal = false;
            });
        },

        // Generate straight from the Product Name field (no modal). Falls back to
        // the default-language name if the current tab's name is empty.
        startAiGenerate(type, lang) {
            const name = (this.translations[lang.id]?.name
                || this.translations[this.defaultLanguageId]?.name || '').trim();
            if (!name) {
                this.showError(__('product_name_required'));
                return;
            }
            if (type === 'seo') {
                this.doGenerateSeo(lang, name);
            } else {
                this.doGenerateDescription(lang, name);
            }
        },

        doGenerateDescription(lang, name) {
            this.aiDescLoading = true;
            axios.post(this.$apiUrl + '/products/generate_description', {
                product_name: name,
                category: this.reviewCategoryName || '',
            }).then(r => {
                if (r.data.status === 1 || r.data.status === '1') {
                    const d = r.data.data || {};
                    if (d.description) this.translations[lang.id].description = d.description;
                    if (d.short_description) this.translations[lang.id].short_description = d.short_description;
                    this.showMessage('success', __('content_generated_successfully'));
                } else {
                    this.showError(r.data.message || __('ai_generation_failed'));
                }
            }).catch(err => {
                this.showError(err.response?.data?.message || __('ai_generation_failed'));
            }).finally(() => { this.aiDescLoading = false; });
        },

        doGenerateSeo(lang, name) {
            this.aiSeoLoading = true;
            axios.post(this.$apiUrl + '/products/generate_seo', {
                product_name: name,
                description: this.translations[lang.id]?.description || '',
            }).then(r => {
                if (r.data.status === 1 || r.data.status === '1') {
                    const d = r.data.data || {};
                    if (d.meta_title) this.translations[lang.id].meta_title = d.meta_title;
                    if (d.meta_description) this.translations[lang.id].meta_description = d.meta_description;
                    if (d.meta_keywords) this.translations[lang.id].meta_keywords = d.meta_keywords;
                    this.showMessage('success', __('content_generated_successfully'));
                } else {
                    this.showError(r.data.message || __('ai_generation_failed'));
                }
            }).catch(err => {
                this.showError(err.response?.data?.message || __('ai_generation_failed'));
            }).finally(() => { this.aiSeoLoading = false; });
        },

        initTranslations() {
            const trans = {};
            for (const l of this.languages) {
                trans[l.id] = {
                    name: '', description: '', short_description: '', manufacturer: '', tags: '', made_in: '',
                    meta_title: '', meta_keywords: '', schema_markup: '', meta_description: '',
                };
            }
            this.translations = trans;
        },

        loadProductForClone() {
            return axios.get(this.$apiUrl + `/products/edit/${this.cloneSourceId}`).then(r => {
                const d = r.data.data || {};
                d.is_draft = 0;

                // SEO is per-product: meta tags and schema markup describe the original
                // and must not be duplicated, or two products compete for the same search
                // terms. (slug is generated server-side with a uniqueness check, so it
                // needs no handling here.)
                if (Array.isArray(d.translations)) {
                    d.translations = d.translations.map(t => ({
                        ...t,
                        meta_title: '',
                        meta_keywords: '',
                        meta_description: '',
                        schema_markup: '',
                    }));
                }

                if (Array.isArray(d.variants)) {
                    d.variants = d.variants.map(v => {
                        const copy = { ...v };
                        copy.id = null;
                        copy.sku = (v.sku || '') + '-copy';
                        copy.image_path = null;
                        copy.gallery_media = [];
                        copy.image = null;
                        copy.gallery_keep = [];
                        return copy;
                    });
                }
                return this.applyProductData(d);
            }).catch(() => { });
        },

        loadProductForEdit() {
            return axios.get(this.$apiUrl + `/products/edit/${this.id}`)
                .then(r => this.applyProductData(r.data.data || {}))
                .catch(() => { });
        },

        applyProductData(d) {
            this.isDraft = !!d.is_draft;
            Object.assign(this.basics, {
                brand_id: d.brand_id || 0,
                tax_category_id: d.tax_category_id || null,
                product_type: d.product_type || 0,
                is_food: Number(d.is_food) || 0,
                is_addon_only: Number(d.is_addon_only) || 0,
                is_prescription_required: Number(d.is_prescription_required) || 0,
                made_in: d.made_in || '',
                return_status: d.return_status || 0,
                return_days: d.return_days || 0,
                cancelable_status: d.cancelable_status || 0,
                till_status_quick: Number(d.till_status_quick ?? d.till_status) || 2,
                till_status_ecommerce: Number(d.till_status_ecommerce ?? d.till_status) || 2,
                cod_allowed: Number(d.cod_allowed ?? 1) ? 1 : 0,
                total_allowed_quantity: d.total_allowed_quantity || 0,
                status: d.status ?? 1,
                sales_channel: d.sales_channel || 'both',
            });
            this.fetchChannelBranches();

            if (Array.isArray(d.translations)) {
                for (const t of d.translations) {
                    if (!this.translations[t.language_id]) continue;
                    this.translations[t.language_id] = {
                        name: t.name || '',
                        description: t.description || '',
                        short_description: t.short_description || '',
                        manufacturer: t.manufacturer || '',
                        tags: t.tags || '',
                        made_in: t.made_in || '',
                        meta_title: t.meta_title || '',
                        meta_keywords: t.meta_keywords || '',
                        schema_markup: t.schema_markup || '',
                        meta_description: t.meta_description || '',
                    };
                }
            }

            return this.resolveCategoryChain(d.category_id).then(() => {
                return this.loadCategorySchema().then(() => {
                    this.hydrateVariantsFromEdit(d.variants || []);
                    this.maxReachedStep = 5;
                });
            });
        },

        resolveCategoryChain(catId) {
            if (!catId) return this.initCategoryLevels();
            this.categoryLevelsLoading = true;
            return axios.get(this.$apiUrl + '/categories/chain', { params: { id: catId } })
                .then(r => {
                    const levels = Array.isArray(r.data.data) ? r.data.data : [];
                    if (levels.length) {
                        this.categoryLevels = levels.map(l => ({
                            parentId: Number(l.parentId || 0),
                            items: Array.isArray(l.items) ? l.items : [],
                            selectedId: l.selectedId != null ? l.selectedId : null,
                        }));
                    }
                })
                .catch(() => { })
                .finally(() => { this.categoryLevelsLoading = false; });
        },

        hydrateVariantsFromEdit(rows) {
            const selByAttr = {};
            for (const v of rows) {
                for (const av of (v.attribute_values || [])) {
                    if (!selByAttr[av.attribute_id]) selByAttr[av.attribute_id] = new Set();
                    selByAttr[av.attribute_id].add(av.value_id);
                }
            }
            const sel = {};
            for (const k of Object.keys(selByAttr)) sel[k] = [...selByAttr[k]];
            this.selectedValuesByAttr = sel;

            this.$nextTick(() => {
                this.variants = rows.map(v => this.hydrateVariant(v));
                // Model (product + variants) is now filled — snapshot the clean baseline.
                this.captureFormBaseline();
            });
        },

        clearAllSelections() {
            this.selectedValuesByAttr = {};
            this.variants = [];
        },

        hydrateVariant(v) {
            const trans = {};
            for (const l of this.languages) trans[l.id] = { name: '' };
            if (Array.isArray(v.translations)) {
                for (const t of v.translations) {
                    if (trans[t.language_id]) trans[t.language_id].name = t.name || '';
                }
            }
            if (this.defaultLanguageId && !trans[this.defaultLanguageId].name) {
                trans[this.defaultLanguageId].name = v.name || '';
            }
            const customByField = {};
            for (const cv of (v.custom_values || [])) {
                customByField[cv.field_id] = {
                    value_text: cv.value_text,
                    value_number: cv.value_number,
                    value_date: cv.value_date,
                    value_json: cv.value_json,
                    translations: {},
                };
                if (Array.isArray(cv.translations)) {
                    for (const t of cv.translations) {
                        customByField[cv.field_id].translations[t.language_id] = {
                            value_text: t.value_text,
                            value_json: t.value_json,
                        };
                    }
                }
            }
            return {
                id: v.id || null,
                tmpKey: 't_' + (++this._tmpKeyCounter),
                attribute_values: (v.attribute_values || []).map(av => ({
                    attribute_id: av.attribute_id, value_id: av.value_id,
                })),
                translations: trans,
                sku: v.sku || '',
                hsn_code: v.hsn_code || '',
                weight: v.weight ?? '',
                length: v.length ?? '',
                breadth: v.breadth ?? '',
                height: v.height ?? '',
                // Price / discounted / slabs / purchase are per-branch now (branch_stocks).
                stock: Number(v.stock) || 0,
                image_file: null,
                image_preview: v.image || null,
                image_url: v.image || null,
                image_path: v.image_path || null,
                gallery_files: [],
                gallery_previews: [],
                gallery_keep: (v.gallery || []).map(g => ({ id: g.id, url: g.url, path: g.path })),
                gallery_media: [],
                gallery_delete_ids: [],
                custom_by_field: customByField,
                branch_stocks: (v.branch_stocks || []).map(s => ({
                    branch_id: Number(s.branch_id),
                    is_listed: Number(s.is_listed) === 1,
                    is_unlimited_stock: Number(s.is_unlimited_stock || 0),
                    stock_status: Number(s.stock_status ?? 1),
                    available: Number(s.available || 0),
                    reserved: Number(s.reserved || 0),
                    min_alert: Number(s.min_alert || 0),
                    // Branch-wise pricing.
                    price: (s.price === null || s.price === undefined) ? null : Number(s.price),
                    discounted_price: (s.discounted_price === null || s.discounted_price === undefined) ? null : Number(s.discounted_price),
                    purchase_price: (s.purchase_price === null || s.purchase_price === undefined) ? null : Number(s.purchase_price),
                    // Does that branch's price already contain its tax?
                    is_tax_inclusive: !!s.is_tax_inclusive,
                    pricing_slabs: Array.isArray(s.pricing_slabs)
                        ? s.pricing_slabs.map(x => ({ min_qty: x.min_qty ?? null, max_qty: x.max_qty ?? null, price: x.price ?? null }))
                        : [],
                })),
            };
        },

        loadCategorySchema() {
            const catId = this.effectiveCategoryId;
            if (!catId) {
                this.categoryAttributes = [];
                this.categoryCustomFields = [];
                this.categoryCustomSections = [];
                this._schemaKey = null;
                this._schemaReq = null;
                return Promise.resolve();
            }

            if (this._schemaKey === catId && this._schemaReq) return this._schemaReq;
            this._schemaKey = catId;
            this._schemaReq = axios.get(this.$apiUrl + '/categories/schema', { params: { id: catId } }).then(r => {
                const d = r.data.data || {};
                const attrs = d.attributes || [];
                const sections = d.custom_sections || [];
                attrs.forEach(a => {
                    Object.freeze(a.translations || []);
                    (a.values || []).forEach(v => Object.freeze(v.translations || []));
                    Object.freeze(a.values || []);
                    Object.freeze(a);
                });
                sections.forEach(s => {
                    (s.fields || []).forEach(f => {
                        Object.freeze(f.translations || []);
                        Object.freeze(f);
                    });
                    Object.freeze(s.fields || []);
                    Object.freeze(s);
                });
                this.categoryAttributes = Object.freeze(attrs);
                this.categoryCustomSections = Object.freeze(sections);
                this.categoryCustomFields = Object.freeze([].concat(...sections.map(s => s.fields || [])));
            }).catch(() => { });
            return this._schemaReq;
        },

        /** One attribute's values as the dropdown wants them, in the admin's language. */
        attrValueOptions(attr) {
            return (attr.values || []).map(v => ({ id: v.id, name: this.valueLabel(v) }));
        },
        attrSelectedCount(attr) {
            return (this.selectedValuesByAttr[attr.id] || []).length;
        },
        /**
         * Replace one attribute's chosen values, then rebuild the matrix.
         *
         * The dropdown hands back the whole list rather than one change at a time, which
         * is also how clearing the field arrives — an empty array, and the attribute
         * stops taking part in the combinations.
         */
        setAttrValues(attrId, ids) {
            this.selectedValuesByAttr = {
                ...this.selectedValuesByAttr,
                [attrId]: Array.isArray(ids) ? ids : [],
            };
            this.regenerateVariants();
        },
        generateAllVariants() {
            const sel = {};
            (this.categoryAttributes || []).forEach(a => {
                sel[a.id] = (a.values || []).map(v => v.id);
            });
            this.selectedValuesByAttr = sel;
            this.$nextTick(() => this.regenerateVariants());
        },

        regenerateVariants() {
            const attrs = (this.categoryAttributes || []).filter(a =>
                (this.selectedValuesByAttr[a.id] || []).length > 0
            );
            if (attrs.length === 0) {
                this.variants = [];
                return;
            }
            const combos = this.cartesian(attrs.map(a =>
                (this.selectedValuesByAttr[a.id] || []).map(vid => ({ attribute_id: a.id, value_id: vid }))
            ));

            if (!this._variantCache) this._variantCache = {};
            for (const v of this.variants) {
                this._variantCache[this.comboKey(v.attribute_values)] = v;
            }

            // Exact match: an unchanged combo keeps its variant object as-is.
            const existingByKey = {};
            for (const v of this.variants) {
                existingByKey[this.comboKey(v.attribute_values)] = v;
            }

            const newAttrIds = new Set(attrs.map(a => a.id));
            const oldAttrIds = new Set();
            (this.variants[0] && this.variants[0].attribute_values || [])
                .forEach(c => oldAttrIds.add(c.attribute_id));
            const sharedIds = [...newAttrIds].filter(id => oldAttrIds.has(id));
            const sharedKey = (av) => (av || [])
                .filter(c => sharedIds.includes(c.attribute_id))
                .slice().sort((a, b) => a.attribute_id - b.attribute_id)
                .map(c => c.attribute_id + ':' + c.value_id).join('|');

            const existingBySharedKey = {};
            if (sharedIds.length) {
                for (const v of this.variants) {
                    const k = sharedKey(v.attribute_values);
                    if (!(k in existingBySharedKey)) existingBySharedKey[k] = v; // first wins
                }
            }

            const idClaimed = new Set();

            this.variants = combos.map(combo => {
                const key = this.comboKey(combo);
                if (existingByKey[key]) return existingByKey[key];

                // Re-added combo we saw before → restore its cached data.
                const cached = this._variantCache[key];
                if (cached) {
                    if (cached.id) idClaimed.add(cached.id);
                    return cached;
                }

                const src = sharedIds.length ? existingBySharedKey[sharedKey(combo)] : null;
                if (src) return this.carryVariantData(src, combo, idClaimed);

                return this.blankVariant(combo);
            });
        },

        carryVariantData(src, combo, idClaimed) {
            const keepId = !!src.id && !idClaimed.has(src.id);
            if (src.id) idClaimed.add(src.id);

            const cloneVal = (val) => {
                if (Array.isArray(val)) return val.map(cloneVal);
                if (val && typeof val === 'object' && typeof File !== 'undefined' && val instanceof File) return val;
                if (val && typeof val === 'object') return { ...val };
                return val;
            };

            const trans = {};
            for (const l of this.languages) {
                trans[l.id] = { name: this.autoVariantName(combo, l.id) };
            }

            return {
                id: keepId ? src.id : null,
                tmpKey: keepId ? (src.tmpKey || ('t_' + (++this._tmpKeyCounter))) : ('t_' + (++this._tmpKeyCounter)),
                attribute_values: combo,
                translations: trans,
                sku: keepId ? src.sku : '',
                hsn_code: src.hsn_code || '',
                weight: src.weight ?? '',
                length: src.length ?? '',
                breadth: src.breadth ?? '',
                height: src.height ?? '',
                stock: src.stock ?? 0,
                image_file: src.image_file || null,
                image_preview: src.image_preview || null,
                image_url: src.image_url || null,
                image_path: src.image_path || null,
                gallery_files: cloneVal(src.gallery_files || []),
                gallery_previews: cloneVal(src.gallery_previews || []),
                gallery_keep: cloneVal(src.gallery_keep || []),
                gallery_media: cloneVal(src.gallery_media || []),
                gallery_delete_ids: cloneVal(src.gallery_delete_ids || []),
                custom_by_field: cloneVal(src.custom_by_field || {}),
                branch_stocks: cloneVal(src.branch_stocks || []),
            };
        },

        cartesian(arrays) {
            return arrays.reduce((acc, curr) =>
                acc.flatMap(a => curr.map(b => a.concat([b]))),
                [[]]);
        },

        comboKey(combo) {
            return combo.slice().sort((a, b) => a.attribute_id - b.attribute_id)
                .map(c => c.attribute_id + ':' + c.value_id).join('|');
        },

        blankVariant(combo) {
            const trans = {};
            for (const l of this.languages) trans[l.id] = { name: this.autoVariantName(combo, l.id) };
            return {
                id: null,
                tmpKey: 't_' + (++this._tmpKeyCounter),
                attribute_values: combo,
                translations: trans,
                sku: '',
                hsn_code: '',
                weight: '',
                length: '',
                breadth: '',
                height: '',
                // Price / discounted / slabs / purchase are per-branch now (branch_stocks).
                stock: 0,
                image_file: null,
                image_preview: null,
                image_url: null,
                image_path: null,
                gallery_files: [],
                gallery_previews: [],
                gallery_keep: [],
                gallery_media: [],
                gallery_delete_ids: [],
                custom_by_field: {},
                branch_stocks: [],
            };
        },

        autoVariantName(combo, langId) {
            const values = this.attrValueLabels(combo, langId);
            const product = this.productNameForLang(langId);

            if (!product) {
                return values;
            }

            return values ? product + ' - ' + values : product;
        },
        /** The attribute values of one combination, in the asked-for language. */
        attrValueLabels(combo, langId) {
            return combo.map(c => {
                const attr = (this.categoryAttributes || []).find(a => a.id === c.attribute_id);
                const val = attr ? (attr.values || []).find(v => v.id === c.value_id) : null;
                return val ? this.valueLabelForLang(val, langId) : '';
            }).filter(Boolean).join(' / ');
        },

        productNameForLang(langId) {
            const own = String(this.translations?.[langId]?.name || '').trim();
            if (own) {
                return own;
            }

            return String(this.translations?.[this.defaultLanguageId]?.name || '').trim();
        },

        /**
         * Every active category, for the picker. The same list the category form's own
         * parent picker loads, so there is nothing new behind it.
         */
        fetchAllCategories() {
            return axios.get(this.$apiUrl + '/categories/options_data')
                .then(r => { this.allCategories = r.data.data || []; })
                .catch(() => { this.allCategories = []; });
        },
        /**
         * Chosen from the picker: open every level that leads there and select it.
         *
         * The same call the form makes when it opens an existing product, so a category
         * picked this way lands exactly as clicking through the pills would have left
         * it — attributes included, since those follow the selection.
         */
        pickCategoryFromTree(id) {
            if (!id || Number(id) === Number(this.effectiveCategoryId)) return;

            if (this.id && !this._catChangeWarned && (this.variants || []).length > 0) {
                this._catChangeWarned = true;
                const msg = __('product_category_change_warning') || 'Changing the category changes the available attributes. Variants built from the previous category may no longer match and will need review.';
                if (window.toastr) window.toastr.warning(msg);
            }

            this.resolveCategoryChain(Number(id));
        },
        catLabel(c) {
            const t = Array.isArray(c.translations)
                ? c.translations.find(x => Number(x.language_id) === Number(this.defaultLanguageId)) : null;
            return (t && t.name && t.name.trim()) ? t.name : (c.name || '');
        },
        attrLabel(a) {
            const t = Array.isArray(a.translations)
                ? a.translations.find(x => Number(x.language_id) === Number(this.defaultLanguageId)) : null;
            return (t && t.name && t.name.trim()) ? t.name : (a.name || '');
        },
        valueLabel(v) { return this.valueLabelForLang(v, this.defaultLanguageId); },
        valueLabelForLang(v, langId) {
            const t = Array.isArray(v.translations)
                ? v.translations.find(x => Number(x.language_id) === Number(langId)) : null;
            return (t && t.value && t.value.trim()) ? t.value : (v.value || '');
        },
        valueCount(attr) { return Array.isArray(attr.values) ? attr.values.length : 0; },
        hasTranslatableFields(section) {
            return (section.fields || []).some(f => ['text', 'textarea'].includes(f.field_type));
        },
        hasNonTranslatableFields(section) {
            return (section.fields || []).some(f => ['number', 'date', 'dropdown', 'checkbox', 'boolean'].includes(f.field_type));
        },
        sectionLabelForLang(s, langId) {
            const t = Array.isArray(s.translations)
                ? s.translations.find(x => Number(x.language_id) === Number(langId)) : null;
            if (t && t.name && String(t.name).trim()) return t.name;
            if (s && s.names && s.names[langId] && String(s.names[langId]).trim()) return s.names[langId];
            return s?.name || s?.title || s?.section_name || __('custom_section');
        },
        fieldLabelForLang(f, langId) {
            const t = Array.isArray(f.translations)
                ? f.translations.find(x => Number(x.language_id) === Number(langId)) : null;
            return (t && t.field_label) ? t.field_label : (f.field_label || '');
        },
        fieldOptionsForLang(f, langId) {
            const t = Array.isArray(f.translations)
                ? f.translations.find(x => Number(x.language_id) === Number(langId)) : null;
            if (t && Array.isArray(t.options) && t.options.length) return t.options;
            return Array.isArray(f.options) ? f.options : [];
        },
        variantAttrSummary(v) {
            return (v.attribute_values || []).map(av => {
                const attr = (this.categoryAttributes || []).find(a => a.id === av.attribute_id);
                const val = attr ? (attr.values || []).find(x => x.id === av.value_id) : null;
                return val ? this.valueLabel(val) : '';
            }).filter(Boolean).join(' / ');
        },
        reviewGallery(v) {
            const keep = (v.gallery_keep || [])
                .filter(g => g && g.url)
                .map(g => ({ url: g.url, video: this.isVideoUrl(g.url) }));
            const fresh = (v.gallery_previews || [])
                .map((url, i) => url ? { url, video: this.isVideoFile((v.gallery_files || [])[i]) } : null)
                .filter(Boolean);
            return keep.concat(fresh);
        },
        /** A stored path or served URL — all we have for a saved row. */
        isVideoUrl(url) {
            return /\.(mp4|m4v|mov|webm)(\?|#|$)/i.test(String(url || ''));
        },
        /** A just-picked File, whose MIME type the browser already read. */
        isVideoFile(file) {
            return !!(file && typeof file.type === 'string' && file.type.startsWith('video/'));
        },
        variantAttrChips(v) {
            return (v.attribute_values || []).map(av => {
                const attr = (this.categoryAttributes || []).find(a => a.id === av.attribute_id);
                const val = attr ? (attr.values || []).find(x => x.id === av.value_id) : null;
                if (!attr || !val) return null;
                return { label: this.attrLabel(attr), value: this.valueLabel(val) };
            }).filter(Boolean);
        },
        variantCustomSections(v) {
            const out = [];
            for (const section of (this.categoryCustomSections || [])) {
                const items = [];
                for (const f of (section.fields || [])) {
                    let val = this.rawCustomScalar(v, f, this.defaultLangObj);
                    if (f.field_type === 'checkbox') {
                        const arr = this.customMultiValues(v, f);
                        if (!arr.length) continue;
                        items.push({ label: this.fieldLabelForLang(f, this.defaultLanguageId), value: arr.join(', ') });
                        continue;
                    }
                    if (val === '' || val === null || val === undefined) continue;
                    if (f.field_type === 'boolean') val = String(val) === '1' ? __('yes') : __('no');
                    items.push({ label: this.fieldLabelForLang(f, this.defaultLanguageId), value: val });
                }
                if (items.length) {
                    out.push({ name: this.sectionLabelForLang(section, this.defaultLanguageId), items });
                }
            }
            return out;
        },

        onVariantMainImage(f, idx) {
            const v = this.variants[idx];
            v.image_preview = f ? URL.createObjectURL(f) : (v.image_url || null);
        },
        onVariantGallery(files, idx) {
            const v = this.variants[idx];
            for (const f of (files || [])) {
                v.gallery_files.push(f);
                v.gallery_previews.push(URL.createObjectURL(f));
            }
        },
        removeKeptGalleryImage(vIdx, gIdx) {
            const v = this.variants[vIdx];
            const removed = v.gallery_keep.splice(gIdx, 1)[0];
            if (removed && removed.id) v.gallery_delete_ids.push(removed.id);
        },
        removeNewGalleryImage(vIdx, pIdx) {
            const v = this.variants[vIdx];
            v.gallery_files.splice(pIdx, 1);
            v.gallery_previews.splice(pIdx, 1);
        },

        // Custom dropdown fields are a plain string list; AppSelect needs { id, name }.
        scalarOptions(list) {
            return (list || []).map(o => ({ id: o, name: o }));
        },
        rawCustomScalar(v, field, lang) {
            const entry = v.custom_by_field[field.id] || {};
            if (lang.is_default) {
                if (field.field_type === 'number') return entry.value_number ?? '';
                if (field.field_type === 'date') return entry.value_date ?? '';
                return entry.value_text ?? '';
            }
            const t = (entry.translations || {})[lang.id] || {};
            return t.value_text ?? '';
        },
        customMultiValues(v, field) {
            const entry = v.custom_by_field[field.id] || {};
            return Array.isArray(entry.value_json) ? entry.value_json : [];
        },
        toggleCustomMulti(v, field, opt) {
            if (!v.custom_by_field[field.id]) v.custom_by_field[field.id] = { translations: {} };
            const entry = v.custom_by_field[field.id];
            if (!Array.isArray(entry.value_json)) entry.value_json = [];
            const i = entry.value_json.indexOf(opt);
            if (i >= 0) entry.value_json.splice(i, 1);
            else entry.value_json.push(opt);
        },
        setCustomScalar(v, field, lang, raw) {
            if (!v.custom_by_field[field.id]) v.custom_by_field[field.id] = { translations: {} };
            const entry = v.custom_by_field[field.id];
            if (lang.is_default) {
                if (field.field_type === 'number') {
                    entry.value_number = raw === '' ? null : Number(raw);
                } else if (field.field_type === 'date') {
                    entry.value_date = raw || null;
                } else {
                    entry.value_text = raw;
                }
            } else {
                if (!entry.translations) entry.translations = {};
                entry.translations[lang.id] = { value_text: raw };
            }
        },

        openAttributeModal(record) {
            this.attributeModal = record || null;
        },
        onAttributeSaved(msg, attrId) {
            this.attributeModal = false;
            const reload = () => {
                this._schemaKey = null;
                this._schemaReq = null;
                this.loadCategorySchema().then(() => this.pruneSelectedValues());
            };
            // A newly created attribute isn't linked to any category yet — attach it
            // to the current one so it shows up in this category's schema.
            if (attrId && this.effectiveCategoryId) {
                axios.post(this.$apiUrl + '/categories/attach_attribute', {
                    category_id: this.effectiveCategoryId,
                    attribute_id: attrId,
                }).then(reload).catch(reload);
            } else {
                reload();
            }
        },
        // Remove selections pointing at values that were deleted in the editor.
        pruneSelectedValues() {
            const validByAttr = {};
            (this.categoryAttributes || []).forEach(a => {
                validByAttr[a.id] = new Set((a.values || []).map(v => v.id));
            });
            Object.keys(this.selectedValuesByAttr || {}).forEach(attrId => {
                const valid = validByAttr[attrId];
                if (!valid) { delete this.selectedValuesByAttr[attrId]; return; }
                this.selectedValuesByAttr[attrId] = (this.selectedValuesByAttr[attrId] || []).filter(id => valid.has(id));
            });
        },

        openCategoryModal() {
            const last = this.selectedCategoryPath[this.selectedCategoryPath.length - 1];
            this.categoryModalParentId = last ? last.id : 0;
            this.categoryModal = true;
        },
        onCategorySaved(payload) {
            this.categoryModal = false;
            const newId = payload?.id || null;
            if (!newId) return;

            this.fetchAllCategories()
                .then(() => this.resolveCategoryChain(newId))
                .then(() => this.loadCategorySchema());
        },

        onStepClick(stepId) {
            if (stepId < this.currentStep || stepId <= this.maxReachedStep) {
                this.currentStep = stepId;
            }
        },
        prevStep() { if (this.currentStep > 1) this.currentStep -= 1; },
        nextStep() {
            if (!this.validateStep(this.currentStep)) return;
            if (this.currentStep < 5) {
                this.currentStep += 1;
                if (this.currentStep > this.maxReachedStep) this.maxReachedStep = this.currentStep;
            }
        },
        validateStep(step) {
            if (step === 1) {
                if (!this.effectiveCategoryId) {
                    this.showError(__('please_select_category')); return false;
                }
                if (this.categoryAttributes.length === 0) {
                    this.showError(__('selected_category_has_no_attributes_add_first')); return false;
                }
                return true;
            }
            if (step === 2) {
                const pname = this.translations[this.defaultLanguageId]?.name;
                if (!pname || !String(pname).trim()) {
                    this.activeLanguageTab = this.languages.findIndex(l => l.is_default);
                    this.showError(__('please_fill_product_name')); return false;
                }
                const desc = this.translations[this.defaultLanguageId]?.description;
                if (!desc || !String(desc).replace(/<[^>]*>/g, '').trim()) {
                    this.activeLanguageTab = this.languages.findIndex(l => l.is_default);
                    this.showError(__('please_fill_description')); return false;
                }
                return true;
            }
            if (step === 3) {
                if (this.generatedVariantCount === 0) {
                    this.showError(__('please_select_at_least_one_value_per_attribute')); return false;
                }
                for (let i = 0; i < this.variants.length; i++) {
                    const v = this.variants[i];
                    const vname = v.translations[this.defaultLanguageId]?.name;
                    if (!vname || !vname.trim()) {
                        this.showError(__('variant_name_required', { n: i + 1 })); return false;
                    }
                    if (!v.sku || !v.sku.trim()) {
                        this.showError(__('sku_required', { n: i + 1 })); return false;
                    }
                    if (v.skuError) {
                        this.showError(v.skuError); return false;
                    }
                    if (!v.image_file && !v.image_path) {
                        this.showError(__('variant_main_image_required', { n: i + 1 })); return false;
                    }
                    // Price is per-branch (PVSS): each listed branch needs selling + purchase
                    // price; discounted (if set) must not exceed selling. At least one branch
                    // must be listed so the variant is sellable somewhere.
                    const listed = (v.branch_stocks || []).filter(s => s.is_listed);
                    if (listed.length === 0) {
                        this.showError(__('list_variant_in_at_least_one_branch', { n: i + 1 })); return false;
                    }
                    for (const s of listed) {
                        const st = this.channelBranches.find(x => Number(x.id) === Number(s.branch_id));
                        const label = st ? st.name : ('#' + s.branch_id);
                        if (!(Number(s.price) > 0)) {
                            this.showError(__('branch_selling_price_required', { n: i + 1, branch: label })); return false;
                        }
                        if (Number(s.discounted_price) > 0 && Number(s.discounted_price) > Number(s.price)) {
                            this.showError(__('branch_discounted_exceeds_selling', { n: i + 1, branch: label })); return false;
                        }
                        if (!(Number(s.purchase_price) >= 0)) {
                            this.showError(__('branch_purchase_price_required', { n: i + 1, branch: label })); return false;
                        }
                        // Quantity slabs: qty↔price both-or-neither, valid range, no overlap.
                        const slabErr = this.validateBranchSlabs(s.pricing_slabs, s);
                        if (slabErr) {
                            this.showError(__(slabErr, { n: i + 1, branch: label })); return false;
                        }
                    }
                    for (const f of this.categoryCustomFields) {
                        if (!f.is_required) continue;
                        const entry = v.custom_by_field[f.id] || {};
                        const hasVal = entry.value_text || entry.value_number || entry.value_date || entry.value_json;
                        if (!hasVal) {
                            this.showError(__('custom_field_required', { field: this.fieldLabelForLang(f, this.defaultLanguageId), n: i + 1 }));
                            return false;
                        }
                    }
                }
                return true;
            }
            if (step === 4) {
                // SEO — all fields optional, nothing to validate.
                return true;
            }
            return true;
        },

        openMediaPicker(target, vIdx) {
            this.mediaPicker = { show: true, target, vIdx };
        },
        onMediaSelect(items) {
            const { target, vIdx } = this.mediaPicker;
            const v = this.variants[vIdx];
            if (!v || !items.length) return;
            if (target === 'main') {
                // Reference the media file directly — nothing is re-uploaded.
                v.image_path = items[0].path;
                v.image_url = items[0].url;
                v.image_file = null;
            } else {
                if (!Array.isArray(v.gallery_media)) v.gallery_media = [];
                for (const it of items) {
                    if (!v.gallery_media.some(m => m.path === it.path)) v.gallery_media.push(it);
                }
            }
            this.markAutoSaveDirty();
        },

        buildPayload(isDraft) {
            const fd = new FormData();
            if (this.id) fd.append('id', this.id);
            fd.append('category_id', this.effectiveCategoryId);
            fd.append('is_draft', isDraft ? 1 : 0);
            for (const [k, v] of Object.entries(this.basics)) fd.append(k, v ?? '');
            // Only meaningful for a food product; sent always so clearing the flag
            const transOut = {};
            for (const lid of Object.keys(this.translations)) {
                transOut[lid] = { ...this.translations[lid] };
            }
            fd.append('translations', JSON.stringify(transOut));

            const attrValuePairs = [];
            for (const attrId of Object.keys(this.selectedValuesByAttr)) {
                for (const valId of this.selectedValuesByAttr[attrId]) {
                    attrValuePairs.push({ attribute_id: Number(attrId), value_id: Number(valId) });
                }
            }
            fd.append('attribute_value_ids', JSON.stringify(attrValuePairs));

            const variantsOut = this.variants.map((v, idx) => {
                if (v.image_file) fd.append(`variant_images[${idx}][main]`, v.image_file);
                for (const f of v.gallery_files) fd.append(`variant_images[${idx}][gallery][]`, f);

                const customRows = Object.keys(v.custom_by_field).map(fieldId => {
                    const entry = v.custom_by_field[fieldId];
                    return {
                        field_id: Number(fieldId),
                        value_text: entry.value_text ?? null,
                        value_number: entry.value_number ?? null,
                        value_date: entry.value_date ?? null,
                        value_json: entry.value_json ?? null,
                        translations: entry.translations || {},
                    };
                });

                return {
                    id: v.id || undefined,
                    name: v.translations[this.defaultLanguageId]?.name || '',
                    sku: v.sku,
                    hsn_code: v.hsn_code || '',
                    weight: v.weight ?? '',
                    length: v.length ?? '',
                    breadth: v.breadth ?? '',
                    height: v.height ?? '',
                    // Price / discounted / slabs / purchase are per-branch now (branch_stocks).
                    stock: v.stock,
                    image_path: v.image_path || null,
                    attribute_values: v.attribute_values,
                    translations: v.translations,
                    custom_values: customRows,
                    gallery_delete_ids: v.gallery_delete_ids,
                    gallery_paths: (v.gallery_media || []).map(m => m.path),
                    branch_stocks: (v.branch_stocks || []).map(s => ({
                        branch_id: s.branch_id,
                        is_listed: s.is_listed ? 1 : 0,
                        is_unlimited_stock: Number(s.is_unlimited_stock) === 1 ? 1 : 0,
                        stock_status: Number(s.stock_status) ? 1 : 0,
                        available: Number(s.available) || 0,
                        reserved: Number(s.reserved) || 0,
                        min_alert: Number(s.min_alert) || 0,
                        // Branch-wise pricing. Only send price/discounted for listed branches.
                        price: s.is_listed ? (Number(s.price) || 0) : null,
                        discounted_price: s.is_listed ? (Number(s.discounted_price) || 0) : null,
                        purchase_price: s.is_listed ? (Number(s.purchase_price) || 0) : null,
                        // Meaningless without tax, so never persisted in that state.
                        is_tax_inclusive: (this.basics.tax_category_id && s.is_tax_inclusive) ? 1 : 0,
                        pricing_slabs: (s.pricing_slabs || [])
                            .filter(x => x && x.min_qty && x.price)
                            .map(x => ({
                                min_qty: Number(x.min_qty),
                                max_qty: (x.max_qty === '' || x.max_qty === null || x.max_qty === undefined) ? null : Number(x.max_qty),
                                price: Number(x.price),
                            })),
                    })),
                };
            });
            fd.append('variants', JSON.stringify(variantsOut));
            fd.append('sales_channel', this.basics.sales_channel || 'both');
            return fd;
        },

        postPayload(fd, successMessageKey) {
            const url = this.id ? '/products/update' : '/products/save';
            this.isLoading = true;
            axios.post(this.$apiUrl + url, fd, {
                headers: { 'Content-Type': 'multipart/form-data' },
            }).then(res => {
                const data = res.data || {};
                if (data.status !== 1) {
                    this.showError(data.message || __('something_went_wrong'));
                    return;
                }
                // Mark clean so the post-save redirect doesn't trip the unsaved-changes guard.
                this.captureFormBaseline();
                this.showMessage('success', __(successMessageKey));
                this.$router.push({ path: '/products' });
            }).catch(err => {
                const msg = err.response?.data?.message || err.message || __('something_went_wrong');
                this.showError(msg);
            }).finally(() => {
                this.isLoading = false;
            });
        },

        async saveRecord() {
            if (!this.validateStep(1) || !this.validateStep(2) || !this.validateStep(3)) return;
            await this.autoSaveSettled();
            this.postPayload(this.buildPayload(false), 'product_saved_successfully');
        },

        async saveDraft() {
            if (!this.effectiveCategoryId) {
                this.showError(__('please_select_category')); return;
            }
            await this.autoSaveSettled();
            this.postPayload(this.buildPayload(true), 'draft_saved_successfully');
        },

        /** Resolve once no auto-save is in flight (never rejects — a failed one is retried). */
        autoSaveSettled() {
            return this.autoSavePromise ? this.autoSavePromise.catch(() => { }) : Promise.resolve();
        },

        markAutoSaveDirty() {
            if (this.isLoadingData) return;
            this.autoSaveDirty = true;
        },
        autoSaveTick() {
            if (this.isLoadingData || this.isLoading || this.autoSaveInFlight) return;
            if (!this.autoSaveDirty) return;
            if (!this.effectiveCategoryId) return;
            const defId = this.defaultLanguageId;
            const name = defId && this.translations[defId] ? String(this.translations[defId].name || '').trim() : '';
            if (!name) return;
            this.autoSaveDraft();
        },
        autoSaveDraft() {
            this.autoSaveInFlight = true;
            this.autoSaveDirty = false;
            const fd = this.buildPayload(true);
            const url = this.id ? '/products/update' : '/products/save';
            this.autoSavePromise = axios.post(this.$apiUrl + url, fd, {
                headers: { 'Content-Type': 'multipart/form-data' },
            }).then(res => {
                const d = res.data || {};
                if (d.status !== 1) {
                    this.autoSaveDirty = true;
                    return;
                }
                this.adoptSavedVariants(d.data && d.data.variants);
                const newId = d.data && d.data.id ? Number(d.data.id) : null;
                if (!this.id && newId) {
                    this.id = newId;
                    this.isDraft = true;
                    // Swap URL so refresh keeps editing the same draft.
                    if (this.$route.name !== 'EditProduct') {
                        this.$router.replace({ name: 'EditProduct', params: { id: newId } }).catch(() => { });
                    }

                    this.recheckVariantSkus();
                }
                this.lastAutoSavedAt = new Date();
                // Draft persisted — refresh the baseline so leaving won't warn about saved edits.
                this.captureFormBaseline();
            }).catch(() => {
                this.autoSaveDirty = true;
            }).finally(() => {
                this.autoSaveInFlight = false;
                this.autoSavePromise = null;
            });

            return this.autoSavePromise;
        },

        adoptSavedVariants(saved) {
            if (!Array.isArray(saved) || !saved.length) return;
            const bySku = {};
            for (const row of saved) {
                const key = String(row.sku || '').trim().toLowerCase();
                if (key) bySku[key] = row;
            }
            this.variants.forEach((v, idx) => {
                const key = String(v.sku || '').trim().toLowerCase();
                const row = (key && bySku[key]) || saved[idx];
                if (!row) return;
                v.id = Number(row.id);
                // The file is on the server now; keep sending its path instead of the file.
                if (row.image_path) {
                    v.image_path = row.image_path;
                    v.image_url = row.image;
                    v.image_preview = row.image;
                    v.image_file = null;
                }
                // Uploaded gallery files came back as stored images — move them to the kept
                // list so the next save references them instead of uploading copies.
                const gallery = Array.isArray(row.gallery) ? row.gallery : [];
                v.gallery_keep = gallery.map(g => ({ id: g.id, url: g.url, path: g.path }));
                v.gallery_files = [];
                v.gallery_previews = [];
                v.gallery_media = [];
                v.gallery_delete_ids = [];
            });
        },

        /** Re-run the server SKU check for every variant against the current product id. */
        recheckVariantSkus() {
            for (const v of this.variants) {
                const sku = (v.sku || '').trim();
                if (!sku) {
                    v.skuError = '';
                    continue;
                }
                if (this.variants.some(o => o !== v && (o.sku || '').trim().toLowerCase() === sku.toLowerCase())) {
                    v.skuError = __('sku_duplicate_in_variants') || 'This SKU is already used by another variant here.';
                    continue;
                }
                axios.get(this.$apiUrl + '/products/check_sku', { params: { sku, product_id: this.id || 0 } })
                    .then(r => {
                        if ((v.sku || '').trim() !== sku) return;
                        v.skuError = (r.data.data && r.data.data.available === false)
                            ? (__('sku_already_used') || 'This SKU is already used by another product.')
                            : '';
                    })
                    .catch(() => { });
            }
        },
        formatAutoSavedAt(d) {
            if (!d) return '';
            try { return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }); }
            catch (e) { return ''; }
        },
    },
};
</script>

<style scoped>
.step-indicator {
    gap: 0.25rem;
}

/* Keep the margin note out of flow so it doesn't inflate the price row height
   (which pushed the wrapped Customer Price field down). */
.slab-margin-note {
    position: absolute;
    left: 0;
    top: 100%;
    margin-top: 2px;
    white-space: nowrap;
}

.step-item {
    font-size: 0.9rem;
}

.cursor-pointer {
    cursor: pointer;
}

.variant-card {
    background: var(--app-card-bg);
}

.gap-2 {
    gap: 0.5rem;
}

.attr-card {
    background: var(--app-card-bg);
}

.section-card {
    border: 1px solid var(--app-card-border);
    box-shadow: none;
}

.dot-listed {
    display: inline-block;
    width: 9px;
    height: 9px;
    border-radius: 50%;
    margin-right: 6px;
}

.dot-listed.on {
    background: #28a745;
}

.dot-listed.off {
    background: var(--app-muted);
}

.branch-stock-card {
    background: var(--app-card-bg);
}

.branch-stock-card .ss-label {
    flex: 0 0 95px;
    font-size: 0.8rem;
    color: var(--app-muted);
    margin-bottom: 0;
}

.branch-stock-card .ss-ctrl {
    flex: 1 1 auto;
}

/* The switch follows its label, so drop Bootstrap's left indent for the input. */
.branch-stock-card .form-check.form-switch .form-check-input {
    margin-left: 0;
    float: none;
}

/* Quantity slab editor — headers line up exactly over the inputs (Min/Max/Price + remove). */
.slab-grid {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr 32px;
    gap: 8px;
}

.slab-remove-btn {
    width: 32px;
    height: 32px;
    padding: 0;
    line-height: 1;
    flex: 0 0 32px;
}

/* Variant matrix: one attribute's header — name, how many are chosen, its search
   box and Clear, on one line that wraps on a narrow screen. */
.attr-head {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: .5rem;
    margin-bottom: .5rem;
}


.attr-count {
    font-size: .72rem;
    color: var(--bs-primary);
    background: rgba(var(--bs-primary-rgb, 13, 110, 253), 0.08);
    border-radius: 999px;
    padding: .1rem .5rem;
}


.cat-level-label {
    font-size: 0.78rem;
    font-weight: 700;
    color: var(--app-muted);
    letter-spacing: 0.06em;
}

/* The category picker sits beside the Add buttons; wide enough for a nested path. */
.cat-picker {
    flex: 1 1 320px;
    min-width: 240px;
    max-width: 420px;
}

/* The chosen category's path: Parent › Child, with the product's own category
   carrying the weight. */
.cat-path {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: .35rem;
    font-size: .85rem;
    color: var(--app-muted);
}

.cat-path-sep {
    color: var(--app-muted);
    opacity: .6;
}

.cat-path-leaf {
    font-weight: 600;
    color: var(--bs-primary);
}

.cat-path-skel {
    width: 220px;
    height: .8rem;
}

.review-banner {
    border: none;
    background: rgba(var(--bs-primary-rgb), .10);
    color: var(--bs-primary);
}

.review-summary {
    border: 1px solid var(--app-card-border);
    border-radius: 6px;
    overflow: hidden;
}

.review-summary-cell {
    flex: 1 1 0;
    min-width: 140px;
    padding: 12px 16px;
    border-right: 1px solid var(--app-card-border);
}

.review-summary-cell:last-child {
    border-right: none;
}

.review-summary .rs-label {
    font-size: .68rem;
    letter-spacing: .04em;
    text-transform: uppercase;
    color: var(--app-muted);
    margin-bottom: 4px;
}

.review-summary .rs-value {
    font-weight: 600;
    color: var(--app-ink);
}

.review-variant-card {
    border: 1px solid var(--app-card-border);
    transition: box-shadow .15s ease;
}

.review-variant-card:hover {
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.08);
}

.review-variant-media {
    width: 110px;
    margin-right: 18px;
    flex-shrink: 0;
}

.review-variant-media .rv-main {
    width: 110px;
    height: 110px;
    background: var(--app-thead-bg);
    border: 1px solid var(--app-card-border);
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    margin-bottom: 8px;
}

.review-variant-media .rv-main img {
    max-width: 100%;
    max-height: 100%;
    object-fit: contain;
}

.review-variant-media .rv-thumb {
    width: 110px;
    height: 70px;
    background: var(--app-thead-bg);
    border: 1px solid var(--app-card-border);
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    margin-bottom: 8px;
}

.review-variant-media .rv-thumb img,
.review-variant-media .rv-thumb video {
    max-width: 100%;
    max-height: 100%;
    object-fit: contain;
}

.review-variant-noimg {
    color: var(--app-card-border);
    font-size: 2rem;
}

.review-variant-info {
    min-width: 0;
}

.rv-name {
    word-break: break-word;
    overflow-wrap: anywhere;
    line-height: 1.3;
}

/* The grip is styled as part of the chip's button group but is not a button: it
   only exists to be grabbed, so it carries the cursor and no hover action. */
.pv-grip { cursor: grab; display: inline-flex; align-items: center; padding-left: .4rem; padding-right: .4rem; }
.pv-grip:active { cursor: grabbing; }
.pv-drag-ghost { opacity: .4; }

.rv-custom-section {
    border-top: 1px dashed var(--app-card-border);
    padding-top: 8px;
}

.rv-custom-title {
    font-size: .72rem;
    letter-spacing: .03em;
    text-transform: uppercase;
    color: var(--app-muted);
    font-weight: 600;
    margin-bottom: 2px;
}

.rv-kv {
    width: 100%;
    font-size: .85rem;
}

.rv-kv td {
    padding: 2px 0;
}

.rv-kv td:first-child {
    color: var(--app-muted);
    width: 90px;
}

.rv-kv td:last-child {
    color: var(--app-ink);
    font-weight: 500;
}

.rv-attr-chip {
    background: var(--app-thead-bg);
    color: var(--app-ink);
    border-radius: 4px;
    padding: 3px 8px;
    font-size: .78rem;
}

.rv-tag {
    background: var(--app-thead-bg);
    color: var(--app-muted);
    border-radius: 4px;
    padding: 3px 8px;
    font-size: .78rem;
}

.rv-tag-cod {
    background: rgba(34, 197, 94, .14);
    color: #2a8a4d;
}
/* The deep green is tuned for a pale tint; on the dark sheet it goes muddy. */
body.theme-dark .rv-tag-cod {
    color: #4ade80;
}

/* AI-assisted field styles (.ai-field/.ai-wrap/.ai-generating) live in
   public/assets/css/custom/common.css so they can be reused app-wide. */
</style>

<style>
/* The addon editor is a wide grid — group rules, then a row per option carrying a type,
   a name, a quantity, a price source and two money fields. At the default modal width
   those columns wrap into each other. Unscoped because the modal renders outside this
   component's tree. */
.modal-dialog.addon-modal-dialog {
    /* Wider than Bootstrap's modal-xl (1140px), which cramped the option rows, but not
       the full screen — past ~1400px the rows just stretch. */
    max-width: min(1400px, 96vw);
}

/* ROOT CAUSE of the form jumping to the top whenever a dropdown was touched:
   common.css:4751 gives any container holding an open multiselect
   `overflow: visible !important`, so the dropdown can escape its box. On a tall
   scrollable modal that turns the body into a non-scrolling element mid-edit, which
   forces scrollTop to 0 and loses the operator's place. Here the body is big enough to
   hold a 300px menu, so keep it scrolling and let the menu stay inside it. */
.modal-dialog.addon-modal-dialog .modal-body:has(.multiselect--active) {
    overflow-y: auto !important;
    overflow-x: hidden !important;
}

/* A dropdown inside the addon editor opens into a scrollable modal body. Without this
   the open menu is clipped by that scroll box and the browser scrolls to reveal it, so
   the whole form appears to jump the moment a select is touched. Lifting the active
   select above its neighbours lets the menu paint over the rows below it instead. */
.modal-dialog.addon-modal-dialog .multiselect--active {
    z-index: 1056;
}

.modal-dialog.addon-modal-dialog .multiselect__content-wrapper {
    z-index: 1056;
}

/* The scrollable modal never actually made its body a scroll container here — the body
   grew past the dialog and the page scrolled instead, which is why touching a select
   threw the form back to the top. Bound the body and let it do its own scrolling. The
   padding leaves a menu on the last row somewhere to open into. */
.modal-dialog.addon-modal-dialog .modal-body {
    overflow-y: auto;
    max-height: calc(100vh - 13rem);
    padding-bottom: 6rem;
}

/* Widen branch-inventory help popover (default bootstrap max-width 276px is too narrow) */
.popover:has(.branch-help-popover) {
    max-width: 420px !important;
}

.branch-help-popover {
    max-width: 420px !important;
    font-size: 0.82rem;
    line-height: 1.35;
}
</style>
