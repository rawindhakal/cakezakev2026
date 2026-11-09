<template>
    <div class="hb-preview-wrap">
        <!-- platform toggle -->
        <div class="hb-preview-toolbar">
            <div class="btn-group btn-group-sm">
                <button v-for="p in platforms" :key="p.value" type="button" class="btn"
                    :class="platform === p.value ? 'btn-primary' : 'btn-outline-secondary'"
                    @click="$emit('update:platform', p.value)">
                    <component :is="p.icon" :size="15" />
                </button>
            </div>
        </div>

        <!-- device frame -->
        <div class="hb-device" :class="'is-' + platform">
            <div class="hb-device-screen">
                <!-- Blinkit-style header: dynamic background from active category -->
                <div class="hb-app-header" :style="headerStyle">
                    <div class="hb-app-statusbar">
                        <span>{{ nowTime }}</span>
                        <span class="hb-app-status-right">
                            <Signal :size="11" />
                        </span>
                    </div>
                    <!-- Page Builder: a plain title bar instead of the home header. -->
                    <div v-if="variant === 'page'" class="hb-app-pagebar">
                        <ArrowLeft :size="13" />
                        <strong class="text-truncate">{{ pageTitle || __('page') }}</strong>
                    </div>
                    <div v-if="variant !== 'page'" class="hb-app-deliv-row">
                        <div>
                            <!-- Minutes are a quick-commerce promise; an ecommerce order
                                 ships over days, so its header shows the address alone. -->
                            <template v-if="mode !== 'ecommerce'">
                                <small class="hb-app-deliv-label">{{ __('delivery_in') }}</small>
                                <div class="hb-app-deliv-time">8 minutes</div>
                            </template>
                            <small class="hb-app-deliv-addr">HOME — {{ __('your_address') }} <ChevronDown :size="10" /></small>
                        </div>
                        <div class="hb-app-actions">
                            <span class="hb-app-action-chip"><User :size="12" /></span>
                        </div>
                    </div>

                    <div v-if="variant !== 'page'" class="hb-app-search">
                        <Search :size="12" />
                        <span>{{ __('search_toys') }}</span>
                        <Mic :size="12" class="ms-auto" />
                    </div>

                    <!-- clickable category rail (lives inside header so it shares bg color) -->
                    <div v-if="variant !== 'page' && categoryTabs && categoryTabs.length" class="hb-cat-rail" v-drag-scroll>
                        <button v-for="t in categoryTabs" :key="t.id" type="button" class="hb-cat-pill"
                            :class="{ active: String(t.id) === String(activeCategoryId) }"
                            @click="$emit('tab-click', t.id)">
                            <span class="hb-cat-pill-icon">
                                <img v-if="t.header_icon_url || t.image_url"
                                    :src="resolveImageUrl(t.header_icon_url || t.image_url)" alt="">
                                <span v-else>{{ (t.name || '?')[0] }}</span>
                            </span>
                            <small>{{ t.name }}</small>
                        </button>
                    </div>
                </div>

                <div v-if="!visibleSections.length" class="hb-preview-empty">
                    <Smartphone :size="12" />
                    <p>{{ __('add_sections_to_see_preview') }}</p>
                </div>

                <div v-for="section in visibleSections" :key="section.id" class="hb-prev-section"
                    :class="{ 'is-selected': section.id === selectedSectionId }"
                    :style="sectionStyle(section)" @click="$emit('edit-section', section.id)">
                    <button type="button" class="hb-prev-edit" @click.stop="$emit('edit-section', section.id)"
                        :title="__('edit')">
                        <Pencil :size="13" />
                    </button>
                    <template v-for="block in section.blocks" :key="block.id">

                        <!-- banner slider -->
                        <div v-if="block.type === 'banner_slider'" class="hb-prev-banner"
                            :class="'style-' + block.config.carousel_style">
                            <template v-if="block.items.length">
                                <!-- story uses top progress bars instead of dots -->
                                <div v-if="block.config.carousel_style === 'story' && block.items.length > 1" class="hb-prev-story-bars">
                                    <span v-for="i in block.items.length" :key="i"
                                        :class="{ on: (i - 1) === currentBannerIdx(block) }"></span>
                                </div>
                                <div class="hb-prev-banner-viewport">
                                    <div class="hb-prev-banner-track" :style="bannerTrackStyle(block)">
                                        <div v-for="(slide, pos) in bannerSlides(block)" :key="pos" class="hb-prev-banner-slide"
                                            :class="{ active: pos === currentBannerIdx(block) + bannerOffset(block) }"
                                            :style="bannerSlideStyle(block, section)">
                                            <img v-if="pickImage(slide.image)" :src="pickImage(slide.image)">
                                            <div v-else class="hb-ph"><ImageIcon :size="22" /></div>
                                        </div>
                                    </div>
                                </div>
                            </template>
                            <div v-else class="hb-ph hb-ph-banner"><Images :size="26" /></div>
                            <div v-if="block.config.indicator === 'dots' && block.items.length > 1 && block.config.carousel_style !== 'story'"
                                class="hb-prev-dots">
                                <span v-for="i in Math.min(block.items.length, 5)" :key="i"
                                    :class="{ on: (i - 1) === currentBannerIdx(block) }"></span>
                            </div>
                        </div>

                        <!-- grid banner -->
                        <div v-else-if="block.type === 'grid_banner'" class="hb-prev-gridbanner-wrap"
                            :style="productWrapStyle(block)">
                            <div v-if="block.config.variant !== 'default' && titleText(block)"
                                class="hb-prev-sec-title"
                                :style="block.config.text_color ? { color: block.config.text_color } : {}">{{ titleText(block) }}</div>
                            <div class="hb-prev-grid"
                                :class="{ 'is-scroll': block.config.grid_layout_type === 'scroll' }"
                                :style="gridBannerStyle(block)">
                                <div v-for="(item, i) in (block.items.length ? block.items : placeholders(gridPlaceholderCount(block)))"
                                    :key="i" class="hb-prev-tile"
                                    :style="tileStyle(block)">
                                    <img v-if="item.image && pickImage(item.image)" :src="pickImage(item.image)">
                                    <div v-else class="hb-ph"><ImageIcon :size="22" /></div>
                                </div>
                            </div>
                        </div>

                        <!-- category section -->
                        <div v-else-if="['category_section', 'occasion_section', 'relationship_section'].includes(block.type)" :style="productWrapStyle(block)">
                            <div v-if="block.config.variant !== 'default' && titleText(block)" class="hb-prev-sec-title"
                                :style="block.config.text_color ? { color: block.config.text_color } : {}">{{ titleText(block) }}</div>
                            <div class="hb-prev-cats"
                                :class="'cat-' + block.layout" :style="catContainerStyle(block)"
                                v-drag-scroll>
                                <div v-for="c in blockCategories(block)" :key="c.id" class="hb-prev-cat"
                                    :class="{ clickable: isTab(c.id) }"
                                    @click="onCategoryClick(c.id)">
                                    <div class="hb-prev-cat-img" :class="{ circle: block.layout === 'circular' }"
                                        :style="catItemStyle(block)">
                                        <img v-if="c.image_url" :src="c.image_url">
                                        <span v-else>{{ (c.name || '?')[0] }}</span>
                                    </div>
                                    <small :style="block.config.item_text_color ? { color: block.config.item_text_color } : {}">{{ c.name }}</small>
                                </div>
                                <p v-if="!blockCategories(block).length" class="hb-prev-hint">
                                    {{ __('select_categories') }}
                                </p>
                            </div>
                        </div>

                        <!-- product slider -->
                        <div v-else-if="block.type === 'product_slider'" class="hb-prev-products-wrap"
                            :style="productWrapStyle(block)">
                            <div v-if="block.config.variant !== 'default' && titleText(block)"
                                class="hb-prev-sec-title"
                                :style="block.config.text_color ? { color: block.config.text_color } : {}">{{ titleText(block) }}</div>
                            <div class="hb-prev-products"
                                :class="['lay-' + block.layout, { 'lay-list-web': isWebList(block) }]"
                                :style="productGridStyle(block)" v-drag-scroll>
                                <div v-for="(p, i) in blockProducts(block)" :key="i" class="hb-prev-product"
                                    :style="{ borderRadius: (block.config.product_card_radius || 0) + 'px' }">
                                    <div class="hb-prev-product-img">
                                        <img v-if="p.image_url" :src="p.image_url">
                                        <div v-else class="hb-ph"><Package :size="20" /></div>
                                    </div>
                                    <div class="hb-prev-product-name">{{ p.name || __('product') }}</div>
                                    <div v-if="productPriceText(p)" class="hb-prev-product-price">
                                        <span class="hb-pp-final">{{ productPriceText(p) }}</span>
                                        <span v-if="productMrpText(p)" class="hb-pp-mrp">{{ productMrpText(p) }}</span>
                                    </div>
                                </div>
                            </div>
                            <span v-if="isApproxSource(block)" class="hb-approx">
                                {{ __('approx_in_preview') }}
                            </span>
                        </div>

                        <!-- product tabs: a tab strip, then the active tab's products drawn
                             exactly like a product slider -->
                        <div v-else-if="block.type === 'product_tabs'" class="hb-prev-products-wrap"
                            :style="productWrapStyle(block)">
                            <div v-if="block.config.variant !== 'default' && titleText(block)"
                                class="hb-prev-sec-title"
                                :style="block.config.text_color ? { color: block.config.text_color } : {}">{{ titleText(block) }}</div>

                            <div class="hb-prev-tabs"
                                :class="['tabs-' + (block.config.tab_style || 'icon_top'), 'ind-' + (block.config.active_indicator || 'underline')]"
                                :style="sideInset()" v-drag-scroll>
                                <!-- The active marker is one element that slides to the chosen tab;
                                     an outlined tab also draws the baseline it rises from. -->
                                <template v-if="tabInd[block.id] && (block.config.active_indicator || 'underline') !== 'none'">
                                    <div class="hb-prev-tab-ind" :style="tabIndStyle(block)">
                                        <!-- Raised tab: one smooth path — rounded top, sides sweeping
                                             out into the baseline — optionally filled. -->
                                        <svg v-if="block.config.active_indicator === 'outline'" class="hb-prev-tab-svg"
                                            :width="tabInd[block.id].width + 2 * tabFoot" :height="tabInd[block.id].height"
                                            :viewBox="`0 0 ${tabInd[block.id].width + 2 * tabFoot} ${tabInd[block.id].height}`">
                                            <defs>
                                                <linearGradient :id="'hb-tg-' + block.id" x1="0" y1="0" x2="0" y2="1">
                                                    <stop offset="0" :stop-color="block.config.active_tab_color || '#212529'" />
                                                    <stop offset="1" :stop-color="block.config.active_tab_color_2 || block.config.active_tab_color || '#212529'"
                                                        :stop-opacity="block.config.active_tab_color_2 ? 1 : 0" />
                                                </linearGradient>
                                                <clipPath :id="'hb-tc-' + block.id"><path :d="raisedTabPath(block)" /></clipPath>
                                            </defs>
                                            <image v-if="block.config.active_bg_style === 'image' && pickImage(block.config.active_bg_image)"
                                                :href="pickImage(block.config.active_bg_image)" x="0" y="0" width="100%" height="100%"
                                                preserveAspectRatio="xMidYMid slice" :clip-path="`url(#hb-tc-${block.id})`" />
                                            <path :d="raisedTabPath(block)" :fill="raisedTabFill(block)"
                                                :stroke="outlineColor(block.config)" stroke-width="1.5" />
                                        </svg>
                                    </div>
                                    <template v-if="block.config.active_indicator === 'outline'">
                                        <div class="hb-prev-tab-base" :style="tabBaseStyle(block, 'left')"></div>
                                        <div class="hb-prev-tab-base" :style="tabBaseStyle(block, 'right')"></div>
                                    </template>
                                </template>
                                <div v-for="(tab, ti) in block.items" :key="tab.id || ti" class="hb-prev-tab"
                                    :class="{ active: activeTabIndex(block) === ti }"
                                    :style="tabStyle(block, ti)"
                                    :ref="el => setTabEl(block.id, ti, el)"
                                    @click="tabIdx[block.id] = ti">
                                    <div v-if="(block.config.tab_style || 'icon_top') === 'icon_top'" class="hb-prev-tab-icon"
                                        :style="{ aspectRatio: aspectCss(block.config.tab_image_aspect) }">
                                        <img v-if="pickImage(tab.image)" :src="pickImage(tab.image)">
                                        <div v-else class="hb-ph"><Package :size="14" /></div>
                                    </div>
                                    <span class="hb-prev-tab-label">{{ tabTitle(tab) || (__('tab') + ' ' + (ti + 1)) }}</span>
                                </div>
                            </div>
                            <p v-if="!block.items.length" class="hb-prev-hint">{{ __('no_tabs_added') }}</p>

                            <template v-if="block.items.length">
                                <!-- Keyed on the active tab so the switch animates (fade / slide). -->
                                <transition :name="'hb-tab-' + (block.config.tab_animation || 'none')" mode="out-in">
                                <div class="hb-prev-products" :key="activeTabIndex(block)"
                                    :class="['lay-' + block.layout, { 'lay-list-web': isWebList(block) }]"
                                    :style="productGridStyle(block)" v-drag-scroll>
                                    <div v-for="(p, i) in tabProducts(block)" :key="i" class="hb-prev-product"
                                        :style="{ borderRadius: (block.config.product_card_radius || 0) + 'px' }">
                                        <div class="hb-prev-product-img">
                                            <img v-if="p.image_url" :src="p.image_url">
                                            <div v-else class="hb-ph"><Package :size="20" /></div>
                                        </div>
                                        <div class="hb-prev-product-name">{{ p.name || __('product') }}</div>
                                        <div v-if="productPriceText(p)" class="hb-prev-product-price">
                                            <span class="hb-pp-final">{{ productPriceText(p) }}</span>
                                            <span v-if="productMrpText(p)" class="hb-pp-mrp">{{ productMrpText(p) }}</span>
                                        </div>
                                    </div>
                                </div>
                                </transition>
                                <span v-if="isApproxSource({ config: selectedProductTab(block).config })" class="hb-approx">
                                    {{ __('approx_in_preview') }}
                                </span>
                            </template>
                        </div>

                        <!-- title image -->
                        <div v-else-if="block.type === 'title_image'" class="hb-prev-title-img">
                            <img v-if="pickImage(block.image)" :src="pickImage(block.image)" :style="titleImgStyle(block)">
                            <div v-else class="hb-ph hb-ph-banner" :style="titleImgStyle(block)"><ImageIcon :size="26" /></div>
                        </div>

                        <!-- brand section -->
                        <div v-else-if="block.type === 'brand_section'" class="hb-prev-brands"
                            :class="'cat-' + block.layout" :style="productWrapStyle(block)">
                            <div v-if="block.config.variant !== 'default' && titleText(block)" class="hb-prev-sec-title"
                                :style="block.config.text_color ? { color: block.config.text_color } : {}">{{ titleText(block) }}</div>
                            <div class="hb-prev-brands-list" :class="'cat-' + block.layout"
                                :style="brandListStyle(block)" v-drag-scroll>
                                <div v-for="b in blockBrands(block)" :key="b.id" class="hb-prev-brand">
                                    <div class="hb-prev-brand-img" :class="{ circle: block.layout === 'circular' }"
                                        :style="brandItemStyle(block)">
                                        <img v-if="b.image_url" :src="b.image_url">
                                        <span v-else>{{ (b.name || '?')[0] }}</span>
                                    </div>
                                    <small v-if="block.config.show_name"
                                        :style="block.config.item_text_color ? { color: block.config.item_text_color } : {}">{{ b.name }}</small>
                                </div>
                            </div>
                            <p v-if="!blockBrands(block).length" class="hb-prev-hint">
                                {{ __('select_brands') }}
                            </p>
                        </div>

                        <!-- text section -->
                        <div v-else-if="block.type === 'text_section'" class="hb-prev-text"
                            :style="textSectionStyle(block)">
                            <div class="hb-prev-text-heading" v-if="titleText(block)">{{ titleText(block) }}</div>
                            <div class="hb-prev-text-sub" v-if="subtitleText(block)">{{ subtitleText(block) }}</div>
                            <p v-if="!titleText(block) && !subtitleText(block)" class="hb-prev-hint mb-0">
                                {{ __('enter_heading') }}
                            </p>
                        </div>

                    </template>
                </div>
            </div>
        </div>

        <!-- Approximation disclaimer. -->
        <div class="hb-preview-note">
            <Info :size="14" /> {{ __('preview_is_approximate_actual_may_vary') }}
        </div>
    </div>
</template>

<script>
import { pickText, IMAGE_ASPECT_DEFAULTS, resolveImageUrl } from '../../homeBuilderHelpers.js';
import { loadGiftingOptions } from '../../giftingOptions.js';
import {
    Signal, ChevronDown, User, Search, Mic, Smartphone, Tablet, Monitor,
    Image as ImageIcon, Images, Package, Info, Pencil, ArrowLeft,
} from 'lucide-vue-next';

export default {
    name: 'LivePreview',
    components: {
        Signal, ChevronDown, User, Search, Mic, Smartphone, Tablet, Monitor,
        ImageIcon, Images, Package, Info, Pencil, ArrowLeft,
    },
    directives: {
        // Click-and-drag horizontal scrolling (scrollbars are hidden). A drag past a
        // few px also cancels the click so chip taps don't fire while scrolling.
        dragScroll: {
            mounted(el) {
                let down = false, moved = false, startX = 0, startScroll = 0;
                el.style.cursor = 'grab';
                const onDown = (e) => {
                    down = true; moved = false; startX = e.pageX; startScroll = el.scrollLeft;
                    el.style.cursor = 'grabbing';
                    // The drag is the scroll; the browser must not also start selecting
                    // text or lifting an image out of the frame.
                    e.preventDefault();
                };
                // Native image drag would otherwise win over the scroll on the first move.
                const onDragStart = (e) => e.preventDefault();
                const onMove = (e) => {
                    if (!down) return;
                    const dx = e.pageX - startX;
                    if (Math.abs(dx) > 3) moved = true;
                    el.scrollLeft = startScroll - dx;
                };
                const onUp = () => { down = false; el.style.cursor = 'grab'; };
                const onClick = (e) => { if (moved) { e.preventDefault(); e.stopPropagation(); moved = false; } };
                el.addEventListener('mousedown', onDown);
                el.addEventListener('dragstart', onDragStart);
                el.addEventListener('click', onClick, true);
                window.addEventListener('mousemove', onMove);
                window.addEventListener('mouseup', onUp);
                el._ds = { onMove, onUp };
            },
            unmounted(el) {
                if (el._ds) {
                    window.removeEventListener('mousemove', el._ds.onMove);
                    window.removeEventListener('mouseup', el._ds.onUp);
                }
            },
        },
    },
    props: {
        config: { type: Object, default: () => ({ sections: [] }) },
        languages: { type: Array, default: () => [] },
        activeLang: { type: [Number, String], default: null },
        defaultLang: { type: [Number, String], default: null },
        allProducts: { type: Array, default: () => [] },
        allCategories: { type: Array, default: () => [] },
        allBrands: { type: Array, default: () => [] },
        platform: { type: String, default: 'app' },
        categoryTabs: { type: Array, default: () => [] },
        activeCategoryId: { type: [Number, String], default: null },
        selectedSectionId: { type: [Number, String], default: null },
        mode: { type: String, default: 'quick' },
        previewMode: { type: String, default: 'quick' },
        homeType: { type: String, default: 'single' },
        // 'home' renders the delivery/search header; 'page' a plain title bar.
        variant: { type: String, default: 'home' },
        pageTitle: { type: String, default: '' },
        headerColor: { type: String, default: '' },
        titleColor: { type: String, default: '' },
    },
    emits: ['update:platform', 'tab-click', 'edit-section'],
    created() {
        loadGiftingOptions().then((g) => { this.gifting = g; });
        // Plain property on purpose — reactive state here would re-render on write.
        this._shuffleCache = {};
    },
    data() {
        return {
            gifting: { occasions: [], relationships: [] },
            platforms: [
                { value: 'app', icon: 'Smartphone' },
                { value: 'tablet', icon: 'Tablet' },
                { value: 'web', icon: 'Monitor' },
            ],
            bannerIdx: {},          // block.id -> current index
            tabIdx: {},             // product_tabs block.id -> selected tab index
            // product_tabs block.id -> measured box of the active tab (drives the sliding marker).
            tabInd: {},
            tabFoot: 8,             // how far a raised tab's sides sweep out into the baseline
            bannerTimers: {},       // block.id -> interval handle
        };
    },
    computed: {
        visibleSections() {
            return (this.config.sections || []).filter(
                s => s.active !== false && (!s.platforms || s.platforms[this.platform] !== false)
            );
        },
        activeTab() {
            return (this.categoryTabs || []).find(t => String(t.id) === String(this.activeCategoryId)) || null;
        },
        headerStyle() {
            const c = this.config || {};
            if (this.variant === 'page') {
                return {
                    background: this.headerColor || '#fff',
                    color: this.titleColor || '#111',
                };
            }
            if (this.homeType === 'single') {
                const ch = c['background_' + (this.previewMode || 'quick')] || {};
                const base = ch.text_color ? { color: ch.text_color } : {};
                const chBg = this.pickImage(ch.image_url);
                if (ch.theme === 'image' && chBg) {
                    return {
                        ...base,
                        backgroundImage: `url(${chBg})`,
                        backgroundSize: 'cover',
                        backgroundPosition: 'center',
                    };
                }
                return { ...base, background: this.colorToGradient(ch.color || '#FFE94B') };
            }
            // category_wise tab bg (per-platform image map)
            const base = c.text_color ? { color: c.text_color } : {};
            const catBg = this.pickImage(c.background_image_url);
            if (c.background_theme === 'image' && catBg) {
                return {
                    ...base,
                    backgroundImage: `url(${catBg})`,
                    backgroundSize: 'cover',
                    backgroundPosition: 'center',
                };
            }
            return { ...base, background: this.colorToGradient(c.background_color || '#FFE94B') };
        },
        nowTime() {
            const d = new Date();
            const h = d.getHours();
            const m = String(d.getMinutes()).padStart(2, '0');
            return `${h}:${m}`;
        },
    },
    watch: {
        config: {
            deep: true,
            handler() {
                this.syncBannerTimers();
            },
        },
    },
    mounted() {
        this.syncBannerTimers();
        this.measureTabIndicators();
        this._onResize = () => this.measureTabIndicators();
        window.addEventListener('resize', this._onResize);
    },
    updated() {
        // Tab boxes move whenever the strip re-renders (new tab, label edit, platform switch).
        this.measureTabIndicators();
    },
    beforeUnmount() {
        Object.values(this.bannerTimers).forEach(t => clearInterval(t));
        this.bannerTimers = {};
        window.removeEventListener('resize', this._onResize);
    },
    methods: {
        resolveImageUrl,
        currentBannerIdx(block) {
            return this.bannerIdx[block.id] || 0;
        },
        // Slide geometry per carousel style: w = slide width %, gap px,
        // center = active slide centered (neighbors peek both sides).
        bannerGeo(style) {
            switch (style) {
                case 'peek':      return { w: 80, gap: 8, center: false };
                case 'card':      return { w: 84, gap: 10, center: true };
                case 'spotlight': return { w: 70, gap: 10, center: true };
                case 'story':     return { w: 100, gap: 0, center: false };
                default:          return { w: 100, gap: 0, center: false }; // full_width
            }
        },
        // Slides as rendered: the real items, plus a wrap-around clone at each end
        // for a centred loop (otherwise the first/last slide has a blank neighbour).
        bannerSlides(block) {
            const items = block.items || [];
            if (!this.bannerOffset(block)) {
                return items;
            }
            return [items[items.length - 1], ...items, items[0]];
        },
        /** 1 when wrap-around clones are rendered, else 0. */
        bannerOffset(block) {
            const items = block.items || [];
            return this.bannerGeo(block.config.carousel_style).center
                && block.config.infinite_loop !== false
                && items.length > 1 ? 1 : 0;
        },
        bannerTrackStyle(block) {
            const g = this.bannerGeo(block.config.carousel_style);
            const idx = this.currentBannerIdx(block) + this.bannerOffset(block);
            const step = `(${g.w}% + ${g.gap}px)`;
            const x = g.center
                ? `calc((100% - ${g.w}%) / 2 - ${idx} * ${step})`
                : `calc(-1 * ${idx} * ${step})`;
            return { transform: `translateX(${x})` };
        },
        bannerSlideStyle(block, section) {
            const g = this.bannerGeo(block.config.carousel_style);
            const style = {
                flex: `0 0 ${g.w}%`,
                maxWidth: `${g.w}%`,
                marginRight: g.gap + 'px',
                aspectRatio: this.blockAspect(block),
            };
            // The section's border radius rounds the banner image itself.
            if (section) {
                style.borderRadius = this.cornerRadiusCss(section);
            }
            return style;
        },
        syncBannerTimers() {
            // Collect every banner_slider block across all sections.
            const active = {};
            (this.config.sections || []).forEach(sec => {
                (sec.blocks || []).forEach(b => {
                    if (b.type !== 'banner_slider') return;
                    active[b.id] = b;
                });
            });
            // Stop timers whose block disappeared or no longer needs rotation.
            Object.keys(this.bannerTimers).forEach(id => {
                const b = active[id];
                const wantAuto = b && b.config && b.config.auto_scroll && (b.items || []).length > 1;
                if (!wantAuto) {
                    clearInterval(this.bannerTimers[id]);
                    delete this.bannerTimers[id];
                }
            });
            // Start timers for new auto-scrolling banners.
            Object.keys(active).forEach(id => {
                const b = active[id];
                const wantAuto = b.config && b.config.auto_scroll && (b.items || []).length > 1;
                if (!wantAuto) return;
                if (this.bannerTimers[id]) return; // already running
                const interval = Math.max(300, Number(b.config.speed_ms) || 3000);
                if (this.bannerIdx[id] == null) this.bannerIdx[id] = 0;
                this.bannerTimers[id] = setInterval(() => {
                    const blk = (this.config.sections || []).flatMap(s => s.blocks || [])
                        .find(x => x.id === id);
                    if (!blk) return;
                    const count = (blk.items || []).length;
                    if (!count) return;
                    const next = ((this.bannerIdx[id] || 0) + 1) % count;
                    if (!blk.config.infinite_loop && next === 0) {
                        // stop at end when no infinite loop
                        clearInterval(this.bannerTimers[id]);
                        delete this.bannerTimers[id];
                        return;
                    }
                    this.bannerIdx[id] = next;
                }, interval);
            });
        },
        blockBrands(block) {
            const ids = block.config.brand_ids || [];
            return ids.map(id => this.allBrands.find(b => b.id === id)).filter(Boolean);
        },
        subtitleText(block) {
            return pickText(block.config.section_subtitle, this.activeLang, this.defaultLang);
        },
        textSectionStyle(block) {
            const cfg = block.config;
            return {
                textAlign: cfg.text_align || 'left',
                color: cfg.text_color || '',
                background: cfg.background_color || '',
                padding: '12px 14px',
            };
        },
        isTab(id) {
            return this.categoryTabs.some(t => String(t.id) === String(id));
        },
        onCategoryClick(id) {
            // A category chip jumps to that category's tab when one exists.
            if (this.isTab(id)) this.$emit('tab-click', id);
        },
        pickImage(img) {
            if (!img) return '';
            if (typeof img === 'string') return resolveImageUrl(img);
            return resolveImageUrl(img[this.platform] || img.app || img.web || img.tablet || '');
        },
        sectionStyle(section) {
            const style = {
                marginTop: (section.margin_top || 0) + 'px',
                marginBottom: (section.margin_bottom || 0) + 'px',
            };
            // A banner slider rounds its slides, not the section box — rounding the box
            // would clip the peeking neighbours of a centred carousel.
            if (section.type === 'banner_slider') {
                return style;
            }
            // Corners in CSS order (TL TR BR BL).
            const c = this.corners(section.border_radius);
            const rounded = c.top_left || c.top_right || c.bottom_left || c.bottom_right;
            style.borderRadius = `${c.top_left}px ${c.top_right}px ${c.bottom_right}px ${c.bottom_left}px`;
            style.overflow = rounded ? 'hidden' : 'visible';
            return style;
        },
        /** Corner radii of a section, as a CSS value (TL TR BR BL). */
        cornerRadiusCss(section) {
            const c = this.corners(section && section.border_radius);
            return `${c.top_left}px ${c.top_right}px ${c.bottom_right}px ${c.bottom_left}px`;
        },
        /** Four corners, from either a plain number or a corner map. */
        corners(value) {
            if (value == null || value === '') value = 0;
            if (typeof value === 'number' || typeof value === 'string') {
                const n = Number(value) || 0;
                return { top_left: n, top_right: n, bottom_left: n, bottom_right: n };
            }
            return {
                top_left: Number(value.top_left) || 0,
                top_right: Number(value.top_right) || 0,
                bottom_left: Number(value.bottom_left) || 0,
                bottom_right: Number(value.bottom_right) || 0,
            };
        },
        // Convert a per-platform "w:h" map to a CSS aspect-ratio value.
        aspectCss(map) {
            const raw = (map && map[this.platform]) || IMAGE_ASPECT_DEFAULTS[this.platform] || '16:9';
            const parts = String(raw).split(':');
            const w = Number(parts[0]);
            const h = Number(parts[1]);
            return (w > 0 && h > 0) ? `${w} / ${h}` : '16 / 9';
        },
        // Banner/tile image ratio (banner_slider / grid_banner tiles / title_image).
        blockAspect(block) {
            return this.aspectCss(block.config && block.config.image_aspect);
        },
        // Ratio for the with_background image (separate from the banner ratio).
        bgAspect(block) {
            return this.aspectCss(block.config && block.config.bg_image_aspect);
        },
        tileStyle(block) {
            return {
                borderRadius: (block.config.tile_radius ?? 6) + 'px',
                aspectRatio: this.blockAspect(block),
            };
        },
        titleImgStyle(block) {
            return { aspectRatio: this.blockAspect(block), objectFit: 'cover', width: '100%' };
        },
        pillIconStyle(t) {
            const url = resolveImageUrl(t.header_icon_url || t.image_url);
            return url ? { backgroundImage: `url(${url})` } : {};
        },
        placeholders(n) {
            return Array.from({ length: n }, () => ({}));
        },
        titleText(block) {
            return pickText(block.config.section_title, this.activeLang, this.defaultLang);
        },
        isApproxSource(block) {
            return ['top_selling', 'trending', 'most_favorited', 'recently_visited', 'buy_again'].includes(block.config.data_source);
        },
        /* ---- product_tabs ------------------------------------------------ */
        activeTabIndex(block) {
            const n = (block.items || []).length;
            const i = this.tabIdx[block.id] ?? 0;
            return n ? Math.min(i, n - 1) : 0;
        },
        // Not `activeTab` — that computed is the category rail's selected tab.
        selectedProductTab(block) {
            return (block.items || [])[this.activeTabIndex(block)] || { config: {} };
        },
        tabTitle(tab) {
            return pickText(tab.title, this.activeLang, this.defaultLang);
        },
        // The active tab's products, through the same lookup a slider uses. The
        // tab's own config wins; the block's limit is the fallback.
        tabProducts(block) {
            const tab = this.selectedProductTab(block);
            const cfg = { ...tab.config, limit: tab.config.limit || block.config.limit || 8 };
            // Each tab keeps its own shuffled order, so flipping between tabs and back
            // shows the same arrangement rather than a fresh one each time.
            return this.blockProducts({ ...block, id: block.id + ':' + (tab.id || this.activeTabIndex(block)), config: cfg });
        },
        // Function refs from the v-for: plain property, never reactive.
        setTabEl(blockId, i, el) {
            if (!this._tabEls) this._tabEls = {};
            if (!this._tabEls[blockId]) this._tabEls[blockId] = [];
            this._tabEls[blockId][i] = el;
        },
        // Box of each block's active tab inside its strip. Written only when it
        // changed, so the updated() hook that calls this never loops.
        measureTabIndicators() {
            const els = this._tabEls || {};
            for (const blockId of Object.keys(els)) {
                const list = els[blockId].filter(Boolean);
                const i = Math.min(this.tabIdx[blockId] ?? 0, Math.max(list.length - 1, 0));
                const el = list[i];
                const strip = el && el.parentElement;
                if (!el || !strip || !el.isConnected) {
                    if (this.tabInd[blockId]) delete this.tabInd[blockId];
                    continue;
                }
                const next = {
                    left: el.offsetLeft, top: el.offsetTop, width: el.offsetWidth, height: el.offsetHeight,
                    total: strip.scrollWidth,
                };
                const cur = this.tabInd[blockId];
                if (!cur || ['left', 'top', 'width', 'height', 'total'].some(k => cur[k] !== next[k])) {
                    this.tabInd[blockId] = next;
                }
            }
        },
        // The active tab's paint: solid colour, two-colour gradient, or an image.
        activeTabBg(cfg) {
            if (cfg.active_bg_style === 'none') return {};
            const c1 = cfg.active_tab_color || '#212529';
            if (cfg.active_bg_style === 'image') {
                const img = this.pickImage(cfg.active_bg_image);
                if (img) return { backgroundImage: `url(${img})`, backgroundSize: 'cover', backgroundPosition: 'center' };
            }
            if (cfg.active_bg_style === 'gradient') {
                // Top edge is the active colour; it runs down into the end colour
                // (fading out when none is set).
                return { background: `linear-gradient(180deg, ${c1}, ${cfg.active_tab_color_2 || 'transparent'})` };
            }
            return { background: c1 };
        },
        // Where the sliding marker sits and what it looks like for this indicator.
        tabIndStyle(block) {
            const cfg = block.config;
            const pos = this.tabInd[block.id];
            const ind = cfg.active_indicator || 'underline';
            const color = cfg.active_tab_color || '#212529';
            const px = v => v + 'px';
            if (ind === 'underline') {
                return { left: px(pos.left), top: px(pos.top + pos.height - 2), width: px(pos.width), height: '2px', background: color };
            }
            const box = { left: px(pos.left), top: px(pos.top), width: px(pos.width), height: px(pos.height) };
            if (ind === 'fill') {
                return { ...box, ...this.activeTabBg(cfg), borderRadius: (cfg.tab_style || 'icon_top') === 'text' ? '999px' : '12px' };
            }
            // outline: the SVG path draws the raised tab; the box only places it.
            return { ...box, left: px(pos.left - this.tabFoot), width: px(pos.width + 2 * this.tabFoot) };
        },
        // Raised tab outline: baseline in from the left, sweep up the side, round
        // the top corners, sweep back down into the baseline on the right.
        raisedTabPath(block) {
            const pos = this.tabInd[block.id];
            const f = this.tabFoot;
            const W = pos.width + 2 * f;
            const H = pos.height;
            const i = 0.75;                      // half the stroke, keeps it inside the box
            const r = Math.max(4, Math.min(14, pos.width / 2, (H - f) / 2));
            const y0 = H - i, x1 = f, x2 = W - f;
            return [
                `M 0 ${y0}`,
                `Q ${x1} ${y0} ${x1 + i} ${y0 - f}`,
                `L ${x1 + i} ${i + r}`,
                `Q ${x1 + i} ${i} ${x1 + i + r} ${i}`,
                `L ${x2 - i - r} ${i}`,
                `Q ${x2 - i} ${i} ${x2 - i} ${i + r}`,
                `L ${x2 - i} ${y0 - f}`,
                `Q ${x2 - i} ${y0} ${W} ${y0}`,
            ].join(' ');
        },
        // Stroke of an outlined tab and its baseline; the active colour when none is set.
        outlineColor(cfg) {
            return cfg.active_outline_color || cfg.active_tab_color || '#212529';
        },
        raisedTabFill(block) {
            const cfg = block.config;
            if (cfg.active_bg_style === 'gradient') return `url(#hb-tg-${block.id})`;
            if (cfg.active_bg_style === 'solid') return cfg.active_tab_color || '#212529';
            return 'none';   // hollow, or the clipped <image> underneath
        },
        // Baseline segments either side of the raised tab (outline).
        tabBaseStyle(block, side) {
            const pos = this.tabInd[block.id];
            const color = this.outlineColor(block.config);
            const y = pos.top + pos.height - 1.5;
            const foot = this.tabFoot;
            if (side === 'left') {
                return { left: 0, top: y + 'px', width: Math.max(pos.left - foot, 0) + 'px', background: color };
            }
            const start = pos.left + pos.width + foot;
            return { left: start + 'px', top: y + 'px', width: Math.max(pos.total - start, 0) + 'px', background: color };
        },
        tabStyle(block, i) {
            const cfg = block.config;
            const active = this.activeTabIndex(block) === i;
            const style = {};
            // An image behind the active tab has a chosen shape; every tab takes it so
            // the strip stays level and the marker matches the tab it slides to.
            if (['fill', 'outline'].includes(cfg.active_indicator) && cfg.active_bg_style === 'image') {
                style.aspectRatio = this.aspectCss(cfg.active_bg_image_aspect);
                style.justifyContent = 'center';
            }
            if (cfg.tab_text_color) style.color = cfg.tab_text_color;
            if (!active) return style;
            const ind = cfg.active_indicator || 'underline';
            if (cfg.active_tab_text_color) {
                // An explicit active title colour wins over every derived rule.
                style.color = cfg.active_tab_text_color;
            } else if (ind === 'fill' || (ind === 'outline' && cfg.active_bg_style !== 'none')) {
                // Painted background behind; the label keeps the text colour (white
                // when none is set) so it stays readable on the fill.
                style.color = cfg.tab_text_color || '#fff';
            } else if (cfg.active_tab_color) {
                style.color = cfg.active_tab_color;
            }
            return style;
        },
        aspectCss(map) {
            const v = (map && map[this.platform]) || '1:1';
            return String(v).replace(':', ' / ');
        },
        blockCategories(block) {
            if (block.type === 'occasion_section' || block.type === 'relationship_section') {
                const isOcc = block.type === 'occasion_section';
                const list = isOcc ? this.gifting.occasions : this.gifting.relationships;
                return ((isOcc ? block.config.occasion_ids : block.config.relationship_ids) || [])
                    .map(id => list.find(x => Number(x.id) === Number(id)))
                    .filter(Boolean);
            }
            const ids = block.config.category_ids || [];
            return ids
                .map(id => this.allCategories.find(c => c.id === id))
                .filter(Boolean);
        },
        // Every active descendant of a category, so picking a parent in the scope
        // previews the same set the resolver will return.
        categorySubtreeIds(rootId) {
            const ids = [Number(rootId)];
            for (let i = 0; i < ids.length; i += 1) {
                this.allCategories
                    .filter(c => Number(c.parent_id) === ids[i])
                    .forEach((c) => { if (!ids.includes(Number(c.id))) ids.push(Number(c.id)); });
            }
            return ids;
        },
        // The optional category/brand scope an ordering-only source can carry.
        // Mirrors HomeLayoutResolver::applySourceFilter so the preview does not
        // promise a list the live section will not show.
        applySourceFilter(list, cfg) {
            const type = cfg.filter_type;
            if (type !== 'category' && type !== 'brand') return list;

            let ids = (type === 'category' ? cfg.filter_category_ids : cfg.filter_brand_ids) || [];
            ids = ids.map(Number).filter(Boolean);
            if (!ids.length) return list;

            if (type === 'category') {
                const subtree = new Set();
                ids.forEach(id => this.categorySubtreeIds(id).forEach(s => subtree.add(s)));
                ids = [...subtree];
            }

            const column = type === 'category' ? 'category_id' : 'brand_id';
            if (cfg.filter_mode === 'exclude') {
                // A product with no brand at all is not one of the excluded brands.
                return list.filter(p => !p[column] || !ids.includes(Number(p[column])));
            }
            return list.filter(p => ids.includes(Number(p[column])));
        },
        blockProducts(block) {
            const cfg = block.config;
            const limit = cfg.limit || 8;
            let list = [];
            if (cfg.data_source === 'manual') {
                list = (cfg.manual_product_ids || [])
                    .map(id => this.allProducts.find(p => p.id === id))
                    .filter(Boolean);
            } else if (cfg.data_source === 'category') {
                const ids = (cfg.slider_category_ids || []).map(Number);
                list = ids.length ? this.allProducts.filter(p => ids.includes(Number(p.category_id))) : [];
            } else {
                list = this.applySourceFilter(this.allProducts.slice(), cfg);
            }
            if (!list.length) {
                // fallback placeholders so the layout is still visible
                return Array.from({ length: Math.min(limit, 6) }, () => ({}));
            }
            /* Shuffle ONCE per block and keep that order until the products behind the
               block actually change. This method re-runs on every re-render — selecting
               a section, typing a title — and a fresh Math.random() each time made the
               row reshuffle on every click. The order is keyed on the ids so a changed
               source or limit still reshuffles, and turning the toggle off restores
               natural order. */
            if (cfg.shuffle_products) {
                const key = block.id + '|' + list.map(p => p.id).join(',') + '|' + limit;
                const cached = this._shuffleCache[block.id];
                if (!cached || cached.key !== key) {
                    this._shuffleCache[block.id] = { key, list: list.slice().sort(() => Math.random() - 0.5) };
                }
                list = this._shuffleCache[block.id].list;
            } else if (this._shuffleCache[block.id]) {
                delete this._shuffleCache[block.id];
            }
            return list.slice(0, limit);
        },
        productPriceText(p) {
            if (!p) return '';
            const sym = (this.$currency || '');
            const disc = Number(p.min_discounted) || 0;
            const min = Number(p.min_price) || 0;
            if (disc > 0) return sym + disc;
            if (min > 0) return sym + min;
            return '';
        },
        productMrpText(p) {
            if (!p) return '';
            const sym = (this.$currency || '');
            const disc = Number(p.min_discounted) || 0;
            const min = Number(p.min_price) || 0;
            if (disc > 0 && min > 0 && min !== disc) return sym + min;
            return '';
        },
        productWrapStyle(block) {
            const cfg = block.config;
            // Inner padding = top/bottom only. Side spacing (10px) lives on the
            // inner scroller so content scrolls edge to edge — only the first/last
            // item keeps the 10px inset.
            const style = { padding: (cfg.block_padding || 0) + 'px 0' };
            if (cfg.variant === 'with_background' && cfg.background_image) {
                const bg = this.pickImage(cfg.background_image);
                if (bg) {
                    style.backgroundImage = `url(${bg})`;
                    style.backgroundSize = 'cover';
                    style.backgroundPosition = 'center';
                    // Product slider reuses image_aspect; every other block type has a
                    // dedicated background ratio (bg_image_aspect).
                    style.aspectRatio = block.type === 'product_slider'
                        ? this.blockAspect(block)
                        : this.bgAspect(block);
                }
            } else if (cfg.variant === 'with_color' && cfg.background_color) {
                style.backgroundColor = cfg.background_color;
            }
            return style;
        },
        /** A list-layout slider on the web preview: one full-width column wastes the width. */
        isWebList(block) {
            // A tab body is a product slider; it takes the same two-up list on web.
            return ['product_slider', 'product_tabs'].includes(block.type)
                && block.layout === 'list' && this.platform === 'web';
        },
        productGridStyle(block) {
            const cfg = block.config;
            const gap = this.dev(cfg.product_grid_gap, 8, true) + 'px';
            const pad = this.sideInset();
            if (block.layout === 'grid') {
                return { display: 'grid', gridTemplateColumns: `repeat(${this.dev(cfg.grid_columns, 2)}, 1fr)`, gap, ...pad };
            }
            // List stays one row per product on a phone; the web layout has room for two.
            if (this.isWebList(block)) {
                return { display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap, ...pad };
            }
            return { gap, ...pad };
        },

        sideInset() {
            return this.platform === 'web'
                ? {}
                : { paddingLeft: '10px', paddingRight: '10px' };
        },
        // Resolve a per-platform numeric map ({app,web,tablet}) to the active device.
        dev(map, fallback, allowZero = false) {
            if (!map || typeof map !== 'object') return fallback;
            const v = Number(map[this.platform]);
            if (Number.isNaN(v)) return fallback;
            return allowZero ? (v >= 0 ? v : fallback) : (v > 0 ? v : fallback);
        },
        catContainerStyle(block) {
            const gap = this.dev(block.config.category_gap, 8, true) + 'px';
            if (block.layout === 'grid') {
                return { display: 'grid', gridTemplateColumns: `repeat(${this.dev(block.config.grid_columns, 4)}, 1fr)`, gap };
            }
            return { gap };
        },
        catItemStyle(block) {
            // Circular ignores radius (stays a circle via the .circle class).
            if (block.layout === 'circular') return {};
            return { borderRadius: this.dev(block.config.category_radius, 12, true) + 'px' };
        },
        brandItemStyle(block) {
            if (block.layout === 'circular') return {};
            return { borderRadius: this.dev(block.config.brand_radius, 8, true) + 'px' };
        },
        brandListStyle(block) {
            const gap = this.dev(block.config.brand_gap, 8, true) + 'px';
            if (block.layout === 'grid') {
                return { display: 'grid', gridTemplateColumns: `repeat(${this.dev(block.config.grid_columns, 4)}, 1fr)`, gap };
            }
            return { gap };
        },
        gridBannerStyle(block) {
            const gap = this.dev(block.config.grid_gap, 8, true);
            const cols = this.dev(block.config.grid_columns, 2);
            // Horizontal scroll: fixed rows, banners flow into columns that scroll sideways.
            const pad = this.sideInset();
            if (block.config.grid_layout_type === 'scroll') {
                const rows = this.dev(block.config.grid_rows, 1);
                return {
                    display: 'grid',
                    gridAutoFlow: 'column',
                    gridTemplateRows: `repeat(${rows}, 1fr)`,
                    gridAutoColumns: `calc((100% - ${(cols - 1) * gap}px) / ${cols})`,
                    gap: gap + 'px',
                    overflowX: 'auto',
                    ...pad,
                };
            }
            return {
                gridTemplateColumns: `repeat(${cols}, 1fr)`,
                gap: gap + 'px',
                ...pad,
            };
        },
        // Placeholder tile count: scroll shows a couple of screens' worth so the
        // horizontal overflow is visible; grid shows a single row.
        gridPlaceholderCount(block) {
            const cols = this.dev(block.config.grid_columns, 2);
            if (block.config.grid_layout_type === 'scroll') {
                return cols * this.dev(block.config.grid_rows, 1) * 2;
            }
            return cols;
        },
        // Mirror Flutter's _gradientFrom: dark (-14% L) → light (+12% L), top to bottom.
        hexToHsl(hex) {
            const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
            if (!m) return null;
            let r = parseInt(m[1], 16) / 255;
            let g = parseInt(m[2], 16) / 255;
            let b = parseInt(m[3], 16) / 255;
            const max = Math.max(r, g, b), min = Math.min(r, g, b);
            let h, s;
            const l = (max + min) / 2;
            if (max === min) {
                h = s = 0;
            } else {
                const d = max - min;
                s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
                switch (max) {
                    case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
                    case g: h = ((b - r) / d + 2) / 6; break;
                    default: h = ((r - g) / d + 4) / 6;
                }
            }
            return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) };
        },
        colorToGradient(color) {
            const hsl = this.hexToHsl(color);
            if (!hsl) return color;
            const darkL  = Math.max(0,   hsl.l - 14);
            const lightL = Math.min(100, hsl.l + 12);
            const dark  = `hsl(${hsl.h}, ${hsl.s}%, ${darkL}%)`;
            const light = `hsl(${hsl.h}, ${hsl.s}%, ${lightL}%)`;
            return `linear-gradient(to bottom, ${dark}, ${light})`;
        },
    },
};
</script>

<style scoped>
.hb-preview-wrap {
    display: flex;
    flex-direction: column;
    align-items: center;
    /* The preview is a picture of the app, not a document: text in it is never
       something to select, and images are never something to drag out. Without
       this every drag-scroll highlights the text it passes over, and grabbing a
       banner lifts a ghost image instead of scrolling the row. */
    user-select: none;
    -webkit-user-select: none;
}
.hb-preview-wrap img {
    -webkit-user-drag: none;
    user-drag: none;
    pointer-events: none;
    width: fit-content;   /* hug the device so the column doesn't reserve empty space */
    max-width: 100%;
    margin: 0 auto;
}

.hb-preview-toolbar {
    margin-bottom: .75rem;
}

.hb-device {
    background: #1f2937;
    border-radius: 1.5rem;
    padding: .35rem;
    box-shadow: 0 12px 30px rgba(0, 0, 0, .25);
    transition: width .2s;
}

.hb-device.is-app {
    width: 320px;
    max-width: 100%;
}

.hb-device.is-tablet {
    width: 380px;
    max-width: 100%;
}

.hb-device.is-web {
    width: 560px;
    max-width: 100%;
    border-radius: .5rem;
    padding: .25rem;
}

.hb-device-screen {
    background: #fff;
    border-radius: 1.25rem;
    /* Fill the visible viewport height (minus the toolbar, note and top offset)
       instead of a fixed height that pushes the page down. */
    height: calc(100vh - 200px);
    min-height: 420px;
    overflow-y: auto;
    overflow-x: hidden;
}
.hb-preview-note {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: .4rem;
    margin-top: .6rem;
    font-size: .72rem;
    color: #98a2b3;
    text-align: center;
}
.hb-preview-note svg { flex-shrink: 0; }

.hb-device.is-web .hb-device-screen {
    border-radius: .4rem;
}

.hb-app-header {
    padding: .5rem .65rem .25rem;
    transition: background .2s;
}

.hb-app-pagebar {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 4px 8px;
    font-size: .72rem;
    border-bottom: 1px solid #eee;
    border-bottom-color: color-mix(in srgb, currentColor 18%, transparent);
}

.hb-app-statusbar {
    display: flex;
    justify-content: space-between;
    font-size: .58rem;
    font-weight: 700;
    color: inherit;
    padding: 2px 4px 6px;
}

.hb-app-status-right {
    display: inline-flex;
    align-items: center;
}

.hb-app-deliv-row {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: 0 4px 6px;
}

.hb-app-deliv-label {
    font-size: .55rem;
    font-weight: 700;
    text-transform: uppercase;
    color: inherit;
    opacity: .65;
    display: block;
}

.hb-app-deliv-time {
    font-size: 1.05rem;
    font-weight: 800;
    color: inherit;
    line-height: 1;
}

.hb-app-deliv-addr {
    font-size: .55rem;
    color: inherit;
    opacity: .8;
    display: inline-flex;
    align-items: center;
    gap: 3px;
    margin-top: 2px;
    text-transform: uppercase;
}

.hb-app-actions {
    display: flex;
    gap: 6px;
}

.hb-app-action-chip {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    background: rgba(255, 255, 255, .55);
    display: inline-flex;
    align-items: center;
    justify-content: center;
    color: #333;
    font-size: .7rem;
}

.hb-app-search {
    display: flex;
    align-items: center;
    gap: 6px;
    background: #fff;
    border-radius: 8px;
    padding: 6px 10px;
    margin: 0 0 8px;
    font-size: .68rem;
    color: #555;
    box-shadow: 0 1px 2px rgba(0, 0, 0, .08);
}

.hb-app-search .fa-microphone {
    color: #777;
}

.hb-cat-rail {
    display: flex;
    flex-wrap: nowrap;
    gap: .4rem;
    padding: .3rem 0 .25rem;
    overflow-x: auto;
}

.hb-cat-pill {
    position: relative;
    flex: none;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    border: 0;
    background: transparent;
    color: inherit;
    width: 42px;
    padding-bottom: 5px;
    cursor: pointer;
}
/* Active indicator spans the whole tab at the bottom of the header rail,
   not just under the category name. */
.hb-cat-pill.active::after {
    content: '';
    position: absolute;
    left: 3px;
    right: 3px;
    bottom: 0;
    height: 2px;
    background: currentColor;
    border-radius: 2px;
}

.hb-cat-pill-icon {
    width: 22px;
    height: 22px;
    color: inherit;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    text-transform: uppercase;
    overflow: hidden;
}

.hb-cat-pill-icon img {
    width: 100%;
    height: 100%;
    object-fit: contain;
}

.hb-cat-pill small {
    font-size: .5rem;
    line-height: 1.05;
    color: inherit;
    text-align: center;
    font-weight: 600;
}

.hb-cat-pill.active small {
    font-weight: 800;
}

.hb-prev-cat.clickable {
    cursor: pointer;
}

.hb-preview-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    color: #ced4da;
    padding: 4rem 1rem;
}

.hb-preview-empty i {
    font-size: 2.5rem;
}

.hb-prev-section {
    position: relative;
}

.hb-ph {
    display: flex;
    align-items: center;
    justify-content: center;
    background: #f1f3f5;
    color: #ced4da;
    width: 100%;
    height: 100%;
    min-height: 60px;
}

.hb-ph-banner {
    height: 130px;
    font-size: 1.5rem;
}

.hb-prev-title-img img {
    width: 100%;
    display: block;
}

/* Banner carousel track */
.hb-prev-banner-viewport {
    overflow: hidden;
    width: 100%;
}

.hb-prev-banner-track {
    display: flex;
    transition: transform .4s ease;
}

.hb-prev-banner-slide {
    position: relative;
    overflow: hidden;
    aspect-ratio: 16 / 7;
    background: #f1f3f5;
    transition: transform .3s ease, opacity .3s ease;
}

.hb-prev-banner-slide img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
}

/* WEB preview: wider banner box, but images fill it (cover) so a set height
   grows the image instead of leaving gray letterbox bands. */
.hb-device.is-web .hb-prev-banner-slide {
    aspect-ratio: 32 / 9;
}

.hb-prev-banner-slide .hb-ph {
    height: 100%;
}

/* card + spotlight: raised cards (radius comes from the section setting) */
.hb-prev-banner.style-card .hb-prev-banner-slide,
.hb-prev-banner.style-spotlight .hb-prev-banner-slide {
    box-shadow: 0 4px 14px rgba(0, 0, 0, .15);
}

/* spotlight: side slides shrink + dim */
.hb-prev-banner.style-spotlight .hb-prev-banner-slide:not(.active) {
    transform: scale(.86);
    opacity: .55;
}

/* story: tall portrait slides */
.hb-prev-banner.style-story .hb-prev-banner-slide {
    aspect-ratio: 9 / 16;
    max-height: 260px;
}

.hb-prev-story-bars {
    display: flex;
    gap: 4px;
    padding: 6px 8px;
}

.hb-prev-story-bars span {
    flex: 1;
    height: 3px;
    border-radius: 2px;
    background: #dee2e6;
}

.hb-prev-story-bars span.on {
    background: #212529;
}

.hb-prev-dots {
    display: flex;
    gap: 4px;
    justify-content: center;
    padding: 6px 0;
}

.hb-prev-dots span {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #dee2e6;
}

.hb-prev-dots span.on {
    background: #212529;
    width: 14px;
    border-radius: 3px;
}

.hb-prev-grid {
    display: grid;
}

.hb-prev-tile {
    aspect-ratio: 1 / 1;
    overflow: hidden;
    background: #f1f3f5;
}

.hb-prev-tile img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.hb-prev-cats {
    display: flex;
    flex-wrap: wrap;
    padding: .25rem 0;
}

.hb-prev-cats.cat-horizontal,
.hb-prev-cats.cat-circular {
    flex-wrap: nowrap;
    overflow-x: auto;
}

.hb-prev-cat {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 3px;
    flex: none;
    text-align: center;
}

.hb-prev-cat-img {
    width: 48px;
    height: 48px;
    border-radius: .5rem;
    background: rgba(var(--bs-primary-rgb), .1);
    color: var(--bs-primary);
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    font-weight: 700;
}

.hb-prev-cat-img.circle {
    border-radius: 50%;
}

.hb-prev-cat-img img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.hb-prev-cat small {
    font-size: .62rem;
    line-height: 1.1;
}

.hb-prev-hint,
.hb-prev-sec-title {
    font-size: .8rem;
}

.hb-prev-sec-title {
    font-weight: 700;
    padding: .25rem .25rem .5rem;
}

.hb-prev-hint {
    color: #adb5bd;
    padding: 1rem;
}

/* product_tabs: the menu strip above the products. The active tab is marked by
   one absolutely positioned marker (.hb-prev-tab-ind) that slides to whichever
   tab is chosen — underline bar, filled block, or a raised outline/folder tab
   joined to a baseline (.hb-prev-tab-base). Colours come from the block config;
   the greys below are the defaults. */
.hb-prev-tabs {
    position: relative;
    display: flex;
    gap: .6rem;
    overflow-x: auto;
    padding-bottom: .3rem;
    margin-bottom: .3rem;
    scrollbar-width: none;
}
.hb-prev-tabs::-webkit-scrollbar { display: none; }
.hb-prev-tab {
    position: relative;
    z-index: 1;
    flex: 0 0 auto;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: .3rem;
    cursor: pointer;
    color: #6c757d;
    font-size: .66rem;
    padding: .15rem .3rem .3rem;
    /* Fixed width: a long title wraps onto a second line instead of stretching the tab. */
    width: 64px;
    text-align: center;
    transition: color .2s;
}
.hb-prev-tab-label {
    display: block;
    width: 100%;
    white-space: normal;
    overflow-wrap: break-word;
    line-height: 1.15;
}
/* Text-only tabs size to their label, wrapping past a sensible width. */
.hb-prev-tabs.tabs-text .hb-prev-tab { width: auto; max-width: 84px; }
.hb-prev-tab.active { color: #212529; font-weight: 700; }
.hb-prev-tab-icon {
    width: 26px;
    overflow: hidden;
    border-radius: 8px;
    background: #f5f6f8;
    display: flex; align-items: center; justify-content: center;
}
.hb-prev-tab-icon img { width: 100%; height: 100%; object-fit: cover; }
.hb-prev-tabs.tabs-text .hb-prev-tab { padding: .3rem .5rem; }
.hb-prev-tab-ind, .hb-prev-tab-base {
    position: absolute;
    pointer-events: none;
    box-sizing: border-box;
    transition: left .25s ease, width .25s ease, top .25s ease, height .25s ease;
}
.hb-prev-tab-base { height: 1.5px; }
.hb-prev-tab-svg { position: absolute; left: 0; top: 0; display: block; overflow: visible; }
.hb-prev-tabs.ind-fill { gap: .4rem; }
.hb-prev-tabs.ind-fill .hb-prev-tab { padding: .25rem .5rem; }
.hb-prev-tabs.tabs-text.ind-fill .hb-prev-tab { padding: .25rem .6rem; }
/* Raised tab: room either side for the sweep, and its open bottom meets the
   baseline, so no strip padding below. */
.hb-prev-tabs.ind-outline { gap: 1rem; padding: 0 8px; }
.hb-prev-tabs.ind-outline .hb-prev-tab { padding: .3rem .6rem .4rem; }

/* Product switch when the active tab changes. */
.hb-tab-fade-enter-active, .hb-tab-fade-leave-active { transition: opacity .18s ease; }
.hb-tab-fade-enter-from, .hb-tab-fade-leave-to { opacity: 0; }
.hb-tab-slide-enter-active, .hb-tab-slide-leave-active { transition: opacity .18s ease, transform .18s ease; }
.hb-tab-slide-enter-from { opacity: 0; transform: translateX(24px); }
.hb-tab-slide-leave-to { opacity: 0; transform: translateX(-24px); }

.hb-prev-products.lay-horizontal {
    display: flex;
    flex-wrap: nowrap;
    overflow-x: auto;
}

.hb-prev-products.lay-horizontal .hb-prev-product {
    flex: 0 0 auto;
    width: 96px;
}

.hb-prev-products.lay-list .hb-prev-product {
    display: flex;
    align-items: center;
    gap: .5rem;
    margin-bottom: .35rem;
}

.hb-prev-products.lay-list .hb-prev-product-img {
    width: 56px;
    flex: none;
}

/* Two per row on web: the grid gap already spaces the rows. */
.hb-prev-products.lay-list-web .hb-prev-product {
    margin-bottom: 0;
}

.hb-prev-product {
    background: #fff;
    border: 1px solid #f1f3f5;
    overflow: hidden;
}

.hb-prev-product-img {
    aspect-ratio: 1 / 1;
    background: #f1f3f5;
}

.hb-prev-product-img img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.hb-prev-product-name {
    font-size: .65rem;
    padding: 3px 4px 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.hb-prev-product-price {
    font-size: .62rem;
    padding: 0 4px 4px;
    display: flex;
    gap: 4px;
    align-items: baseline;
}

.hb-pp-final {
    font-weight: 700;
    color: #111;
}

.hb-pp-mrp {
    color: #999;
    text-decoration: line-through;
    font-size: .55rem;
}

.hb-prev-brands {
    padding: .35rem 0;
}

.hb-prev-brands-list {
    display: flex;
    flex-wrap: wrap;
    padding: .25rem 0;
}

.hb-prev-brands-list.cat-horizontal,
.hb-prev-brands-list.cat-circular {
    flex-wrap: nowrap;
    overflow-x: auto;
}

.hb-prev-brand {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 3px;
    flex: none;
    text-align: center;
}

.hb-prev-brand-img {
    width: 56px;
    height: 56px;
    background: #f7f7f7;
    border: 1px solid #eee;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    color: #555;
    font-weight: 700;
}

.hb-prev-brand-img.circle {
    border-radius: 50%;
}

.hb-prev-brand-img img {
    width: 100%;
    height: 100%;
    object-fit: contain;
    padding: 4px;
}

.hb-prev-brand small {
    font-size: .6rem;
    line-height: 1.1;
    color: #444;
}

.hb-prev-text {
    border-radius: 4px;
    padding: 10px !important;
}

.hb-prev-text-heading {
    font-size: 1rem;
    font-weight: 800;
    color: inherit;
}

.hb-prev-text-sub {
    font-size: .72rem;
    margin-top: 2px;
    opacity: .85;
    color: inherit;
    white-space: pre-line;
}

.hb-approx {
    position: absolute;
    top: 2px;
    right: 4px;
    font-size: .55rem;
    background: rgba(0, 0, 0, .55);
    color: #fff;
    padding: 1px 5px;
    border-radius: 3px;
}

/* Hide scrollbars everywhere (keep scroll behavior). Horizontal rails are
   scrolled by click-and-drag via the v-drag-scroll directive. */
.hb-device-screen,
.hb-cat-rail,
.hb-prev-cats,
.hb-prev-products,
.hb-prev-brands-list,
.hb-prev-banner-viewport {
    scrollbar-width: none;
    -ms-overflow-style: none;
}
.hb-device-screen::-webkit-scrollbar,
.hb-cat-rail::-webkit-scrollbar,
.hb-prev-cats::-webkit-scrollbar,
.hb-prev-products::-webkit-scrollbar,
.hb-prev-brands-list::-webkit-scrollbar,
.hb-prev-banner-viewport::-webkit-scrollbar {
    display: none;
}
</style>
<style scoped>
/* Click-to-edit affordance over each previewed section. */
.hb-prev-section { position: relative; cursor: pointer; }
.hb-prev-section.is-inactive { opacity: .45; }
.hb-prev-section.is-selected { outline: 2px solid var(--bs-primary); outline-offset: -2px; border-radius: 4px; }
.hb-prev-edit {
    position: absolute; top: 4px; right: 4px; z-index: 6;
    width: 24px; height: 24px; padding: 0; border: none; border-radius: 6px;
    background: var(--bs-primary); color: #fff;
    display: none; align-items: center; justify-content: center;
    box-shadow: 0 1px 4px rgba(0,0,0,.25);
}
.hb-prev-section:hover .hb-prev-edit { display: inline-flex; }
</style>
