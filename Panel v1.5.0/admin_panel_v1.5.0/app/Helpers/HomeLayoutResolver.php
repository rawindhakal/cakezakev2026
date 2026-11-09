<?php

namespace App\Helpers;

use App\Helpers\CustomerProductShaper;
use App\Models\Brand;
use App\Models\Category;
use App\Models\Favorite;
use App\Models\HomeLayout;
use App\Models\PageLayout;
use App\Models\Product;
use App\Models\ProductStockAlert;
use App\Models\RecentlyVisitedProduct;
use App\Services\LanguageService;
use App\Services\TaxService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Resolves the correct published Home Builder layout for a customer request
 * (by zone + channel + category) and populates each section/block with real
 * product / category / banner data ready for the app/web to render.
 */
class HomeLayoutResolver
{

    private int $defaultLangId;
    private ?int $langId;
    /** @var int[] */
    private array $branchIds = [];
    private ?int $userId = null;
    /** @var int[] */
    private array $favoriteIds = [];
    // Zone delivery info — same for every product in the zone (one zone == one branch).
    private ?string $branchName = null;
    private int $timeToDeliver = 0;
    /** Device the caller asked for, or null when it wants every section. */
    private ?string $device = null;

    /** Section window: how many sections to return, and where to start. */
    private int $sectionOffset = 0;
    private ?int $sectionLimit = self::DEFAULT_SECTION_LIMIT;
    /** Active sections before the window was applied — lets the app know when to stop. */
    private int $totalSections = 0;
    // Zone currency — same for every product in the zone.
    private ?array $currency = null;
    /** @var array<int,string> redirect_id => product slug (per-request memo) */
    private array $productSlugCache = [];
    /** @var array<int,bool> page id => page is published + active (per-request memo) */
    private array $pageServableCache = [];
    /** @var array<int,string> page id => slug (per-request memo) */
    private array $pageSlugCache = [];

    public function __construct()
    {
        $defaultLang = (new LanguageService())->getDefaultLanguage();
        $this->defaultLangId = $defaultLang ? (int) $defaultLang->id : 0;
        $this->langId = LanguageService::getCurrentId() ?: $this->defaultLangId;
    }

    /**
     * @param int[] $branchIds zone-scoped branch ids (drives PVSS listing + product visibility).
     * @return array{layout: array, home_type: string, category_tabs: array}|null
     */
    /** Sections returned when the caller names no limit. */
    public const DEFAULT_SECTION_LIMIT = 6;

    public function sectionWindow(int $offset = 0, ?int $limit = self::DEFAULT_SECTION_LIMIT): self
    {
        $this->sectionOffset = max(0, $offset);
        $this->sectionLimit  = ($limit === null || $limit <= 0) ? null : $limit;

        return $this;
    }

    public function forDevice(?string $device): self
    {
        $this->device = in_array($device, self::PLATFORMS, true) ? $device : null;

        return $this;
    }

    public function resolve(string $channel, ?int $zoneId, $categoryId, array $branchIds = [], ?int $userId = null, ?string $branchName = null, int $timeToDeliver = 0, ?array $currency = null): ?array
    {
        $this->setContext($branchIds, $userId, $branchName, $timeToDeliver, $currency);

        $layout = $this->pickLayout($channel, $zoneId);
        if (!$layout) {
            return null;
        }

        $categoryTabs = [];
        if ($layout->home_type === 'category_wise') {
            // Per tab: pickCategoryLayout() returns the active tab's own config.
            $config = $this->pickCategoryLayout($layout, $channel, $categoryId, $categoryTabs);
        } else {
            $config = $layout->published_json ?: ['sections' => []];
            $bg = $config['background_' . $channel] ?? null;
            if (is_array($bg)) {
                $config['background_theme']     = $bg['theme'] ?? 'color';
                $config['background_color']     = $bg['color'] ?? '#ffffffff';
                $config['background_image_url'] = $this->deviceImages($bg['image_url'] ?? '');
                $config['text_color']           = $bg['text_color'] ?? '#000000';
            }
        }

        // Taken from whatever was served — the layout root for a single layout, the
        // active tab for a category-wise one — so each tab can carry its own hints.
        $this->searchSuggestions = self::normalizeSuggestions($config['search_suggestions'] ?? null, $this->langId, $this->defaultLangId);

        $populated = $this->populate($config, $channel);

        // Stored image values are storage-relative paths; serve absolute URLs.
        $populated = self::absolutizeImageUrls($populated);
        $categoryTabs = self::absolutizeImageUrls($categoryTabs);

        $result = [
            'layout'        => $populated,
            'total_sections' => $this->totalSections,
            'offset'        => $this->sectionOffset,
            'limit'         => $this->sectionLimit,
            'home_type'     => $layout->home_type,
            'home_layout_name' => $layout->name,
            'category_tabs' => $categoryTabs,
            'layout_mode'   => $layout->mode, // quick | ecommerce
        ];

        return $result;
    }

    /**
     * Populate a Page Builder page with the same zone / channel / branch gating a
     * home layout gets. A page has no header background and no category tabs —
     * only sections. Branch ids may be empty (no location yet): banners and text
     * still render, product blocks come back empty.
     */
    public function resolvePage(array $config, string $channel, array $branchIds = [], ?int $userId = null, ?string $branchName = null, int $timeToDeliver = 0, ?array $currency = null): array
    {
        $this->setContext($branchIds, $userId, $branchName, $timeToDeliver, $currency);

        $populated = self::absolutizeImageUrls($this->populate($config, $channel));

        return [
            'sections'       => $populated['sections'] ?? [],
            'total_sections' => $this->totalSections,
            'offset'         => $this->sectionOffset,
            'limit'          => $this->sectionLimit,
        ];
    }

    /** The customer context shared by resolve() and resolvePage(). */
    private function setContext(array $branchIds, ?int $userId, ?string $branchName, int $timeToDeliver, ?array $currency): void
    {
        $this->branchIds      = array_values(array_filter(array_map('intval', $branchIds)));
        $this->userId        = $userId;
        $this->branchName     = $branchName;
        $this->timeToDeliver = $timeToDeliver;
        $this->currency      = $currency;
    }

    public function activeCategoryId(): ?int
    {
        return $this->activeCategoryId;
    }

    /**
     * The search-bar hints an admin typed for whatever was actually served: the
     * layout's own list for a single layout, the active tab's list for a
     * category-wise one. Empty when nothing was set, which is the caller's cue to
     * fall back to random product names.
     *
     * @return string[]
     */
    public function searchSuggestions(): array
    {
        return $this->searchSuggestions;
    }

    /** Resolve the button label of a channel's layout for a location (flattened). */
    public function channelLabel(string $channel, ?int $zoneId): string
    {
        $layout = $this->pickLayout($channel, $zoneId, true);
        return $layout ? $this->labelOf($layout) : self::defaultChannelLabel($channel);
    }

    /** Layout's button label, falling back to the channel default. */
    private function labelOf(HomeLayout $layout): string
    {
        $label = $this->flattenText($layout->channel_label ?? []);
        return $label !== '' ? $label : self::defaultChannelLabel($layout->mode);
    }

    /** Default button label per channel when none is set. */
    private static function defaultChannelLabel(string $channel): string
    {
        return $channel === 'ecommerce' ? 'Shop All' : 'Quick';
    }

    /**
     * Most-specific-wins: a zone-scoped layout containing $zoneId beats a global
     * one; ties broken by latest published_at.
     */
    private function pickLayout(string $channel, ?int $zoneId, bool $labelOnly = false): ?HomeLayout
    {
        if ($zoneId) {
            $zoneLayout = $this->newestPublished($channel, 'zone', $zoneId, $labelOnly);
            if ($zoneLayout) {
                return $zoneLayout;
            }
        }

        // Fallback: the global layout for this channel.
        return $this->newestPublished($channel, 'global', null, $labelOnly);
    }

    /**
     * The most recently published layout for a scope.
     *
     * Picks the id first and loads the row second, on purpose. A `SELECT * … ORDER BY`
     * drags every candidate's JSON columns through MySQL's sort buffer; with several
     * published layouts and the stock 256K buffer that fails with "Out of sort
     * memory" and the whole home screen goes blank. Sorting a handful of ids costs
     * nothing and the row is fetched once, by primary key.
     */
    private function newestPublished(string $channel, string $scope, ?int $zoneId = null, bool $labelOnly = false): ?HomeLayout
    {

        $key = $channel . '|' . $scope . '|' . $zoneId;
        if (array_key_exists($key, $this->publishedCache)) {
            return $this->publishedCache[$key];
        }
        if ($labelOnly && array_key_exists($key . '|label', $this->publishedCache)) {
            return $this->publishedCache[$key . '|label'];
        }

        $id = HomeLayout::where('status', 'published')
            ->where('is_active', 1)
            ->where('mode', $channel)
            ->where('zone_scope', $scope)
            ->when($zoneId !== null, fn ($q) => $q->where('zone_id', $zoneId))
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->value('id');

        if ($labelOnly) {
            return $this->publishedCache[$key . '|label'] = $id
                ? HomeLayout::select(['id', 'mode', 'channel_label'])->find($id)
                : null;
        }

        return $this->publishedCache[$key] = $id ? HomeLayout::find($id) : null;
    }

    /** @var array<string, HomeLayout|null> */
    private array $publishedCache = [];

    /**
     * Pulls the per-category LayoutConfig (handling the same/split storage shape)
     * and fills $categoryTabs with the tab list for the rail.
     */
    /** Category of the tab being returned; null on the "All" tab or a single layout. */
    private ?int $activeCategoryId = null;
    /** @var string[] Admin-written search-bar hints for the layout/tab that was served. */
    private array $searchSuggestions = [];

    /** Cache of root category id => its own id + every descendant id. */
    private static array $subtreeCache = [];

    /** @var array<int, int[]>|null active parent id => active child ids */
    private static ?array $activeChildrenOf = null;

    /**
     * A category id + every active descendant id. Products hang off whichever category
     * they were filed under — a parent for some, a leaf for others — so scoping a parent
     * to an exact category_id would hide everything filed deeper.
     */
    public static function categorySubtreeIds(int $rootId): array
    {
        if (isset(self::$subtreeCache[$rootId])) {
            return self::$subtreeCache[$rootId];
        }

        // The tree is small; one fetch beats a recursive query per level, and one
        // fetch serves every root asked for in the request.
        if (self::$activeChildrenOf === null) {
            self::$activeChildrenOf = [];
            foreach (Category::where('status', 1)->get(['id', 'parent_id']) as $c) {
                self::$activeChildrenOf[(int) $c->parent_id][] = (int) $c->id;
            }
        }
        $childrenOf = self::$activeChildrenOf;

        $ids = [$rootId];
        $queue = [$rootId];
        while ($queue) {
            foreach ($childrenOf[array_shift($queue)] ?? [] as $kid) {
                if (!in_array($kid, $ids, true)) {
                    $ids[] = $kid;
                    $queue[] = $kid;
                }
            }
        }

        return self::$subtreeCache[$rootId] = $ids;
    }

    private function pickCategoryLayout(HomeLayout $layout, string $channel, $categoryId, array &$categoryTabs): array
    {
        $split = $layout->category_scope === 'split';
        $maps = $layout->category_layouts_published ?: [];

        if ($split) {
            $maps = $maps[$channel] ?? [];
            $catIds = $channel === 'quick'
                ? ($layout->category_ids_quick ?: [])
                : ($layout->category_ids_ecommerce ?: []);
        } else {
            $catIds = $layout->category_ids ?: [];
        }

        $tabsDef = (!$split) ? ($layout->category_tabs_published ?: []) : [];

        $bgFrom = fn ($cfg) => [
            'background_theme'     => $cfg['background_theme'] ?? 'color',
            'background_color'     => $cfg['background_color'] ?? '#ffffffff',
            'background_image_url' => $this->deviceImages($cfg['background_image_url'] ?? ''),
            'text_color'           => $cfg['text_color'] ?? '#000000',
            'header_icon_url'      => $cfg['header_icon_url'] ?? '',
        ];
        // Multilang tab name → the request-locale string.
        $pickName = function ($name) {
            if (is_array($name)) {
                $loc = app()->getLocale();
                return (string) ($name[$loc] ?? (reset($name) ?: ''));
            }
            return (string) $name;
        };

        $orderedKeys = [];

        if (!empty($tabsDef)) {
            foreach ($tabsDef as $tab) {
                if (array_key_exists('active', $tab) && !$tab['active']) {
                    continue;
                }
                $kind = $tab['kind'] ?? 'system';
                if ($kind === 'custom') {
                    $key = (string) ($tab['key'] ?? '');
                    if ($key === '') {
                        continue;
                    }
                    $categoryTabs[] = array_merge([
                        'id'        => $key,               // string key → no numeric category restriction
                        'name'      => $pickName($tab['name'] ?? ''),
                        'image_url' => $this->firstImage($tab['icon_url'] ?? ''),
                    ], $bgFrom($maps[$key] ?? []));
                    $orderedKeys[] = $key;
                } else { // system (any legacy 'all' tab is dropped)
                    $catId = (int) ($tab['category_id'] ?? 0);
                    $cat = $catId ? Category::where('id', $catId)->where('status', 1)->first() : null;
                    if (!$cat) {
                        continue;
                    }
                    $categoryTabs[] = array_merge([
                        'id'        => (string) $cat->id,   // string, matching custom tab ids
                        'name'      => $cat->name,
                        'image_url' => $cat->image_url,
                        'slug'      => $cat->slug,
                    ], $bgFrom($maps[(string) $cat->id] ?? []));
                    $orderedKeys[] = (string) $cat->id;
                }
            }
        } else {
            // Legacy: system categories in the categories-table order.
            $orderedCats = Category::whereIn('id', $catIds)->where('status', 1)
                ->orderBy('row_order')->orderBy('id')->get();
            foreach ($orderedCats as $cat) {
                $categoryTabs[] = array_merge([
                    'id'        => (string) $cat->id,
                    'name'      => $cat->name,
                    'image_url' => $cat->image_url,
                    'slug'      => $cat->slug,
                ], $bgFrom($maps[(string) $cat->id] ?? []));
                $orderedKeys[] = (string) $cat->id;
            }
        }

        // Resolve which tab's layout to return (default = first tab).
        $reqKey = ($categoryId !== null && $categoryId !== '') ? (string) $categoryId : '';
        $key = $reqKey !== '' ? $reqKey : (string) ($orderedKeys[0] ?? '');


        $this->activeCategoryId = ((int) $key > 0 && (string) (int) $key === $key) ? (int) $key : null;

        $config = $maps[$key] ?? null;
        return is_array($config) && isset($config['sections']) ? $config : ['sections' => []];
    }

    /**
     * Admin-written search hints, cleaned for the response.
     *
     * Entries are plain strings as the builder writes them. A language map is also
     * accepted — the rest of the builder's text is stored that way, so a future
     * translated field needs no change here or in the apps: locale code, then
     * language id, then whatever the map holds.
     *
     * @return string[]
     */
    private static function normalizeSuggestions($raw, ?int $langId = null, int $defaultLangId = 0): array
    {
        if (!is_array($raw)) {
            return [];
        }

        $out = [];
        foreach ($raw as $entry) {
            if (is_array($entry)) {
                $entry = $entry[app()->getLocale()]
                    ?? $entry[(string) $langId]
                    ?? $entry[(string) $defaultLangId]
                    ?? (reset($entry) ?: '');
            }
            if (is_scalar($entry)) {
                $text = trim((string) $entry);
                if ($text !== '' && !in_array($text, $out, true)) {
                    $out[] = $text;
                }
            }
            if (count($out) >= self::MAX_SEARCH_SUGGESTIONS) {
                break;
            }
        }

        return $out;
    }

    /** Hints past this many are dropped — the search bar rotates a few, not a catalogue. */
    private const MAX_SEARCH_SUGGESTIONS = 20;

    /* ---------------------------------------------------------------- */

    private function populate(array $config, string $channel): array
    {
        // Count first, then window: the offset must skip active sections, and a
        // disabled one must never consume a slot in the page.
        $active = [];
        foreach ($config['sections'] ?? [] as $section) {
            if (!filter_var($section['active'] ?? true, FILTER_VALIDATE_BOOLEAN)) {
                continue;
            }
            if (!$this->builtForDevice($section)) {
                continue;
            }
            $active[] = $section;
        }
        $this->totalSections = count($active);
        $active = array_slice($active, $this->sectionOffset, $this->sectionLimit);

        $sections = [];
        foreach ($active as $section) {
            $blocks = $section['blocks'] ?? [];
            foreach ($blocks as &$block) {
                $this->populateBlock($block, $channel);
            }
            unset($block);

            // Keep only the section root keys the client renders.
            $sections[] = [
                'id'            => $section['id'] ?? null,
                'type'          => $section['type'] ?? '',
                'margin_top'    => $section['margin_top'] ?? 0,
                'margin_bottom' => $section['margin_bottom'] ?? 0,
                'border_radius_corners' => $this->pickCorners($section['border_radius'] ?? 0),
                'blocks'        => $blocks,
            ];
        }

        // Clean layout root: sections + flattened background only (drop the raw
        // per-channel background_quick / background_ecommerce objects).
        return [
            'sections'             => $sections,
            'background_theme'     => $config['background_theme'] ?? 'color',
            'background_color'     => $config['background_color'] ?? '#ffffffff',
            'background_image_url' => $this->deviceImages($config['background_image_url'] ?? ''),
            'text_color'           => $config['text_color'] ?? '#000000',
            'header_icon_url'      => $config['header_icon_url'] ?? '',
        ];
    }

    /**
     * Config keys that are meaningful per block type. Everything else in the stored
     * config (the editor saves one fat config object for all types) is dropped from
     * the API response so app/web only see params relevant to the block they render.
     * Source-id lists (manual_product_ids / category_id / brand_ids / category_ids)
     * are intentionally excluded — the resolved products/categories/brands replace them.
     */
    private const CONFIG_KEYS = [
        'banner_slider'    => ['carousel_style', 'indicator', 'auto_scroll', 'infinite_loop', 'speed_ms', 'image_aspect'],
        'grid_banner'      => ['variant', 'section_title', 'text_color', 'background_color', 'background_image_url', 'bg_image_aspect', 'block_padding', 'grid_columns', 'grid_gap', 'grid_rows', 'grid_layout_type', 'tile_radius', 'image_aspect'],
        'category_section' => ['variant', 'text_color', 'item_text_color', 'background_color', 'background_image_url', 'bg_image_aspect', 'grid_columns', 'category_gap', 'category_radius', 'section_title'],
        // Occasion / relationship showcases share the category section's look.
        'occasion_section'     => ['variant', 'text_color', 'item_text_color', 'background_color', 'background_image_url', 'bg_image_aspect', 'grid_columns', 'category_gap', 'category_radius', 'section_title'],
        'relationship_section' => ['variant', 'text_color', 'item_text_color', 'background_color', 'background_image_url', 'bg_image_aspect', 'grid_columns', 'category_gap', 'category_radius', 'section_title'],
        'product_slider'   => ['variant', 'section_title', 'data_source', 'limit', 'grid_columns', 'product_grid_gap', 'product_card_radius', 'block_padding', 'background_image_url', 'background_color', 'text_color', 'image_aspect', 'shuffle_products'],
        // Tabs share one look; each tab's data source lives on the tab itself.
        'product_tabs'     => ['variant', 'section_title', 'limit', 'grid_columns', 'product_grid_gap', 'product_card_radius', 'block_padding', 'background_image_url', 'background_color', 'text_color', 'image_aspect', 'tab_style', 'tab_image_aspect', 'active_indicator', 'active_bg_style', 'active_tab_color', 'active_tab_color_2', 'active_outline_color', 'active_bg_image_url', 'active_bg_image_aspect', 'tab_text_color', 'active_tab_text_color', 'tab_animation'],
        'brand_section'    => ['variant', 'text_color', 'item_text_color', 'background_color', 'background_image_url', 'bg_image_aspect', 'grid_columns', 'brand_gap', 'brand_radius', 'show_name', 'section_title'],
        'text_section'     => ['text_align', 'text_color', 'background_color', 'section_title', 'section_subtitle'],
        'title_image'      => ['image_aspect'],
    ];

    /** Config keys stored as {app,tablet,web} numeric maps — shipped as-is, one value per platform. */
    private const DEVICE_KEYS = ['grid_columns', 'grid_gap', 'grid_rows', 'category_gap', 'category_radius', 'brand_gap', 'brand_radius', 'product_grid_gap'];

    /** Per-platform fallback for the keys above when left blank in the builder. */
    private const DEVICE_DEFAULTS = [
        'grid_rows'    => ['app' => 1, 'tablet' => 1, 'web' => 1],
    ];

    private const PLATFORMS = ['app', 'tablet', 'web'];

    /** Per-platform default image aspect ratio ("w:h") when none is set. */
    private const IMAGE_ASPECT_DEFAULTS = ['app' => '16:9', 'tablet' => '16:9', 'web' => '3:1'];

    /** Block types whose `layout` is editable in the builder (others have no layout UI). */
    private const LAYOUT_TYPES = ['category_section', 'product_slider', 'product_tabs', 'brand_section', 'occasion_section', 'relationship_section'];

    private const TABS_MAX = 8;
    private const TAB_LIMIT_MAX = 20;

    private function populateBlock(array &$block, string $channel): void
    {
        $type = $block['type'] ?? '';
        $cfg = is_array($block['config'] ?? null) ? $block['config'] : [];

        // Flatten translatable text fields.
        foreach (['section_title', 'section_subtitle'] as $tk) {
            if (isset($cfg[$tk])) {
                $cfg[$tk] = $this->flattenText($cfg[$tk]);
            }
        }
        // Resolve any background image carried in config.
        if (isset($cfg['background_image'])) {
            $cfg['background_image_url'] = $this->deviceImages($cfg['background_image']);
        }
        // Image aspect ratio ("w:h"), one per platform. The client derives
        // height = renderedWidth / ratio, matching the preview at any screen width.
        if (in_array($type, ['banner_slider', 'grid_banner', 'title_image', 'product_slider', 'product_tabs'], true)) {
            $cfg['image_aspect'] = $this->deviceAspects($cfg['image_aspect'] ?? null);
        }
        if ($type === 'product_tabs') {
            // Tab icons are small squares by default, unlike the wide banner ratios.
            $cfg['tab_image_aspect'] = $this->deviceAspects($cfg['tab_image_aspect'] ?? null, ['app' => '1:1', 'tablet' => '1:1', 'web' => '1:1']);
            // 'pill' was a tab style before the active-tab options existed: it is
            // text tabs with a filled active tab. Always ship the full option set.
            if (($cfg['tab_style'] ?? '') === 'pill') {
                $cfg['tab_style'] = 'text';
                $cfg['active_indicator'] = 'fill';
            }
            $cfg['tab_style']          = in_array($cfg['tab_style'] ?? '', ['icon_top', 'text'], true) ? $cfg['tab_style'] : 'icon_top';
            // 'folder' was a filled outline tab; it is now outline + a background.
            if (($cfg['active_indicator'] ?? '') === 'folder') {
                $cfg['active_indicator'] = 'outline';
            }
            $cfg['active_indicator']   = in_array($cfg['active_indicator'] ?? '', ['underline', 'fill', 'outline', 'none'], true) ? $cfg['active_indicator'] : 'underline';
            // none = hollow outline; a fill always has paint.
            $bgStyles = $cfg['active_indicator'] === 'outline' ? ['none', 'solid', 'gradient', 'image'] : ['solid', 'gradient', 'image'];
            $cfg['active_bg_style']    = in_array($cfg['active_bg_style'] ?? '', $bgStyles, true) ? $cfg['active_bg_style'] : ($cfg['active_indicator'] === 'outline' ? 'none' : 'solid');
            $cfg['active_bg_image_url'] = $this->deviceImages($cfg['active_bg_image'] ?? '');
            // Shape of the active tab when an image sits behind it (width : height).
            $cfg['active_bg_image_aspect'] = $this->deviceAspects($cfg['active_bg_image_aspect'] ?? null, ['app' => '1:1', 'tablet' => '1:1', 'web' => '1:1']);
            $cfg['active_tab_color']   = (string) ($cfg['active_tab_color'] ?? '');
            $cfg['active_tab_color_2'] = (string) ($cfg['active_tab_color_2'] ?? '');
            // Outlined tab stroke + baseline; empty means "use the active colour".
            $cfg['active_outline_color'] = (string) ($cfg['active_outline_color'] ?? '');
            $cfg['tab_text_color']     = (string) ($cfg['tab_text_color'] ?? '');
            // Active tab title; empty = derived (tab_text_color/white on a painted tab, else active_tab_color).
            $cfg['active_tab_text_color'] = (string) ($cfg['active_tab_text_color'] ?? '');
            $cfg['tab_animation']      = in_array($cfg['tab_animation'] ?? '', ['none', 'fade', 'slide'], true) ? $cfg['tab_animation'] : 'fade';
        }

        if (in_array($type, ['grid_banner', 'category_section', 'brand_section', 'occasion_section', 'relationship_section'], true)) {
            $cfg['bg_image_aspect'] = $this->deviceAspects($cfg['bg_image_aspect'] ?? null);
        }

        // Trim config down to the keys this block type actually uses.
        $allowed = self::CONFIG_KEYS[$type] ?? [];
        $cleanCfg = [];
        foreach ($allowed as $key) {
            if (array_key_exists($key, $cfg)) {
                $cleanCfg[$key] = $cfg[$key];
            }
        }
        // Per-platform numbers ship as {app, tablet, web} — the client picks.
        foreach (self::DEVICE_KEYS as $dk) {
            if (array_key_exists($dk, $cleanCfg)) {
                $cleanCfg[$dk] = $this->deviceNums($cleanCfg[$dk], self::DEVICE_DEFAULTS[$dk] ?? null);
            }
        }

        // Rebuild a clean block: only the root keys this type needs.
        $clean = [
            'id'   => $block['id'] ?? null,
            'type' => $type,
        ];
        // layout only for types with a layout selector in the builder.
        if (in_array($type, self::LAYOUT_TYPES, true)) {
            $clean['layout'] = $block['layout'] ?? null;
        }
        // config only when this type actually has config fields.
        if (!empty($cleanCfg)) {
            $clean['config'] = $cleanCfg;
        }
        if (isset($block['caption'])) {
            $clean['caption'] = $this->flattenText($block['caption']);
        }

        if ($type === 'product_slider') {
            $resolved = $this->resolveProducts($cfg, $channel);
            $clean['products'] = $resolved['products'];
            $clean['viewMorePreviewImages'] = $resolved['viewMorePreviewImages'];
            // Echo back the source id(s) driving this slider — the explicit selection
            // of a manual/category/brand source, or the scope put on a dynamic one.
            $clean = array_merge($clean, self::sourceEcho($cfg));
        } elseif ($type === 'product_tabs') {
            $clean['tabs'] = $this->resolveTabs($block['items'] ?? [], $cfg, $channel);
        } elseif ($type === 'category_section') {
            $clean['categories'] = $this->resolveCategories($cfg, $channel);
        } elseif ($type === 'brand_section') {
            $clean['brands'] = $this->resolveBrands($cfg);
        } elseif ($type === 'occasion_section') {
            $clean['occasions'] = $this->resolveGiftingItems('occasions', $cfg['occasion_ids'] ?? []);
        } elseif ($type === 'relationship_section') {
            $clean['relationships'] = $this->resolveGiftingItems('relationships', $cfg['relationship_ids'] ?? []);
        } elseif (in_array($type, ['banner_slider', 'grid_banner'], true)) {
            $clean['items'] = $this->resolveItems($block['items'] ?? []);
        } elseif ($type === 'title_image') {
            $clean['images'] = $this->deviceImages($block['image'] ?? []);
            $clean += $this->redirectFields($cfg);
        } elseif ($type === 'text_section') {
            $clean += $this->redirectFields($cfg);
        }

        $block = $clean;
    }

    /**
     * The categories a product_slider draws from. Accepts the multi list and the
     * single `category_id` sliders saved before the list existed.
     *
     * @return int[]
     */
    private static function sliderCategoryIds(array $cfg): array
    {
        $ids = $cfg['slider_category_ids'] ?? [];
        if (!is_array($ids)) {
            $ids = [];
        }
        if (empty($ids) && isset($cfg['category_id']) && $cfg['category_id'] !== '') {
            $ids = [$cfg['category_id']];
        }

        return array_values(array_unique(array_filter(array_map('intval', $ids))));
    }

    private static function sourceFilter(array $cfg): ?array
    {
        $type = $cfg['filter_type'] ?? 'none';
        if (!in_array($type, ['category', 'brand'], true)) {
            return null;
        }

        $raw = $cfg[$type === 'category' ? 'filter_category_ids' : 'filter_brand_ids'] ?? [];
        $ids = array_values(array_unique(array_filter(array_map('intval', is_array($raw) ? $raw : []))));
        if (empty($ids)) {
            return null;
        }

        // A chosen parent covers everything filed deeper, same as the `category` source.
        if ($type === 'category') {
            $expanded = [];
            foreach ($ids as $id) {
                foreach (self::categorySubtreeIds($id) as $sub) {
                    $expanded[$sub] = true;
                }
            }
            $ids = array_keys($expanded);
        }

        return [
            'type' => $type,
            'mode' => ($cfg['filter_mode'] ?? 'include') === 'exclude' ? 'exclude' : 'include',
            'ids'  => $ids,
        ];
    }

    /**
     * Narrow a dynamic source to — or away from — a set of categories or brands.
     * `products.brand_id` is nullable and defaults to 0, so excluding brands must
     * keep the products that have no brand at all.
     */
    private static function applySourceFilter(Builder $query, array $cfg): void
    {
        $filter = self::sourceFilter($cfg);
        if ($filter === null) {
            return;
        }

        $column = $filter['type'] === 'category' ? 'category_id' : 'brand_id';
        if ($filter['mode'] === 'exclude') {
            $query->where(function ($q) use ($column, $filter) {
                $q->whereNotIn($column, $filter['ids'])->orWhereNull($column);
            });
        } else {
            $query->whereIn($column, $filter['ids']);
        }
    }

    /**
     * The source ids echoed alongside a resolved slider or tab so a "view more"
     * screen can reproduce the same list through customer/products. Category ids
     * are echoed already subtree-expanded, so the listing endpoint needs no tree
     * logic of its own, and a filtered dynamic source echoes under the very same
     * keys an explicit source does — existing app builds forward them already.
     */
    private static function sourceEcho(array $cfg): array
    {
        $source = $cfg['data_source'] ?? 'manual';
        if ($source === 'manual') {
            return ['manual_product_ids' => implode(',', array_map('intval', $cfg['manual_product_ids'] ?? []))];
        }
        if ($source === 'category') {
            return ['category_ids' => implode(',', self::sliderCategoryIds($cfg))];
        }
        if ($source === 'brand') {
            return ['brand_ids' => implode(',', array_map('intval', $cfg['brand_ids'] ?? []))];
        }

        $filter = self::sourceFilter($cfg);
        if ($filter === null) {
            return [];
        }

        $echo = [
            ($filter['type'] === 'category' ? 'category_ids' : 'brand_ids') => implode(',', $filter['ids']),
        ];
        if ($filter['mode'] === 'exclude') {
            $echo['filter_mode'] = 'exclude';
        }

        return $echo;
    }

    private function resolveProducts(array $cfg, string $channel): array
    {
        $empty = ['products' => [], 'viewMorePreviewImages' => []];
        $limit = (int) ($cfg['limit'] ?? 10);
        $limit = $limit > 0 ? min($limit, 50) : 10;
        $source = $cfg['data_source'] ?? 'manual';

        $branchIds = $this->branchIds;
        $query = Product::query()
            ->where('status', 1)
            ->where('is_draft', 0)
            ->taxonomyActive()
            ->notAddonOnly()
            ->whereIn('sales_channel', [$channel, 'both']);

        // Same visibility gate as the customer products listing: at least one
        // variant must have a listed PVSS row in a zone branch. Applied even with no
        // zone branches — an empty branch list must show nothing, not everything.
        $query->whereExists(function ($q) use ($branchIds) {
            $q->select(DB::raw(1))
                ->from('product_variants as pv')
                ->join('product_variant_branch_stocks as pvss', 'pvss.product_variant_id', '=', 'pv.id')
                ->whereColumn('pv.product_id', 'products.id')
                ->whereIn('pvss.branch_id', $branchIds ?: [0])
                ->where('pvss.is_listed', 1);
        });

        $explicitSources = ['manual', 'category', 'brand', 'occasion', 'relationship'];
        if (!in_array($source, $explicitSources, true)) {
            if ($this->activeCategoryId) {
                $query->whereIn('category_id', self::categorySubtreeIds($this->activeCategoryId));
            }

            self::applySourceFilter($query, $cfg);
        }

        if ($source === 'manual') {
            $ids = array_map('intval', $cfg['manual_product_ids'] ?? []);
            if (empty($ids)) {
                return $empty;
            }
            $query->whereIn('id', $ids)
                ->orderByRaw('FIELD(id,' . implode(',', $ids) . ')');
        } elseif ($source === 'category') {
            $catIds = self::sliderCategoryIds($cfg);
            if (empty($catIds)) {
                return $empty;
            }
            $subtree = [];
            foreach ($catIds as $catId) {
                $subtree = array_merge($subtree, self::categorySubtreeIds($catId));
            }
            $query->whereIn('category_id', array_values(array_unique($subtree)))
                ->orderByDesc('id');
        } elseif ($source === 'brand') {
            $brandIds = array_map('intval', $cfg['brand_ids'] ?? []);
            if (empty($brandIds)) {
                return $empty;
            }
            $query->whereIn('brand_id', $brandIds)->orderByDesc('id');
        } elseif ($source === 'occasion' || $source === 'relationship') {
            // Products tagged with any of the picked occasions / relationships
            // (products.occasions / products.relationships hold slugs).
            $table = $source === 'occasion' ? 'occasions' : 'relationships';
            $ids = array_values(array_filter(array_map('intval', $cfg[$source . '_ids'] ?? [])));
            $slugs = empty($ids) ? [] : DB::table($table)->whereIn('id', $ids)->pluck('slug')->all();
            if (empty($slugs)) {
                return $empty;
            }
            $column = $source === 'occasion' ? 'occasions' : 'relationships';
            $query->where(function ($q) use ($column, $slugs) {
                foreach ($slugs as $slug) {
                    $q->orWhereJsonContains($column, $slug);
                }
            })->orderByDesc('id');
        } elseif ($source === 'new_arrivals') {
            $query->orderByDesc('id');
        } elseif ($source === 'best_rated') {
            if (Schema::hasColumn('products', 'rating')) {
                $query->orderByDesc('rating');
            } else {
                $query->orderByDesc('id');
            }
        } elseif (in_array($source, ['discounted', 'offer'], true)) {
            // Price is per-branch (PVSS): "on discount" is evaluated in the zone's branches.
            $query->whereHas('variants.branchStocks', function ($q) use ($branchIds) {
                $q->whereIn('branch_id', $branchIds ?: [0])->where('is_listed', 1)
                    ->whereColumn('discounted_price', '<', 'price')
                    ->where('discounted_price', '>', 0);
            })->orderByDesc('id');
        } elseif ($source === 'recently_visited') {
            $userId = $this->userId;
            if (!$userId) {
                return $empty;
            }
            $ids = RecentlyVisitedProduct::where('user_id', $userId)
                ->orderByDesc('visited_at')
                ->orderByDesc('created_at')
                ->limit($limit)
                ->pluck('product_id')
                ->all();
            if (empty($ids)) {
                return $empty;
            }
            $query->whereIn('id', $ids)
                ->orderByRaw('FIELD(id,' . implode(',', $ids) . ')');
        } elseif ($source === 'buy_again') {
            $userId = $this->userId;
            if (!$userId) {
                return $empty;
            }
            $ids = DB::table('order_items as oi')
                ->join('product_variants as pv', 'oi.product_variant_id', '=', 'pv.id')
                ->where('oi.user_id', $userId)
                ->orderByDesc('oi.created_at')
                ->pluck('pv.product_id')
                ->unique()
                ->values()
                ->all();
            if (empty($ids)) {
                return $empty;
            }
            $query->whereIn('id', $ids)
                ->orderByRaw('FIELD(id,' . implode(',', $ids) . ')');
        } elseif ($source === 'trending') {
            // Most ordered in the last 30 days (windowed top_selling).
            $query->orderByDesc(DB::raw('(
                SELECT COUNT(*) FROM order_items oi
                JOIN product_variants pv ON oi.product_variant_id = pv.id
                WHERE pv.product_id = products.id
                  AND oi.created_at >= (NOW() - INTERVAL 30 DAY)
            )'));
        } elseif ($source === 'most_favorited') {
            $query->orderByDesc(DB::raw('(
                SELECT COUNT(*) FROM favorites WHERE favorites.product_id = products.id
            )'));
        } else {
            // top_selling / fallback — newest as a safe default.
            $query->orderByDesc('id');
        }

        // Shuffle wins over the source's own ordering: the point of the toggle is a
        // different set on every request, not a reshuffle of one fixed top slice.
        if (filter_var($cfg['shuffle_products'] ?? false, FILTER_VALIDATE_BOOLEAN)) {
            $query->reorder()->inRandomOrder();
        }

        // Fetch limit + 3 so the overflow can drive a "view more" preview.
        $products = $query->with([
            'variants',
            'variants.translations',
            'variants.images',
            'variants.branchStocks' => fn ($q) => $q->whereIn('branch_id', $branchIds ?: [0]),
            'variants.attributeValues.attribute.translations',
            'variants.attributeValues.attributeValue.translations',
            'brand.translations',
            'category.translations',
            'ratings',
            'translations',
        ])->limit($limit + 3)->get();

        $this->loadFavorites($products->pluck('id')->all());
        TaxService::warmFor($products->pluck('id')->all(), $branchIds);

        $cards = $products->take($limit)
            ->map(fn (Product $p) => CustomerProductShaper::shapeCard($p, $this->favoriteIds, $this->timeToDeliver, $this->branchName, $this->currency))
            ->values()->all();

        // Up to 3 preview images from the products BEYOND the limit (the "view more" set).
        $viewMore = [];
        foreach ($products->slice($limit, 3) as $p) {
            $shaped = CustomerProductShaper::shapeCard($p, $this->favoriteIds, $this->timeToDeliver, $this->branchName, $this->currency);
            $img = $shaped['images'][0]['image_url'] ?? '';
            if ($img !== '') {
                $viewMore[] = $img;
            }
        }

        return ['products' => $cards, 'viewMorePreviewImages' => $viewMore];
    }

    private function loadFavorites(array $productIds): void
    {
        if (!$this->userId || empty($productIds)) {
            $this->favoriteIds = [];
            return;
        }
        $this->favoriteIds = Favorite::where('user_id', $this->userId)
            ->whereIn('product_id', $productIds)
            ->pluck('product_id')
            ->all();
        // Cards also carry the customer's "notify me" flag per variant.
        CustomerProductShaper::setNotifyRequestedVariantIds(
            ProductStockAlert::waiting()->where('user_id', $this->userId)
                ->whereIn('product_id', $productIds)
                ->pluck('product_variant_id')->all()
        );
    }

    private function resolveBrands(array $cfg): array
    {
        $ids = array_map('intval', $cfg['brand_ids'] ?? []);
        if (empty($ids)) {
            return [];
        }
        return Brand::with('translations')->whereIn('id', $ids)
            ->where('status', 1)
            ->orderByRaw('FIELD(id,' . implode(',', $ids) . ')')
            ->get()
            ->map(fn ($b) => [
                'id'        => $b->id,
                'name'      => $b->name,
                'image_url' => $b->image_url,
            ])->all();
    }

    /** Active occasions / relationships, in the order the admin picked them. */
    private function resolveGiftingItems(string $table, array $ids): array
    {
        $ids = array_values(array_filter(array_map('intval', $ids)));
        if (empty($ids)) {
            return [];
        }
        return DB::table($table)->whereIn('id', $ids)->where('status', 1)
            ->orderByRaw('FIELD(id,' . implode(',', $ids) . ')')
            ->get()
            ->map(fn ($r) => [
                'id'        => (int) $r->id,
                'name'      => $r->name,
                'slug'      => $r->slug,
                'image_url' => $r->image ? asset('storage/' . ltrim($r->image, '/')) : asset('images/gift-placeholder.svg'),
            ])->all();
    }

    private function resolveCategories(array $cfg, string $channel): array
    {
        $ids = array_map('intval', $cfg['category_ids'] ?? []);
        if (empty($ids)) {
            return [];
        }

        $withProducts = array_flip(CommonHelper::categoryIdsWithProducts($this->branchIds, $channel));
        $ids = array_values(array_filter($ids, fn ($id) => isset($withProducts[$id])));
        if (empty($ids)) {
            return [];
        }
        // Which of these categories have at least one active child (single query).
        $parentsWithChild = Category::whereIn('parent_id', $ids)
            ->where('status', 1)
            ->distinct()
            ->pluck('parent_id')
            ->map(fn ($v) => (int) $v)
            ->all();
        $parentsWithChild = array_flip($parentsWithChild);

        return Category::with('translations')->whereIn('id', $ids)
            ->where('status', 1)
            ->orderByRaw('FIELD(id,' . implode(',', $ids) . ')')
            ->get()
            ->map(fn ($c) => [
                'id'        => $c->id,
                'name'      => $c->name,
                'slug'      => $c->slug,
                'image_url' => $c->image_url,
                'has_child' => isset($parentsWithChild[(int) $c->id]),
            ])->all();
    }

    /**
     * The tabs of a product_tabs block, each with its own products.
     *
     * A tab is a product_slider's data-source config wearing a title and an icon, so
     * each one goes through the same resolveProducts() the slider uses — same zone
     * and branch visibility gate, same shuffle, same sources. The tab's own config
     * wins over the block's, so `limit` set once at block level covers every tab
     * and any single tab can still override it.
     */
    private function resolveTabs(array $items, array $blockCfg, string $channel): array
    {
        $tabs = [];
        foreach (array_slice(array_values($items), 0, self::TABS_MAX) as $item) {
            if (!is_array($item)) {
                continue;
            }
            $tabCfg = is_array($item['config'] ?? null) ? $item['config'] : [];

            // Block-level presentation + block-level limit as the floor; the tab's own
            // data-source keys and any explicit limit on top.
            $cfg = array_merge(
                ['limit' => $blockCfg['limit'] ?? 10],
                array_filter($tabCfg, fn ($v, $k) => $k !== 'limit' || ($v !== null && $v !== ''), ARRAY_FILTER_USE_BOTH)
            );
            $cfg['limit'] = min(max(1, (int) ($cfg['limit'] ?? 10)), self::TAB_LIMIT_MAX);

            $resolved = $this->resolveProducts($cfg, $channel);
            $tab = [
                'id'                    => $item['id'] ?? null,
                'title'                 => $this->flattenText($item['title'] ?? ''),
                'images'                => $this->deviceImages($item['image'] ?? []),
                'data_source'           => $cfg['data_source'] ?? 'manual',
                'limit'                 => $cfg['limit'],
                'products'              => $resolved['products'],
                'viewMorePreviewImages' => $resolved['viewMorePreviewImages'],
            ];
            // Echo the source ids for this tab, exactly as a slider does.
            $tab = array_merge($tab, self::sourceEcho($cfg));
            $tabs[] = $tab;
        }

        return $tabs;
    }

    private function resolveItems(array $items): array
    {
        return array_values(array_map(fn ($item) => [
            'images' => $this->deviceImages($item['image'] ?? []),
        ] + $this->redirectFields($item), $items));
    }

    /**
     * The redirect keys every clickable block/item ships. A page redirect whose
     * target is unpublished, inactive or deleted degrades to 'none' so the app
     * never opens a dead page.
     */
    private function redirectFields(array $src): array
    {
        $type = $src['redirect_type'] ?? 'none';
        $id   = $src['redirect_id'] ?? null;
        if ($type === 'page' && !$this->pageServable((int) $id)) {
            $type = 'none';
            $id   = null;
        }

        $out = [
            'redirect_type' => $type,
            'redirect_id'   => $id,
            'redirect_slug' => $this->resolveRedirectSlug($type, $id),
            'has_child'     => $this->redirectHasChild($type, $id),
            'redirect_url'  => $src['redirect_url'] ?? '',
        ];

        // A filtered product listing ("Up to 50% off", "Shop red"). The client opens
        // its product list and passes redirect_params straight to customer/products
        // (and customer/products/filters) — no key translation on the client side.
        if ($type === 'products') {
            $out['redirect_title']  = $this->flattenText($src['redirect_filters']['title'] ?? '');
            $out['redirect_params'] = self::redirectParams($src['redirect_filters'] ?? []);
        }

        return $out;
    }

    /**
     * The saved filter set as customer/products query parameters. Empty values are
     * dropped so the client can send the map as-is, and every value is re-validated
     * here — a layout saved by an older panel, or hand-edited JSON, cannot smuggle
     * anything past the listing API.
     */
    private static function redirectParams($filters): array
    {
        if (!is_array($filters)) {
            return [];
        }

        $csv = function ($value): string {
            $ids = is_array($value) ? $value : explode(',', (string) $value);
            $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));
            return implode(',', $ids);
        };
        // Zero and below is dropped, not clamped to "0": a 0 bound narrows nothing
        // (min) or would empty the listing (max), so a negative or junk value saved
        // by hand must disappear rather than travel to the app as a real filter.
        $money = function ($value): string {
            if ($value === null || $value === '' || (float) $value <= 0) {
                return '';
            }
            return rtrim(rtrim(number_format((float) $value, 2, '.', ''), '0'), '.');
        };
        $percent = function ($value): string {
            if ($value === null || $value === '') {
                return '';
            }
            $n = min(100, (int) round((float) $value));
            return $n > 0 ? (string) $n : '';
        };

        // A single category only — the app's listing screen filters by one. A layout
        // saved while the panel offered a multi-select keeps the first id.
        $one = function ($value) use ($csv): string {
            $ids = explode(',', $csv($value));
            return $ids[0] ?? '';
        };

        $params = [
            'category_id'          => $one($filters['category_id'] ?? ($filters['category_ids'] ?? '')),
            'brand_ids'            => $csv($filters['brand_ids'] ?? []),
            'attribute_value_ids'  => $csv($filters['attribute_value_ids'] ?? []),
            'min_price'            => $money($filters['min_price'] ?? ''),
            'max_price'            => $money($filters['max_price'] ?? ''),
            'min_discount_percent' => $percent($filters['min_discount_percent'] ?? ''),
            'max_discount_percent' => $percent($filters['max_discount_percent'] ?? ''),
            'sort'                 => in_array($filters['sort'] ?? '', self::REDIRECT_SORTS, true)
                ? $filters['sort']
                : '',
        ];

        return array_filter($params, fn ($v) => $v !== '' && $v !== null);
    }

    /** Sorts a filtered-listing redirect may pin; anything else falls back to the app default. */
    private const REDIRECT_SORTS = ['new', 'popular', 'price_low', 'price_high', 'discount'];

    private function pageServable(int $id): bool
    {
        if ($id <= 0) {
            return false;
        }
        if (!array_key_exists($id, $this->pageServableCache)) {
            $this->pageServableCache[$id] = PageLayout::servable()->whereKey($id)->exists();
        }
        return $this->pageServableCache[$id];
    }

    /**
     * Slug of the redirect target. Product/category/page redirects carry a slug;
     * brand, url (and none) return ''. Per-request memoized to avoid N+1 lookups.
     */
    private function resolveRedirectSlug($type, $id): string
    {
        if (empty($id) || !in_array($type, ['product', 'category', 'page'], true)) {
            return '';
        }
        $id = (int) $id;
        if ($type === 'page') {
            if (!array_key_exists($id, $this->pageSlugCache)) {
                $this->pageSlugCache[$id] = (string) (PageLayout::whereKey($id)->value('slug') ?? '');
            }
            return $this->pageSlugCache[$id];
        }
        if ($type === 'product') {
            if (!array_key_exists($id, $this->productSlugCache)) {
                $this->productSlugCache[$id] = (string) (Product::where('id', $id)->value('slug') ?? '');
            }
            return $this->productSlugCache[$id];
        }
        return $this->categoryIndex()['slug'][$id] ?? '';
    }

    private function categoryIndex(): array
    {
        if ($this->categoryIndex === null) {
            $index = ['slug' => [], 'hasActiveChild' => []];
            foreach (Category::query()->toBase()->get(['id', 'parent_id', 'slug', 'status']) as $c) {
                $index['slug'][(int) $c->id] = (string) ($c->slug ?? '');
                if ((int) $c->status === 1 && $c->parent_id) {
                    $index['hasActiveChild'][(int) $c->parent_id] = true;
                }
            }
            $this->categoryIndex = $index;
        }

        return $this->categoryIndex;
    }

    private ?array $categoryIndex = null;

    private function redirectHasChild($type, $id): bool
    {
        if ($type !== 'category' || empty($id)) {
            return false;
        }
        return isset($this->categoryIndex()['hasActiveChild'][(int) $id]);
    }

    /**
     * Recursively convert storage-relative upload paths (home_builder/... or
     * page_builder/...) to absolute URLs. Legacy absolute URLs pass through untouched.
     */
    public static function absolutizeImageUrls($value)
    {
        if (is_array($value)) {
            return array_map([self::class, 'absolutizeImageUrls'], $value);
        }
        if (is_string($value) && (str_starts_with($value, 'home_builder/') || str_starts_with($value, 'page_builder/'))) {
            return CommonHelper::imageUrl($value);
        }
        return $value;
    }

    /**
     * A single image URL. Used where the builder only ever uploads one picture — a
     * category tab icon — so the client gets a plain string, not a platform map.
     */
    private function firstImage($image): string
    {
        if (!is_array($image)) {
            return is_string($image) ? $image : '';
        }
        foreach (['app', 'web', 'tablet'] as $p) {
            if (!empty($image[$p]) && is_string($image[$p])) {
                return $image[$p];
            }
        }

        return '';
    }

    /**
     * One image per platform. A value saved as a single string (before images went
     * per-platform) is used for all three, and a platform with no image of its own
     * borrows another's (app first, then web, then tablet) — uploading only the app
     * image still fills tablet and web.
     */
    private function deviceImages($image): array
    {
        if (!is_array($image)) {
            $one = is_string($image) ? $image : '';
            return ['app' => $one, 'tablet' => $one, 'web' => $one];
        }

        $fallback = '';
        foreach (['app', 'web', 'tablet'] as $p) {
            if (!empty($image[$p]) && is_string($image[$p])) {
                $fallback = $image[$p];
                break;
            }
        }

        $out = [];
        foreach (self::PLATFORMS as $p) {
            $own = $image[$p] ?? '';
            $out[$p] = (is_string($own) && $own !== '') ? $own : $fallback;
        }

        return $out;
    }

    /**
     * One number per platform. A value saved as a single number (before the field went
     * per-platform) is used for all three; a platform left blank falls back to its own
     * default, then to whatever another platform holds.
     */
    private function deviceNums($map, ?array $defaults = null): array
    {
        $num = function ($v) {
            return ($v !== '' && $v !== null && is_numeric($v)) ? (int) $v : null;
        };

        if (!is_array($map)) {
            $one = $num($map);
            if ($one !== null) {
                return ['app' => $one, 'tablet' => $one, 'web' => $one];
            }
            $map = [];
        }

        $out = [];
        foreach (self::PLATFORMS as $p) {
            $out[$p] = $num($map[$p] ?? null) ?? ($defaults[$p] ?? null);
        }
        // Nothing set for a platform: borrow another's rather than ship a null the
        // client would have to guess about.
        $fallback = null;
        foreach ($out as $v) {
            if ($v !== null) {
                $fallback = $v;
                break;
            }
        }
        foreach ($out as $p => $v) {
            if ($v === null) {
                $out[$p] = $fallback;
            }
        }

        return $out;
    }

    /**
     * One aspect ratio ("w:h") per platform. A single string (saved before ratios went
     * per-platform) applies to all three; a platform left blank takes its own default.
     */
    private function deviceAspects($aspect, ?array $defaults = null): array
    {
        $valid = fn ($v) => is_string($v) && str_contains($v, ':') ? $v : null;
        $defaults = $defaults ?? self::IMAGE_ASPECT_DEFAULTS;

        if ($one = $valid($aspect)) {
            return ['app' => $one, 'tablet' => $one, 'web' => $one];
        }

        $aspect = is_array($aspect) ? $aspect : [];
        $out = [];
        foreach (self::PLATFORMS as $p) {
            $out[$p] = $valid($aspect[$p] ?? null) ?? ($defaults[$p] ?? '16:9');
        }

        return $out;
    }

    private function builtForDevice(array $section): bool
    {
        if ($this->device === null) {
            return true;
        }
        $platforms = $section['platforms'] ?? null;
        if (!is_array($platforms) || !array_key_exists($this->device, $platforms)) {
            return true;
        }

        return filter_var($platforms[$this->device], FILTER_VALIDATE_BOOLEAN);
    }

    /**
     * A section's radius as four corners.
     */
    private function pickCorners($value): array
    {
        $flat = fn ($n) => [
            'top_left'     => (float) $n,
            'top_right'    => (float) $n,
            'bottom_left'  => (float) $n,
            'bottom_right' => (float) $n,
        ];

        if (!is_array($value)) {
            return $flat(is_numeric($value) ? $value : 0);
        }

        return [
            'top_left'     => (float) ($value['top_left'] ?? 0),
            'top_right'    => (float) ($value['top_right'] ?? 0),
            'bottom_left'  => (float) ($value['bottom_left'] ?? 0),
            'bottom_right' => (float) ($value['bottom_right'] ?? 0),
        ];
    }

    /**
     * Flattens a {langId: text} translatable map to the request language,
     * falling back to default language then any non-empty value.
     */
    public function flattenText($value): string
    {
        if (is_string($value)) {
            return $value;
        }
        if (!is_array($value)) {
            return '';
        }
        if (!empty($value[$this->langId])) {
            return $value[$this->langId];
        }
        if (!empty($value[$this->defaultLangId])) {
            return $value[$this->defaultLangId];
        }
        foreach ($value as $text) {
            if (!empty($text)) {
                return $text;
            }
        }
        return '';
    }
}
