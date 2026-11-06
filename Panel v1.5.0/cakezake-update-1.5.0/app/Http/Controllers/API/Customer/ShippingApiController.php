<?php

namespace App\Http\Controllers\API\Customer;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\ProductVariant;
use App\Models\Branch;
use App\Models\Zone;
use App\Services\Shipping\CourierPricing;
use App\Services\Shipping\ParcelCalculator;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * "Do you deliver to my pincode, and by when?"
 *
 * A guest can ask this from a product page before signing in, which is the whole point:
 * a shopper should learn a parcel cannot reach them before they fill a cart.
 *
 * The zone answers the question, not the carrier. A branch can hand an order to a delivery
 * boy or to a courier it tracks by hand, so a carrier that does not reach a pincode is
 * only one closed door out of three — `serviceable` therefore stays true unless the zone
 * delivers by courier alone (`ecommerce_delivery_methods`). The carrier's own
 * answer is reported separately as `courier_serviceable`, and it contributes the charge
 * and the delivery estimate, which is all a shopper actually gains from asking.
 */
class ShippingApiController extends Controller
{
    public function __construct(private CourierPricing $pricing) {}

    public function checkServiceability(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'pincode'            => 'required|string|max:16',
            'product_variant_id' => 'nullable|integer|exists:product_variants,id',
            'quantity'           => 'nullable|numeric|min:1',
            'branch_id'           => 'nullable|integer|exists:branches,id',
            'latitude'           => 'nullable|numeric',
            'longitude'          => 'nullable|numeric',
            'cod'                => 'nullable|boolean',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $countryCode = $this->countryCode($request);
        $pincode = trim((string) $request->pincode);
        /* The app knows where its customer is, so the zone comes from that point — the
           same gate the product page passed through. The branch follows from the zone,
           because the parcel leaves a branch and its pincode is what a carrier quotes from. */
        $zone = $this->zone($request);
        $branch = $this->branch($request, $zone);
        $zone = $zone ?: $branch?->zone;
        $blocks = $zone ? $zone->deliversByCourierOnly() : false;

        /* Nothing to ask, or nobody to ask: no plugin, no pickup pincode, or a zone that
           does not ship by courier — its riders decide, and no carrier is consulted. The
           order can still be placed; we simply cannot put a date or a charge against it. */
        $zoneUsesCourier = $zone === null
            || in_array(Zone::DELIVERY_COURIER, CommonHelper::deliveryMethodsForZone($zone), true);

        if (!$zoneUsesCourier || !$this->pricing->available($countryCode) || !$branch || empty($branch->pincode)) {
            return CommonHelper::responseWithData([
                'checked'             => false,
                'serviceable'         => true,
                'courier_serviceable' => null,
                'pincode'             => $pincode,
                'zone_id'             => $zone?->id,
                'message'             => __('courier_check_is_not_available'),
            ]);
        }

        $parcel = $this->parcel($request);

        $quote = $this->pricing->quotes([
            'delivery_pincode' => $pincode,
            'pickup_pincode'   => (string) $branch->pincode,
            'branch_id'         => (int) $branch->id,
            'weight'           => $parcel['weight'],
            'length'           => $parcel['length'],
            'breadth'          => $parcel['breadth'],
            'height'           => $parcel['height'],
            'declared_value'   => $parcel['declared_value'],
            'cod'              => (bool) $request->boolean('cod'),
            'country_code'     => $countryCode,
        ]);

        // The carrier was unreachable rather than unwilling — same answer as never asking.
        if (!$quote['checked']) {
            return CommonHelper::responseWithData([
                'checked'             => false,
                'serviceable'         => true,
                'courier_serviceable' => null,
                'pincode'             => $pincode,
                'zone_id'             => $zone?->id,
                'message'             => __('courier_check_is_not_available'),
            ]);
        }

        $courierServes = (bool) $quote['serviceable'];
        $cheapest = $quote['cheapest'];

        if ($courierServes) {
            $message = __('delivery_is_available_at_this_pincode');
        } elseif ($blocks) {
            $message = __('delivery_is_not_available_at_this_pincode');
        } else {
            // The branch still delivers here, just not through this carrier.
            $message = __('courier_cannot_reach_this_pincode_but_we_can_deliver');
        }

        return CommonHelper::responseWithData([
            'checked'             => true,
            'serviceable'         => $courierServes || !$blocks,
            'courier_serviceable' => $courierServes,
            'pincode'             => $pincode,
            'zone_id'             => $zone?->id,
            'charge'              => $cheapest['charge'] ?? null,
            'eta_days'            => $cheapest['eta_days'] ?? null,
            'eta_text'            => $cheapest['eta_text'] ?? null,
            'cod_available'       => collect($quote['couriers'])->contains(fn ($c) => !empty($c['cod_available'])),
            'message'             => $message,
        ]);
    }

    /* ---------------------------------------------------------------- helpers */

    /**
     * Which branch would ship this.
     *
     * A variant is stocked per branch, so the one that sells it is the one quoting; the
     * request may also name a branch outright (a branch-scoped storefront).
     */
    private function branch(Request $request, ?Zone $zone = null): ?Branch
    {
        if ($request->filled('branch_id')) {
            return Branch::find((int) $request->input('branch_id'));
        }

        // A zone resolved from the customer's location: ship from a branch of that zone.
        if ($zone) {
            $branch = Branch::where('zone_id', $zone->id)->where('status', 1)
                ->whereNotNull('pincode')->where('pincode', '!=', '')->first();
            if ($branch) {
                return $branch;
            }
        }

        if ($request->filled('product_variant_id')) {
            $branchId = \Illuminate\Support\Facades\DB::table('product_variant_branch_stocks')
                ->where('product_variant_id', (int) $request->input('product_variant_id'))
                ->value('branch_id');
            if ($branchId) {
                return Branch::find((int) $branchId);
            }
        }

        // Otherwise the customer's own cart tells us, and failing that the only branch
        // with a pickup pincode set.
        if ($user = auth('api')->user()) {
            $branchId = \Illuminate\Support\Facades\DB::table('carts')
                ->where('user_id', $user->id)->whereNotNull('branch_id')->value('branch_id');
            if ($branchId) {
                return Branch::find((int) $branchId);
            }
        }

        return Branch::whereNotNull('pincode')->where('pincode', '!=', '')->where('status', 1)->first();
    }

    /**
     * The zone the question is being asked from.
     *
     * Coordinates decide it when the app sends them, exactly as the product listing does;
     * otherwise the zone is left to the branch that ends up quoting.
     */
    private function zone(Request $request): ?Zone
    {
        if ($request->filled('latitude') && $request->filled('longitude')) {
            return CommonHelper::getDeliverableCity(
                (float) $request->input('latitude'),
                (float) $request->input('longitude'),
                'ecommerce'
            );
        }

        return null;
    }

    /** The parcel being quoted: this one variant, or the customer's cart. */
    private function parcel(Request $request): array
    {
        $calculator = app(ParcelCalculator::class);

        if ($request->filled('product_variant_id')) {
            $variant = ProductVariant::find((int) $request->input('product_variant_id'));

            return $calculator->fromLines([[
                'variant_id' => (int) $request->input('product_variant_id'),
                'quantity'   => (float) ($request->input('quantity') ?: 1),
                'name'       => (string) ($variant->name ?? ''),
                'value'      => (float) ($variant->discounted_price ?: $variant->price ?? 0) * (float) ($request->input('quantity') ?: 1),
            ]]);
        }

        if ($user = auth('api')->user()) {
            $rows = \Illuminate\Support\Facades\DB::table('carts')
                ->where('user_id', $user->id)
                ->get(['id', 'product_variant_id', 'qty']);
            if ($rows->isNotEmpty()) {
                return $calculator->fromCartItems($rows);
            }
        }

        // Nothing to weigh: quote a minimum parcel so the pincode itself is still checked.
        return $calculator->fromLines([['variant_id' => null, 'quantity' => 1]]);
    }

    private function countryCode(Request $request): ?string
    {
        $code = trim((string) $request->input('country_code', ''));
        if ($code !== '') {
            return strtoupper($code);
        }

        return null;
    }
}
