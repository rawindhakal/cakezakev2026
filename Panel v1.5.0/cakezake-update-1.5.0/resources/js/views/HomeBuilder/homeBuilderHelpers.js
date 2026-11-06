// Shared data helpers for the Home Builder module.
// Mirrors the layout shape consumed by the customer API (HomeLayoutResolver).

import axios from 'axios';


// Layout JSON branches storage-relative image paths (home_builder/...); legacy rows
// may hold absolute URLs. Resolve either to a displayable URL.
export function resolveImageUrl(v) {
    if (!v) return '';
    if (/^https?:\/\//i.test(v) || v.startsWith('data:')) return v;
    return (window.baseUrl || '') + '/storage/' + v;
}

// Per-platform default image height (px). Applied when a height field is left
// blank — both in the builder placeholder and the backend resolver.
export const IMAGE_ASPECT_DEFAULTS = { app: '16:9', tablet: '16:9', web: '3:1' };

// Section/block types — each section hosts exactly one block of the same type.
// icon = lucide component name (rendered via <component :is>).
export const SECTION_TYPES = [
  { value: 'banner_slider', label: 'Banner Slider', icon: 'Images' },
  { value: 'category_section', label: 'Category Section', icon: 'LayoutGrid' },
  { value: 'product_slider', label: 'Product Slider', icon: 'Package' },
  { value: 'product_tabs', label: 'Tabbed Products', icon: 'PanelTop' },
  { value: 'brand_section', label: 'Top Brands', icon: 'Tags' },
  { value: 'grid_banner', label: 'Grid Banner', icon: 'Grid3x3' },
  { value: 'title_image', label: 'Title Image', icon: 'ImageIcon' },
  { value: 'text_section', label: 'Heading / Text', icon: 'Heading' },
];

export const SECTION_TYPE_LABELS = SECTION_TYPES.reduce((acc, t) => {
  acc[t.value] = t.label;
  return acc;
}, {});

let idCounter = 0;
export function genId(prefix) {
  idCounter += 1;
  return `${prefix}-${Date.now().toString(36)}-${idCounter}`;
}

// Header background image is per-platform ({app,web,tablet}), like block images.
// Upgrades an old single-string value to the map so existing layouts keep working.
function toImageMap(v) {
  if (v && typeof v === 'object' && !Array.isArray(v)) return { ...newImage(), ...v };
  const s = typeof v === 'string' ? v : '';
  return { app: s, web: s, tablet: s };
}

function toAspectMap(v) {
  const d = IMAGE_ASPECT_DEFAULTS;
  if (typeof v === 'string' && v.includes(':')) return { app: v, web: v, tablet: v };
  if (v && typeof v === 'object' && !Array.isArray(v)) {
    return {
      app: v.app || d.app,
      web: v.web || d.web,
      tablet: v.tablet || d.tablet,
    };
  }
  return { ...d };
}

function emptyBg() {
  return { theme: 'color', color: '#FFE94B', image_url: newImage(), text_color: '#000000' };
}

function normBg(bg) {
  const b = { ...emptyBg(), ...(bg || {}) };
  b.image_url = toImageMap(bg && bg.image_url);
  return b;
}

export function emptyConfig() {
  return {
    sections: [],
    // category_wise tab bg (flat)
    background_theme: 'color',
    background_color: '#FFE94B',
    background_image_url: newImage(),
    text_color: '#000000',
    header_icon_url: '',
    search_suggestions: [],
    // single-mode per-channel bg
    background_quick: emptyBg(),
    background_ecommerce: emptyBg(),
  };
}

function newImage() {
  return { app: '', web: '', tablet: '' };
}

// Per-platform numeric map (grid columns / gaps / radii). app/web/tablet.
function numMap(app, web, tablet) {
  return { app, web, tablet };
}

export function newBlockConfig() {
  return {
    data_source: 'manual',          // manual | top_selling | trending | recently_visited | buy_again | most_favorited | category | brand | discounted | best_rated | new_arrivals
    limit: 10,
    category_ids: [],               // category_section
    category_id: '',                // legacy single category (product_slider data_source=category)
    slider_category_ids: [],        // product_slider data_source=category (multi)
    shuffle_products: false,        // product_slider: random order on every request
    brand_ids: [],                  // brand_section + product_slider data_source=brand
    manual_product_ids: [],         // product_slider data_source=manual
    // Optional scope on an ordering-only data source ("Trending, but only in Food").
    // Own keys, not the data-source lists above: switching a slider from By Category
    // to Trending must not silently keep the old ids as an invisible filter.
    filter_type: 'none',            // none | category | brand
    filter_mode: 'include',         // include | exclude
    filter_category_ids: [],
    filter_brand_ids: [],
    variant: 'default',             // default | with_title | with_background
    section_title: {},              // translatable {langId: text}
    section_subtitle: {},           // translatable subtitle/caption
    text_align: 'left',             // text_section: left|center|right
    text_color: '',
    item_text_color: '',            // category/brand item name label color
    background_color: '',           // text_section bg
    background_image: newImage(),
    image_aspect: { ...IMAGE_ASPECT_DEFAULTS }, // per-device image aspect ratio "w:h" (banner_slider / grid_banner / title_image)
    bg_image_aspect: { ...IMAGE_ASPECT_DEFAULTS }, // per-device aspect for the with_background image (product_slider / grid_banner)
    // Per-platform grid columns (category_section / brand_section / product_slider / grid_banner grid layouts).
    grid_columns: numMap(2, 4, 3),
    item_width: '100%',
    preview_item_count: 5,
    auto_scroll: true,
    speed_ms: 3000,
    infinite_loop: true,
    center_focus: false,
    indicator: 'dots',              // dots | none
    carousel_style: 'full_width',   // full_width | peek | card | story | spotlight
    block_padding: 0,
    block_radius: 0,
    grid_gap: numMap(8, 8, 8),      // grid_banner gap (per-platform)
    // grid_banner layout: 'grid' (wraps by columns) or 'scroll' (fixed rows,
    // scrolls horizontally). grid_rows is per-platform, used by the scroll layout.
    grid_layout_type: 'grid',
    grid_rows: numMap(1, 1, 1),
    tile_radius: 6,
    category_gap: numMap(8, 8, 8),  // category_section gap (per-platform)
    category_radius: numMap(12, 12, 12), // category_section item radius (per-platform)
    brand_gap: numMap(8, 8, 8),     // brand_section gap (per-platform)
    brand_radius: numMap(8, 8, 8),  // brand_section item radius (per-platform)
    // Per platform: the same gap rarely suits a phone and a desktop grid.
    product_grid_gap: { app: 8, tablet: 8, web: 8 },
    product_card_radius: 0,
    // product_tabs: how the tab strip is drawn. Icons sit above the label by
    // default (the "menu" look); text is for tighter headers.
    tab_style: 'icon_top',          // icon_top | text
    tab_image_aspect: { app: '1:1', tablet: '1:1', web: '1:1' },
    // How the active tab is marked: underline | fill | outline | none.
    // fill paints a background (solid / gradient / image); outline is a raised
    // tab joined to a baseline, with an optional background of the same kinds.
    active_indicator: 'underline',
    active_bg_style: 'solid',       // none (outline only) | solid | gradient | image
    active_tab_color: '',
    active_tab_color_2: '',         // gradient end colour
    active_outline_color: '',       // outlined tab: stroke + baseline (falls back to active colour)
    active_bg_image: newImage(),    // per-platform image behind the active tab
    active_bg_image_aspect: { app: '1:1', tablet: '1:1', web: '1:1' }, // shape of that tab when an image is behind it
    tab_text_color: '',
    active_tab_text_color: '',      // active tab title; empty = derived (see LivePreview.tabStyle)
    tab_animation: 'fade',          // none | fade | slide — product switch when a tab changes
    show_name: true,                // brand_section: show brand name below logo
    redirect_type: 'none',          // title_image / text_section: none|product|category|products|url
    redirect_id: '',
    redirect_url: '',
    redirect_filters: newRedirectFilters(),
  };
}

/**
 * Blocks that show a Section Title once their display variant is anything but
 * 'default' — exactly the rule BlockEditor renders the field by.
 */
const TITLED_BLOCK_TYPES = [
  'grid_banner', 'category_section', 'product_slider', 'product_tabs', 'brand_section',
];

/**
 * Does this block render a translatable title / subtitle right now?
 *
 * BlockEditor draws the inputs and SectionEditor builds the language tabs around
 * them, so both read these two helpers: a variant that shows a title but no
 * language tabs would leave that title English-only.
 */
export function blockHasTitle(block) {
  if (!block) return false;
  if (block.type === 'text_section') return true;
  const variant = (block.config && block.config.variant) || 'default';
  return TITLED_BLOCK_TYPES.includes(block.type) && variant !== 'default';
}

export function blockHasSubtitle(block) {
  return !!block && block.type === 'text_section';
}

// Default layout per block type — horizontal for sliders, grid for category.
function defaultLayout(type) {
  if (type === 'category_section') return 'horizontal';
  if (type === 'brand_section') return 'horizontal';
  if (type === 'product_slider') return 'horizontal';
  if (type === 'product_tabs') return 'horizontal';
  return 'horizontal';
}

export function newBlock(type = 'title_image') {
  return {
    id: genId('blk'),
    type,
    layout: defaultLayout(type),
    image: newImage(),
    config: newBlockConfig(),
    items: [],
  };
}

/** Platforms a section shows on. All on by default — a new section shows everywhere. */
export function newPlatforms(on = true) {
  return { app: !!on, tablet: !!on, web: !!on };
}

export function toPlatforms(value) {
  if (!value || typeof value !== 'object') return newPlatforms(true);
  return {
    app: value.app !== false,
    tablet: value.tablet !== false,
    web: value.web !== false,
  };
}

/** One corner set: {top_left, top_right, bottom_left, bottom_right}, all the same. */
export function newCorners(v = 0) {
  const n = Number(v) || 0;
  return { top_left: n, top_right: n, bottom_left: n, bottom_right: n };
}

/**
 * Accept whatever a layout holds — a plain number saved before corners existed, or
 * an already-shaped corner map — and return four corners. Radius is NOT per
 * platform: a rounded corner looks the same on every device.
 */
export function toCornerRadius(value) {
  if (value == null || value === '') return newCorners(0);
  if (typeof value === 'number' || typeof value === 'string') return newCorners(value);
  return {
    top_left: Number(value.top_left) || 0,
    top_right: Number(value.top_right) || 0,
    bottom_left: Number(value.bottom_left) || 0,
    bottom_right: Number(value.bottom_right) || 0,
  };
}

/** Per-platform plain numbers: {app, tablet, web}. */
export function toPlatformNumber(value, fallback = 0) {
  if (value == null || value === '') value = fallback;
  if (typeof value === 'number' || typeof value === 'string') {
    const n = Number(value) || 0;
    return { app: n, tablet: n, web: n };
  }
  return {
    app: Number(value.app) || 0,
    tablet: Number(value.tablet) || 0,
    web: Number(value.web) || 0,
  };
}

export function newSection(type = 'banner_slider') {
  return {
    id: genId('sec'),
    type,
    active: true,
    margin_top: 0,
    margin_bottom: 0,
    border_radius: newCorners(0),
    border_radius_custom: false,
    platforms: newPlatforms(true),
    blocks: [newBlock(type)],
  };
}

export function newBannerItem() {
  return {
    image: newImage(),
    redirect_type: 'none',   // none | product | category | brand | page | products | url
    redirect_id: '',
    redirect_url: '',
    redirect_filters: newRedirectFilters(),
  };
}

/**
 * The filter set behind a `products` redirect — a banner that opens the product
 * list already narrowed ("Up to 50% off", "Shop red", "Under 100").
 *
 * Every key maps to a parameter the customer products API already understands;
 * HomeLayoutResolver turns this into the ready-to-send `redirect_params` map, so
 * the apps never translate key names themselves.
 */
export function newRedirectFilters() {
  return {
    title: {},                   // translatable heading for the opened listing
    // One category, not a list: the app's product-list screen filters by a single
    // category, so a multi-select here could not be shown once the screen opens.
    category_id: '',
    brand_ids: [],
    attribute_value_ids: [],     // e.g. Colour = Red
    min_price: '',
    max_price: '',
    min_discount_percent: '',    // "40% off and above"
    max_discount_percent: '',    // "Up to 50% off"
    sort: '',                    // '' = let the app use its own default
  };
}

/** Repair a filter set loaded from a layout saved before the field existed. */
export function toRedirectFilters(value) {
  const base = newRedirectFilters();
  const src = value && typeof value === 'object' && !Array.isArray(value) ? value : {};
  const ids = (v) => (Array.isArray(v) ? v : String(v == null ? '' : v).split(','))
    .map((x) => Number(x))
    .filter((x) => Number.isFinite(x) && x > 0);
  const num = (v) => (v === '' || v == null ? '' : v);
  // Accepts a layout saved while the category picker was still multi-select.
  const oneId = (v, legacy) => {
    const direct = ids(v == null || v === '' ? [] : [v]);
    if (direct.length) return direct[0];
    const old = ids(legacy);
    return old.length ? old[0] : '';
  };

  const out = {
    ...base,
    ...src,
    title: (src.title && typeof src.title === 'object') ? src.title : {},
    category_id: oneId(src.category_id, src.category_ids),
    brand_ids: ids(src.brand_ids),
    attribute_value_ids: ids(src.attribute_value_ids),
    min_price: num(src.min_price),
    max_price: num(src.max_price),
    min_discount_percent: num(src.min_discount_percent),
    max_discount_percent: num(src.max_discount_percent),
    sort: REDIRECT_SORTS.includes(src.sort) ? src.sort : '',
  };
  delete out.category_ids; // the old multi-select key, now folded into category_id
  return out;
}

/** True when the filter set would narrow nothing — nothing worth saving. */
export function redirectFiltersEmpty(filters) {
  const f = toRedirectFilters(filters);
  // Zero and below narrows nothing and is dropped by the resolver, so it does not
  // count as a filter here either.
  const pos = (v) => v !== '' && v != null && Number(v) > 0;
  return !f.category_id && !f.brand_ids.length && !f.attribute_value_ids.length
    && !pos(f.min_price) && !pos(f.max_price)
    && !pos(f.min_discount_percent) && !pos(f.max_discount_percent);
}

const REDIRECT_SORTS = ['new', 'popular', 'price_low', 'price_high', 'discount'];

/** Sort the listing opens with; blank leaves the app's own default in place. */
export function redirectSortOptions() {
  return [
    { id: '', name: __('app_default') },
    { id: 'new', name: __('newest_first') },
    { id: 'popular', name: __('most_popular') },
    { id: 'price_low', name: __('price_low_to_high') },
    { id: 'price_high', name: __('price_high_to_low') },
    { id: 'discount', name: __('biggest_discount') },
  ];
}

/**
 * One tab of a product_tabs block. A tab is a product_slider's data-source config
 * wearing a title and an icon — the block owns the look, the tab owns what it shows.
 * `limit` is null so the block-level limit applies until the admin overrides it.
 */
export const TABS_MAX = 8;
export const TAB_LIMIT_MAX = 20;

export function newTabItem() {
  return {
    id: genId('tab'),
    title: {},                     // translatable {langId: text}
    image: newImage(),             // the icon above the label
    config: {
      data_source: 'manual',
      limit: null,
      manual_product_ids: [],
      slider_category_ids: [],
      brand_ids: [],
      shuffle_products: false,
      filter_type: 'none',
      filter_mode: 'include',
      filter_category_ids: [],
      filter_brand_ids: [],
    },
  };
}

// Repair the optional category/brand scope on a layout saved before it existed,
// or saved with a half-filled selection.
function normalizeSourceFilter(config) {
  if (!['category', 'brand'].includes(config.filter_type)) config.filter_type = 'none';
  if (config.filter_mode !== 'exclude') config.filter_mode = 'include';
  if (!Array.isArray(config.filter_category_ids)) config.filter_category_ids = [];
  if (!Array.isArray(config.filter_brand_ids)) config.filter_brand_ids = [];
  return config;
}

// Normalize a layout loaded from the API so every expected key exists
// (covers configs saved by an older builder version).
export function normalizeConfig(config) {
  const cfg = config && typeof config === 'object' ? config : emptyConfig();
  const sections = Array.isArray(cfg.sections) ? cfg.sections : [];
  sections.forEach((section) => {
    if (!section.id) section.id = genId('sec');
    section.active = section.active !== false;
    section.margin_bottom = section.margin_bottom || 0;
    section.platforms = toPlatforms(section.platforms);
    section.border_radius = toCornerRadius(section.border_radius);
    section.border_radius_custom = section.border_radius_custom === true;
    if (!Array.isArray(section.blocks) || !section.blocks.length) {
      section.blocks = [newBlock(section.type)];
    }
    section.blocks.forEach((block) => {
      if (!block.id) block.id = genId('blk');
      block.image = { ...newImage(), ...(block.image || {}) };
      block.config = { ...newBlockConfig(), ...(block.config || {}) };
      // A layout saved before the gap went per-platform holds a single number.
      block.config.product_grid_gap = toPlatformNumber(block.config.product_grid_gap, 8);
      // A slider saved before multi-category held one id — carry it into the list.
      if (!Array.isArray(block.config.slider_category_ids)) block.config.slider_category_ids = [];
      if (!block.config.slider_category_ids.length && block.config.category_id !== '' && block.config.category_id != null) {
        block.config.slider_category_ids = [Number(block.config.category_id)];
      }
      block.config.shuffle_products = block.config.shuffle_products === true;
      normalizeSourceFilter(block.config);
      // Old layouts used grid_2/3/4 — collapse to a single 'grid' (column count
      // is now a per-platform field).
      if (typeof block.layout === 'string' && block.layout.startsWith('grid_')) {
        block.layout = 'grid';
      }
      // Repair per-platform map fields that may have loaded as old scalars.
      const def = newBlockConfig();
      ['grid_columns', 'grid_gap', 'grid_rows', 'category_gap', 'category_radius', 'brand_gap', 'brand_radius'].forEach((k) => {
        const v = block.config[k];
        if (!v || typeof v !== 'object' || Array.isArray(v)) block.config[k] = def[k];
      });
      // Image sizing is an aspect ratio. Ensure image_aspect exists as a
      // {app,tablet,web} string map; purge any legacy px sizing key.
      block.config.image_aspect = toAspectMap(block.config.image_aspect);
      block.config.bg_image_aspect = toAspectMap(block.config.bg_image_aspect);
      delete block.config.image_height;

      block.config.background_image = toImageMap(block.config.background_image);
      // Backfill grid_banner layout type on old layouts.
      if (block.config.grid_layout_type !== 'scroll') block.config.grid_layout_type = 'grid';
      if (!Array.isArray(block.items)) block.items = [];
      // A `products` redirect carries a filter set. Repair it wherever a redirect
      // can live — the block config (title_image / text_section) and each banner.
      block.config.redirect_filters = toRedirectFilters(block.config.redirect_filters);
      if (['banner_slider', 'grid_banner'].includes(block.type)) {
        block.items = block.items.map((it) => ({
          ...newBannerItem(),
          ...(it || {}),
          image: { ...newImage(), ...((it && it.image) || {}) },
          redirect_filters: toRedirectFilters(it && it.redirect_filters),
        }));
      }
      // Tabs: every stored tab gets the full shape, so a tab saved by an older
      // builder never trips a missing-key read in the editor.
      if (block.type === 'product_tabs') {
        block.config.tab_image_aspect = toAspectMap(block.config.tab_image_aspect);
        // 'pill' used to be a tab style; it is now text tabs with a filled active tab.
        if (block.config.tab_style === 'pill') {
          block.config.tab_style = 'text';
          block.config.active_indicator = 'fill';
        }
        if (!block.config.active_indicator) block.config.active_indicator = 'underline';
        // 'folder' was a filled outline tab; it is now outline + a background.
        if (block.config.active_indicator === 'folder') block.config.active_indicator = 'outline';
        if (!block.config.active_bg_style) block.config.active_bg_style = 'solid';
        if (block.config.active_indicator === 'fill' && block.config.active_bg_style === 'none') block.config.active_bg_style = 'solid';
        block.config.active_bg_image = toImageMap(block.config.active_bg_image);
        block.config.active_bg_image_aspect = toAspectMap(block.config.active_bg_image_aspect);
        if (!block.config.tab_animation) block.config.tab_animation = 'fade';
        if (block.config.active_tab_color_2 === undefined) block.config.active_tab_color_2 = '';
        if (block.config.active_outline_color === undefined) block.config.active_outline_color = '';
        if (block.config.active_tab_text_color === undefined) block.config.active_tab_text_color = '';
        block.items = block.items.map((t) => {
          const fresh = newTabItem();
          return {
            ...fresh, ...(t || {}),
            id: (t && t.id) || fresh.id,
            title: (t && t.title && typeof t.title === 'object') ? t.title : {},
            image: { ...newImage(), ...((t && t.image) || {}) },
            config: normalizeSourceFilter({ ...fresh.config, ...((t && t.config) || {}) }),
          };
        });
      }
    });
  });
  return {
    sections,
    background_theme: cfg.background_theme === 'image' ? 'image' : 'color',
    background_color: cfg.background_color || '#FFE94B',
    background_image_url: toImageMap(cfg.background_image_url),
    text_color: cfg.text_color || '#000000',
    header_icon_url: cfg.header_icon_url || '',
    search_suggestions: normSuggestions(cfg.search_suggestions),
    background_quick: normBg(cfg.background_quick),
    background_ecommerce: normBg(cfg.background_ecommerce),
  };
}

/**
 * Search-bar hints: a plain list of words, trimmed and de-duplicated.
 *
 * This function is also what protects the editor from a layout saved before the
 * field existed, where the key is simply absent.
 */
function normSuggestions(value) {
  if (!Array.isArray(value)) return [];
  const out = [];
  value.forEach((v) => {
    const text = String(v == null ? '' : v).trim();
    if (text && !out.includes(text)) out.push(text);
  });
  return out;
}

// Deep-clone a section blob and re-stamp every id so paste/insert
// never collides with an existing draft's section/block keys.
/**
 * Where a clickable banner / title image / text section can send the customer.
 * Shared by RedirectPicker and BannerItemRow so the two never drift apart.
 */
export function redirectTypeOptions() {
    return [
        { id: 'none', name: __('no_redirect') },
        { id: 'product', name: __('product') },
        { id: 'category', name: __('category') },
        { id: 'brand', name: __('brand') },
        { id: 'page', name: __('page_builder') },
        { id: 'products', name: __('filtered_product_list') },
        { id: 'url', name: __('url') },
    ];
}

const attributeOptionCache = new Map();

export function attributeValueOptions(categoryId = '') {
  const key = categoryId === '' || categoryId == null ? 'all' : String(categoryId);
  if (!attributeOptionCache.has(key)) {
    const params = key === 'all' ? {} : { category_id: key };
    attributeOptionCache.set(key, axios
      .get((window.baseUrl || '') + '/api/attributes/dropdown', { params })
      .then((res) => {
        const rows = res.data?.data || [];
        const out = [];
        rows.forEach((attr) => {
          (attr.active_values || attr.activeValues || []).forEach((val) => {
            out.push({ id: val.id, name: `${attr.name}: ${val.value}` });
          });
        });
        return out;
      })
      .catch((e) => {
        attributeOptionCache.delete(key);
        throw e;
      }));
  }
  return attributeOptionCache.get(key);
}

/** Redirect-picker rows for pages; a page that isn't live yet says so in its label. */
export function pageOptions(rows) {
    return (rows || []).map(p => {
        let name = p.name;
        if (p.status !== 'published') name += ' (' + __('draft') + ')';
        else if (!p.is_active) name += ' (' + __('inactive') + ')';
        return { id: p.id, name };
    });
}

export function cloneAndReidSection(section) {
  const clone = JSON.parse(JSON.stringify(section || {}));
  clone.id = genId('sec');
  (clone.blocks || []).forEach((b) => { b.id = genId('blk'); });
  return clone;
}

// Build a {langId: text} map for a translatable field, pre-filled with `text`
// on the active default language only. Falls back to an empty map when no
// language id is known (rare, e.g. multilingual disabled).
function titleMap(defaultLangId, text) {
  if (!text) return {};
  if (defaultLangId == null || defaultLangId === '') return { 0: text };
  return { [defaultLangId]: text };
}

// Built-in section presets. Each `build(defaultLangId)` returns a ready-to-insert
// section object compatible with normalizeConfig + the customer resolver.
// The defaultLangId is used to seed translatable fields (section_title etc.)
// with the template's default English copy.
export const BUILTIN_TEMPLATES = [
  {
    id: 'tpl-hero-banner',
    name: 'Hero Banner Slider',
    description: 'Full-width auto-scrolling banners. Promos & announcements.',
    icon: 'Images',
    section_type: 'banner_slider',
    build: () => ({
      ...newSection('banner_slider'),
      margin_top: 0, margin_bottom: 8, border_radius: 0,
      blocks: [(() => {
        const b = newBlock('banner_slider');
        b.config.auto_scroll = true;
        b.config.speed_ms = 3000;
        b.config.infinite_loop = true;
        b.config.carousel_style = 'full_width';
        b.items = [newBannerItem(), newBannerItem()];
        return b;
      })()],
    }),
  },
  {
    id: 'tpl-category-rail',
    name: 'Category Showcase',
    description: 'Horizontal scrollable category chips for quick navigation.',
    icon: 'LayoutGrid',
    section_type: 'category_section',
    build: () => ({
      ...newSection('category_section'),
      margin_bottom: 8, border_radius: 12,
      blocks: [(() => {
        const b = newBlock('category_section');
        b.layout = 'horizontal';
        b.config.category_gap = { app: 10, web: 10, tablet: 10 };
        b.config.category_radius = { app: 16, web: 16, tablet: 16 };
        return b;
      })()],
    }),
  },
  {
    id: 'tpl-flash-sale',
    name: 'Flash Sale Grid',
    description: '2×2 deal tile grid for limited-time offers.',
    icon: 'Zap',
    section_type: 'grid_banner',
    build: () => ({
      ...newSection('grid_banner'),
      margin_bottom: 12, border_radius: 12,
      blocks: [(() => {
        const b = newBlock('grid_banner');
        b.config.grid_columns = { app: 2, web: 2, tablet: 2 };
        b.config.grid_gap = { app: 8, web: 8, tablet: 8 };
        b.config.tile_radius = 10;
        b.items = [newBannerItem(), newBannerItem(), newBannerItem(), newBannerItem()];
        return b;
      })()],
    }),
  },
  {
    id: 'tpl-featured-products',
    name: 'Featured Products',
    description: 'Horizontally scrollable product carousel with title.',
    icon: 'Star',
    section_type: 'product_slider',
    build: (defaultLangId) => ({
      ...newSection('product_slider'),
      margin_top: 4, margin_bottom: 8,
      blocks: [(() => {
        const b = newBlock('product_slider');
        b.layout = 'horizontal';
        b.config.variant = 'with_title';
        b.config.section_title = titleMap(defaultLangId, 'Featured Products');
        b.config.data_source = 'manual';
        b.config.limit = 10;
        return b;
      })()],
    }),
  },
  {
    id: 'tpl-product-tabs',
    name: 'Tabbed Products',
    description: 'Menu tabs above a product row — each tab has its own source.',
    icon: 'PanelTop',
    section_type: 'product_tabs',
    build: (defaultLangId) => ({
      ...newSection('product_tabs'),
      margin_top: 4, margin_bottom: 8,
      blocks: [(() => {
        const b = newBlock('product_tabs');
        b.layout = 'horizontal';
        b.config.variant = 'with_title';
        b.config.section_title = titleMap(defaultLangId, "Today's Special Deals");
        b.config.limit = 10;
        b.items = ['Skin Care', 'Home Essentials', 'Grocery'].map((name) => {
          const t = newTabItem();
          t.title = titleMap(defaultLangId, name);
          t.config.data_source = 'top_selling';
          return t;
        });
        return b;
      })()],
    }),
  },
  {
    id: 'tpl-new-arrivals',
    name: 'New Arrivals Grid',
    description: '2-column product grid. Showcase new stock.',
    icon: 'Award',
    section_type: 'product_slider',
    build: (defaultLangId) => ({
      ...newSection('product_slider'),
      margin_top: 4, margin_bottom: 12,
      blocks: [(() => {
        const b = newBlock('product_slider');
        b.layout = 'grid';
        b.config.variant = 'with_title';
        b.config.section_title = titleMap(defaultLangId, 'New Arrivals');
        b.config.data_source = 'new_arrivals';
        b.config.limit = 6;
        b.config.grid_columns = { app: 2, web: 2, tablet: 2 };
        b.config.product_grid_gap = { app: 10, tablet: 10, web: 10 };
        b.config.product_card_radius = 10;
        return b;
      })()],
    }),
  },
  {
    id: 'tpl-best-branches',
    name: 'Best Branches Carousel',
    description: 'Top-selling products in a horizontal slider.',
    icon: 'Flame',
    section_type: 'product_slider',
    build: (defaultLangId) => ({
      ...newSection('product_slider'),
      margin_bottom: 8,
      blocks: [(() => {
        const b = newBlock('product_slider');
        b.layout = 'horizontal';
        b.config.variant = 'with_title';
        b.config.section_title = titleMap(defaultLangId, 'Best Branches');
        b.config.data_source = 'top_selling';
        b.config.limit = 8;
        return b;
      })()],
    }),
  },
  {
    id: 'tpl-promo-banner',
    name: 'Promo Banner Strip',
    description: 'Single full-width promotional banner.',
    icon: 'Gift',
    section_type: 'title_image',
    build: () => ({
      ...newSection('title_image'),
      margin_bottom: 8, border_radius: 16,
      blocks: [newBlock('title_image')],
    }),
  },
  {
    id: 'tpl-bg-product-slider',
    name: 'Products with Background',
    description: 'Product slider over a full-bleed background image.',
    icon: 'ImageIcon',
    section_type: 'product_slider',
    build: (defaultLangId) => ({
      ...newSection('product_slider'),
      margin_bottom: 12,
      blocks: [(() => {
        const b = newBlock('product_slider');
        b.layout = 'horizontal';
        b.config.variant = 'with_background';
        b.config.section_title = titleMap(defaultLangId, 'Top Picks');
        b.config.data_source = 'manual';
        b.config.limit = 10;
        b.config.block_padding = 12;
        return b;
      })()],
    }),
  },
  {
    id: 'tpl-deal-3col',
    name: 'Top Picks Grid (3-col)',
    description: 'Compact 3-column product grid, high density.',
    icon: 'Trophy',
    section_type: 'product_slider',
    build: (defaultLangId) => ({
      ...newSection('product_slider'),
      margin_top: 4, margin_bottom: 12,
      blocks: [(() => {
        const b = newBlock('product_slider');
        b.layout = 'grid';
        b.config.variant = 'with_title';
        b.config.section_title = titleMap(defaultLangId, 'Top Picks');
        b.config.data_source = 'discounted';
        b.config.limit = 9;
        b.config.grid_columns = { app: 3, web: 3, tablet: 3 };
        b.config.product_grid_gap = { app: 8, tablet: 8, web: 8 };
        b.config.product_card_radius = 8;
        return b;
      })()],
    }),
  },
  {
    id: 'tpl-brand-strip',
    name: 'Top Brands Strip',
    description: 'Horizontal brand logos with optional name.',
    icon: 'Tags',
    section_type: 'brand_section',
    build: (defaultLangId) => ({
      ...newSection('brand_section'),
      margin_bottom: 8,
      blocks: [(() => {
        const b = newBlock('brand_section');
        b.layout = 'horizontal';
        b.config.section_title = titleMap(defaultLangId, 'Top Brands');
        b.config.brand_gap = { app: 12, web: 12, tablet: 12 };
        b.config.show_name = true;
        return b;
      })()],
    }),
  },
];

// Resolve a translatable {langId: text} map to a single display string.
export function pickText(value, langId, defaultLangId) {
  if (typeof value === 'string') return value;
  if (!value || typeof value !== 'object') return '';
  if (value[langId]) return value[langId];
  if (value[defaultLangId]) return value[defaultLangId];
  const first = Object.values(value).find((v) => v);
  return first || '';
}
