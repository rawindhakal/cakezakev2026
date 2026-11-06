<?php

namespace App\Services\Shipping;

use App\Services\Shipping\HandlesReturnPickups;
use App\Services\Shipping\UsesVolumetricWeight;
use App\Plugins\Dto\ReturnPickupRequest;
use App\Plugins\Dto\ShippingQuoteRequest;
use App\Plugins\Registries\ShippingProviderRegistry;
use App\Helpers\CommonHelper;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\ReturnRequest;
use App\Models\ReturnStatusList;
use App\Models\Branch;
use App\Models\Zone;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * The core side of having a courier collect a return.
 *
 * The forward service's mirror: here the customer is the pickup and the branch is the
 * drop, and the only thing a provider decides is the rate and the waybill. Which returns
 * may be collected, what the parcel weighs and what the request's status becomes all
 * stay on this side.
 *
 * With no plugin installed — or a zone that does not use a courier — every method answers
 * "no provider", and the panel offers only the rider and manual tracking.
 */
final class ReturnShipmentService
{
    /** Opening the dialog twice must not bill two quote calls. */
    private const QUOTE_TTL = 300;

    public function __construct(private ShippingProviderRegistry $registry) {}

    /**
     * The carrier that can collect this return, if any.
     *
     * A request already booked keeps its carrier even after the zone stops using one —
     * the same rule as a forward parcel, for the same reason: a collection the courier is
     * already committed to still has to be finished.
     */
    public function providerFor(ReturnRequest $return, ?string $key = null): ?HandlesReturnPickups
    {
        if (!$this->zoneAllowsCourier($return)) {
            return null;
        }

        $countryCode = $this->countryCode($return);
        $provider = $key
            ? $this->registry->provider($key)
            : $this->registry->default('ecommerce', $countryCode);

        if (!$provider instanceof HandlesReturnPickups || !$provider->isConfigured()) {
            return null;
        }

        return $provider;
    }

    /**
     * What the panel needs before it can ask for reverse rates.
     *
     * @return array{ok:bool, message?:string, data?:array}
     */
    public function context(ReturnRequest $return, array $overrides = []): array
    {
        $item = OrderItem::find($return->order_item_id);
        if (!$item) {
            return ['ok' => false, 'message' => 'order_item_not_found'];
        }

        $order = Order::find($return->order_id);
        $branch = Branch::with('zone.country')->find($item->branch_id);
        if (!$order || !$branch) {
            return ['ok' => false, 'message' => 'branch_not_found'];
        }

        $pickup = $this->customerAddress($return, $order);
        $drop = $branch->pickupInfo();
        $provider = $this->providerFor($return);
        $parcel = $this->parcel($item, $provider, $overrides);

        $blocking = [];
        if (!$provider) {
            $blocking[] = $this->zoneAllowsCourier($return)
                ? 'no_shipping_provider_is_available'
                : 'this_zone_does_not_ship_by_courier';
        }
        // A guessed weight is a wrong reverse rate exactly as it is a wrong forward one.
        if (!empty($parcel['estimated_items'])) {
            $blocking[] = 'add_weight_to_these_products_first';
        }
        if (empty($pickup['pincode'])) {
            $blocking[] = 'customer_pincode_is_missing';
        }
        if (empty($pickup['city']) || empty($pickup['state'])) {
            $blocking[] = 'customer_city_or_state_is_missing';
        }
        if (empty($drop['pincode'])) {
            $blocking[] = 'branch_pickup_pincode_is_missing';
        }
        if (!$this->mayBook($return)) {
            $blocking[] = 'this_return_cannot_be_collected_at_this_stage';
        }

        return [
            'ok'   => empty($blocking),
            'data' => [
                'return_request_id' => (int) $return->id,
                'return_number'     => (string) $return->return_number,
                'order_number'      => (string) ($order->order_number ?? ''),
                'provider'          => $provider?->key(),
                'provider_name'     => $provider?->label(),
                'pickup'            => $pickup,     // the customer
                'drop'              => $drop,       // the branch
                'parcel'            => $parcel,
                'item'              => [
                    'id'       => (int) $item->id,
                    'name'     => $item->product_name,
                    'quantity' => (float) $item->quantity,
                ],
                'blocking'          => $blocking,
                'estimated'         => $parcel['estimated_items'],
            ],
            'message' => $blocking[0] ?? null,
        ];
    }

    /** Reverse rates for this return: the same pincode pair, travelling the other way. */
    public function quote(ReturnRequest $return, ?string $providerKey = null, array $overrides = []): array
    {
        $context = $this->context($return, $overrides);
        if (!$context['ok']) {
            return $context;
        }

        $provider = $this->providerFor($return, $providerKey);
        if (!$provider) {
            return ['ok' => false, 'message' => 'no_shipping_provider_is_available'];
        }

        $data = $context['data'];
        $request = new ShippingQuoteRequest(
            pickupPincode: (string) $data['pickup']['pincode'],      // from the customer
            deliveryPincode: (string) $data['drop']['pincode'],      // to the branch
            weight: (float) $data['parcel']['weight'],
            cod: false,                                              // nothing is collected on a return
            declaredValue: (float) $data['parcel']['declared_value'],
            length: (float) $data['parcel']['length'],
            breadth: (float) $data['parcel']['breadth'],
            height: (float) $data['parcel']['height'],
            branchId: (int) ($data['drop']['branch_id'] ?? 0),
            channel: 'ecommerce',
            countryCode: $this->countryCode($return),
        );

        try {
            $quotes = Cache::remember(
                $provider->key() . ':return:' . $request->cacheKey(),
                self::QUOTE_TTL,
                fn () => array_map(fn ($q) => $q->toArray(), $provider->quote($request))
            );
        } catch (\Throwable $e) {
            Log::error('[Shipping] return quote failed: ' . $e->getMessage());

            return ['ok' => false, 'message' => 'could_not_fetch_courier_rates'];
        }

        return [
            'ok'   => true,
            'data' => [
                'provider'      => $provider->key(),
                'provider_name' => $provider->label(),
                'serviceable'   => !empty($quotes),
                'couriers'      => $quotes,
            ],
        ];
    }

    /**
     * Book the collection.
     *
     * Writes the carrier's handles onto the return request, where the panel and the
     * status writer read them — the same columns a manually tracked return uses, so one
     * reverse journey reads the same however it was arranged.
     */
    public function createPickup(ReturnRequest $return, ?string $courierId = null, ?string $providerKey = null, array $overrides = []): array
    {
        $context = $this->context($return, $overrides);
        if (!$context['ok']) {
            return ['ok' => false, 'message' => (string) $context['message']];
        }

        $provider = $this->providerFor($return, $providerKey);
        if (!$provider) {
            return ['ok' => false, 'message' => 'no_shipping_provider_is_available'];
        }
        if (!empty($return->courier_shipment_id)) {
            return ['ok' => false, 'message' => 'this_return_is_already_booked_with_a_courier'];
        }
        if (!empty($return->tracking_id)) {
            return ['ok' => false, 'message' => 'this_return_already_has_a_tracking_number'];
        }

        $data = $context['data'];
        $item = OrderItem::find($return->order_item_id);
        $order = Order::find($return->order_id);

        $request = new ReturnPickupRequest(
            returnRequestId: (int) $return->id,
            returnNumber: (string) $return->return_number,
            orderId: (int) $return->order_id,
            orderNumber: (string) ($order->order_number ?? ''),
            items: [[
                'name'          => (string) $item->product_name,
                'sku'           => (string) ($item->product_variant_id ?: $item->id),
                'units'         => (int) max(1, (float) $item->quantity),
                'selling_price' => round((float) $item->price, 2),
                'hsn'           => (string) ($item->hsn_code ?? ''),
            ]],
            pickup: $data['pickup'],
            drop: $data['drop'],
            weight: (float) $data['parcel']['weight'],
            length: (float) $data['parcel']['length'],
            breadth: (float) $data['parcel']['breadth'],
            height: (float) $data['parcel']['height'],
            subTotal: round((float) $item->sub_total, 2),
            courierId: $courierId,
            requestDate: optional($return->created_at)->format('Y-m-d H:i'),
            reason: (string) ($return->return_reason ?? ''),
        );

        try {
            $result = $provider->createReturnPickup($request);
        } catch (\Throwable $e) {
            Log::error('[Shipping] return pickup failed: ' . $e->getMessage());

            return ['ok' => false, 'message' => 'could_not_book_the_return_pickup'];
        }

        if (!$result->ok) {
            return ['ok' => false, 'message' => $result->error ?: 'could_not_book_the_return_pickup'];
        }

        $return->courier_provider = $provider->key();
        $return->courier_shipment_id = $result->shipmentId ?: $result->providerOrderId;
        // Kept apart from the shipment id: a carrier that cancels by order refuses one.
        $return->courier_order_id = $result->providerOrderId;
        $return->courier_agency = $result->courierName ?: $provider->label();
        $return->tracking_id = $result->awb;
        $return->tracking_url = $result->trackingUrl;
        $return->courier_exception = null;
        $return->save();

        return [
            'ok'   => true,
            'data' => [
                'provider'     => $provider->key(),
                'shipment_id'  => $return->courier_shipment_id,
                'awb'          => $return->tracking_id,
                'courier_name' => $return->courier_agency,
                'tracking_url' => $return->tracking_url,
                'rate'         => $result->rate,
            ],
        ];
    }

    /** Call off a collection the carrier has not made yet. */
    public function cancelPickup(ReturnRequest $return): array
    {
        if (empty($return->courier_shipment_id)) {
            return ['ok' => false, 'message' => 'this_return_has_no_courier_pickup'];
        }
        if ((int) $return->status >= ReturnStatusList::$rReceivedFromCustomer) {
            return ['ok' => false, 'message' => 'the_parcel_is_already_collected'];
        }

        $provider = $this->providerFor($return, (string) $return->courier_provider ?: null);
        if (!$provider) {
            return ['ok' => false, 'message' => 'no_shipping_provider_is_available'];
        }

        try {
            $cancelled = $provider->cancelReturnPickup(
                (string) $return->courier_shipment_id,
                $return->courier_order_id ? (string) $return->courier_order_id : null
            );
        } catch (\Throwable $e) {
            Log::error('[Shipping] return pickup cancel failed: ' . $e->getMessage());

            return ['ok' => false, 'message' => 'could_not_cancel_the_return_pickup'];
        }

        if (!$cancelled) {
            return ['ok' => false, 'message' => 'could_not_cancel_the_return_pickup'];
        }

        // The request goes back to being a return nobody has collected yet.
        $return->courier_provider = null;
        $return->courier_shipment_id = null;
        $return->courier_order_id = null;
        $return->courier_agency = null;
        $return->tracking_id = null;
        $return->tracking_url = null;
        $return->courier_exception = null;
        $return->save();

        return ['ok' => true, 'message' => 'return_pickup_cancelled'];
    }

    /* ---------------------------------------------------------------- internals */

    /**
     * A return may be collected once it is accepted and before it is on its way.
     *
     * Rejected and refunded requests are finished, and a request already with a rider is
     * not something to hand to a courier as well.
     */
    public function mayBook(ReturnRequest $return): bool
    {
        if ((int) $return->delivery_boy_id > 0) {
            return false;
        }

        return in_array((int) $return->status, [
            ReturnStatusList::$rAccepted,
            ReturnStatusList::$rDeliveryBoyAssigned,
        ], true);
    }

    /** Does the return's zone ship by courier — or did it, for this request? */
    private function zoneAllowsCourier(ReturnRequest $return): bool
    {
        if (!empty($return->courier_shipment_id)) {
            return true;      // already booked; the journey has to be finishable
        }

        $order = Order::find($return->order_id);
        $zone = Zone::find((int) ($order->zone_id ?? 0));

        return $zone === null || in_array(
            Zone::DELIVERY_COURIER,
            CommonHelper::deliveryMethodsForZone($zone),
            true
        );
    }

    /** Where the parcel is collected from: the address the return was raised against. */
    private function customerAddress(ReturnRequest $return, ?Order $order): array
    {
        $raw = is_array($return->address) ? $return->address : (json_decode((string) $return->address, true) ?: []);

        // The return's own snapshot first, then the order's, then the address row —
        // a return raised before postal parts were stored still has to be collectable.
        $orderRaw = $order
            ? (is_array($order->address) ? $order->address : (json_decode((string) $order->address, true) ?: []))
            : [];

        $pick = fn (string $key) => (string) ($raw[$key] ?? ($orderRaw[$key] ?? ''));

        $address = [
            'name'    => $pick('name'),
            'address' => $pick('address'),
            'city'    => $pick('city'),
            'state'   => $pick('state'),
            'pincode' => $pick('pincode'),
            'country' => $pick('country'),
            'phone'   => (string) ($raw['mobile'] ?? ($orderRaw['mobile'] ?? ($order->mobile ?? ''))),
            'email'   => (string) (optional($order?->user)->email ?? ''),
        ];

        // The return's own copy of the pincode, then the order's.
        $address['pincode'] = $address['pincode']
            ?: (string) ($return->pickup_pincode ?? '')
            ?: (string) ($order->delivery_pincode ?? '');

        $gaps = array_keys(array_filter(
            ['address' => 1, 'city' => 1, 'state' => 1, 'pincode' => 1, 'country' => 1, 'name' => 1],
            fn ($_, $key) => $address[$key] === '',
            ARRAY_FILTER_USE_BOTH
        ));

        if ($gaps && $return->address_id) {
            $row = \App\Models\UserAddress::find($return->address_id);
            if ($row) {
                foreach ($gaps as $key) {
                    $address[$key] = (string) ($row->{$key} ?? '');
                }
            }
        }

        return $address;
    }

    /** The parcel going back: the one item, with whatever the admin corrected. */
    private function parcel(OrderItem $item, $provider, array $overrides): array
    {
        return app(ParcelCalculator::class)->fromOrderItems([$item], [
            'volumetric_divisor' => $provider instanceof UsesVolumetricWeight
                ? $provider->volumetricDivisor()
                : ParcelCalculator::DEFAULT_VOLUMETRIC_DIVISOR,
            'overrides'          => $overrides,
        ]);
    }

    private function countryCode(ReturnRequest $return): ?string
    {
        $order = Order::find($return->order_id);
        $code = (string) (\App\Models\Country::where('id', (int) ($order->country_id ?? 0))->value('code') ?? '');

        return $code !== '' ? strtoupper($code) : null;
    }
}
