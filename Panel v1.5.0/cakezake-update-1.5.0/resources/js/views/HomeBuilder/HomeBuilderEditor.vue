<template>
    <div class="hb-editor">
        <!-- ===== Top bar ===== -->
        <div class="hb-topbar">
            <div class="d-flex align-items-center gap-2">
                <router-link to="/home_builder" class="btn btn-sm btn-light">
                    <ArrowLeft :size="16" />
                </router-link>
                <input type="text" class="form-control form-control-sm hb-name-input" v-model="name"
                    :placeholder="__('enter_name')">
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
                <button class="btn btn-sm btn-outline-secondary" @click="openSetupWizard"
                    :disabled="saving || publishing" v-if="$can('home_builder_update')">
                    <Settings :size="15" /> {{ __('edit_setup') }}
                </button>
                <!-- Draft mode: save the draft + schedule its auto-publish. -->
                <button v-if="previewSource === 'draft'" class="btn btn-sm btn-outline-primary"
                    @click="saveDraft" :disabled="saving || publishing">
                    <b-spinner small v-if="saving"></b-spinner>
                    <Save :size="15" v-else />
                    {{ __('save_draft') }}
                </button>
                <button v-if="previewSource === 'draft'" class="btn btn-sm btn-outline-primary" @click="openSchedule"
                    :disabled="saving || publishing" v-show="$can('home_builder_publish')"
                    :title="__('schedule_publish')">
                    <CalendarClock :size="15" />
                    {{ scheduledPublishAt ? __('scheduled') : __('schedule') }}
                </button>
                <!-- Publish: draft mode promotes the draft; published mode pushes the live edits. -->
                <button class="btn btn-sm btn-primary" @click="publish" :disabled="saving || publishing"
                    v-if="$can('home_builder_publish')">
                    <b-spinner small v-if="publishing"></b-spinner>
                    <Rocket :size="15" v-else />
                    {{ previewSource === 'published' ? __('publish_changes') : __('publish') }}
                </button>
            </div>
        </div>

        <!-- Pending-schedule banner: draft will auto-publish at the shown local time. -->
        <div v-if="scheduledPublishAt" class="alert alert-info d-flex align-items-center gap-2 py-2 px-3 mb-2 small">
            <CalendarClock :size="16" />
            <span>{{ __('draft_will_publish_at') }} <strong>{{ scheduledLocalDisplay }}</strong></span>
            <button class="btn btn-sm btn-link text-danger p-0 ms-auto" @click="cancelSchedule"
                :disabled="scheduling">{{ __('cancel_schedule') }}</button>
        </div>

        <!-- Schedule modal -->
        <b-modal v-model="showScheduleModal" :title="__('schedule_publish')" centered
            :ok-title="__('save')" :cancel-title="__('cancel')" :ok-disabled="scheduling || !scheduleInput"
            @ok.prevent="saveSchedule">
            <p class="text-muted small mb-2">{{ __('schedule_publish_note') }}</p>
            <div class="form-group">
                <label class="small" for="hb_schedule_at">{{ __('publish_date_and_time') }}</label>
                <input type="datetime-local" id="hb_schedule_at" class="form-control" :min="nowLocal"
                    v-model="scheduleInput">
            </div>
            <div class="alert alert-warning small mt-3 mb-0">
                {{ __('schedule_publish_warning') }}
            </div>
        </b-modal>

        <!-- Category bar (category_wise): full-width tab list + add/reorder actions. -->
        <div v-if="!loading && homeType === 'category_wise'" class="hb-cat-bar">
            <div class="hb-cat-bar-pills">
                <button v-for="t in categoryTabs" :key="t.key" type="button" class="hb-cat-pill"
                    :class="{ active: t.key === activeTabKey, inactive: t.active === false }"
                    @click="switchTab(t.key)"
                    v-b-tooltip.hover :title="t.active === false ? __('inactive') : ''">
                    {{ tabLabel(t.key) }}
                    <span v-if="t.kind === 'custom'" class="hb-cat-pill-badge">{{ __('custom') }}</span>
                </button>
            </div>
            <div class="hb-cat-bar-actions ms-auto">
                <button type="button" class="btn btn-sm btn-outline-secondary" :disabled="!activeTabKey"
                    v-b-tooltip.hover :title="__('clone_category_from_layout_hint')" @click="openImport">
                    <Copy :size="14" /> {{ __('clone_category_from_layout') }}
                </button>
                <button type="button" class="btn btn-sm btn-outline-secondary" @click="openReorder">
                    <ArrowUpDown :size="14" /> {{ __('custom_categories') }}
                </button>
                <button type="button" class="btn btn-sm btn-primary" @click="addCategoryOpen = true">
                    <Plus :size="14" /> {{ __('add_category') }}
                </button>
            </div>
        </div>

        <!-- Loading: skeleton matching the 3-column builder (section list |
             preview | config) so the layout doesn't jump when the editor mounts. -->
        <div v-if="loading" class="hb-grid hb-skel">
            <!-- Col 1: section list -->
            <div class="hb-col hb-col-list">
                <div class="skel skel-line" style="width:55%;height:.9rem;margin-bottom:1rem"></div>
                <div v-for="n in 6" :key="'hbskl-' + n" class="hb-skel-row">
                    <div class="skel hb-skel-grip"></div>
                    <div class="skel skel-line mb-0" style="flex:1"></div>
                    <div class="skel hb-skel-dot"></div>
                </div>
                <div class="skel hb-skel-add"></div>
            </div>
            <!-- Col 2: preview -->
            <div class="hb-col hb-col-preview">
                <div class="skel hb-skel-preview"></div>
            </div>
            <!-- Col 3: config panel -->
            <div class="hb-col hb-col-config">
                <div class="hb-skel-config">
                    <div class="skel skel-line" style="width:50%;height:.95rem;margin-bottom:1.1rem"></div>
                    <div v-for="n in 5" :key="'hbskc-' + n" class="hb-skel-field">
                        <div class="skel skel-line" style="width:35%;margin-bottom:.5rem"></div>
                        <div class="skel hb-skel-input"></div>
                    </div>
                </div>
            </div>
        </div>

        <div v-else class="hb-grid">
            <!-- ===== Col 1: sections + header config ===== -->
            <div class="hb-col hb-col-list">
                <!-- Note + category rail stay stuck under the top bar while the
                     builder list scrolls. -->
                <div class="hb-subhead">
                    <div class="alert py-2 px-3 mb-2 small d-flex align-items-center gap-2"
                        :class="previewSource === 'published' ? 'alert-info' : 'alert-secondary'">
                        <component :is="previewSource === 'published' ? 'Rocket' : 'Pen'" :size="14" />
                        {{ previewSource === 'published' ? __('editing_published_layout') : __('editing_draft_layout') }}
                    </div>
                </div>
                <div>
                <!-- Header Settings — selectable; its config opens in the right panel. -->
                <div class="hb-sec-row hb-header-row" :class="{ active: selectedIsHeader }" @click="selectHeader">
                    <span class="hb-sec-row-icon"><Settings :size="15" /></span>
                    <span class="hb-sec-row-title">{{ __('header_settings') }}</span>
                </div>
                <!-- /hb-header-card -->

                <!-- Sections heading + inline add -->
                <div class="d-flex align-items-center justify-content-between my-2">
                    <h6 class="mb-0 fw-bold">{{ __('sections') }}</h6>
                    <button type="button" class="btn btn-sm btn-primary d-inline-flex align-items-center gap-1"
                        @click="addSectionOpen = true">
                        <Plus :size="15" /> {{ __('add') }}
                    </button>
                </div>

                <!-- Section list — ONLY these reorder (drag handle). Click selects → Col 3. -->
                <div class="hb-sections">
                    <draggable v-model="activeConfig.sections" item-key="id" handle=".hb-row-grip"
                        :animation="180" ghost-class="hb-drag-ghost"
                        @start="dragging = true" @end="dragging = false">
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

                    <p v-if="!activeConfig.sections.length" class="text-muted text-center py-3">
                        {{ __('no_sections_yet') }}
                    </p>
                </div>
                </div><!-- /hb-readonly -->
            </div>

            <!-- ===== Col 2: live preview (hugs the device — no empty space beside) ===== -->
            <div class="hb-col hb-col-preview">
                <div class="hb-preview-sticky">
                    <LivePreview :config="previewConfig" :languages="languages" :active-lang="activeLang"
                        :default-lang="defaultLang" :all-products="channelProducts" :all-categories="allCategories"
                        :all-brands="allBrands"
                        :platform="previewPlatform" @update:platform="previewPlatform = $event"
                        :category-tabs="previewTabs" :active-category-id="activeTabKey"
                        :mode="layout.mode" :preview-mode="previewMode" :home-type="homeType"
                        :selected-section-id="selectedSectionId"
                        @tab-click="onPreviewTabClick" @edit-section="selectSection" />
                </div>
            </div>

            <!-- ===== Col 3: config panel (header settings OR selected section) ===== -->
            <div class="hb-col hb-col-config">
                <div class="hb-config-panel">
                    <!-- Header settings config -->
                    <template v-if="selectedIsHeader">
                        <div class="hb-config-head">
                            <Settings :size="16" />
                            <strong class="text-truncate">{{ __('header_settings') }}</strong>
                        </div>
                                        <!-- copy layout from another category tab -->
                <div v-if="homeType === 'category_wise' && copyFromOptions.length" class="hb-copy-bar mb-2">
                    <label class="small text-muted me-1">{{ __('copy_layout_from') }}:</label>
                    <AppSelect v-model="copySource" class="form-select form-select-sm hb-copy-select"
                        :options="copyFromOptions" label-key="label" track-by="key"
                        :placeholder="__('select_category_to_copy')" />
                    <button type="button" class="btn btn-sm btn-outline-primary"
                        v-b-tooltip.hover :title="__('apply_copy_hint')"
                        :disabled="!copySource" @click="applyCopy">
                        <Copy :size="15" /> {{ __('apply_copy') }}
                    </button>
                </div>

                <!-- background theme for active tab (category_wise) -->
                <div v-if="homeType === 'category_wise'" class="hb-tab-bg-bar mb-2">
                    <div class="row g-2 align-items-start">
                        <!-- Full row for images (uploads need the width); half-row for color. -->
                        <div class="hb-fld" :class="activeConfig.background_theme === 'image' ? 'col-12' : 'col-md-6'">
                            <label class="small fw-bold mb-1 d-block">
                                {{ __('header_background_for') }} <span class="text-primary">{{ tabLabel(activeTabKey) }}</span>
                            </label>
                            <small class="hb-field-note">{{ __('header_background_hint') }}</small>
                            <div class="d-flex gap-2 align-items-center">
                                <div class="btn-group btn-group-toggle btn-group-sm" role="group">
                                    <label class="btn btn-outline-primary"
                                        :class="{ active: activeConfig.background_theme === 'color' }">
                                        <input type="radio" value="color" v-model="activeConfig.background_theme" autocomplete="off">
                                        {{ __('color') }}
                                    </label>
                                    <label class="btn btn-outline-primary"
                                        :class="{ active: activeConfig.background_theme === 'image' }">
                                        <input type="radio" value="image" v-model="activeConfig.background_theme" autocomplete="off">
                                        {{ __('image') }}
                                    </label>
                                </div>
                                <div v-if="activeConfig.background_theme === 'color'" class="d-flex gap-2 align-items-center flex-grow-1">
                                    <ColorInput class="flex-grow-1" show-hex placeholder="#FFE94B"
                                        :model-value="activeConfig.background_color" @update:model-value="activeConfig.background_color = $event" />
                                </div>
                            </div>
                            <!-- Per-platform header images on their own full-width row. -->
                            <div v-if="activeConfig.background_theme === 'image'" class="row g-2 mt-1">
                                <div class="col-4">
                                    <HbImageUpload :label="__('app')" :model-value="activeConfig.background_image_url.app"
                                        @update:model-value="activeConfig.background_image_url.app = $event" />
                                </div>
                                <div class="col-4">
                                    <HbImageUpload :label="__('tablet')" :model-value="activeConfig.background_image_url.tablet"
                                        @update:model-value="activeConfig.background_image_url.tablet = $event" />
                                </div>
                                <div class="col-4">
                                    <HbImageUpload :label="__('web')" :model-value="activeConfig.background_image_url.web"
                                        @update:model-value="activeConfig.background_image_url.web = $event" />
                                </div>
                            </div>
                        </div>
                        <div class="hb-fld" :class="activeConfig.background_theme === 'image' ? 'col-12' : 'col-md-6'">
                            <label class="small fw-bold mb-1 d-block">{{ __('text_color') }}</label>
                            <small class="hb-field-note">{{ __('header_text_color_hint') }}</small>
                            <div class="d-flex gap-2 align-items-center">
                                <ColorInput class="flex-grow-1" show-hex placeholder="#000000"
                                        :model-value="activeConfig.text_color" @update:model-value="activeConfig.text_color = $event" />
                            </div>
                        </div>
                    </div>
                    <div class="row g-2 align-items-start mt-2">
                        <div class="col-md-6 hb-fld">
                            <label class="small fw-bold mb-1 d-block">{{ __('category_icon') }}</label>
                            <small class="hb-field-note">{{ __('category_icon_hint') }}</small>
                            <HbImageUpload v-model="activeConfig.header_icon_url" />
                        </div>
                    </div>
                </div>

                <!-- per-channel bg for single mode -->
                <div v-if="homeType === 'single'" class="hb-tab-bg-bar mb-2">
                    <div v-for="ch in singleChannels" :key="ch" class="mb-2">
                        <div class="row g-2 align-items-start">
                            <!-- Full row for images (uploads need the width); half-row for color. -->
                            <div class="hb-fld" :class="bgRef(ch).theme === 'image' ? 'col-12' : 'col-md-6'">
                                <label class="small fw-bold mb-1 d-block">
                                    {{ __('header_background_for') }}
                                    <span class="text-primary">{{ __(ch) }}</span>
                                </label>
                                <small class="hb-field-note">{{ __('header_background_hint') }}</small>
                                <div class="d-flex gap-2 align-items-center">
                                    <div class="btn-group btn-group-toggle btn-group-sm" role="group">
                                        <label class="btn btn-outline-primary"
                                            :class="{ active: bgRef(ch).theme === 'color' }">
                                            <input type="radio" value="color" v-model="bgRef(ch).theme" autocomplete="off">
                                            {{ __('color') }}
                                        </label>
                                        <label class="btn btn-outline-primary"
                                            :class="{ active: bgRef(ch).theme === 'image' }">
                                            <input type="radio" value="image" v-model="bgRef(ch).theme" autocomplete="off">
                                            {{ __('image') }}
                                        </label>
                                    </div>
                                    <div v-if="bgRef(ch).theme === 'color'" class="d-flex gap-2 align-items-center flex-grow-1">
                                        <ColorInput class="flex-grow-1" show-hex placeholder="#FFE94B"
                                            :model-value="bgRef(ch).color"
                                            @update:model-value="bgRef(ch).color = $event" />
                                    </div>
                                </div>
                                <!-- Per-platform header images on their own full-width row. -->
                                <div v-if="bgRef(ch).theme === 'image'" class="row g-2 mt-1">
                                    <div class="col-4">
                                        <HbImageUpload :label="__('app')" :model-value="bgRef(ch).image_url.app"
                                            @update:model-value="bgRef(ch).image_url.app = $event" />
                                    </div>
                                    <div class="col-4">
                                        <HbImageUpload :label="__('tablet')" :model-value="bgRef(ch).image_url.tablet"
                                            @update:model-value="bgRef(ch).image_url.tablet = $event" />
                                    </div>
                                    <div class="col-4">
                                        <HbImageUpload :label="__('web')" :model-value="bgRef(ch).image_url.web"
                                            @update:model-value="bgRef(ch).image_url.web = $event" />
                                    </div>
                                </div>
                            </div>
                            <div class="hb-fld" :class="bgRef(ch).theme === 'image' ? 'col-12' : 'col-md-6'">
                                <label class="small fw-bold mb-1 d-block">{{ __('text_color') }}</label>
                                <small class="hb-field-note">{{ __('header_text_color_hint') }}</small>
                                <div class="d-flex gap-2 align-items-center">
                                    <ColorInput class="flex-grow-1" show-hex placeholder="#000000"
                                        :model-value="bgRef(ch).text_color"
                                        @update:model-value="bgRef(ch).text_color = $event" />
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- search-bar hints: one list per layout (single) or per tab (category_wise) -->
                <div class="hb-tab-bg-bar mb-2">
                    <div class="row g-2 align-items-start">
                        <div class="col-12 hb-fld">
                            <label class="small fw-bold mb-1 d-block">
                                {{ __('search_suggestions') }}
                                <span v-if="homeType === 'category_wise'" class="text-primary">{{ tabLabel(activeTabKey) }}</span>
                            </label>
                            <small class="hb-field-note">{{ __('search_suggestions_hint') }}</small>
                            <AppSelect multiple taggable tags-only :options="[]"
                                :model-value="activeConfig.search_suggestions"
                                @update:model-value="activeConfig.search_suggestions = $event"
                                :placeholder="__('type_a_name_and_press_enter')" />
                        </div>
                    </div>
                </div>

                    </template>
                    <!-- Selected section config (status toggle + delete live in the section list). -->
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
                            :languages="languages" :default-lang="defaultLang" :all-products="pickerProducts"
                            :all-categories="allCategories" :scoped-categories="pickerCategories" :all-brands="allBrands"
                            :all-pages="allPages" @save-template="onSaveTemplate" />
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

        <!-- Custom categories modal (order, rename, enable, delete): applies only on OK. -->
        <b-modal v-model="reorderOpen" :title="__('custom_categories')" centered
            :ok-title="__('apply')" :cancel-title="__('cancel')" @ok.prevent="applyReorder">
            <p class="text-muted small mb-2">{{ __('drag_to_reorder') }}</p>
            <draggable v-model="reorderTabs" item-key="key" handle=".hb-reorder-grip" :animation="150" tag="div">
                <template #item="{ element: t }">
                    <div>
                        <div class="hb-reorder-row">
                            <span class="hb-reorder-grip" :title="__('drag_to_reorder')"><GripVertical :size="16" /></span>
                            <span class="flex-grow-1 text-truncate">{{ reorderLabel(t) }}</span>
                            <span v-if="t.kind === 'custom'" class="badge bg-info-subtle text-info me-1">{{ __('custom') }}</span>
                            <!-- Off keeps the tab in the builder but drops it from the API. -->
                            <div class="form-check form-switch m-0 me-1"
                                v-b-tooltip.hover :title="t.active === false ? __('inactive') : __('active')">
                                <input type="checkbox" class="form-check-input"
                                    :checked="t.active !== false"
                                    @change="t.active = $event.target.checked">
                            </div>
                            <!-- Only custom tabs own their name; system tabs read it from the category. -->
                            <button v-if="t.kind === 'custom'" type="button" class="btn btn-xs p-1"
                                @click="toggleReorderEdit(t.key)" :title="__('edit_custom_category')">
                                <Pen :size="14" />
                            </button>
                            <button v-if="t.kind !== 'all'" type="button" class="btn btn-xs text-danger p-1"
                                @click="removeReorderTab(t.key)" :title="__('delete')"><Trash2 :size="15" /></button>
                        </div>

                        <div v-if="reorderEditKey === t.key" class="hb-reorder-edit">
                            <label class="form-label small fw-bold">{{ __('category_name') }}</label>
                            <TranslatableInput v-if="languages.length === 1"
                                v-model="t.name" :languages="languages" :active-lang="languages[0].id"
                                :placeholder="__('category_name') + ' *'" />
                            <b-tabs v-else v-model="reorderLangTabIndex" content-class="mt-2" class="hb-block-lang-tabs mb-2">
                                <b-tab v-for="lang in languages" :key="'rcn-' + t.key + '-' + lang.id">
                                    <template #title>
                                        <span :class="{ 'text-primary fw-bold': lang.is_default }">{{ lang.name }}</span>
                                    </template>
                                    <TranslatableInput v-model="t.name" :languages="languages" :active-lang="lang.id"
                                        :placeholder="__('category_name') + (lang.is_default ? ' *' : '')" />
                                </b-tab>
                            </b-tabs>
                            <HbImageUpload :label="__('category_icon')" :model-value="t.icon_url"
                                @update:model-value="t.icon_url = $event" />
                        </div>
                    </div>
                </template>
            </draggable>
        </b-modal>

        <!-- Import a category design from another layout into the current tab. -->
        <b-modal v-model="importOpen" :title="__('clone_category_from_layout')" centered
            :ok-title="__('clone')" :cancel-title="__('cancel')"
            :ok-disabled="!importReady" @ok.prevent="applyImport">
            <p class="small text-muted mb-3">
                {{ __('importing_into') }}: <b>{{ tabLabel(activeTabKey) }}</b>
            </p>

            <div v-if="importLoading" class="text-center py-4"><b-spinner small></b-spinner></div>

            <template v-else-if="!importLayoutOptions.length">
                <p class="text-muted mb-0">{{ __('no_importable_layouts') }}</p>
            </template>

            <template v-else>
                <label class="form-label small fw-bold">{{ __('source_layout') }}</label>
                <AppSelect class="form-select mb-3" v-model="importLayoutId" :options="importLayoutOptions"
                    :placeholder="__('select_layout')" @update:model-value="onImportLayoutChange" />

                <template v-if="importLayout">
                    <div class="btn-group btn-group-sm w-100 mb-3" role="group">
                        <label class="btn btn-outline-primary" :class="{ active: importSource === 'draft' }">
                            <input type="radio" class="btn-check" value="draft" v-model="importSource"
                                autocomplete="off" @change="onImportSourceChange">
                            {{ __('draft') }}
                        </label>
                        <label class="btn btn-outline-primary" :class="{ active: importSource === 'published' }"
                            :disabled="!importHasPublished">
                            <input type="radio" class="btn-check" value="published" v-model="importSource"
                                autocomplete="off" :disabled="!importHasPublished" @change="onImportSourceChange">
                            {{ __('published') }}
                        </label>
                    </div>

                    <template v-if="importLayout.home_type === 'category_wise'">
                        <label class="form-label small fw-bold">{{ __('source_category') }}</label>
                        <AppSelect class="form-select" v-model="importTabKey" :options="importTabOptions"
                            :placeholder="__('select_category')" />
                        <p v-if="!importTabOptions.length" class="text-muted small mt-2 mb-0">
                            {{ __('no_records_found') }}
                        </p>
                    </template>
                    <p v-else class="text-muted small mb-0">
                        <b>{{ __('whole_layout') }}</b> — {{ __('single_layout') }}
                    </p>
                </template>

                <p class="text-muted small mt-3 mb-0">{{ __('import_replaces_current_tab') }}</p>
            </template>
        </b-modal>

        <!-- Add Category modal: choose type via radio, then fill only that section. -->
        <b-modal v-model="addCategoryOpen" :title="__('add_category')" centered
            :ok-title="__('add')" :cancel-title="__('cancel')"
            :ok-disabled="newCatKind === 'system' ? !newSystemCatId : !(newCustomName[defaultLang] || '').trim()"
            @ok.prevent="addCategory">
            <div class="btn-group btn-group-sm w-100 mb-3" role="group">
                <label class="btn btn-outline-primary" :class="{ active: newCatKind === 'system' }">
                    <input type="radio" class="btn-check" value="system" v-model="newCatKind" autocomplete="off">
                    {{ __('system_category') }}
                </label>
                <label class="btn btn-outline-primary" :class="{ active: newCatKind === 'custom' }">
                    <input type="radio" class="btn-check" value="custom" v-model="newCatKind" autocomplete="off">
                    {{ __('custom_category') }}
                </label>
            </div>

            <div v-if="newCatKind === 'system'">
                <label class="form-label small fw-bold">{{ __('select_category') }}</label>
                <AppSelect class="form-select" v-model="newSystemCatId" :options="systemCatOptions"
                    :placeholder="__('select_category')" />
                <small class="text-muted d-block mt-1">{{ __('system_category_tab_hint') }}</small>
            </div>

            <div v-else>
                <label class="form-label small fw-bold">{{ __('category_name') }}</label>
                <TranslatableInput v-if="languages.length === 1"
                    v-model="newCustomName" :languages="languages"
                    :active-lang="languages[0].id"
                    :placeholder="__('category_name') + ' *'" />
                <b-tabs v-else v-model="langTabIndex" content-class="mt-2" class="hb-block-lang-tabs mb-2">
                    <b-tab v-for="lang in languages" :key="'ccn-' + lang.id">
                        <template #title>
                            <span :class="{ 'text-primary fw-bold': lang.is_default }">{{ lang.name }}</span>
                        </template>
                        <TranslatableInput v-model="newCustomName" :languages="languages"
                            :active-lang="lang.id"
                            :placeholder="__('category_name') + (lang.is_default ? ' *' : '')" />
                    </b-tab>
                </b-tabs>
                <HbImageUpload :label="__('category_icon')" :model-value="newCustomIcon"
                    @update:model-value="newCustomIcon = $event" />
                <small class="text-muted d-block mt-1">{{ __('custom_category_tab_hint') }}</small>
            </div>
        </b-modal>

        <HomeBuilderWizard v-if="setupWizard" :existing-layouts="otherLayouts" :initial-layout="layout"
            @complete="onSetupComplete" @close="setupWizard = false" />

        <TemplatePicker v-if="templatePickerOpen" :default-lang="defaultLang"
            @close="templatePickerOpen = false" @pick="onTemplatePick" />
    </div>
</template>

<script>
import axios from 'axios';
import draggable from 'vuedraggable';
import SectionEditor from './components/SectionEditor.vue';
import LivePreview from './components/preview/LivePreview.vue';
import HbImageUpload from './components/HbImageUpload.vue';
import HomeBuilderWizard from './components/HomeBuilderWizard.vue';
import TemplatePicker from './components/TemplatePicker.vue';
import SectionTypeCard from './components/SectionTypeCard.vue';
import TranslatableInput from './components/TranslatableInput.vue';
import {
    ArrowLeft, Settings, Save, Rocket, Copy, Sparkles, Pen, CalendarClock,
    Images, LayoutGrid, Package, PanelTop, Tags, Grid3x3, Image as ImageIcon, Heading,
    GripVertical, Plus, Trash2, MousePointerClick, ChevronDown, ChevronUp, Bookmark, X, ArrowUpDown,
    MoreVertical,
} from 'lucide-vue-next';
import {
    SECTION_TYPES, emptyConfig, newSection, normalizeConfig, genId, cloneAndReidSection, pageOptions,
} from './homeBuilderHelpers.js';
import ColorInput from './components/ColorInput.vue';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';

export default {
    name: 'HomeBuilderEditor',
    mixins: [UnsavedChanges],
    components: {
        draggable, SectionEditor, LivePreview, HbImageUpload, HomeBuilderWizard, TemplatePicker, TranslatableInput,
        SectionTypeCard,
        ColorInput,
        ArrowLeft, Settings, Save, Rocket, Copy, Sparkles, Pen, CalendarClock,
        Images, LayoutGrid, Package, PanelTop, Tags, Grid3x3, ImageIcon, Heading,
        GripVertical, Plus, Trash2, MousePointerClick, ChevronDown, ChevronUp, Bookmark, X, ArrowUpDown,
        MoreVertical,
    },
    data() {
        return {
            layoutId: null,
            layout: null,
            name: '',
            status: 'draft',
            dragging: false,
            languages: [],
            activeLang: null,
            langTabIndex: 0,
            defaultLang: null,
            draftConfig: emptyConfig(),
            branch: {},                 // category_wise: catKey->config (or {quick,ecommerce})
            activeTabKey: '',
            activeChannel: 'quick',
            previewMode: 'quick',
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
            // Scheduled auto-publish (UTC string from server; local input for the picker).
            scheduledPublishAt: null,
            showScheduleModal: false,
            scheduleInput: '',
            scheduling: false,
            copySource: '',
            setupWizard: false,
            otherLayouts: [],
            templatePickerOpen: false,
            // 3-column editor state.
            selectedSectionId: null,
            selectedIsHeader: false,
            addSectionOpen: false,
            // Ordered header tabs (system + custom) — source of truth for category-wise.
            categoryTabs: [],
            platformOptions: [
                { value: 'app', text: 'App' },
                { value: 'tablet', text: 'Tablet' },
                { value: 'web', text: 'Web' },
            ],
            addCategoryOpen: false,
            reorderOpen: false,
            reorderTabs: [],           // tentative copy edited in the reorder modal
            // Import a category design from another layout into the active tab.
            importOpen: false,
            importLoading: false,
            importLayouts: [],
            importLayoutId: '',
            importSource: 'draft',
            importTabKey: '',
            reorderEditKey: '',        // custom tab currently being renamed in that modal
            reorderLangTabIndex: 0,
            newCatKind: 'system',
            newSystemCatId: '',
            newCustomName: {},     // { langId: text } — multilang custom category name
            newCustomIcon: '',
        };
    },
    computed: {
        // Only layouts that actually carry a design are worth offering.
        importLayoutOptions() {
            return (this.importLayouts || [])
                .filter(l => Number(l.id) !== Number(this.layout.id) && this.layoutHasDesign(l))
                .map(l => ({ id: l.id, name: l.name + ' · ' + (l.mode || '') }));
        },
        importLayout() {
            return (this.importLayouts || []).find(l => Number(l.id) === Number(this.importLayoutId)) || null;
        },
        importHasPublished() {
            const l = this.importLayout;
            if (!l) return false;
            return l.home_type === 'category_wise'
                ? !!Object.keys(l.category_layouts_published || {}).length
                : !!(l.published_json && Object.keys(l.published_json).length);
        },
        // Tabs of the SOURCE layout that hold a design in the chosen snapshot.
        importTabOptions() {
            const l = this.importLayout;
            if (!l || l.home_type !== 'category_wise') return [];
            const map = this.importSource === 'published'
                ? (l.category_layouts_published || {})
                : (l.category_layouts_draft || {});
            const tabs = (this.importSource === 'published'
                ? l.category_tabs_published
                : l.category_tabs_draft) || [];

            const label = (key) => {
                const t = tabs.find(x => x && String(x.key) === String(key));
                if (t && t.kind === 'custom') return this.strVal(t.name) || __('custom_category');
                const cat = (this.allCategories || []).find(c => String(c.id) === String(key));
                return cat ? cat.name : ('#' + key);
            };
            return Object.keys(map)
                .filter(k => (map[k]?.sections || []).length)
                .map(k => ({ id: k, name: label(k) }));
        },
        importReady() {
            if (!this.importLayout || !this.activeTabKey) return false;
            return this.importLayout.home_type === 'category_wise' ? !!this.importTabKey : true;
        },
        homeType() {
            return this.layout ? this.layout.home_type : 'single';
        },
        // Currently-selected section (Col 3 config panel), and its index in the list.
        selectedSectionIndex() {
            if (!this.selectedSectionId) return -1;
            return (this.activeConfig.sections || []).findIndex(s => s.id === this.selectedSectionId);
        },
        selectedSection() {
            const i = this.selectedSectionIndex;
            return i >= 0 ? this.activeConfig.sections[i] : null;
        },
        // Preview column follows the device so it doesn't reserve web-width for the
        // narrow app/tablet frames; the config panel takes the freed space.
        previewColClass() {
            // App/Tablet hug the device (less empty space beside), Web trimmed down a bit.
            return { app: 'col-12 col-lg-4', tablet: 'col-12 col-lg-4', web: 'col-12 col-lg-5' }[this.previewPlatform] || 'col-12 col-lg-5';
        },
        configColClass() {
            return { app: 'col-12 col-lg-5', tablet: 'col-12 col-lg-5', web: 'col-12 col-lg-4' }[this.previewPlatform] || 'col-12 col-lg-4';
        },
        // System categories not already added as a tab.
        systemCatOptions() {
            const used = new Set(this.categoryTabs.filter(t => t.kind === 'system').map(t => Number(t.category_id)));
            return (this.allCategories || [])
                .filter(c => !used.has(Number(c.id)))
                .map(c => ({ id: c.id, name: c.name }));
        },
        // datetime-local `min` — blocks scheduling in the past.
        nowLocal() {
            const p = n => String(n).padStart(2, '0');
            const d = new Date();
            return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
        },
        // Human-readable local rendering of the stored UTC schedule.
        scheduledLocalDisplay() {
            if (!this.scheduledPublishAt) return '';
            const d = new Date(this.scheduledPublishAt);
            return isNaN(d.getTime()) ? '' : d.toLocaleString();
        },
        // The working buffer the form + preview render. `previewSource` chooses which
        // source (draft / published) is loaded into it; both are editable.
        activeConfig() {
            return this.draftConfig;
        },
        previewConfig() {
            return this.draftConfig;
        },
        hasDraftContent() {
            if (!this.layout) return false;
            if (this.homeType === 'single') {
                const j = this.layout.draft_json;
                return !!(j && Array.isArray(j.sections) && j.sections.length);
            }
            return Object.keys(this.coerceMap(this.layout.category_layouts_draft)).length > 0;
        },
        hasPublished() {
            if (!this.layout) return false;
            if (this.homeType === 'single') {
                const j = this.layout.published_json;
                return !!(j && Array.isArray(j.sections) && j.sections.length);
            }
            return Object.keys(this.coerceMap(this.layout.category_layouts_published)).length > 0;
        },
        // Per-channel split is gone (layouts are single-channel) — always false.
        isSplit() {
            return false;
        },
        // Category tab keys for the active context.
        tabKeys() {
            if (!this.layout || this.layout.home_type !== 'category_wise') return [];
            return this.categoryTabs.map(t => t.key);
        },
        previewTabs() {
            const map = this.currentMap();
            return this.categoryTabs.filter(t => t.active !== false).map(t => {
                const cat = t.kind === 'system' ? this.allCategories.find(c => String(c.id) === String(t.category_id)) : null;
                const tabCfg = (map && map[t.key]) || {};
                return {
                    id: t.key,
                    name: this.tabLabel(t.key),
                    image_url: t.kind === 'custom' ? this.imgVal(t.icon_url) : (cat ? cat.image_url : ''),
                    header_icon_url: tabCfg.header_icon_url || '',
                    text_color: tabCfg.text_color || '',
                };
            });
        },
        singleChannels() {
            if (!this.layout) return [];
            return [this.layout.mode];
        },
        copyFromOptions() {
            if (this.homeType !== 'category_wise') return [];
            const map = this.currentMap();
            return this.tabKeys
                .filter(k => k !== this.activeTabKey && map[k] && (map[k].sections || []).length)
                .map(k => ({ key: k, label: this.tabLabel(k) }));
        },
        // Channel the editor is currently authoring for. Drives the product
        // list passed to block editors + live preview so dropdowns and preview
        // only show products whose sales_channel matches.
        currentChannel() {
            return this.layout ? this.layout.mode : 'quick';
        },
        // allProducts filtered to the layout's channel (channel-eligible + 'both' products).
        // Products offered in the section pickers. On a category-wise layout each tab
        // only offers its own category's products; the "All" tab offers everything.
        // Products can sit on a parent OR a child category, so a parent tab includes
        pickerProducts() {
            if (this.homeType !== 'category_wise' || !this.activeTabKey) {
                return this.channelProducts;
            }
            const rootId = Number(this.activeTabKey);
            if (!rootId) return this.channelProducts;
            const allowed = this.subtreeCategoryIds(rootId);
            return this.channelProducts.filter(p => allowed.has(Number(p.category_id)));
        },
        // Categories offered in the section pickers (category_section + product_slider
        // data_source=category). On a category-wise layout each tab offers only its own
        // header category subtree — the tab category itself plus every descendant — so a
        // parent tab includes its whole tree and a child tab includes its own subtree.
        // The "All" tab and non-category-wise layouts offer every category.
        pickerCategories() {
            if (this.homeType !== 'category_wise' || !this.activeTabKey) {
                return this.allCategories;
            }
            const rootId = Number(this.activeTabKey);
            if (!rootId) return this.allCategories;
            const allowed = this.subtreeCategoryIds(rootId);
            return this.allCategories.filter(c => allowed.has(Number(c.id)));
        },
        channelProducts() {
            const ch = this.currentChannel;
            return this.allProducts.filter(p => {
                const sc = (p.sales_channel || 'both');
                return sc === 'both' || sc === ch;
            });
        },
    },
    created() {
        this.layoutId = this.$route.params.id;
        if (!this.layoutId) {
            this.$router.replace('/home_builder');
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
        // Tracked state for the UnsavedChanges guard — the editable layout config
        // (name + working buffer + per-category maps + tab order). Warns before
        // leaving the editor with unsaved section/config edits.
        formState() {
            return {
                name: this.name,
                categoryTabs: this.categoryTabs,
                ...(this.homeType === 'single'
                    ? { draftConfig: this.draftConfig }
                    : { branch: this.prunedBranch() }),
            };
        },
        /**
         * Branch minus tabs that hold nothing but defaults. Opening a tab calls
         * A tab the user actually touched (even just its background) no longer
         * matches the pristine shape, so it stays in the snapshot.
         */
        normalizeBranch() {
            const walk = (map) => {
                Object.keys(map || {}).forEach((k) => {
                    const v = map[k];
                    if (!v || typeof v !== 'object') return;
                    // Split mode nests channel => { tabKey: config }.
                    if (!Object.prototype.hasOwnProperty.call(v, 'sections')) walk(v);
                    else map[k] = normalizeConfig(v);
                });
            };
            walk(this.branch);
        },
        prunedBranch() {
            if (!this._pristineConfigJson) {
                this._pristineConfigJson = JSON.stringify(normalizeConfig(emptyConfig()));
            }
            const prune = (map) => {
                const out = {};
                Object.keys(map || {}).forEach((k) => {
                    const v = map[k];
                    if (!v || typeof v !== 'object') return;
                    // Split mode nests channel => { tabKey: config }.
                    if (!Object.prototype.hasOwnProperty.call(v, 'sections')) {
                        const inner = prune(v);
                        if (Object.keys(inner).length) out[k] = inner;
                        return;
                    }
                    if (JSON.stringify(v) !== this._pristineConfigJson) out[k] = v;
                });
                return out;
            };
            return prune(this.branch);
        },
        // Set of category ids in the subtree rooted at rootId (the category itself
        // plus every descendant), from allCategories' parent_id links.
        subtreeCategoryIds(rootId) {
            const root = Number(rootId);
            const childrenOf = new Map();
            for (const c of this.allCategories) {
                const pid = Number(c.parent_id || 0);
                if (!childrenOf.has(pid)) childrenOf.set(pid, []);
                childrenOf.get(pid).push(Number(c.id));
            }
            const allowed = new Set([root]);
            const queue = [root];
            while (queue.length) {
                for (const kid of (childrenOf.get(queue.shift()) || [])) {
                    if (!allowed.has(kid)) { allowed.add(kid); queue.push(kid); }
                }
            }
            return allowed;
        },
        async init() {
            try {
                const [langRes, layoutRes, catRes, brandRes, pageRes] = await Promise.all([
                    axios.get(this.$apiUrl + '/active_languages'),
                    axios.get(this.$apiUrl + '/home_layouts/edit/' + this.layoutId),
                    axios.get(this.$apiUrl + '/categories', { params: { status: 1 } }),
                    axios.get(this.$apiUrl + '/products/brands/get').catch(() => ({ data: { data: [] } })),
                    axios.get(this.$apiUrl + '/page_layouts/options').catch(() => ({ data: { data: [] } })),
                ]);

                const layoutData = layoutRes.data?.data;
                // A zone-scoped layout offers only products listed in that zone's branch;
                // a global layout offers products listed in any branch.
                const prodParams = { per_page: 1000, page: 1, is_draft: 0, listed_only: 1 };
                if (layoutData && layoutData.zone_scope === 'zone' && layoutData.zone_id) {
                    prodParams.zone_id = layoutData.zone_id;
                }
                const prodRes = await axios.get(this.$apiUrl + '/products', { params: prodParams });

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
                    brand_id: p.brand ? p.brand.id : (p.brand_id ?? null),
                    sales_channel: (p.sales_channel || 'both').toString().toLowerCase(),
                    min_price: Number(p.min_price) || 0,
                    max_price: Number(p.max_price) || 0,
                    min_discounted: Number(p.min_discounted) || 0,
                }));
                this.allBrands = (brandRes.data?.data || []).map(b => ({
                    id: b.id, name: b.name, image_url: b.image_url || '',
                }));
                this.allPages = pageOptions(pageRes.data?.data || []);

                this.layout = layoutRes.data?.data;
                if (!this.layout) {
                    this.showError(__('home_layout_not_found'));
                    this.$router.replace('/home_builder');
                    return;
                }
                this.name = this.layout.name;
                this.status = this.layout.status;
                this.scheduledPublishAt = this.layout.scheduled_publish_at || null;
                this.buildEditingState();
                // Editor state loaded — snapshot the clean baseline for the unsaved-changes guard.
                this.captureFormBaseline();
            } catch (e) {
                this.showError(__('something_went_wrong'));
            } finally {
                this.loading = false;
            }
        },
        buildEditingState() {
            // Single-channel layout — preview header reads background_<channel>.
            this.previewMode = this.layout.mode || 'quick';
            this.activeChannel = this.layout.mode || 'quick';
            if (this.homeType !== 'single') {
                this.activeTabKey = this.tabKeys[0] || '';
            }
            // Default to editing the published snapshot when one exists.
            this.previewSource = this.hasPublished ? 'published' : 'draft';
            this.loadSource(this.previewSource);
            // Open the header settings in the config panel by default.
            this.selectHeader();
        },
        // Load a source (draft | published) into the editable working buffer.
        loadSource(source) {
            const clone = (v) => (v ? JSON.parse(JSON.stringify(v)) : null);
            if (this.homeType === 'single') {
                const j = source === 'published' ? this.layout.published_json : this.layout.draft_json;
                this.draftConfig = normalizeConfig(clone(j) || emptyConfig());
                return;
            }
            // category_wise — per-category maps. (Split mode is disabled, so flat map.)
            const map = source === 'published'
                ? this.layout.category_layouts_published
                : this.layout.category_layouts_draft;
            this.branch = this.coerceMap(clone(map) || {});
            // Normalize now, not on first visit: normalizeConfig() backfills ids
            this.normalizeBranch();
            this.buildCategoryTabs(source);   // ordered tabs (system + custom) for this source
            if (!this.activeTabKey || !this.tabKeys.includes(this.activeTabKey)) this.activeTabKey = this.tabKeys[0] || '';
            this.draftConfig = this.ensureTabConfig(this.activeTabKey);
        },
        setSource(source) {
            if (this.previewSource === source) return;
            this.previewSource = source;
            this.loadSource(source);
            // Switching source reloads the working buffer from that snapshot; re-baseline
            // so the toggle alone isn't read as an unsaved edit by the guard.
            this.captureFormBaseline();
        },
        openSetupWizard() {
            // Persist current draft state first so the user doesn't lose in-progress edits
            // when the wizard's save reloads init().
            this.saving = true;
            axios.post(this.$apiUrl + '/home_layouts/save', this.buildPayload())
                .then(() => axios.get(this.$apiUrl + '/home_layouts'))
                .then(res => {
                    const all = res.data?.data || [];
                    this.otherLayouts = all.filter(l => l.id !== this.layout.id);
                    this.setupWizard = true;
                })
                .catch(err => {
                    this.showError(err.response?.data?.message || __('something_went_wrong'));
                })
                .finally(() => { this.saving = false; });
        },
        onSetupComplete(payload) {
            this.saving = true;
            axios.post(this.$apiUrl + '/home_layouts/save', payload)
                .then(() => {
                    this.setupWizard = false;
                    this.showMessage('success', __('home_layout_saved_successfully'));
                    this.loading = true;
                    return this.init();
                })
                .catch(err => {
                    this.showError(err.response?.data?.message || __('something_went_wrong'));
                })
                .finally(() => { this.saving = false; });
        },
        bgRef(channel) {
            const cfg = this.activeConfig;
            const key = 'background_' + channel;
            if (!cfg[key]) {
                cfg[key] = { theme: 'color', color: '#FFE94B', image_url: { app: '', web: '', tablet: '' }, text_color: '#000000' };
            } else {
                if (cfg[key].text_color == null) cfg[key].text_color = '#000000';
                // Upgrade a legacy single-string image to the per-platform map.
                const im = cfg[key].image_url;
                if (!im || typeof im !== 'object' || Array.isArray(im)) {
                    const s = typeof im === 'string' ? im : '';
                    cfg[key].image_url = { app: s, web: s, tablet: s };
                }
            }
            return cfg[key];
        },
        coerceMap(val) {
            if (val == null) return {};
            if (Array.isArray(val)) {
                const obj = {};
                val.forEach((v, i) => { if (v != null) obj[String(i)] = v; });
                return obj;
            }
            return val;
        },
        currentMap() {
            if (this.isSplit) {
                if (!this.branch[this.activeChannel]) this.branch[this.activeChannel] = {};
                return this.branch[this.activeChannel];
            }
            return this.branch;
        },
        ensureTabConfig(key) {
            if (!key) return emptyConfig();
            const map = this.currentMap();
            map[key] = normalizeConfig(map[key] || emptyConfig());
            return map[key];
        },
        persistCurrent() {
            if (this.homeType === 'single' || !this.activeTabKey) return;
            this.currentMap()[this.activeTabKey] = this.draftConfig;
        },
        switchTab(key) {
            this.persistCurrent();
            this.activeTabKey = key;
            this.draftConfig = this.ensureTabConfig(key);
        },
        // Preview category rail / chip click → jump to that tab.
        onPreviewTabClick(id) {
            const key = String(id);
            if (this.tabKeys.includes(key)) this.switchTab(key);
        },
        tabLabel(key) {
            const tab = this.categoryTabs.find(t => t.key === key);
            if (tab && tab.kind === 'custom') return this.strVal(tab.name) || __('category');
            const cat = this.allCategories.find(c => String(c.id) === String(key));
            return cat ? cat.name : '#' + key;
        },
        strVal(v) {
            if (v == null) return '';
            if (typeof v === 'string') return v;
            return String(v[this.defaultLang] || Object.values(v).find(x => x && String(x).trim()) || '');
        },
        imgVal(v) {
            if (!v) return '';
            return typeof v === 'string' ? v : (v.app || v.web || v.tablet || '');
        },
        // Build the ordered tab list from the layout (source draft/published) or
        // backfill from the legacy category_ids.
        buildCategoryTabs(source) {
            const raw = source === 'published' ? this.layout.category_tabs_published : this.layout.category_tabs_draft;
            if (Array.isArray(raw) && raw.length) {
                // Tabs saved before the toggle existed have no flag — treat them as on.
                this.categoryTabs = JSON.parse(JSON.stringify(raw))
                    .map(t => ({ ...t, active: t.active !== false }));
                return;
            }
            const tabs = [];
            const orderIndex = new Map(this.allCategories.map((c, i) => [String(c.id), i]));
            const catIds = (this.layout.category_ids || []).map(String).slice()
                .sort((a, b) => (orderIndex.has(a) ? orderIndex.get(a) : 1e9) - (orderIndex.has(b) ? orderIndex.get(b) : 1e9));
            catIds.forEach(id => tabs.push({ key: id, kind: 'system', category_id: Number(id), active: true }));
            this.categoryTabs = tabs;
        },
        addCategory() {
            if (this.newCatKind === 'system') this.addSystemTab();
            else this.addCustomTab();
        },
        addSystemTab() {
            const id = Number(this.newSystemCatId);
            if (!id || this.categoryTabs.some(t => t.kind === 'system' && Number(t.category_id) === id)) {
                this.addCategoryOpen = false;
                return;
            }
            this.categoryTabs.push({ key: String(id), kind: 'system', category_id: id, active: true });
            this.newSystemCatId = '';
            this.addCategoryOpen = false;
            this.switchTab(String(id));
        },
        addCustomTab() {
            const name = { ...(this.newCustomName || {}) };
            if (!(name[this.defaultLang] || '').trim()) { this.showError(__('required')); return; }
            const key = 'custom-' + genId('cat');
            this.categoryTabs.push({ key, kind: 'custom', name, icon_url: this.newCustomIcon || '', active: true });
            this.newCustomName = {};
            this.newCustomIcon = '';
            this.addCategoryOpen = false;
            this.switchTab(key);
        },
        layoutHasDesign(l) {
            if (!l) return false;
            if (l.home_type === 'category_wise') {
                const maps = [l.category_layouts_draft, l.category_layouts_published];
                return maps.some(m => Object.values(m || {}).some(c => (c?.sections || []).length));
            }
            return [l.draft_json, l.published_json].some(c => (c?.sections || []).length);
        },
        openImport() {
            this.importOpen = true;
            this.importLayoutId = '';
            this.importTabKey = '';
            this.importSource = 'draft';
            this.importLoading = true;
            axios.get(this.$apiUrl + '/home_layouts')
                .then(res => { this.importLayouts = res.data?.data || []; })
                .catch(() => { this.importLayouts = []; })
                .finally(() => { this.importLoading = false; });
        },
        onImportLayoutChange() {
            this.importTabKey = '';
            // Default to whichever snapshot actually has content.
            this.importSource = this.importHasPublished && !this.importHasDraft() ? 'published' : 'draft';
        },
        importHasDraft() {
            const l = this.importLayout;
            if (!l) return false;
            return l.home_type === 'category_wise'
                ? Object.values(l.category_layouts_draft || {}).some(c => (c?.sections || []).length)
                : (l.draft_json?.sections || []).length > 0;
        },
        onImportSourceChange() {
            this.importTabKey = '';
        },
        /**
         * Copy the chosen design into the active tab. Section/block ids are stripped so
         * normalizeConfig() mints fresh ones — otherwise two tabs would share ids after
         * importing the same source twice.
         */
        applyImport() {
            if (!this.importLayout || !this.importReady) return;
            // Overwriting a tab's whole design is not undoable — make that explicit.
            this.$swal.fire({
                title: __('clone_category_confirm_title'),
                text: __('clone_category_confirm_text'),
                icon: 'warning', showCancelButton: true,
                confirmButtonText: __('yes_clone_it'), cancelButtonText: __('cancel'),
            }).then(r => { if (r.value) this.doImport(); });
        },
        doImport() {
            const l = this.importLayout;
            if (!l || !this.importReady) return;

            let src;
            if (l.home_type === 'category_wise') {
                const map = this.importSource === 'published'
                    ? (l.category_layouts_published || {})
                    : (l.category_layouts_draft || {});
                src = map[this.importTabKey];
            } else {
                src = this.importSource === 'published' ? l.published_json : l.draft_json;
            }
            if (!src) { this.showError(__('no_records_found')); return; }

            const copy = JSON.parse(JSON.stringify(src));
            (copy.sections || []).forEach(sec => {
                delete sec.id;
                (sec.blocks || []).forEach(b => delete b.id);
            });

            const cfg = normalizeConfig(copy);
            this.currentMap()[this.activeTabKey] = cfg;
            this.draftConfig = cfg;
            this.selectedSectionId = (cfg.sections[0] || {}).id || null;
            this.importOpen = false;
            this.showMessage('success', __('cloned_successfully'));
        },
        openReorder() {
            // Work on a copy — nothing changes until Apply.
            this.reorderTabs = JSON.parse(JSON.stringify(this.categoryTabs));
            this.reorderEditKey = '';
            this.reorderOpen = true;
        },
        // Label off the row itself: a custom tab being renamed here is not yet in
        // categoryTabs, so tabLabel(key) would show the old name.
        reorderLabel(t) {
            if (t.kind !== 'custom') return this.tabLabel(t.key);
            return this.strVal(t.name) || __('category');
        },
        toggleReorderEdit(key) {
            this.reorderEditKey = this.reorderEditKey === key ? '' : key;
            this.reorderLangTabIndex = 0;
        },
        removeReorderTab(key) {
            const i = this.reorderTabs.findIndex(t => t.key === key);
            if (i >= 0) this.reorderTabs.splice(i, 1);
        },
        applyReorder() {
            // A custom tab must keep a name in the default language.
            const unnamed = this.reorderTabs.find(
                t => t.kind === 'custom' && !String((t.name || {})[this.defaultLang] || '').trim()
            );
            if (unnamed) {
                this.reorderEditKey = unnamed.key;
                this.showError(__('required'));
                return;
            }
            // Commit order + any removals from the modal.
            const keptKeys = new Set(this.reorderTabs.map(t => t.key));
            (this.categoryTabs || []).forEach(t => {
                if (!keptKeys.has(t.key) && this.branch) delete this.branch[t.key];
            });
            this.categoryTabs = JSON.parse(JSON.stringify(this.reorderTabs));
            if (!this.tabKeys.includes(this.activeTabKey)) this.switchTab(this.tabKeys[0] || '');
            this.reorderEditKey = '';
            this.reorderOpen = false;
        },
        removeTab(key) {
            this.$swal.fire({
                title: __('are_you_sure'), text: __('you_want_be_able_to_revert_this'),
                icon: 'warning', showCancelButton: true,
                confirmButtonText: __('yes_sure'), cancelButtonText: __('cancel'),
            }).then(r => {
                if (!r.value) return;
                const i = this.categoryTabs.findIndex(t => t.key === key);
                if (i >= 0) this.categoryTabs.splice(i, 1);
                if (this.branch) delete this.branch[key];
                if (this.activeTabKey === key) this.switchTab(this.tabKeys[0] || '');
            });
        },
        iconFor(type) {
            const t = SECTION_TYPES.find(x => x.value === type);
            return t ? t.icon : 'LayoutGrid';
        },
        selectSection(id) {
            this.selectedSectionId = id;
            this.selectedIsHeader = false;
        },
        selectHeader() {
            this.selectedIsHeader = true;
            this.selectedSectionId = null;
        },
        removeSelected() {
            if (this.selectedSectionIndex >= 0) this.removeSection(this.selectedSectionIndex);
        },
        addSection(type) {
            const s = newSection(type);
            this.draftConfig.sections.push(s);
            this.selectSection(s.id);      // open the new one in the config panel
            this.addSectionOpen = false;
        },
        onTemplatePick(section) {
            this.draftConfig.sections.push(section);
            this.selectedSectionId = section.id;
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
                    .then(() => {
                        this.showMessage('success', __('template_saved'));
                    })
                    .catch(err => {
                        this.showError(err.response?.data?.message || __('something_went_wrong'));
                    });
            });
        },
        applyCopy() {
            if (!this.copySource) return;
            const map = this.currentMap();
            const src = map[this.copySource];
            if (!src) return;
            const cloned = JSON.parse(JSON.stringify(src));
            // Re-id sections + blocks so drag/keys stay unique after copy.
            const stamp = () => 'c_' + Math.random().toString(36).slice(2, 9);
            (cloned.sections || []).forEach(sec => {
                sec.id = stamp();
                (sec.blocks || []).forEach(b => { b.id = stamp(); });
            });
            this.draftConfig = cloned;
            map[this.activeTabKey] = cloned;
            this.copySource = '';
            this.showMessage('success', __('layout_copied'));
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
        // Copy sits right under its source, with fresh section/block ids so the two
        // never share a key, and opens in the config panel.
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
        // Editing the published surface saves to *_published; editing the draft
        // surface saves to *_draft — the two never cross-contaminate.
        buildPayload(source = this.previewSource) {
            this.persistCurrent();
            const l = this.layout;
            const pub = source === 'published';
            const payload = {
                id: this.layoutId,
                name: this.name.trim() || l.name,
                mode: l.mode,
                home_type: l.home_type,
                zone_scope: l.zone_scope,
                zone_id: l.zone_id || null,
                category_scope: l.category_scope,
                category_ids: l.category_ids || [],
                category_ids_quick: l.category_ids_quick || [],
                category_ids_ecommerce: l.category_ids_ecommerce || [],
                category_build_method: l.category_build_method || 'independent',
                is_active: l.is_active,
            };
            if (this.homeType === 'single') {
                payload[pub ? 'published_json' : 'draft_json'] = this.draftConfig;
            } else {
                payload[pub ? 'category_layouts_published' : 'category_layouts_draft'] = this.branch;
                // Ordered tabs (system + custom) + keep category_ids in sync (system tabs).
                payload[pub ? 'category_tabs_published' : 'category_tabs_draft'] = this.categoryTabs;
                payload.category_ids = this.categoryTabs
                    .filter(t => t.kind === 'system')
                    .map(t => Number(t.category_id));
            }
            return payload;
        },
        saveDraft() {
            this.persistCurrent();
            this.saving = true;
            axios.post(this.$apiUrl + '/home_layouts/save', this.buildPayload())
                .then(res => {
                    if (res.data?.data) {
                        this.status = res.data.data.status;
                        this.layout = { ...this.layout, ...res.data.data };
                    }
                    // Draft persisted — refresh the clean baseline so leaving won't warn.
                    this.captureFormBaseline();
                    this.showMessage('success', __('home_layout_saved_successfully'));
                })
                .catch(err => {
                    this.showError(err.response?.data?.message || __('something_went_wrong'));
                })
                .finally(() => { this.saving = false; });
        },
        publish() {
            this.persistCurrent();
            const live = this.previewSource === 'published';
            this.$swal.fire({
                title: live ? __('publish_changes') : __('publish_home_layout'),
                text: live ? __('publish_changes_confirm') : __('publish_home_layout_confirm'),
                icon: 'question',
                showCancelButton: true,
                confirmButtonText: live ? __('publish_changes') : __('publish'),
                cancelButtonText: __('cancel'),
            }).then(result => {
                if (!result.isConfirmed) return;
                this.publishing = true;
                const source = live ? 'published' : 'draft';
                axios.post(this.$apiUrl + '/home_layouts/save', this.buildPayload(source))
                    .then(() => {
                        const form = new FormData();
                        form.append('id', this.layoutId);
                        form.append('from', source);
                        return axios.post(this.$apiUrl + '/home_layouts/publish', form);
                    })
                    .then(res => {
                        if (res.data?.data) {
                            this.status = res.data.data.status;
                            // Refresh published snapshot so it stays current.
                            this.layout = { ...this.layout, ...res.data.data };
                        }
                        this.previewSource = 'published';
                        // Layout persisted + published — refresh the clean baseline.
                        this.captureFormBaseline();
                        this.showMessage('success', __('home_layout_published_successfully'));
                    })
                    .catch(err => {
                        this.showError(err.response?.data?.message || __('something_went_wrong'));
                    })
                    .finally(() => { this.publishing = false; });
            });
        },

        // ---- Scheduled publish ----
        pad(n) { return String(n).padStart(2, '0'); },
        // Stored UTC ISO -> local "YYYY-MM-DDTHH:mm" for the datetime-local input.
        utcToLocalInput(iso) {
            if (!iso) return '';
            const d = new Date(iso);
            if (isNaN(d.getTime())) return '';
            return `${d.getFullYear()}-${this.pad(d.getMonth() + 1)}-${this.pad(d.getDate())}T${this.pad(d.getHours())}:${this.pad(d.getMinutes())}`;
        },
        // Local "YYYY-MM-DDTHH:mm" -> UTC "YYYY-MM-DD HH:mm:ss" for storage.
        localInputToUtc(local) {
            if (!local) return '';
            const d = new Date(local);
            if (isNaN(d.getTime())) return '';
            return `${d.getUTCFullYear()}-${this.pad(d.getUTCMonth() + 1)}-${this.pad(d.getUTCDate())} ${this.pad(d.getUTCHours())}:${this.pad(d.getUTCMinutes())}:00`;
        },
        openSchedule() {
            this.scheduleInput = this.utcToLocalInput(this.scheduledPublishAt);
            this.showScheduleModal = true;
        },
        saveSchedule() {
            const utc = this.localInputToUtc(this.scheduleInput);
            if (!utc) { this.showError(__('invalid_schedule_time')); return; }
            this.scheduling = true;
            // Persist the latest draft first so the scheduled publish ships current content.
            axios.post(this.$apiUrl + '/home_layouts/save', this.buildPayload())
                .then(() => {
                    const form = new FormData();
                    form.append('id', this.layoutId);
                    form.append('scheduled_publish_at', utc);
                    return axios.post(this.$apiUrl + '/home_layouts/schedule', form);
                })
                .then(res => {
                    this.scheduledPublishAt = res.data?.data?.scheduled_publish_at || null;
                    this.showScheduleModal = false;
                    // Draft was persisted before scheduling — refresh the clean baseline.
                    this.captureFormBaseline();
                    this.showMessage('success', __('home_layout_scheduled_successfully'));
                })
                .catch(err => {
                    this.showError(err.response?.data?.message || __('something_went_wrong'));
                })
                .finally(() => { this.scheduling = false; });
        },
        cancelSchedule() {
            this.$swal.fire({
                title: __('cancel_schedule'),
                text: __('cancel_schedule_confirm'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: __('ok'),
                cancelButtonText: __('cancel'),
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (!result.value) return;
                this.scheduling = true;
                const form = new FormData();
                form.append('id', this.layoutId);
                form.append('scheduled_publish_at', '');
                axios.post(this.$apiUrl + '/home_layouts/schedule', form)
                    .then(() => {
                        this.scheduledPublishAt = null;
                        this.showMessage('success', __('home_layout_schedule_cancelled'));
                    })
                    .catch(err => {
                        this.showError(err.response?.data?.message || __('something_went_wrong'));
                    })
                    .finally(() => { this.scheduling = false; });
            });
        },
    },
};
</script>

<style scoped src="./editorShell.css"></style>
<style scoped>
.hb-tab-rail {
    display: flex;
    gap: .35rem;
    overflow-x: auto;
    padding-bottom: .25rem;
}
.hb-subhead .hb-tab-rail {
    margin-bottom: 0;
    padding-bottom: .5rem;
}
.hb-tab {
    flex: none;
    border: 1px solid var(--app-card-border);
    background: var(--app-card-bg);
    border-radius: 1rem;
    padding: .25rem .8rem;
    font-size: .8rem;
    color: var(--app-ink);
}
.hb-tab.active {
    background: var(--bs-primary);
    border-color: var(--bs-primary);
    color: #fff;
}
/* Header settings card (copy layout + header background + text color + icon). */
.hb-header-card {
    background: var(--app-card-bg);
    border: 1px solid var(--app-card-border, #e6eaf2);
    border-radius: 12px;
    padding: 1rem;
    margin-bottom: 1rem;
}
.hb-header-card .hb-tab-bg-bar {
    margin-bottom: 0 !important;
}
.hb-header-card .hb-copy-bar {
    padding-bottom: .75rem;
    margin-bottom: .75rem !important;
    border-bottom: 1px solid var(--app-card-border, #e6eaf2);
}
.hb-copy-bar {
    display: flex;
    align-items: center;
    gap: .5rem;
}
/* Header field: label + input, hint pushed to the bottom (below the field). */
.hb-fld { display: flex; flex-direction: column; }
.hb-fld > .hb-field-note { order: 9; margin-top: .35rem; }
/* Short "what is this field for" note under header fields. */
.hb-field-note {
    display: block;
    font-size: .72rem;
    color: var(--app-muted, var(--app-muted));
    margin-bottom: .4rem;
    line-height: 1.3;
}
.hb-copy-select {
    max-width: 220px;
}
.hb-add-section {
    display: flex;
    flex-wrap: wrap;
    gap: .35rem;
    align-items: center;
    margin-top: .5rem;
    padding: .65rem;
    border: 1px dashed #ced4da;
    border-radius: .6rem;
}
.hb-readonly {
    pointer-events: none;
    opacity: .7;
    user-select: none;
}
</style>
<style scoped>
/* ===== 3-column editor ===== */
.hb-header-toggle {
    display: flex; align-items: center; gap: 6px; width: 100%;
    border: none; background: transparent; font-weight: 600; font-size: .82rem;
    color: var(--bs-body-color); padding: .35rem .1rem;
}
.hb-header-body { padding-top: .4rem; }

/* Category tab rail (draggable system + custom tabs). */
.hb-tab-rail { display: flex; flex-wrap: wrap; align-items: center; gap: .35rem; margin-bottom: .5rem; }
.hb-tab-rail-inner { display: flex; flex-wrap: wrap; gap: .35rem; }
.hb-tab { display: inline-flex; align-items: center; gap: 2px; border: 1px solid var(--app-card-border); border-radius: 999px; padding: 1px 4px 1px 2px; background: var(--app-card-bg,#fff); }
.hb-tab.active { border-color: var(--bs-primary); background: rgba(var(--bs-primary-rgb), .08); }
.hb-tab-grip { cursor: grab; color: var(--app-muted); display: inline-flex; }
.hb-tab-btn { border: none; background: transparent; font-size: .72rem; padding: 2px 4px; color: var(--bs-body-color); white-space: nowrap; }
.hb-tab.active .hb-tab-btn { color: var(--bs-primary); font-weight: 600; }
.hb-tab-x { border: none; background: transparent; color: var(--app-muted); display: inline-flex; padding: 0 2px; }
.hb-tab-x:hover { color: var(--bs-danger); }
.hb-tab-add { border: 1px dashed var(--bs-primary); background: transparent; color: var(--bs-primary); border-radius: 999px; font-size: .72rem; padding: 2px 8px; display: inline-flex; align-items: center; gap: 3px; }

/* Full-width category bar — sticks right under the top bar. */
.hb-cat-bar { display: flex; align-items: center; gap: .75rem; flex-wrap: wrap;
    background: var(--app-card-bg); border: 1px solid var(--app-card-border);
    border-radius: .6rem; padding: .45rem .6rem; margin-bottom: .75rem;
    position: sticky; top: calc(var(--app-header-h, 64px) + 3.4rem); z-index: 9; }
.hb-cat-bar-pills { display: flex; flex-wrap: wrap; gap: .35rem; min-width: 0; }
.hb-cat-pill { border: 1px solid var(--app-card-border); background: var(--app-card-bg);
    color: var(--app-ink);
    border-radius: 999px; padding: 3px 12px; font-size: .78rem; white-space: nowrap;
    display: inline-flex; align-items: center; gap: 5px; }
.hb-cat-pill.inactive { opacity: .55; text-decoration: line-through; }
.hb-cat-pill.active { border-color: var(--bs-primary); background: rgba(var(--bs-primary-rgb), .1); color: var(--bs-primary); font-weight: 600; }
.hb-cat-pill-badge { font-size: .58rem; text-transform: uppercase; letter-spacing: .3px;
    background: rgba(var(--bs-primary-rgb), .15); color: var(--bs-primary); border-radius: 4px; padding: 0 4px; }
.hb-cat-bar-actions { display: flex; gap: .4rem; }
.hb-reorder-row { display: flex; align-items: center; gap: .6rem; padding: .5rem .25rem;
    border-bottom: 1px solid var(--app-card-border); }
.hb-reorder-grip { cursor: grab; color: var(--app-muted); display: inline-flex; }
/* Inline rename panel for a custom tab, expanded from the row's pencil. */
.hb-reorder-edit {
    border: 1px dashed var(--app-card-border);
    border-radius: .5rem;
    padding: .75rem;
    margin: .25rem 0 .5rem 1.6rem;
    background: var(--app-thead-bg);
}
</style>
