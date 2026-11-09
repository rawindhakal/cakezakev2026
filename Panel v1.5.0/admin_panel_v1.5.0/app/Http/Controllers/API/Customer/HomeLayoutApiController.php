<?php

namespace App\Http\Controllers\API\Customer;

use App\Helpers\CommonHelper;
use App\Helpers\CustomerProductShaper;
use App\Helpers\HomeLayoutResolver;
use App\Http\Controllers\Controller;
use App\Models\PageLayout;
use App\Models\Branch;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class HomeLayoutApiController extends Controller
{
    /**
     * Resolves and returns the published Home Builder layout for the app/web,
     * populated with real products / categories / banners.
     *
     * Headers:
     *  - channel:     quick | ecommerce (optional, defaults to quick). Only
     *                 matters to disambiguate when a 'both' layout is matched;
     *                 channel-specific layouts ignore it.
     *  - Content-Language: language code for translatable text (optional)
     *
     * Query / form params:
     *  - latitude, longitude (required) — used to resolve the customer's zone.
     *  - category_id: optional, for category-wise layouts.
     *  - device:      app | tablet | web. Filters WHICH sections come back (each
     *                 section is built for chosen platforms). Values inside a section
     *                 stay per-platform. Omit it to get every section.
     *  - offset, limit: paging over SECTIONS only (default limit 6). What sits
     *                 inside a section is never trimmed by them. Pass limit=0 for
     *                 every section.
     */
    public function getHomeLayout(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude'  => 'required',
            'longitude' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $ctx = self::zoneContext((float) $request->latitude, (float) $request->longitude, $request->header('channel'));
        if (!$ctx) {
            return CommonHelper::responseError(__('not_deliverable_to_this_location'));
        }
        [
            'channel' => $channel, 'zone' => $zone, 'quickZone' => $quickZone, 'ecomZone' => $ecomZone,
            'availableModes' => $availableModes, 'availableMode' => $availableMode,
            'branchIds' => $branchIds, 'branchClosed' => $branchClosed, 'delivery' => $delivery,
            'branchName' => $branchName, 'timeToDeliver' => $timeToDeliver,
        ] = $ctx;

        $categoryId = $request->input('category_id');

        $userId = $request->user('api-customers') ? $request->user('api-customers')->id : null;

        // Sections are paged; everything inside a section always comes in full.
        $offset = max(0, (int) $request->input('offset', 0));
        $limit  = $request->has('limit')
            ? max(0, (int) $request->input('limit'))
            : HomeLayoutResolver::DEFAULT_SECTION_LIMIT;

        $device = in_array($request->input('device'), ['app', 'tablet', 'web'], true)
            ? $request->input('device') : null;

        $resolver = new HomeLayoutResolver();
        $resolver->forDevice($device)->sectionWindow($offset, $limit);
        $result = $resolver->resolve(
            $channel,
            (int) $zone->id,
            $categoryId,
            $branchIds,
            $userId,
            $branchName,
            $timeToDeliver,
            CommonHelper::countryCurrency($zone?->country)
        );

        // Button label(s): the served layout's label, plus per-channel labels for the
        // toggle (both channels' labels when the location supports both).
        $channelLabels = [];
        foreach ($availableModes as $m) {
            $z = $m === 'quick' ? $quickZone : $ecomZone;
            $channelLabels[$m] = $resolver->channelLabel($m, (int) $z->id);
        }

        $activeCategoryId = $resolver->activeCategoryId();
        $searchSuggestions = $resolver->searchSuggestions();
        if (!$searchSuggestions) {
            $searchSuggestions = CommonHelper::randomActiveProductNames(
                10,
                $channel,
                $branchIds,
                $activeCategoryId ? HomeLayoutResolver::categorySubtreeIds($activeCategoryId) : null
            );
            // A tab with nothing listed here yet still gets a placeholder, from the channel.
            if (!$searchSuggestions && $activeCategoryId) {
                $searchSuggestions = CommonHelper::randomActiveProductNames(10, $channel, $branchIds);
            }
        }

        if (!$result) {
            return CommonHelper::responseSuccessWithData('success', [
                'layout'        => ['sections' => []],
                'total_sections' => 0,
                'offset'        => $offset,
                'limit'         => $limit ?: null,
                'home_type'     => 'single',
                'category_tabs' => [],
                'zone_id'       => (int) $zone->id,
                'zone_slug'     => $zone->slug,
                'available_modes' => $availableMode,
                'layout_mode'     => null,
                'quick_button_label'    => $channelLabels['quick'] ?? null,
                'ecommerce_button_label' => $channelLabels['ecommerce'] ?? null,
                'search_suggestions'     => $searchSuggestions,
                'branch_closed'           => $branchClosed,
            ]);
        }

        $layoutMode = $result['layout_mode'] ?? null;
        unset($result['layout_mode']);

        $result['zone_id'] = (int) $zone->id;
        $result['zone_slug'] = $zone->slug;
        // available_modes: 'both' when the location supports quick + ecommerce (app
        // shows a toggle), else the single channel name.
        $result['available_modes'] = $availableMode;
        // layout_mode = which channel the served layout is for.
        $result['layout_mode'] = $layoutMode;
        // ecommerce_button_label = each channel's button name (null when not
        // available at this location).
        $result['quick_button_label']     = $channelLabels['quick'] ?? null;
        $result['ecommerce_button_label'] = $channelLabels['ecommerce'] ?? null;
        $result['search_suggestions']     = $searchSuggestions;
        // 1 = quick branch closed now (products shown, but cart/order blocked).
        $result['branch_closed']           = $branchClosed;

        if ($channel === 'quick') {
            $result['time_to_deliver'] = CustomerProductShaper::formatDeliveryTime($timeToDeliver, false);
            $result['distance']        = $delivery['distance'] . ' ' . $delivery['distance_unit'];
        }

        return CommonHelper::responseSuccessWithData('success', $result);
    }

    /**
     * A published Page Builder page, populated like the home layout.
     *
     * Params: slug or id (one required); latitude, longitude (optional — without a
     * deliverable location banners and text still render, product blocks come
     * back empty); device (app | tablet | web); offset, limit (sections).
     * Header `channel` picks quick | ecommerce when the location serves both.
     */
    public function getPage(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'id'        => 'nullable|integer|required_without:slug',
            'slug'      => 'nullable|string|required_without:id',
            'latitude'  => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $page = $request->filled('slug')
            ? PageLayout::servable()->where('slug', $request->slug)->first()
            : PageLayout::servable()->find((int) $request->id);
        if (!$page) {
            return CommonHelper::responseError('page_not_found');
        }

        $ctx = null;
        if ($request->filled('latitude') && $request->filled('longitude')) {
            $ctx = self::zoneContext((float) $request->latitude, (float) $request->longitude, $request->header('channel'));
        }

        // No location → the requested channel decides the product gating rules;
        // there are no branches, so product blocks resolve empty.
        $requested = strtolower(trim((string) $request->header('channel')));
        $channel   = $ctx['channel'] ?? (in_array($requested, ['quick', 'ecommerce'], true) ? $requested : 'quick');
        $zone      = $ctx['zone'] ?? null;

        $userId = $request->user('api-customers') ? $request->user('api-customers')->id : null;

        $offset = max(0, (int) $request->input('offset', 0));
        $limit  = $request->has('limit')
            ? max(0, (int) $request->input('limit'))
            : HomeLayoutResolver::DEFAULT_SECTION_LIMIT;

        $device = in_array($request->input('device'), ['app', 'tablet', 'web'], true)
            ? $request->input('device') : null;

        $resolver = new HomeLayoutResolver();
        $resolver->forDevice($device)->sectionWindow($offset, $limit);
        $result = $resolver->resolvePage(
            $page->published_json ?: ['sections' => []],
            $channel,
            $ctx['branchIds'] ?? [],
            $userId,
            $ctx['branchName'] ?? null,
            (int) ($ctx['timeToDeliver'] ?? 0),
            $zone ? CommonHelper::countryCurrency($zone->country) : null
        );

        return CommonHelper::responseSuccessWithData('success', [
            'page' => [
                'id'       => $page->id,
                'slug'     => $page->slug,
                'name'     => $page->name,
                'title'    => $resolver->flattenText($page->title),
                'header_color' => $page->header_color ?: '#FFFFFF',
                'title_color'  => $page->title_color ?: null,
                'seo'      => self::pageSeo($page),
                'sections' => $result['sections'],
            ],
            'total_sections' => $result['total_sections'],
            'offset'         => $result['offset'],
            'limit'          => $result['limit'] ?: null,
            'zone_id'        => $zone ? (int) $zone->id : null,
            'layout_mode'    => $channel,
        ]);
    }

    /** The page's SEO block with the OG image made absolute; null when none was written. */
    private static function pageSeo(PageLayout $page): ?array
    {
        $seo = is_array($page->seo) ? $page->seo : null;
        if (!$seo) {
            return null;
        }
        if (!empty($seo['og_image'])) {
            $seo['og_image'] = preg_match('#^https?://#', $seo['og_image'])
                ? $seo['og_image']
                : asset('storage/' . ltrim($seo['og_image'], '/'));
        }
        return $seo;
    }

    /**
     * Where a customer is and what serves them: the deliverable zone for the
     * requested channel, its branches, and the zone's delivery info. Null when
     * no zone delivers to the point (or the zone has no active branch). Shared
     * by the home layout and Page Builder endpoints.
     *
     * @return array{channel:string, zone:\App\Models\Zone, quickZone:mixed, ecomZone:mixed,
     *   availableModes:string[], availableMode:string, branchIds:int[], branchClosed:int,
     *   delivery:array, branchName:?string, timeToDeliver:int}|null
     */
    public static function zoneContext(float $lat, float $lng, ?string $requestedChannel): ?array
    {
        // Detect which channels this location is deliverable to. A point may sit in
        // a quick zone, an ecommerce zone, both, or neither (zones are per-channel).
        $quickZone = CommonHelper::getDeliverableCity($lat, $lng, 'quick');
        $ecomZone  = CommonHelper::getDeliverableCity($lat, $lng, 'ecommerce');

        $availableModes = [];
        if ($quickZone) {
            $availableModes[] = 'quick';
        }
        if ($ecomZone) {
            $availableModes[] = 'ecommerce';
        }
        if (empty($availableModes)) {
            return null;
        }

        // Requested channel (header). Honor it when available here; otherwise fall
        // back to the location's available channel (quick preferred).
        $requested = strtolower(trim((string) $requestedChannel));
        $channel = in_array($requested, $availableModes, true) ? $requested : $availableModes[0];
        $zone = $channel === 'quick' ? $quickZone : $ecomZone;

        $zoneBranches = Branch::where('status', 1)
            ->where('zone_id', $zone->id)
            ->get();

        if ($zoneBranches->isEmpty()) {
            return null;
        }

        $branchClosed = 0;
        if ($channel === 'quick') {
            $openBranches = $zoneBranches->filter(fn ($s) => CommonHelper::isBranchOpenNow($s));
            $branchClosed = ($zoneBranches->isNotEmpty() && $openBranches->isEmpty()) ? 1 : 0;
        }

        // One zone == one branch, so branch + delivery time are the same for every
        // product in the layout — resolve once. Delivery time is quick commerce only.
        $delivery = CustomerProductShaper::zoneDelivery($zone, $lat, $lng);

        return [
            'channel'        => $channel,
            'zone'           => $zone,
            'quickZone'      => $quickZone,
            'ecomZone'       => $ecomZone,
            'availableModes' => $availableModes,
            // 'both' when the location supports quick + ecommerce, else the single channel.
            'availableMode'  => count($availableModes) === 2 ? 'both' : $availableModes[0],
            'branchIds'       => $zoneBranches->pluck('id')->all(),
            'branchClosed'    => $branchClosed,
            'delivery'       => $delivery,
            'branchName'      => $delivery['branch_name'],
            'timeToDeliver'  => $channel === 'quick' ? (int) $delivery['time_to_deliver'] : 0,
        ];
    }
}
