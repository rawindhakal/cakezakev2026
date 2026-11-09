<template>
    <div class="hb-block-editor">

        <!-- ============ BANNER SLIDER ============ -->
        <template v-if="block.type === 'banner_slider'">
            <div class="row g-2 mb-3">
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('carousel_style') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('carousel_style_hint')" /></label>
                    <AppSelect class="form-select form-select-sm" v-model="cfg.carousel_style" :options="carousel_styleOptions" :searchable="false" />
                </div>
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('indicator') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('indicator_hint')" /></label>
                    <AppSelect class="form-select form-select-sm" v-model="cfg.indicator" :options="indicatorOptions" :searchable="false" />
                </div>
            </div>
            <div class="row g-2 mb-3">
                <div class="col-6 col-md-3 hb-switch-col">
                    <label class="hb-lbl">{{ __('auto_scroll') }}</label>
                    <div class="form-check form-switch ps-0">
                        <input class="form-check-input ms-0" type="checkbox" role="switch" v-model="cfg.auto_scroll">
                    </div>
                </div>
                <div class="col-6 col-md-3 hb-switch-col">
                    <label class="hb-lbl">{{ __('infinite_loop') }}</label>
                    <div class="form-check form-switch ps-0">
                        <input class="form-check-input ms-0" type="checkbox" role="switch" v-model="cfg.infinite_loop">
                    </div>
                </div>
                <div class="col-md-4" v-if="cfg.auto_scroll">
                    <label class="hb-lbl">{{ __('speed_ms') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('speed_ms_hint')" /></label>
                    <DimensionSlider :model-value="cfg.speed_ms" :min="0" :max="8000" :step="100" suffix="ms" :num-width="120" @update:model-value="cfg.speed_ms = $event" />
                </div>
            </div>
            <div class="mb-3">
                <PlatformAspectInput :label="__('image_ratio')" :hint="__('image_ratio_hint')" :model-value="cfg.image_aspect"
                    @update:model-value="cfg.image_aspect = $event" />
            </div>
            <hr class="my-2">
            <strong class="small d-block mb-2">{{ __('banner_items') }}</strong>
            <BannerItemRow v-for="(item, i) in block.items" :key="i" :item="item" :index="i"
                :count="block.items.length" :all-products="allProducts" :all-categories="allCategories" :all-brands="allBrands" :all-pages="allPages"
                :languages="languages" :active-lang="activeLang"
                @remove="removeItem(i)" @move-up="moveItem(i, -1)" @move-down="moveItem(i, 1)" />
            <p v-if="!block.items.length" class="text-muted small">{{ __('no_banners_added') }}</p>
            <button type="button" class="btn btn-sm btn-outline-primary w-100 mt-1" @click="addItem">
                <Plus :size="15" /> {{ __('add_banner') }}
            </button>
        </template>

        <!-- ============ GRID BANNER ============ -->
        <template v-else-if="block.type === 'grid_banner'">
            <div class="row g-2 mb-3">
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('layout_type') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('grid_layout_type_hint')" /></label>
                    <select class="form-select form-select-sm" v-model="cfg.grid_layout_type">
                        <option value="grid">{{ __('grid') }}</option>
                        <option value="scroll">{{ __('horizontal_scroll') }}</option>
                    </select>
                </div>
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('display_variant') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('display_variant_hint')" /></label>
                    <AppSelect class="form-select form-select-sm" v-model="cfg.variant" :options="variantOptions" :searchable="false" />
                </div>
            </div>
            <div class="row g-2 mb-3" v-if="hasTitleField">
                <div class="col-md-9">
                    <TranslatableInput :label="__('section_title')" :model-value="cfg.section_title"
                        @update:model-value="cfg.section_title = $event" :languages="languages" :active-lang="activeLang" />
                </div>
                <div class="col-md-3">
                    <label class="hb-lbl">{{ __('text_color') }}</label>
                    <ColorInput :model-value="cfg.text_color" @update:model-value="cfg.text_color = $event" />
                </div>
            </div>
            <div class="mb-3" v-if="cfg.variant === 'with_color'">
                <label class="hb-lbl">{{ __('background_color') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('background_color_hint')" /></label>
                <ColorInput :model-value="cfg.background_color" @update:model-value="cfg.background_color = $event" />
            </div>
            <div class="mb-3" v-if="cfg.variant === 'with_background'">
                <label class="hb-lbl">{{ __('background_image') }}</label>
                <div class="row g-2">
                    <div class="col-4">
                        <HbImageUpload :label="__('app')" :model-value="cfg.background_image.app"
                            @update:model-value="cfg.background_image.app = $event" />
                    </div>
                    <div class="col-4">
                        <HbImageUpload :label="__('tablet')" :model-value="cfg.background_image.tablet"
                            @update:model-value="cfg.background_image.tablet = $event" />
                    </div>
                    <div class="col-4">
                        <HbImageUpload :label="__('web')" :model-value="cfg.background_image.web"
                            @update:model-value="cfg.background_image.web = $event" />
                    </div>
                </div>
                <div class="mt-2">
                    <PlatformAspectInput :label="__('background_ratio')" :hint="__('background_ratio_hint')" :model-value="cfg.bg_image_aspect"
                        @update:model-value="cfg.bg_image_aspect = $event" />
                </div>
            </div>
            <div class="row g-2 mb-3">
                <div class="col-md-6">
                    <PlatformTriInput :label="__('columns')" :hint="__('columns_hint')" :min="1" :max="8" suffix=""
                        :model-value="cfg.grid_columns" @update:model-value="cfg.grid_columns = $event" />
                </div>
                <!-- Rows drive the horizontal-scroll layout (banners fill rows, scroll sideways). -->
                <div class="col-md-6" v-if="cfg.grid_layout_type === 'scroll'">
                    <PlatformTriInput :label="__('rows')" :hint="__('rows_hint')" :min="1" :max="12" suffix=""
                        :model-value="cfg.grid_rows" @update:model-value="cfg.grid_rows = $event" />
                </div>
                <div class="col-md-6">
                    <PlatformTriInput :label="__('gap')" :hint="__('gap_hint')" :max="60"
                        :model-value="cfg.grid_gap" @update:model-value="cfg.grid_gap = $event" />
                </div>
            </div>
            <div class="mb-3">
                <PlatformAspectInput :label="__('image_ratio')" :hint="__('image_ratio_hint')" :model-value="cfg.image_aspect"
                    @update:model-value="cfg.image_aspect = $event" />
            </div>
            <div class="row g-2 mb-3">
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('tile_radius') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('tile_radius_hint')" /></label>
                    <DimensionSlider :model-value="cfg.tile_radius" :min="0" :max="50" @update:model-value="cfg.tile_radius = $event" />
                </div>
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('inner_padding') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('inner_padding_hint')" /></label>
                    <DimensionSlider :model-value="cfg.block_padding" :min="0" :max="100" @update:model-value="cfg.block_padding = $event" />
                </div>
            </div>
            <hr class="my-2">
            <strong class="small d-block mb-2">{{ __('banner_items') }}</strong>
            <BannerItemRow v-for="(item, i) in block.items" :key="i" :item="item" :index="i"
                :count="block.items.length" :all-products="allProducts" :all-categories="allCategories" :all-brands="allBrands" :all-pages="allPages"
                :languages="languages" :active-lang="activeLang"
                @remove="removeItem(i)" @move-up="moveItem(i, -1)" @move-down="moveItem(i, 1)" />
            <p v-if="!block.items.length" class="text-muted small">{{ __('no_banners_added') }}</p>
            <!-- Add button below the list for easier reach as banners grow. -->
            <button type="button" class="btn btn-sm btn-outline-primary w-100 mt-1" @click="addItem">
                <Plus :size="15" /> {{ __('add_banner') }}
            </button>
        </template>

        <!-- ============ CATEGORY SECTION ============ -->
        <template v-else-if="['category_section', 'occasion_section', 'relationship_section'].includes(block.type)">
            <div class="row g-2 mb-3">
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('layout') }}</label>
                    <AppSelect class="form-select form-select-sm" v-model="block.layout" :options="layoutOptions" :searchable="false" />
                </div>
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('display_variant') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('display_variant_hint')" /></label>
                    <AppSelect class="form-select form-select-sm" v-model="cfg.variant" :options="variantOptions" :searchable="false" />
                </div>
            </div>
            <div class="row g-2 mb-3" v-if="hasTitleField">
                <div class="col-md-9">
                    <TranslatableInput :label="__('section_title')" :model-value="cfg.section_title"
                        @update:model-value="cfg.section_title = $event" :languages="languages" :active-lang="activeLang" />
                </div>
                <div class="col-md-3">
                    <label class="hb-lbl">{{ __('text_color') }}</label>
                    <ColorInput :model-value="cfg.text_color" @update:model-value="cfg.text_color = $event" />
                </div>
            </div>
            <div class="mb-3" v-if="cfg.variant === 'with_color'">
                <label class="hb-lbl">{{ __('background_color') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('background_color_hint')" /></label>
                <ColorInput :model-value="cfg.background_color" @update:model-value="cfg.background_color = $event" />
            </div>
            <div class="mb-3" v-if="cfg.variant === 'with_background'">
                <label class="hb-lbl">{{ __('background_image') }}</label>
                <div class="row g-2">
                    <div class="col-4">
                        <HbImageUpload :label="__('app')" :model-value="cfg.background_image.app"
                            @update:model-value="cfg.background_image.app = $event" />
                    </div>
                    <div class="col-4">
                        <HbImageUpload :label="__('tablet')" :model-value="cfg.background_image.tablet"
                            @update:model-value="cfg.background_image.tablet = $event" />
                    </div>
                    <div class="col-4">
                        <HbImageUpload :label="__('web')" :model-value="cfg.background_image.web"
                            @update:model-value="cfg.background_image.web = $event" />
                    </div>
                </div>
                <div class="mt-2">
                    <PlatformAspectInput :label="__('background_ratio')" :hint="__('background_ratio_hint')" :model-value="cfg.bg_image_aspect"
                        @update:model-value="cfg.bg_image_aspect = $event" />
                </div>
            </div>
            <div class="row g-2 mb-3">
                <div class="col-md-6" v-if="block.layout === 'grid'">
                    <PlatformTriInput :label="__('columns')" :hint="__('columns_hint')" :min="1" :max="8" suffix=""
                        :model-value="cfg.grid_columns" @update:model-value="cfg.grid_columns = $event" />
                </div>
                <div class="col-md-6">
                    <PlatformTriInput :label="__('gap')" :hint="__('gap_hint')" :max="60"
                        :model-value="cfg.category_gap" @update:model-value="cfg.category_gap = $event" />
                </div>
                <div class="col-md-6" v-if="block.layout !== 'circular'">
                    <PlatformTriInput :label="__('radius')" :hint="__('radius_hint')" :max="50"
                        :model-value="cfg.category_radius" @update:model-value="cfg.category_radius = $event" />
                </div>
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('name_text_color') }}</label>
                    <ColorInput :model-value="cfg.item_text_color" @update:model-value="cfg.item_text_color = $event" />
                </div>
            </div>
            <template v-if="block.type === 'occasion_section'">
                <label class="hb-lbl">{{ __('select_occasions') }}</label>
                <AppSelect class="form-select form-select-sm" multiple :model-value="cfg.occasion_ids"
                    @update:model-value="cfg.occasion_ids = $event"
                    :options="gifting.occasions" :placeholder="__('select_occasions')" />
                <p class="text-muted small mb-0 mt-1">{{ __('manage_in_gifting') }}</p>
            </template>
            <template v-else-if="block.type === 'relationship_section'">
                <label class="hb-lbl">{{ __('select_relationships') }}</label>
                <AppSelect class="form-select form-select-sm" multiple :model-value="cfg.relationship_ids"
                    @update:model-value="cfg.relationship_ids = $event"
                    :options="gifting.relationships" :placeholder="__('select_relationships')" />
                <p class="text-muted small mb-0 mt-1">{{ __('manage_in_gifting') }}</p>
            </template>
            <template v-else>
                <label class="hb-lbl">{{ __('select_categories') }}</label>
                <AppSelect class="form-select form-select-sm" multiple :model-value="cfg.category_ids"
                    @update:model-value="cfg.category_ids = $event"
                    :options="categoryOptions" :placeholder="__('select_categories')" />
            </template>
        </template>

        <!-- ============ PRODUCT SLIDER ============ -->
        <template v-else-if="block.type === 'product_slider'">
            <div class="row g-2 mb-3">
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('layout') }}</label>
                    <AppSelect class="form-select form-select-sm" v-model="block.layout" :options="layoutOptions2" :searchable="false" />
                </div>
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('display_variant') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('display_variant_hint')" /></label>
                    <AppSelect class="form-select form-select-sm" v-model="cfg.variant" :options="variantOptions" :searchable="false" />
                </div>
            </div>

            <div class="row g-2 mb-3" v-if="hasTitleField">
                <div class="col-md-9">
                    <TranslatableInput :label="__('section_title')" :model-value="cfg.section_title"
                        @update:model-value="cfg.section_title = $event" :languages="languages" :active-lang="activeLang" />
                </div>
                <div class="col-md-3">
                    <label class="hb-lbl">{{ __('text_color') }}</label>
                    <ColorInput :model-value="cfg.text_color" @update:model-value="cfg.text_color = $event" />
                </div>
            </div>
            <div class="mb-3" v-if="cfg.variant === 'with_color'">
                <label class="hb-lbl">{{ __('background_color') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('background_color_hint')" /></label>
                <ColorInput :model-value="cfg.background_color" @update:model-value="cfg.background_color = $event" />
            </div>
            <div class="mb-3" v-if="cfg.variant === 'with_background'">
                <label class="hb-lbl">{{ __('background_image') }}</label>
                <div class="row g-2">
                    <div class="col-4">
                        <HbImageUpload :label="__('app')" :model-value="cfg.background_image.app"
                            @update:model-value="cfg.background_image.app = $event" />
                    </div>
                    <div class="col-4">
                        <HbImageUpload :label="__('tablet')" :model-value="cfg.background_image.tablet"
                            @update:model-value="cfg.background_image.tablet = $event" />
                    </div>
                    <div class="col-4">
                        <HbImageUpload :label="__('web')" :model-value="cfg.background_image.web"
                            @update:model-value="cfg.background_image.web = $event" />
                    </div>
                </div>
                <div class="mt-2">
                    <PlatformAspectInput :label="__('background_ratio')" :hint="__('background_ratio_hint')" :model-value="cfg.image_aspect"
                        @update:model-value="cfg.image_aspect = $event" />
                </div>
            </div>

            <div class="row g-2 mb-3">
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('data_source') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('data_source_hint')" /></label>
                    <AppSelect class="form-select form-select-sm" v-model="cfg.data_source" :options="data_sourceOptions" :searchable="false" />
                </div>
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('limit') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('limit_hint')" /></label>
                    <DimensionSlider :model-value="cfg.limit" :min="1" :max="50" suffix="" @update:model-value="cfg.limit = $event" />
                </div>
            </div>

            <div class="mb-3" v-if="cfg.data_source === 'manual'">
                <label class="hb-lbl">{{ __('select_products') }}</label>
                <AppSelect class="form-select form-select-sm" multiple :model-value="cfg.manual_product_ids"
                    @update:model-value="cfg.manual_product_ids = $event"
                    :options="allProducts" :placeholder="__('select_products')" />
            </div>
            <div class="mb-3" v-if="cfg.data_source === 'category'">
                <label class="hb-lbl">{{ __('categories') }}</label>
                <AppSelect class="form-select form-select-sm" multiple :model-value="cfg.slider_category_ids"
                    @update:model-value="cfg.slider_category_ids = $event"
                    :options="categoryOptions" :placeholder="__('select_categories')" />
            </div>
            <div class="mb-3" v-if="cfg.data_source === 'brand'">
                <label class="hb-lbl">{{ __('brands') }}</label>
                <AppSelect class="form-select form-select-sm" multiple :model-value="cfg.brand_ids"
                    @update:model-value="cfg.brand_ids = $event"
                    :options="allBrands" :placeholder="__('select_brands')" />
            </div>

            <!-- An ordering-only source draws from the whole catalogue. This scopes it
                 to part of it, or keeps that part out. Hidden for the sources that
                 already pick products by membership, where it would contradict them. -->
            <div class="mb-3" v-if="isDynamicSource">
                <div class="row g-2">
                    <div class="col-md-6">
                        <label class="hb-lbl">{{ __('filter_products') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('filter_products_hint')" /></label>
                        <AppSelect class="form-select form-select-sm" :model-value="cfg.filter_type"
                            @update:model-value="setFilterType($event)"
                            :options="filterTypeOptions" :searchable="false" :allow-empty="false" />
                    </div>
                    <div class="col-md-6" v-if="cfg.filter_type !== 'none'">
                        <label class="hb-lbl">{{ __('filter_mode') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('filter_mode_hint')" /></label>
                        <AppSelect class="form-select form-select-sm" v-model="cfg.filter_mode"
                            :options="filterModeOptions" :searchable="false" :allow-empty="false" />
                    </div>
                </div>
                <div class="mt-2" v-if="cfg.filter_type === 'category'">
                    <label class="hb-lbl">{{ __('categories') }}</label>
                    <AppSelect class="form-select form-select-sm" multiple :model-value="cfg.filter_category_ids"
                        @update:model-value="cfg.filter_category_ids = $event"
                        :options="categoryOptions" :placeholder="__('select_categories')" />
                </div>
                <div class="mt-2" v-if="cfg.filter_type === 'brand'">
                    <label class="hb-lbl">{{ __('brands') }}</label>
                    <AppSelect class="form-select form-select-sm" multiple :model-value="cfg.filter_brand_ids"
                        @update:model-value="cfg.filter_brand_ids = $event"
                        :options="allBrands" :placeholder="__('select_brands')" />
                </div>
            </div>

            <div class="form-check form-switch mb-3 hb-switch-row">
                <label class="form-check-label hb-lbl" :for="'shuffle-' + block.id">
                    {{ __('shuffle_products') }}
                    <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('shuffle_products_hint')" />
                </label>
                <input class="form-check-input" type="checkbox" role="switch" :id="'shuffle-' + block.id"
                    :checked="cfg.shuffle_products === true"
                    @change="cfg.shuffle_products = $event.target.checked">
            </div>

            <div class="row g-2 mb-3" v-if="block.layout === 'grid'">
                <div class="col-md-8">
                    <PlatformTriInput :label="__('columns')" :hint="__('columns_hint')" :min="1" :max="8" suffix=""
                        :model-value="cfg.grid_columns" @update:model-value="cfg.grid_columns = $event" />
                </div>
            </div>

            <div class="row g-3">
                <div class="col-md-6">
                    <PlatformTriInput :label="__('card_gap')" :hint="__('card_gap_hint')" :min="0" :max="60"
                        :model-value="cfg.product_grid_gap"
                        @update:model-value="cfg.product_grid_gap = $event" />
                </div>
                <div class="col-md-6">
                    <label class="hb-lbl d-block mb-1">{{ __('spacing') }}</label>
                    <div class="hb-stack">
                        <div>
                            <label class="hb-lbl">{{ __('card_radius') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('card_radius_hint')" /></label>
                            <DimensionSlider :model-value="cfg.product_card_radius" :min="0" :max="50" @update:model-value="cfg.product_card_radius = $event" />
                        </div>
                        <div>
                            <label class="hb-lbl">
                                {{ __('inner_padding') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('inner_padding_hint')" />
                            </label>
                            <DimensionSlider :model-value="cfg.block_padding" :min="0" :max="100" @update:model-value="cfg.block_padding = $event" />
                        </div>
                    </div>
                </div>
            </div>
        </template>

        <!-- ============ PRODUCT TABS ============
             A product slider whose rows are chosen by tab. The block owns the look
             (layout, variant, colours, card sizing) and a default limit; each tab
             owns only its title, icon and data source. -->
        <template v-else-if="block.type === 'product_tabs'">
            <div class="row g-2 mb-3">
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('layout') }}</label>
                    <AppSelect class="form-select form-select-sm" v-model="block.layout" :options="layoutOptions2" :searchable="false" />
                </div>
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('display_variant') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('display_variant_hint')" /></label>
                    <AppSelect class="form-select form-select-sm" v-model="cfg.variant" :options="variantOptions" :searchable="false" />
                </div>
            </div>

            <div class="row g-2 mb-3" v-if="hasTitleField">
                <div class="col-md-9">
                    <TranslatableInput :label="__('section_title')" :model-value="cfg.section_title"
                        @update:model-value="cfg.section_title = $event" :languages="languages" :active-lang="activeLang" />
                </div>
                <div class="col-md-3">
                    <label class="hb-lbl">{{ __('text_color') }}</label>
                    <ColorInput :model-value="cfg.text_color" @update:model-value="cfg.text_color = $event" />
                </div>
            </div>
            <div class="mb-3" v-if="cfg.variant === 'with_color'">
                <label class="hb-lbl">{{ __('background_color') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('background_color_hint')" /></label>
                <ColorInput :model-value="cfg.background_color" @update:model-value="cfg.background_color = $event" />
            </div>
            <div class="mb-3" v-if="cfg.variant === 'with_background'">
                <label class="hb-lbl">{{ __('background_image') }}</label>
                <div class="row g-2">
                    <div class="col-4">
                        <HbImageUpload :label="__('app')" :model-value="cfg.background_image.app"
                            @update:model-value="cfg.background_image.app = $event" />
                    </div>
                    <div class="col-4">
                        <HbImageUpload :label="__('tablet')" :model-value="cfg.background_image.tablet"
                            @update:model-value="cfg.background_image.tablet = $event" />
                    </div>
                    <div class="col-4">
                        <HbImageUpload :label="__('web')" :model-value="cfg.background_image.web"
                            @update:model-value="cfg.background_image.web = $event" />
                    </div>
                </div>
                <div class="mt-2">
                    <PlatformAspectInput :label="__('background_ratio')" :hint="__('background_ratio_hint')" :model-value="cfg.image_aspect"
                        @update:model-value="cfg.image_aspect = $event" />
                </div>
            </div>

            <!-- Tab strip look -->
            <div class="row g-2 mb-2">
                <div class="col-md-4">
                    <label class="hb-lbl">{{ __('tab_style') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('tab_style_hint')" /></label>
                    <AppSelect class="form-select form-select-sm" v-model="cfg.tab_style" :options="tabStyleOptions" :searchable="false" :allow-empty="false" />
                </div>
                <div class="col-md-4">
                    <label class="hb-lbl">{{ __('active_tab_style') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('active_tab_style_hint')" /></label>
                    <AppSelect class="form-select form-select-sm" :model-value="cfg.active_indicator" @update:model-value="setActiveIndicator" :options="activeIndicatorOptions" :searchable="false" :allow-empty="false" />
                </div>
                <div class="col-md-4">
                    <label class="hb-lbl">{{ __('tab_animation') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('tab_animation_hint')" /></label>
                    <AppSelect class="form-select form-select-sm" v-model="cfg.tab_animation" :options="tabAnimationOptions" :searchable="false" :allow-empty="false" />
                </div>
            </div>
            <div class="row g-2 mb-3">
                <div class="col-md-4" v-if="activeTabHasBackground">
                    <label class="hb-lbl">{{ __('active_background') }}</label>
                    <AppSelect class="form-select form-select-sm" v-model="cfg.active_bg_style" :options="activeBgOptions" :searchable="false" :allow-empty="false" />
                </div>
                <!-- An image paints the active tab; the colour has no role then. -->
                <div class="col-md-4" v-if="!(activeTabHasBackground && cfg.active_bg_style === 'image')">
                    <label class="hb-lbl">{{ __('active_tab_color') }}</label>
                    <ColorInput :model-value="cfg.active_tab_color" @update:model-value="cfg.active_tab_color = $event" />
                </div>
                <div class="col-md-4" v-if="activeTabHasBackground && cfg.active_bg_style === 'gradient'">
                    <label class="hb-lbl">{{ __('gradient_end_color') }}</label>
                    <ColorInput :model-value="cfg.active_tab_color_2" @update:model-value="cfg.active_tab_color_2 = $event" />
                </div>
                <div class="col-md-4" v-if="cfg.active_indicator === 'outline'">
                    <label class="hb-lbl">{{ __('outline_color') }}</label>
                    <ColorInput :model-value="cfg.active_outline_color" @update:model-value="cfg.active_outline_color = $event" />
                </div>
                <div class="col-md-4">
                    <label class="hb-lbl">{{ __('tab_text_color') }}</label>
                    <ColorInput :model-value="cfg.tab_text_color" @update:model-value="cfg.tab_text_color = $event" />
                </div>
                <!-- On a painted tab the active colour is the paint, so the title needs its own colour. -->
                <div class="col-md-4" v-if="activeTabIsPainted">
                    <label class="hb-lbl">{{ __('active_tab_text_color') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('active_tab_text_color_hint')" /></label>
                    <ColorInput :model-value="cfg.active_tab_text_color" @update:model-value="cfg.active_tab_text_color = $event" />
                </div>
            </div>
            <!-- Image behind the active tab, one per platform. -->
            <div class="row g-2 mb-3" v-if="activeTabHasBackground && cfg.active_bg_style === 'image'">
                <div class="col-12"><label class="hb-lbl mb-0">{{ __('active_tab_image') }}</label></div>
                <div class="col-4">
                    <HbImageUpload :label="__('app')" :model-value="cfg.active_bg_image.app"
                        @update:model-value="cfg.active_bg_image.app = $event" />
                </div>
                <div class="col-4">
                    <HbImageUpload :label="__('tablet')" :model-value="cfg.active_bg_image.tablet"
                        @update:model-value="cfg.active_bg_image.tablet = $event" />
                </div>
                <div class="col-4">
                    <HbImageUpload :label="__('web')" :model-value="cfg.active_bg_image.web"
                        @update:model-value="cfg.active_bg_image.web = $event" />
                </div>
                <div class="col-12">
                    <PlatformAspectInput :label="__('active_tab_image_ratio')" :hint="__('active_tab_image_ratio_hint')"
                        :model-value="cfg.active_bg_image_aspect" @update:model-value="cfg.active_bg_image_aspect = $event" />
                </div>
            </div>
            <div class="mb-3" v-if="cfg.tab_style === 'icon_top'">
                <PlatformAspectInput :label="__('tab_icon_ratio')" :hint="__('tab_icon_ratio_hint')" :model-value="cfg.tab_image_aspect"
                    @update:model-value="cfg.tab_image_aspect = $event" />
            </div>

            <!-- Products per tab, unless a tab overrides it -->
            <div class="row g-2 mb-3">
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('products_per_tab') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('products_per_tab_hint')" /></label>
                    <DimensionSlider :model-value="cfg.limit" :min="1" :max="tabLimitMax" suffix="" @update:model-value="cfg.limit = $event" />
                </div>
                <div class="col-md-6" v-if="block.layout === 'grid'">
                    <PlatformTriInput :label="__('columns')" :hint="__('columns_hint')" :min="1" :max="8" suffix=""
                        :model-value="cfg.grid_columns" @update:model-value="cfg.grid_columns = $event" />
                </div>
            </div>

            <div class="row g-3 mb-3">
                <div class="col-md-6">
                    <PlatformTriInput :label="__('card_gap')" :hint="__('card_gap_hint')" :min="0" :max="60"
                        :model-value="cfg.product_grid_gap"
                        @update:model-value="cfg.product_grid_gap = $event" />
                </div>
                <div class="col-md-6">
                    <label class="hb-lbl d-block mb-1">{{ __('spacing') }}</label>
                    <div class="hb-stack">
                        <div>
                            <label class="hb-lbl">{{ __('card_radius') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('card_radius_hint')" /></label>
                            <DimensionSlider :model-value="cfg.product_card_radius" :min="0" :max="50" @update:model-value="cfg.product_card_radius = $event" />
                        </div>
                        <div>
                            <label class="hb-lbl">
                                {{ __('inner_padding') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('inner_padding_hint')" />
                            </label>
                            <DimensionSlider :model-value="cfg.block_padding" :min="0" :max="100" @update:model-value="cfg.block_padding = $event" />
                        </div>
                    </div>
                </div>
            </div>

            <hr class="my-2">
            <div class="d-flex align-items-center mb-2">
                <strong class="small">{{ __('tabs') }}</strong>
                <span class="text-muted small ms-auto">{{ block.items.length }} / {{ tabsMax }}</span>
            </div>
            <TabItemRow v-for="(tab, i) in block.items" :key="tab.id || i" :item="tab" :index="i"
                :count="block.items.length" :inherited-limit="Number(cfg.limit) || 10"
                :data-source-options="data_sourceOptions" :languages="languages" :active-lang="activeLang"
                :all-products="allProducts" :all-categories="categoryOptions" :all-brands="allBrands"
                @remove="removeItem(i)" @move-up="moveItem(i, -1)" @move-down="moveItem(i, 1)" />
            <p v-if="!block.items.length" class="text-muted small">{{ __('no_tabs_added') }}</p>
            <button type="button" class="btn btn-sm btn-outline-primary w-100 mt-1"
                :disabled="block.items.length >= tabsMax" @click="addTab">
                <Plus :size="15" /> {{ __('add_tab') }}
            </button>
        </template>

        <!-- ============ BRAND SECTION ============ -->
        <template v-else-if="block.type === 'brand_section'">
            <div class="row g-2 mb-3">
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('layout') }}</label>
                    <AppSelect class="form-select form-select-sm" v-model="block.layout" :options="layoutOptions3" :searchable="false" />
                </div>
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('display_variant') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('display_variant_hint')" /></label>
                    <AppSelect class="form-select form-select-sm" v-model="cfg.variant" :options="variantOptions" :searchable="false" />
                </div>
            </div>
            <div class="row g-2 mb-3" v-if="hasTitleField">
                <div class="col-md-9">
                    <TranslatableInput :label="__('section_title')" :model-value="cfg.section_title"
                        @update:model-value="cfg.section_title = $event" :languages="languages" :active-lang="activeLang" />
                </div>
                <div class="col-md-3">
                    <label class="hb-lbl">{{ __('text_color') }}</label>
                    <ColorInput :model-value="cfg.text_color" @update:model-value="cfg.text_color = $event" />
                </div>
            </div>
            <div class="mb-3" v-if="cfg.variant === 'with_color'">
                <label class="hb-lbl">{{ __('background_color') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('background_color_hint')" /></label>
                <ColorInput :model-value="cfg.background_color" @update:model-value="cfg.background_color = $event" />
            </div>
            <div class="mb-3" v-if="cfg.variant === 'with_background'">
                <label class="hb-lbl">{{ __('background_image') }}</label>
                <div class="row g-2">
                    <div class="col-4">
                        <HbImageUpload :label="__('app')" :model-value="cfg.background_image.app"
                            @update:model-value="cfg.background_image.app = $event" />
                    </div>
                    <div class="col-4">
                        <HbImageUpload :label="__('tablet')" :model-value="cfg.background_image.tablet"
                            @update:model-value="cfg.background_image.tablet = $event" />
                    </div>
                    <div class="col-4">
                        <HbImageUpload :label="__('web')" :model-value="cfg.background_image.web"
                            @update:model-value="cfg.background_image.web = $event" />
                    </div>
                </div>
                <div class="mt-2">
                    <PlatformAspectInput :label="__('background_ratio')" :hint="__('background_ratio_hint')" :model-value="cfg.bg_image_aspect"
                        @update:model-value="cfg.bg_image_aspect = $event" />
                </div>
            </div>
            <div class="row g-2 mb-3">
                <div class="col-md-6" v-if="block.layout === 'grid'">
                    <PlatformTriInput :label="__('columns')" :hint="__('columns_hint')" :min="1" :max="8" suffix=""
                        :model-value="cfg.grid_columns" @update:model-value="cfg.grid_columns = $event" />
                </div>
                <div class="col-md-6">
                    <PlatformTriInput :label="__('gap')" :hint="__('gap_hint')" :max="60"
                        :model-value="cfg.brand_gap" @update:model-value="cfg.brand_gap = $event" />
                </div>
                <div class="col-md-6" v-if="block.layout !== 'circular'">
                    <PlatformTriInput :label="__('radius')" :hint="__('radius_hint')" :max="50"
                        :model-value="cfg.brand_radius" @update:model-value="cfg.brand_radius = $event" />
                </div>
            </div>
            <div class="row g-2 mb-3">
                <div class="col-md-6 hb-switch-col">
                    <label class="hb-lbl">{{ __('show_brand_name') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('show_brand_name_hint')" /></label>
                    <div class="form-check form-switch ps-0">
                        <input class="form-check-input ms-0" type="checkbox" role="switch" v-model="cfg.show_name">
                    </div>
                </div>
                <div class="col-md-6" v-if="cfg.show_name">
                    <label class="hb-lbl">{{ __('name_text_color') }}</label>
                    <ColorInput :model-value="cfg.item_text_color" @update:model-value="cfg.item_text_color = $event" />
                </div>
            </div>
            <label class="hb-lbl mt-2">{{ __('select_brands') }}</label>
            <AppSelect class="form-select form-select-sm" multiple :model-value="cfg.brand_ids"
                @update:model-value="cfg.brand_ids = $event"
                :options="allBrands" :placeholder="__('select_brands')" />
            <p v-if="!allBrands.length" class="text-muted small mb-0 mt-1">{{ __('no_brands_found') }}</p>
        </template>

        <!-- ============ TEXT SECTION ============ -->
        <template v-else-if="block.type === 'text_section'">
            <div class="row g-2 mb-3">
                <div class="col-md-6">
                    <label class="hb-lbl">{{ __('text_align') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('text_align_hint')" /></label>
                    <AppSelect class="form-select form-select-sm" v-model="cfg.text_align" :options="text_alignOptions" :searchable="false" />
                </div>
                <div class="col-md-3">
                    <label class="hb-lbl">{{ __('text_color') }}</label>
                    <ColorInput :model-value="cfg.text_color" @update:model-value="cfg.text_color = $event" />
                </div>
                <div class="col-md-3">
                    <label class="hb-lbl">{{ __('background_color') }} <Info :size="13" class="hb-info" v-b-tooltip.hover :title="__('background_color_hint')" /></label>
                    <ColorInput :model-value="cfg.background_color" @update:model-value="cfg.background_color = $event" />
                </div>
            </div>
            <TranslatableInput :label="__('heading')" :model-value="cfg.section_title"
                @update:model-value="cfg.section_title = $event" :languages="languages" :active-lang="activeLang" />
            <div class="mt-2 mb-2">
                <TranslatableInput :label="__('subtitle')" :model-value="cfg.section_subtitle"
                    @update:model-value="cfg.section_subtitle = $event" :languages="languages"
                    :active-lang="activeLang" type="textarea" />
            </div>
            <RedirectPicker :config="cfg" :all-products="allProducts" :all-categories="allCategories" :all-brands="allBrands" :all-pages="allPages"
                :languages="languages" :active-lang="activeLang" />
        </template>

        <!-- ============ TITLE IMAGE ============ -->
        <template v-else-if="block.type === 'title_image'">
            <div class="row g-2 mb-2">
                <div class="col-4">
                    <HbImageUpload :label="__('app')" :model-value="block.image.app"
                        @update:model-value="block.image.app = $event" />
                </div>
                <div class="col-4">
                    <HbImageUpload :label="__('tablet')" :model-value="block.image.tablet"
                        @update:model-value="block.image.tablet = $event" />
                </div>
                <div class="col-4">
                    <HbImageUpload :label="__('web')" :model-value="block.image.web"
                        @update:model-value="block.image.web = $event" />
                </div>
            </div>
            <div class="mb-2">
                <PlatformAspectInput :label="__('image_ratio')" :hint="__('image_ratio_hint')" :model-value="cfg.image_aspect"
                    @update:model-value="cfg.image_aspect = $event" />
            </div>
            <RedirectPicker :config="cfg" :all-products="allProducts" :all-categories="allCategories" :all-brands="allBrands" :all-pages="allPages"
                :languages="languages" :active-lang="activeLang" />
        </template>

        <!-- redirect picker reused after text_section (insertion handled in template above) -->
    </div>
</template>

<script>
import BannerItemRow from './BannerItemRow.vue';
import TabItemRow from './TabItemRow.vue';
import HbImageUpload from './HbImageUpload.vue';
import TranslatableInput from './TranslatableInput.vue';
import RedirectPicker from './RedirectPicker.vue';
import PlatformTriInput from './PlatformTriInput.vue';
import PlatformAspectInput from './PlatformAspectInput.vue';
import DimensionSlider from './DimensionSlider.vue';
import ColorInput from './ColorInput.vue';
import { newBannerItem, newTabItem, TABS_MAX, TAB_LIMIT_MAX, blockHasTitle } from '../homeBuilderHelpers.js';
import { Plus, Info } from 'lucide-vue-next';
import { loadGiftingOptions } from '../giftingOptions.js';

export default {
    name: 'BlockEditor',
    components: { Plus, Info, BannerItemRow, TabItemRow, HbImageUpload, TranslatableInput, RedirectPicker, PlatformTriInput, PlatformAspectInput, DimensionSlider, ColorInput },
    data() {
        return { gifting: { occasions: [], relationships: [] } };
    },
    created() {
        loadGiftingOptions().then((g) => { this.gifting = g; });
    },
    props: {
        block: { type: Object, required: true },
        languages: { type: Array, default: () => [] },
        activeLang: { type: [Number, String], default: null },
        allProducts: { type: Array, default: () => [] },
        allCategories: { type: Array, default: () => [] },
        // Category subtree for the active category-wise tab. Used by the category
        // target dropdowns; RedirectPicker keeps the full allCategories list.
        scopedCategories: { type: Array, default: () => [] },
        allBrands: { type: Array, default: () => [] },
        allPages: { type: Array, default: () => [] },
    },
    computed: {
        // Options for the category target dropdowns (category section + product
        // slider by-category). Uses the tab's subtree when provided, else the full list.
        categoryOptions() {
            return (this.scopedCategories && this.scopedCategories.length)
                ? this.scopedCategories
                : this.allCategories;
        },
        // Fixed option set — no search box needed.
        carousel_styleOptions() {
            return [
                { id: 'full_width', name: (__('full_width')) },
                { id: 'peek', name: (__('peek')) },
                { id: 'card', name: (__('card')) },
                { id: 'story', name: (__('story')) },
                { id: 'spotlight', name: (__('spotlight')) },
            ];
        },
        // Fixed option set — no search box needed.
        indicatorOptions() {
            return [
                { id: 'dots', name: (__('dots')) },
                { id: 'none', name: (__('none')) },
            ];
        },
        // Fixed option set — no search box needed.
        layoutOptions() {
            return [
                { id: 'horizontal', name: (__('horizontal')) },
                { id: 'grid', name: (__('grid')) },
                { id: 'circular', name: (__('circular')) },
            ];
        },
        // Fixed option set — no search box needed.
        tabsMax() { return TABS_MAX; },
        tabLimitMax() { return TAB_LIMIT_MAX; },
        tabStyleOptions() {
            return [
                { id: 'icon_top', name: (__('icon_above_label')) },
                { id: 'text', name: (__('text_only')) },
            ];
        },
        activeIndicatorOptions() {
            return [
                { id: 'underline', name: __('underline') },
                { id: 'fill', name: __('filled_background') },
                { id: 'outline', name: __('outlined_tab') },
                { id: 'none', name: __('text_color_only') },
            ];
        },
        // An outlined tab may stay hollow; a filled one always has a background.
        activeBgOptions() {
            const opts = [
                { id: 'solid', name: __('solid') },
                { id: 'gradient', name: __('gradient') },
                { id: 'image', name: __('image') },
            ];
            return this.cfg.active_indicator === 'outline'
                ? [{ id: 'none', name: __('none') }, ...opts]
                : opts;
        },
        tabAnimationOptions() {
            return [
                { id: 'none', name: __('none') },
                { id: 'fade', name: __('fade') },
                { id: 'slide', name: __('slide') },
            ];
        },
        // Only fill / outline can paint a background behind the active tab.
        activeTabHasBackground() {
            return ['fill', 'outline'].includes(this.cfg.active_indicator);
        },
        // Something (solid / gradient / image) is actually painted behind the active tab.
        activeTabIsPainted() {
            return this.activeTabHasBackground && this.cfg.active_bg_style !== 'none';
        },
        // Same rule SectionEditor builds the language tabs from, so a visible title
        // always has tabs to translate it in.
        hasTitleField() {
            return blockHasTitle(this.block);
        },
        variantOptions() {
            return [
                { id: 'default', name: (__('default')) },
                { id: 'with_title', name: (__('with_title')) },
                { id: 'with_background', name: (__('with_background')) },
                { id: 'with_color', name: (__('with_color')) },
            ];
        },
        // Fixed option set — no search box needed.
        layoutOptions2() {
            return [
                { id: 'horizontal', name: (__('horizontal')) },
                { id: 'grid', name: (__('grid')) },
                { id: 'list', name: (__('list')) },
            ];
        },
        // Fixed option set — no search box needed.
        data_sourceOptions() {
            return [
                { id: 'manual', name: (__('manual')) },
                { id: 'top_selling', name: (__('top_selling')) },
                { id: 'trending', name: (__('trending')) },
                { id: 'new_arrivals', name: (__('new_arrivals')) },
                { id: 'best_rated', name: (__('best_rated')) },
                { id: 'discounted', name: (__('discounted')) },
                { id: 'most_favorited', name: (__('most_favorited')) },
                { id: 'recently_visited', name: (__('recently_visited')) },
                { id: 'buy_again', name: (__('buy_again')) },
                { id: 'category', name: (__('by_category')) },
                { id: 'brand', name: (__('by_brand')) },
            ];
        },
        // Fixed option set — no search box needed.
        layoutOptions3() {
            return [
                { id: 'horizontal', name: (__('horizontal')) },
                { id: 'grid', name: (__('grid')) },
                { id: 'circular', name: (__('circular')) },
            ];
        },
        // Fixed option set — no search box needed.
        text_alignOptions() {
            return [
                { id: 'left', name: (__('left')) },
                { id: 'center', name: (__('center')) },
                { id: 'right', name: (__('right')) },
            ];
        },
        cfg() {
            return this.block.config;
        },
        // manual/category/brand already choose products; the rest only order them,
        // and only those can be scoped.
        isDynamicSource() {
            return !['manual', 'category', 'brand'].includes(this.cfg.data_source);
        },
        // Fixed option set — no search box needed.
        filterTypeOptions() {
            return [
                { id: 'none', name: (__('no_filter')) },
                { id: 'category', name: (__('by_category')) },
                { id: 'brand', name: (__('by_brand')) },
            ];
        },
        // Fixed option set — no search box needed.
        filterModeOptions() {
            return [
                { id: 'include', name: (__('include_only')) },
                { id: 'exclude', name: (__('exclude_these')) },
            ];
        },
    },
    methods: {
        // Drop the other list when the scope changes, so a leftover selection can
        // never filter by something the form is no longer showing.
        setFilterType(v) {
            this.cfg.filter_type = v;
            if (v !== 'category') this.cfg.filter_category_ids = [];
            if (v !== 'brand') this.cfg.filter_brand_ids = [];
            if (v === 'none') this.cfg.filter_mode = 'include';
        },
        // Switching the marker picks a sensible background: an outline starts
        // hollow, a fill needs paint.
        setActiveIndicator(v) {
            this.cfg.active_indicator = v;
            if (v === 'outline') this.cfg.active_bg_style = 'none';
            else if (v === 'fill' && this.cfg.active_bg_style === 'none') this.cfg.active_bg_style = 'solid';
        },
        addItem() {
            this.block.items.push(newBannerItem());
        },
        addTab() {
            if (this.block.items.length >= TABS_MAX) return;
            this.block.items.push(newTabItem());
        },
        removeItem(i) {
            this.block.items.splice(i, 1);
        },
        moveItem(i, dir) {
            const j = i + dir;
            if (j < 0 || j >= this.block.items.length) return;
            const arr = this.block.items;
            [arr[i], arr[j]] = [arr[j], arr[i]];
        },
    },
};
</script>

<style scoped>
/* Label left, switch right: undo Bootstrap's leading-input layout. */
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

/* Stacked fields, framed like the platform-wise inputs beside them. */
.hb-stack {
    display: flex;
    flex-direction: column;
    gap: .4rem;
    border: 1px solid var(--app-card-border);
    border-radius: .4rem;
    padding: .5rem;
    background: var(--app-thead-bg);
}
.hb-lbl {
    font-size: .75rem;
    color: var(--app-muted);
    margin-bottom: .15rem;
    display: block;
}
/* Short "what is this for" note under a non-obvious field. */
.hb-hint {
    display: block;
    font-size: .68rem;
    color: var(--app-muted);
    line-height: 1.3;
    margin-bottom: .3rem;
}
/* Info (i) icon next to a label — hint shows on hover. */
.hb-info {
    display: inline-block;
    color: var(--app-muted);
    cursor: help;
    vertical-align: -2px;
}
.hb-info:hover {
    color: var(--bs-primary);
}
.hb-pick-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
    gap: .35rem;
    max-height: 200px;
    overflow-y: auto;
    border: 1px solid var(--app-card-border);
    border-radius: .4rem;
    padding: .5rem;
}
.hb-pick-item {
    display: flex;
    align-items: center;
    gap: .35rem;
    font-size: .8rem;
    margin: 0;
    cursor: pointer;
}
.hb-switch-col {
    display: flex;
    flex-direction: column;
    gap: .2rem;
}
.hb-switch-col .form-check {
    min-height: auto;
    margin: 0;
}
.hb-switch-col .form-check-input {
    margin-top: 0;
}
</style>
