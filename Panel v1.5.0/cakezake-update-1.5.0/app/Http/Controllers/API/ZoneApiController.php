<?php

namespace App\Http\Controllers\API;

use App\Plugins\Registries\ShippingProviderRegistry;
use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Country;
use App\Models\Order;
use App\Models\Region;
use App\Models\Zone;
use App\Services\LanguageService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class ZoneApiController extends Controller
{
    protected $languageService;

    public function __construct(LanguageService $languageService)
    {
        $this->languageService = $languageService;
    }

    public function getZones(Request $request)
    {
        $query = Zone::with('translations')->orderBy('id', 'desc');
        $limit = $request->input('limit', 5);
        $offset = $request->input('offset', 0);

        if ($request->has('search')) {
            $searchTerm = $request->input('search');
            $query->where(function ($q) use ($searchTerm) {
                $q->where('name', 'like', '%' . $searchTerm . '%')
                    ->orWhere('city', 'like', '%' . $searchTerm . '%')
                    ->orWhere('state', 'like', '%' . $searchTerm . '%');
            });
        }

        if ($request->filled('sales_channel')) {
            $query->where('sales_channel', $request->input('sales_channel'));
        }

        if ($request->filled('status')) {
            $query->where('status', (int) $request->input('status'));
        }

        // Global header country/zone filter.
        if ($request->filled('country_id')) {
            $query->where('country_id', (int) $request->input('country_id'));
        }
        if ($request->filled('zone_id')) {
            $query->where('id', (int) $request->input('zone_id'));
        }

        $total = $query->count();

        if ($request->limit) {
            $zones = $query->skip($offset)->take($limit)->get();
        } else {
            $zones = $query->get();
        }

        return CommonHelper::responseWithData($zones, $total);
    }

    private function generateZoneSlug(string $name, int $ignoreId = 0): string
    {
        $base = trim(strtolower(preg_replace('/[^a-z0-9]+/i', '-', $name)), '-');
        if ($base === '') {
            $base = 'zone';
        }

        $slug = $base;
        $i = 1;
        while (Zone::where('slug', $slug)->where('id', '!=', $ignoreId)->exists()) {
            $slug = $base . '-' . $i++;
        }
        return $slug;
    }

    public function save(Request $request)
    {
        $defaultLanguage = $this->languageService->getDefaultLanguage();
        $isDefaultLanguage = ($request->language_id == $defaultLanguage->id);

        if ($request->filled('id')) {
            $zone = Zone::find($request->id);
            if (!$zone) {
                return CommonHelper::responseError('Zone not found');
            }
        } else {
            if (!$isDefaultLanguage) {
                return CommonHelper::responseError('Please create zone in default language first');
            }

            $validator = Validator::make($request->all(), [
                'name'          => 'required',
                'sales_channel' => 'required|in:quick,ecommerce,both',
            ]);

            if ($validator->fails()) {
                return CommonHelper::responseError($validator->errors()->first());
            }

            $zone = new Zone();
        }

        if ($isDefaultLanguage) {
            $salesChannel = $request->input('sales_channel', 'quick');
            $salesChannel = in_array($salesChannel, Zone::CHANNELS, true) ? $salesChannel : Zone::CHANNEL_QUICK;

            // Slug is derived from the name, not entered in the form. Only (re)generate it when
            // the name actually changes so a rename updates it but an unrelated edit doesn't.
            $newName = $request->input('name');
            if (!$zone->exists || $zone->getOriginal('name') !== $newName || empty($zone->slug)) {
                $zone->slug = $this->generateZoneSlug($newName, (int) ($zone->id ?? 0));
            }

            $zone->name              = $newName;
            $zone->city              = $request->input('city');
            $zone->state             = $request->input('state');
            $zone->region_id         = $request->filled('region_id') ? (int) $request->input('region_id') : null;
            $zone->delivery_charge_is_taxable   = (int) $request->input('delivery_charge_is_taxable', 0);
            $zone->delivery_charge_tax_included = (int) $request->input('delivery_charge_tax_included', 0);
            $zone->delivery_charge_tax_category_id = $request->filled('delivery_charge_tax_category_id')
                ? (int) $request->input('delivery_charge_tax_category_id') : null;
            $zone->status           = (int) $request->input('status', 1);
            $zone->sales_channel    = $salesChannel;
            // One catchment per served channel — quick and ecommerce ranges differ.
            $zone->polygon_boundary_quick = $salesChannel === Zone::CHANNEL_ECOMMERCE ? null
                : $this->normalizePolygon($this->parseJsonInput($request->input('polygon_boundary_quick')));
            $zone->polygon_boundary_ecommerce = $salesChannel === Zone::CHANNEL_QUICK ? null
                : $this->normalizePolygon($this->parseJsonInput($request->input('polygon_boundary_ecommerce')));

            // ---- Country (source of currency + payment gateways now) ----
            $countryId = (int) $request->input('country_id');
            if (!$countryId || !Country::where('id', $countryId)->exists()) {
                return CommonHelper::responseError(__('country_is_required_for_the_zone'));
            }
            $zone->country_id = $countryId;

            if ($zone->region_id && !Region::where('id', $zone->region_id)->where('country_id', $countryId)->exists()) {
                return CommonHelper::responseError(__('region_does_not_belong_to_country'));
            }
            if ($zone->delivery_charge_is_taxable && !$zone->delivery_charge_tax_category_id) {
                return CommonHelper::responseError(__('tax_category_required_when_taxable'));
            }

            $isActive = (int) $zone->status === 1;

            foreach ($zone->servedChannels() as $ch) {
                $poly = $ch === Zone::CHANNEL_ECOMMERCE
                    ? $zone->polygon_boundary_ecommerce
                    : $zone->polygon_boundary_quick;

                if (!is_array($poly) || count($poly) < 3) {
                    return CommonHelper::responseError(
                        __('polygon_needs_at_least_three_points_for_channel', ['channel' => $ch])
                    );
                }
                if (!$isActive) {
                    continue;
                }
                $others = Zone::query()
                    ->where('id', '!=', $zone->id ?? 0)
                    ->where('status', 1)
                    ->serving($ch)
                    ->get(['id', 'name', 'sales_channel', 'polygon_boundary_quick', 'polygon_boundary_ecommerce']);
                foreach ($others as $other) {
                    $otherPoly = $this->normalizePolygon($other->polygonFor($ch));
                    if (!is_array($otherPoly) || count($otherPoly) < 3) {
                        continue;
                    }
                    if (CommonHelper::polygonsOverlap($poly, $otherPoly)) {
                        return CommonHelper::responseError(
                            __('polygon_overlaps_existing_zone_for_channel', ['zone' => $other->name, 'channel' => $ch])
                        );
                    }
                }
            }

            $zone->save();

            if ($this->servesChannel($salesChannel, Zone::CHANNEL_QUICK)) {
                $zone->distance_unit        = $request->input('quick_distance_unit', 'km');
                $zone->base_delivery_charge = (float) $request->input('quick_base_delivery_charge', 0);
                $zone->base_distance        = (float) $request->input('quick_base_distance', 0);
                $zone->charge_per_km        = (float) $request->input('quick_charge_per_km', 0);
                $zone->travel_time_per_km   = (float) $request->input('quick_travel_time_per_km', 0);
                $zone->minimum_order_amount = (float) $request->input('quick_minimum_order_amount', 0);
                $zone->free_delivery_above  = (float) $request->input('quick_free_delivery_above', 0);
                $zone->surge_slots          = $this->parseJsonInput($request->input('quick_surge_slots'));
                $zone->additional_charges_quick = $this->parseJsonInput($request->input('quick_additional_charges'));

                if (is_array($zone->surge_slots)) {
                    foreach ($zone->surge_slots as $idx => $slot) {
                        $row = $idx + 1;
                        if (trim((string) ($slot['label'] ?? '')) === '') {
                            return CommonHelper::responseError(__('surge_slot_label_is_required', ['row' => $row]));
                        }
                        if (trim((string) ($slot['start'] ?? '')) === '' || trim((string) ($slot['end'] ?? '')) === '') {
                            return CommonHelper::responseError(__('surge_slot_time_is_required', ['row' => $row]));
                        }
                        if ((float) ($slot['charge'] ?? 0) <= 0) {
                            return CommonHelper::responseError(__('surge_slot_charge_must_be_greater_than_zero', ['row' => $row]));
                        }
                        if (!empty($slot['is_taxable']) && empty($slot['tax_category_id'])) {
                            return CommonHelper::responseError(__('tax_category_required_when_taxable'));
                        }
                    }
                }
                if ($err = $this->validateCharges($zone->additional_charges_quick)) {
                    return CommonHelper::responseError($err);
                }
            }

            if ($this->servesChannel($salesChannel, Zone::CHANNEL_ECOMMERCE)) {
                $strategy = $request->input('ecommerce_pricing_strategy', 'flat');
                // 'courier' prices from a shipping plugin's live quote; with none
                // installed it falls back to the flat rule at charge time.
                $zone->pricing_strategy         = in_array($strategy, ['flat', 'slab', 'city', 'area', 'courier'], true) ? $strategy : 'flat';

                // What this zone adds to a courier's own rate before the customer sees it.
                $markup = (string) $request->input('ecommerce_courier_markup_type', 'none');
                $zone->courier_markup_type  = in_array($markup, ['none', 'percent', 'fixed'], true) ? $markup : 'none';
                $zone->courier_markup_value = max(0, (float) $request->input('ecommerce_courier_markup_value', 0));
                $zone->courier_round_to     = max(0, (float) $request->input('ecommerce_courier_round_to', 0));
                $zone->courier_min_charge   = max(0, (float) $request->input('ecommerce_courier_min_charge', 0));
                // Which doors this zone may use. An empty or nonsense choice means no
                // restriction rather than a zone nobody can ship from.
                $methods = $request->input('ecommerce_delivery_methods');
                $methods = is_array($methods) ? $methods : array_filter(array_map('trim', explode(',', (string) $methods)));
                $methods = array_values(array_intersect(Zone::DELIVERY_METHODS, $methods));
                $zone->ecommerce_delivery_methods = $methods ?: Zone::DELIVERY_METHODS;
                $zone->default_delivery_charge  = (float) $request->input('ecommerce_default_delivery_charge', 0);
                $zone->free_delivery_threshold  = (float) $request->input('ecommerce_free_delivery_threshold', 0);
                $zone->flat_delivery_charge     = (float) $request->input('ecommerce_flat_delivery_charge', 0);
                $zone->flat_free_delivery_above = (float) $request->input('ecommerce_flat_free_delivery_above', 0);
                $zone->slab_pricing             = $this->parseJsonInput($request->input('ecommerce_slab_pricing'));
                $zone->city_pricing             = $this->parseJsonInput($request->input('ecommerce_city_pricing'));
                $zone->area_pricing             = $this->parseJsonInput($request->input('ecommerce_area_pricing'));
                $zone->additional_charges_ecommerce = $this->parseJsonInput($request->input('ecommerce_additional_charges'));
                $zone->ecommerce_delivery_days  = max(0, (int) $request->input('ecommerce_delivery_days', 0));

                if ($err = $this->validateCharges($zone->additional_charges_ecommerce)) {
                    return CommonHelper::responseError($err);
                }
            }

            $zone->save();
        }

        // Labels sit on the zone translation, split per channel like the charges.
        $surgeLabels = $this->parseJsonInput($request->input('quick_surge_labels'));
        $quickNames  = $this->parseJsonInput($request->input('quick_additional_charge_names'));
        $ecomNames   = $this->parseJsonInput($request->input('ecommerce_additional_charge_names'));

        if (!is_array($surgeLabels)) {
            $surgeLabels = array_map(fn ($x) => $x['label'] ?? '', $zone->surge_slots ?? []);
        }
        if (!is_array($quickNames)) {
            $quickNames = array_map(fn ($c) => $c['name'] ?? '', $zone->additional_charges_quick ?? []);
        }
        if (!is_array($ecomNames)) {
            $ecomNames = array_map(fn ($c) => $c['name'] ?? '', $zone->additional_charges_ecommerce ?? []);
        }

        $zone->saveTranslation((int) $request->language_id, [
            'surge_labels'                      => $surgeLabels,
            'additional_charge_names_quick'     => $quickNames,
            'additional_charge_names_ecommerce' => $ecomNames,
        ]);

        return CommonHelper::responseWithData([
            'id'      => $zone->id,
            'message' => __('zone_saved_successfully'),
        ]);
    }


    /** Does a zone with $salesChannel serve $channel? ('both' serves either.) */
    protected function servesChannel(string $salesChannel, string $channel): bool
    {
        return $salesChannel === $channel || $salesChannel === Zone::CHANNEL_BOTH;
    }

    /** Shared validation for a channel's additional-charge rows. */
    protected function validateCharges($charges): ?string
    {
        if (!is_array($charges)) {
            return null;
        }
        foreach ($charges as $idx => $c) {
            $row = $idx + 1;
            if (trim((string) ($c['name'] ?? '')) === '') {
                return __('additional_charge_name_is_required', ['row' => $row]);
            }
            if ((float) ($c['amount'] ?? 0) <= 0) {
                return __('additional_charge_amount_must_be_greater_than_zero', ['row' => $row]);
            }
            if (!empty($c['is_taxable']) && empty($c['tax_category_id'])) {
                return __('tax_category_required_when_taxable');
            }
            // Which orders pay it. Absent = delivery, the pre-pickup behaviour.
            if (!in_array($c['applies_to'] ?? 'delivery', ['delivery', 'pickup', 'both'], true)) {
                return __('additional_charge_applies_to_is_invalid', ['row' => $row]);
            }
        }
        return null;
    }

    public function takenBoundaries(Request $request)
    {
        $channel = $request->input('sales_channel');
        if (!in_array($channel, Zone::REAL_CHANNELS, true)) {
            return CommonHelper::responseWithData(['zones' => []]);
        }

        $zones = Zone::query()
            ->where('status', 1)
            ->serving($channel)
            ->when($request->input('exclude_id'), fn ($q, $id) => $q->where('id', '!=', (int) $id))
            ->get(['id', 'name', 'sales_channel', 'polygon_boundary_quick', 'polygon_boundary_ecommerce']);

        $out = [];
        foreach ($zones as $z) {
            $points = $z->polygonFor($channel);
            if (!is_array($points) || count($points) < 3) {
                continue;
            }
            $out[] = [
                'id'     => (int) $z->id,
                // Raw name: this is a map label, not translated content.
                'name'   => $z->getRawOriginal('name') ?: ('Zone #' . $z->id),
                'points' => $points,
            ];
        }

        return CommonHelper::responseWithData(['zones' => $out]);
    }

    /**
     * The couriers a zone can name as one of its delivery methods.
     *
     * The form labels the checkbox with the carrier's own name — "Shiprocket" says more to
     * an admin than "shipping plugin" does — so it needs the installed provider, optionally
     * narrowed to the country the zone sits in.
     */
    public function courierProviders(Request $request)
    {
        $countryCode = null;
        if ($request->filled('country_id')) {
            $countryCode = (string) Country::where('id', (int) $request->input('country_id'))->value('code') ?: null;
        }

        $registry = app(ShippingProviderRegistry::class);
        $serving = array_keys($registry->usable('ecommerce', $countryCode));

        $providers = collect($registry->describe())
            ->filter(fn ($p) => in_array('ecommerce', $p['channels'], true))
            ->map(fn ($p) => [
                'key'        => $p['key'],
                'label'      => $p['label'],
                'icon'       => $p['icon'],
                'configured' => $p['configured'],
                // Installed and set up, and it serves this zone's country.
                'usable'     => in_array($p['key'], $serving, true),
            ])
            ->values()
            ->all();

        return CommonHelper::responseWithData(['providers' => $providers]);
    }

    public function edit($id)
    {
        $zone = Zone::with('translations')->find($id);
        if (!$zone) {
            return CommonHelper::responseError('Zone not found');
        }
        return CommonHelper::responseWithData($zone);
    }

    public function delete(Request $request)
    {
        if ($request->filled('id')) {
            $zone = Zone::find($request->id);
            if ($zone) {
                // Block delete when orders reference this zone (history must survive).
                if (Order::where('zone_id', $zone->id)->exists()) {
                    return CommonHelper::responseError('zone_in_use_deactivate_instead');
                }
                $zone->delete();
                return CommonHelper::responseSuccess('zone_deleted_successfully');
            }
            return CommonHelper::responseSuccess('zone_already_deleted');
        }
        return CommonHelper::responseError('Zone id required');
    }

    /**
     * Wrap each vertex's longitude into [-180, 180] so polygons drawn after
     * the user pans the map past the antimeridian (lng ends up at -290 etc.)
     * compare against zones drawn in the canonical range.
     */
    protected function normalizePolygon($polygon)
    {
        if (!is_array($polygon)) {
            return $polygon;
        }
        return array_map(function ($p) {
            if (!is_array($p) || !isset($p['lng'])) {
                return $p;
            }
            $lng = (float) $p['lng'];
            // Wrap into (-180, 180].
            $lng = fmod($lng + 180, 360);
            if ($lng < 0) {
                $lng += 360;
            }
            $p['lng'] = $lng - 180;
            return $p;
        }, $polygon);
    }

    protected function parseJsonInput($input)
    {
        if (is_null($input) || $input === '') {
            return null;
        }
        if (is_array($input)) {
            return $input;
        }
        $decoded = json_decode($input, true);
        return json_last_error() === JSON_ERROR_NONE ? $decoded : null;
    }

    /**
     * True if the gateway config map has at least one enabled method. A method is
     * enabled when its toggle key (`*_payment_method`) is truthy ("1"/1/true).
     */
    protected function hasEnabledPaymentMethod(array $gateways): bool
    {
        foreach ($gateways as $key => $value) {
            $isToggle = is_string($key) && str_ends_with($key, '_payment_method');
            if ($isToggle && in_array($value, [1, '1', true, 'true'], true)) {
                return true;
            }
        }
        return false;
    }
}
