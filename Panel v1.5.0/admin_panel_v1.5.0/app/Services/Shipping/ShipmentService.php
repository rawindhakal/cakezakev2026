<?php

namespace App\Services\Shipping;

use App\Plugins\Dto\ShipmentRequest;
use App\Plugins\Dto\ShipmentResult;
use App\Plugins\Dto\ShippingQuoteRequest;
use App\Plugins\Dto\TrackingUpdate;
use App\Services\Shipping\HandlesDeliveryExceptions;
use App\Services\Shipping\PrintsShippingDocuments;
use App\Services\Shipping\ReportsQuoteFailure;
use App\Services\Shipping\UsesVolumetricWeight;
use App\Plugins\Registries\ShippingProviderRegistry;
use App\Models\Country;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusList;
use App\Models\Branch;
use App\Models\Transaction;
use App\Models\UserAddress;
use App\Models\Zone;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * The core side of handing a parcel to a courier.
 *
 * Everything a carrier is never allowed to decide lives here: which items may travel
 * together, what the parcel weighs, where it is going, and what happens to the order
 * afterwards. A provider only answers "for how much" and "here is your AWB".
 *
 * With no shipping plugin installed every method returns a plain "no provider" error, so
 * the panel simply never offers the option.
 */
final class ShipmentService
{
    /** Quotes are cached briefly: opening the dialog twice must not bill two API calls. */
    private const QUOTE_TTL = 300;

    public function __construct(private ShippingProviderRegistry $registry) {}

    /** Is any courier usable for this order at all? */
    /**
     * @param  array  $itemIds  the lines being acted on, so a parcel already with the
     *                          carrier keeps its courier even if the zone has since
     *                          stopped using one
     */
    public function providerFor(Order $order, ?string $key = null, array $itemIds = [])
    {
        // A zone that does not ship by courier has none, whatever is installed. Checked
        // here so the dialog, the quote and the booking all agree.
        if (!$this->zoneAllowsCourier($order, $itemIds)) {
            return null;
        }

        $countryCode = $this->countryCode($order);

        if ($key) {
            $provider = $this->registry->provider($key);

            return $provider && $provider->isConfigured() ? $provider : null;
        }

        return $this->registry->default('ecommerce', $countryCode);
    }

    private function extraCharges($items): float
    {
        $total = 0.0;
        foreach ($items as $item) {
            foreach ((array) $item->additional_charges as $charge) {
                $total += (float) ($charge['amount'] ?? 0);
            }
            foreach ((array) $item->surge_charges as $charge) {
                $total += (float) ($charge['charge'] ?? 0);
            }
        }

        return round($total, 2);
    }

    private function codAmountFor(Order $order, $items): float
    {
        if (!$this->isCod($order)) {
            return 0.0;
        }

        return round(min(
            round((float) $items->sum('final_total'), 2),
            round((float) $order->remaining_final, 2)
        ), 2);
    }

    /**
     * Does the order's zone use a courier — or did it, for these lines?
     *
     * A zone's methods decide what may still be handed over, never what already has been.
     * A parcel booked while the zone used a courier keeps its labels, its tracking and its
     * cancellation long after the zone has switched to its own riders; withdrawing the
     * provider from a consignment the carrier is holding would strand it.
     */
    private function zoneAllowsCourier(Order $order, array $itemIds = []): bool
    {
        $zone = Zone::find((int) ($order->zone_id ?? 0));
        if ($zone === null || $zone->allowsDeliveryMethod(Zone::DELIVERY_COURIER)) {
            return true;
        }

        $booked = OrderItem::where('order_id', $order->id)->whereNotNull('courier_shipment_id');
        if ($itemIds) {
            $booked->whereIn('id', $itemIds);
        }

        return $booked->exists();
    }

    /**
     * What the panel needs to open the ship dialog: the parcel as core computed it, the
     * addresses, and anything the admin must fix first.
     *
     * @return array{ok:bool, message?:string, data?:array}
     */
    /**
     * @param array $overrides  weight / length / breadth / height the admin typed, if any
     */
    public function context(Order $order, array $itemIds, array $overrides = []): array
    {
        $items = $this->shippableItems($order, $itemIds);
        if (is_string($items)) {
            return ['ok' => false, 'message' => $items];
        }

        $branch = Branch::with('zone.country')->find($items->first()->branch_id);
        if (!$branch) {
            return ['ok' => false, 'message' => 'branch_not_found'];
        }

        $pickup = $branch->pickupInfo();
        $shipping = $this->shippingAddress($order);
        $provider = $this->providerFor($order, null, $items->pluck('id')->all());
        $parcel = $this->parcel($items, $branch, $provider, $overrides);

        $blocking = [];
        if (!$provider) {
            $blocking[] = $this->zoneAllowsCourier($order, $items->pluck('id')->all())
                ? 'no_shipping_provider_is_available'
                : 'this_zone_does_not_ship_by_courier';
        }
        if (!empty($parcel['estimated_items'])) {
            $blocking[] = 'add_weight_to_these_products_first';
        }
        /* A box nobody measured is a quote for a parcel that does not exist: the carrier
           reweighs at its hub and bills the difference weeks later. The dialog leaves
           these fields empty and refuses to ask for rates; this is the same rule on the
           server, so a direct call cannot skip it. */
        if (empty($parcel['box_known'])) {
            $blocking[] = 'add_parcel_dimensions_first';
        }
        if (empty($pickup['pincode'])) {
            $blocking[] = 'branch_pickup_pincode_is_missing';
        }
        if (empty($shipping['pincode'])) {
            $blocking[] = 'customer_pincode_is_missing';
        }
        // Same reason as the reverse parcel: a carrier rejects an address with no town.
        if (empty($shipping['city']) || empty($shipping['state'])) {
            $blocking[] = 'customer_city_or_state_is_missing';
        }

        return [
            'ok'   => empty($blocking),
            'data' => [
                'order_id'      => (int) $order->id,
                'order_number'  => (string) $order->order_number,
                'provider'      => $provider?->key(),
                'provider_name' => $provider?->label(),
                'cod'           => $this->isCod($order),
                'cod_amount'    => $this->codAmountFor($order, $items),
                'pickup'        => $pickup,
                'shipping'      => $shipping,
                'parcel'        => $parcel,
                'items'         => $items->map(fn (OrderItem $i) => [
                    'id'       => (int) $i->id,
                    'name'     => $i->product_name,
                    'quantity' => (float) $i->quantity,
                    'status'   => (int) $i->active_status,
                    'awb'      => $i->tracking_id,
                ])->values()->all(),
                'blocking'      => $blocking,
                // Items whose variant has no weight, so the admin knows the parcel is
                // being estimated rather than measured.
                'estimated'     => $parcel['estimated_items'],
            ],
            'message' => $blocking[0] ?? null,
        ];
    }

    /**
     * Courier options for these items.
     *
     * @return array{ok:bool, message?:string, data?:array}
     */
    public function quote(Order $order, array $itemIds, ?string $providerKey = null, array $overrides = []): array
    {
        $context = $this->context($order, $itemIds, $overrides);
        if (!$context['ok']) {
            return $context;
        }

        $provider = $this->providerFor($order, $providerKey, $itemIds);
        if (!$provider) {
            return ['ok' => false, 'message' => 'no_shipping_provider_is_available'];
        }

        $data = $context['data'];
        $request = new ShippingQuoteRequest(
            pickupPincode: (string) $data['pickup']['pincode'],
            deliveryPincode: (string) $data['shipping']['pincode'],
            weight: (float) $data['parcel']['weight'],
            cod: (bool) $data['cod'],
            declaredValue: (float) $data['parcel']['declared_value'],
            length: (float) $data['parcel']['length'],
            breadth: (float) $data['parcel']['breadth'],
            height: (float) $data['parcel']['height'],
            branchId: (int) $data['pickup']['branch_id'],
            channel: 'ecommerce',
            countryCode: $this->countryCode($order),
        );

        try {
            $quotes = Cache::remember(
                $provider->key() . ':' . $request->cacheKey(),
                self::QUOTE_TTL,
                fn () => array_map(fn ($q) => $q->toArray(), $provider->quote($request))
            );
        } catch (\Throwable $e) {
            Log::error('[Shipping] quote failed: ' . $e->getMessage());

            return ['ok' => false, 'message' => 'could_not_fetch_courier_rates'];
        }

        return [
            'ok'   => true,
            'data' => [
                'provider'      => $provider->key(),
                'provider_name' => $provider->label(),
                'serviceable'   => !empty($quotes),
                'couriers'      => $quotes,
                'parcel'        => $data['parcel'],
                'message'       => empty($quotes) && $provider instanceof ReportsQuoteFailure
                    ? ($provider->lastQuoteMessage() ? __($provider->lastQuoteMessage()) : null)
                    : null,
            ],
        ];
    }

    /**
     * Book the parcel.
     *
     * The selected items travel as ONE consignment — the admin picked them together, so
     * they share an AWB, exactly like the panel's bulk courier-tracking action.
     *
     * @return array{ok:bool, message:string, data?:array}
     */
    public function createShipment(Order $order, array $itemIds, ?string $courierId = null, ?string $providerKey = null, ?int $adminId = null, array $overrides = []): array
    {
        $context = $this->context($order, $itemIds, $overrides);
        if (!$context['ok']) {
            return ['ok' => false, 'message' => (string) $context['message']];
        }

        $provider = $this->providerFor($order, $providerKey, $itemIds);
        if (!$provider) {
            return ['ok' => false, 'message' => 'no_shipping_provider_is_available'];
        }

        $items = $this->shippableItems($order, $itemIds);
        if (is_string($items)) {
            return ['ok' => false, 'message' => $items];
        }

        // Already booked? Two AWBs for one parcel is the worst outcome here.
        $booked = $items->filter(fn (OrderItem $i) => !empty($i->courier_shipment_id) || !empty($i->tracking_id));
        if ($booked->isNotEmpty()) {
            return ['ok' => false, 'message' => 'some_items_are_already_shipped'];
        }

        $data = $context['data'];
        $request = new ShipmentRequest(
            orderId: (int) $order->id,
            orderNumber: (string) $order->order_number,
            items: $items->map(fn (OrderItem $i) => [
                'name'          => (string) $i->product_name,
                'order_item_id' => (int) $i->id,
                'sku'           => (string) ($i->product_variant_id ?: $i->id),
                'units'         => (int) max(1, (float) $i->quantity),
                'selling_price' => round((float) ($i->discounted_price ?: $i->price), 2),
                'discount'      => round((float) $i->promo_discount, 2),
                'tax'           => round((float) $i->tax_amount, 2),
                'hsn'           => (string) ($i->hsn_code ?? ''),
            ])->values()->all(),
            pickup: $data['pickup'],
            shipping: $data['shipping'],
            billing: $this->billingAddress($order, $data['shipping']),
            weight: (float) $data['parcel']['weight'],
            length: (float) $data['parcel']['length'],
            breadth: (float) $data['parcel']['breadth'],
            height: (float) $data['parcel']['height'],
            subTotal: round((float) $items->sum('sub_total'), 2),
            cod: (bool) $data['cod'],
            codAmount: (float) $data['cod_amount'],
            shippingCharges: round((float) $items->sum('delivery_charge'), 2),
            otherCharges: $this->extraCharges($items),

            discount: round((float) $items->sum('promo_discount') + (float) $items->sum('wallet_balance'), 2),
            courierId: $courierId,
            orderDate: optional($order->created_at)->format('Y-m-d H:i'),
        );

        try {
            $result = $provider->createShipment($request);
        } catch (\Throwable $e) {
            Log::error('[Shipping] createShipment failed: ' . $e->getMessage());

            return ['ok' => false, 'message' => 'could_not_create_the_shipment'];
        }

        if (!$result->ok) {
            return ['ok' => false, 'message' => (string) ($result->error ?: 'could_not_create_the_shipment')];
        }

        $this->recordShipment($items, $provider->key(), $result);
        $this->recordEta($items, $request, $provider->key(), $courierId);

        // "Shipment created" is not "shipped": the carrier's own pickup event moves the
        // items on, through the same path a webhook uses.
        app(CourierStatusService::class)->apply(
            new TrackingUpdate(
                TrackingUpdate::CREATED,
                $result->awb,
                $result->shipmentId,
                $result->courierName,
                'shipment_created'
            ),
            $items->pluck('id')->map(fn ($id) => (int) $id)->all(),
            $adminId
        );

        return [
            'ok'      => true,
            'message' => 'shipment_created_successfully',
            'data'    => [
                'awb'          => $result->awb,
                'shipment_id'  => $result->shipmentId,
                'courier_name' => $result->courierName,
                'label_url'    => $result->labelUrl,
                'tracking_url' => $result->trackingUrl,
                'rate'         => $result->rate,
                'items'        => $items->pluck('id')->all(),
            ],
        ];
    }

    /** Ask the carrier to collect a parcel it has already accepted. */
    public function schedulePickup(Order $order, array $itemIds): array
    {
        [$provider, $shipmentId, $error, $providerOrderId] = $this->bookedShipment($order, $itemIds);
        if ($error) {
            return ['ok' => false, 'message' => $error];
        }

        try {
            return $provider->schedulePickup($shipmentId)
                ? ['ok' => true, 'message' => 'pickup_scheduled_successfully']
                : ['ok' => false, 'message' => 'could_not_schedule_the_pickup'];
        } catch (\Throwable $e) {
            Log::error('[Shipping] schedulePickup failed: ' . $e->getMessage());

            return ['ok' => false, 'message' => 'could_not_schedule_the_pickup'];
        }
    }

    /** A printable label for a booked parcel. */
    public function label(Order $order, array $itemIds): array
    {
        [$provider, $shipmentId, $error, $providerOrderId] = $this->bookedShipment($order, $itemIds);
        if ($error) {
            return ['ok' => false, 'message' => $error];
        }

        $stored = OrderItem::whereIn('id', $itemIds)->value('courier_label_url');
        if ($stored) {
            return ['ok' => true, 'message' => 'success', 'data' => ['label_url' => $stored]];
        }

        try {
            $url = $provider->labelUrl($shipmentId);
        } catch (\Throwable $e) {
            Log::error('[Shipping] labelUrl failed: ' . $e->getMessage());
            $url = null;
        }

        if (!$url) {
            return ['ok' => false, 'message' => 'label_is_not_available_yet'];
        }

        OrderItem::whereIn('id', $itemIds)->update(['courier_label_url' => $url]);

        return ['ok' => true, 'message' => 'success', 'data' => ['label_url' => $url]];
    }

    /**
     * Cancel a booked shipment.
     *
     * Only the shipment: the order items keep their status, because cancelling a parcel
     * is not cancelling a sale — the admin may rebook with another courier.
     */
    public function cancelShipment(Order $order, array $itemIds): array
    {
        [$provider, $shipmentId, $error, $providerOrderId] = $this->bookedShipment($order, $itemIds);
        if ($error) {
            return ['ok' => false, 'message' => $error];
        }

        try {
            $cancelled = $provider->cancelShipment($shipmentId, $providerOrderId);
        } catch (\Throwable $e) {
            Log::error('[Shipping] cancelShipment failed: ' . $e->getMessage());

            return ['ok' => false, 'message' => 'could_not_cancel_the_shipment'];
        }

        if (!$cancelled) {
            return ['ok' => false, 'message' => 'could_not_cancel_the_shipment'];
        }

        $consignment = OrderItem::where('order_id', $order->id)
            ->where('courier_shipment_id', $shipmentId)
            ->pluck('id')
            ->all();
        $itemIds = $consignment ?: $itemIds;

        OrderItem::whereIn('id', $itemIds)->update([
            'courier_shipment_id' => null,
            'courier_order_id'    => null,
            'courier_label_url'   => null,
            'tracking_id'         => null,
            'tracking_url'        => null,
        ]);

        return ['ok' => true, 'message' => 'shipment_cancelled_successfully'];
    }

    public function documents(Order $order, array $itemIds, string $document = 'labels'): array
    {
        $shipmentIds = OrderItem::whereIn('id', $itemIds)
            ->where('order_id', $order->id)
            ->whereNotNull('courier_shipment_id')
            ->pluck('courier_shipment_id')
            ->filter()->unique()->values()->all();

        if (empty($shipmentIds)) {
            return ['ok' => false, 'message' => 'this_item_has_no_shipment_yet'];
        }

        $provider = $this->providerFor($order, (string) OrderItem::whereIn('id', $itemIds)->value('courier_provider') ?: null, $itemIds);
        if (!$provider) {
            return ['ok' => false, 'message' => 'no_shipping_provider_is_available'];
        }
        if (!$provider instanceof PrintsShippingDocuments) {
            return ['ok' => false, 'message' => 'this_courier_cannot_print_in_bulk'];
        }

        try {
            $url = $document === 'manifest'
                ? $provider->manifestUrl($shipmentIds)
                : $provider->labelsUrl($shipmentIds);
        } catch (\Throwable $e) {
            Log::error('[Shipping] bulk ' . $document . ' failed: ' . $e->getMessage());
            $url = null;
        }

        if (!$url) {
            return ['ok' => false, 'message' => $document === 'manifest' ? 'manifest_is_not_available_yet' : 'label_is_not_available_yet'];
        }

        return ['ok' => true, 'message' => 'success', 'data' => ['url' => $url, 'shipments' => count($shipmentIds)]];
    }

    /**
     * Act on a failed delivery: another attempt, or send it back.
     *
     * The decision is the admin's; all core does is carry it to the carrier and clear
     * the flag on the line so the panel stops shouting about something already handled.
     *
     * @param string $action HandlesDeliveryExceptions::REATTEMPT | ::RETURN
     */
    public function resolveException(Order $order, array $itemIds, string $action, ?string $comment = null): array
    {
        $items = OrderItem::whereIn('id', $itemIds)->where('order_id', $order->id)->get();
        $awb = (string) $items->pluck('tracking_id')->filter()->first();
        if ($awb === '') {
            return ['ok' => false, 'message' => 'this_item_has_no_tracking_number'];
        }

        $provider = $this->providerFor($order, (string) $items->pluck('courier_provider')->filter()->first() ?: null, $items->pluck('id')->all());
        if (!$provider) {
            return ['ok' => false, 'message' => 'no_shipping_provider_is_available'];
        }
        if (!$provider instanceof HandlesDeliveryExceptions) {
            // The carrier has no such API: the admin resolves it in the carrier's own
            // dashboard, which is worth saying rather than failing silently.
            return ['ok' => false, 'message' => 'resolve_this_in_the_courier_dashboard'];
        }

        try {
            $result = $provider->resolveDeliveryException($awb, $action, $comment);
        } catch (\Throwable $e) {
            Log::error('[Shipping] delivery exception not resolved: ' . $e->getMessage());

            return ['ok' => false, 'message' => 'could_not_send_this_to_the_courier'];
        }

        if (empty($result['ok'])) {
            return ['ok' => false, 'message' => (string) ($result['message'] ?? 'could_not_send_this_to_the_courier')];
        }

        // The carrier accepted the instruction, so the line is no longer waiting on us.
        OrderItem::whereIn('id', $items->pluck('id'))->update(['courier_exception' => null]);

        return ['ok' => true, 'message' => (string) $result['message']];
    }

    /** Pull the carrier's current state — used when a webhook was missed. */
    public function track(Order $order, array $itemIds, ?int $adminId = null): array
    {
        $items = OrderItem::whereIn('id', $itemIds)->where('order_id', $order->id)->get();
        $awb = (string) $items->pluck('tracking_id')->filter()->first();
        if ($awb === '') {
            return ['ok' => false, 'message' => 'this_item_has_no_tracking_number'];
        }

        $provider = $this->providerFor($order, (string) $items->pluck('courier_provider')->filter()->first() ?: null, $items->pluck('id')->all());
        if (!$provider) {
            return ['ok' => false, 'message' => 'no_shipping_provider_is_available'];
        }

        try {
            $update = $provider->track($awb);
        } catch (\Throwable $e) {
            Log::error('[Shipping] track failed: ' . $e->getMessage());

            return ['ok' => false, 'message' => 'could_not_fetch_tracking'];
        }

        if (!$update) {
            return ['ok' => false, 'message' => 'could_not_fetch_tracking'];
        }

        $applied = app(CourierStatusService::class)->apply($update, $items->pluck('id')->map(fn ($i) => (int) $i)->all(), $adminId);

        return [
            'ok'   => true,
            'message' => 'success',
            'data' => [
                'status'         => $update->status,
                'carrier_status' => $update->carrierStatus,
                'courier_name'   => $update->courierName,
                'location'       => $update->location,
                'happened_at'    => $update->happenedAt,
                'scans'          => $update->scans,
                'applied'        => $applied['applied'],
            ],
        ];
    }

    /* ---------------------------------------------------------------- internals */

    /**
     * The items that may actually be shipped together, or a message saying why not.
     *
     * One consignment means one order, one branch and live items only. A courier cannot
     * carry two branches' parcels under one AWB, and a cancelled line has nothing to send.
     *
     * @return \Illuminate\Support\Collection<int,OrderItem>|string
     */
    private function shippableItems(Order $order, array $itemIds)
    {
        $itemIds = array_values(array_unique(array_map('intval', $itemIds)));
        if (empty($itemIds)) {
            return 'please_select_at_least_one_item';
        }

        if (($order->channel ?? 'ecommerce') !== 'ecommerce') {
            return 'only_ecommerce_orders_can_be_shipped_by_courier';
        }
        if (($order->delivery_type ?? 'delivery') === 'pickup') {
            return 'a_pickup_order_is_not_shipped';
        }

        $items = OrderItem::whereIn('id', $itemIds)->where('order_id', $order->id)->get();
        if ($items->count() !== count($itemIds)) {
            return 'some_items_do_not_belong_to_this_order';
        }

        $blocked = [OrderStatusList::$cancelled, OrderStatusList::$returned, OrderStatusList::$paymentPending];
        if ($items->contains(fn (OrderItem $i) => in_array((int) $i->active_status, $blocked, true))) {
            return 'cancelled_returned_or_unpaid_items_cannot_be_shipped';
        }
        if ($items->pluck('branch_id')->unique()->count() > 1) {
            return 'items_from_different_branches_cannot_travel_together';
        }

        return $items;
    }

    /**
     * The parcel as core computes it — same arithmetic the cart uses when it quotes a
     * rate, so what the customer was charged and what the courier is told agree.
     */
    private function parcel($items, ?Branch $branch = null, $provider = null, array $overrides = []): array
    {
        return app(ParcelCalculator::class)->fromOrderItems($items, [
            // The box and filler weigh something on every parcel this branch sends.
            'volumetric_divisor' => $provider instanceof UsesVolumetricWeight
                ? $provider->volumetricDivisor()
                : ParcelCalculator::DEFAULT_VOLUMETRIC_DIVISOR,
            'overrides'          => $overrides,
        ]);
    }

    /** Where the parcel is going: the order's own snapshot, or its address row. */
    private function shippingAddress(Order $order): array
    {
        $raw = is_array($order->address) ? $order->address : (json_decode((string) $order->address, true) ?: []);

        $address = [
            'name'     => (string) ($raw['name'] ?? ''),
            'address'  => (string) ($raw['address'] ?? ''),
            'area'     => (string) ($raw['area'] ?? ''),
            'landmark' => (string) ($raw['landmark'] ?? ''),
            'city'     => (string) ($raw['city'] ?? ''),
            'state'    => (string) ($raw['state'] ?? ''),
            'pincode'  => (string) ($raw['pincode'] ?? ''),
            'country'  => (string) ($raw['country'] ?? ''),
            'phone'    => (string) ($raw['mobile'] ?? $order->mobile ?? ''),
            'email'    => (string) (optional($order->user)->email ?? ''),
        ];

        // The order's own copy, which an older order was backfilled with.
        if ($address['pincode'] === '') {
            $address['pincode'] = (string) ($order->delivery_pincode ?? '');
        }

        // Orders placed before 1.4.0 kept only the formatted line, so the postal parts
        // come from the address row they were placed against.
        if (($address['pincode'] === '' || $address['city'] === '') && $order->address_id) {
            $row = UserAddress::find($order->address_id);
            if ($row) {
                $address['area'] = $address['area'] ?: (string) ($row->area ?? '');
                $address['landmark'] = $address['landmark'] ?: (string) ($row->landmark ?? '');
                $address['city'] = $address['city'] ?: (string) ($row->city ?? '');
                $address['state'] = $address['state'] ?: (string) ($row->state ?? '');
                $address['pincode'] = $address['pincode'] ?: (string) ($row->pincode ?? '');
                $address['country'] = $address['country'] ?: (string) ($row->country ?? '');
                $address['address'] = $address['address'] ?: (string) ($row->address ?? '');
            }
        }

        return $address;
    }

    /** A separately-typed billing address, or the shipping one. */
    private function billingAddress(Order $order, array $shipping): array
    {
        $raw = is_array($order->address) ? $order->address : (json_decode((string) $order->address, true) ?: []);
        if (empty($raw['billing']) || !empty($raw['billing_same_as_shipping'])) {
            return $shipping;
        }

        $b = is_array($raw['billing']) ? $raw['billing'] : (json_decode((string) $raw['billing'], true) ?: []);

        return array_merge($shipping, array_filter([
            'name'    => $b['name'] ?? null,
            'address' => $b['address'] ?? null,
            'city'    => $b['city'] ?? null,
            'state'   => $b['state'] ?? null,
            'pincode' => $b['pincode'] ?? null,
            'country' => $b['country'] ?? null,
            'phone'   => $b['mobile'] ?? null,
        ]));
    }

    /** Write what the carrier gave us onto every item in the consignment. */
    private function recordShipment($items, string $providerKey, ShipmentResult $result): void
    {
        OrderItem::whereIn('id', $items->pluck('id'))->update([
            'courier_provider'    => $providerKey,
            'courier_shipment_id' => $result->shipmentId,
            // The carrier's other handle. Kept because they are not interchangeable:
            // some carriers cancel by order and refuse a shipment id.
            'courier_order_id'    => $result->providerOrderId,
            'courier_label_url'   => $result->labelUrl,
            'courier_agency'      => $result->courierName ?: $providerKey,
            'tracking_id'         => $result->awb,
            'tracking_url'        => $result->trackingUrl,
        ]);
    }

    /**
     * Promise the customer the courier's own ETA.
     *
     * The chosen courier's quote is still in the cache from the dialog, so the days it
     * offered become the item's estimated delivery date — better than a zone-wide guess.
     * An item the admin already gave a date is left alone.
     */
    private function recordEta($items, ShipmentRequest $request, string $providerKey, ?string $courierId): void
    {
        if (!$courierId) {
            return;
        }

        $quoteRequest = new ShippingQuoteRequest(
            pickupPincode: (string) ($request->pickup['pincode'] ?? ''),
            deliveryPincode: (string) ($request->shipping['pincode'] ?? ''),
            weight: $request->weight,
            cod: $request->cod,
            channel: 'ecommerce',
        );

        $cached = Cache::get($providerKey . ':' . $quoteRequest->cacheKey());
        $days = collect(is_array($cached) ? $cached : [])
            ->firstWhere('courier_id', $courierId)['eta_days'] ?? null;
        if (!$days) {
            return;
        }

        $date = now()->addDays((int) $days)->toDateString();
        OrderItem::whereIn('id', $items->pluck('id'))
            ->whereNull('estimated_delivery_date')
            ->update(['estimated_delivery_date' => $date]);
    }

    /** The provider + shipment id behind these items, or why there is none. */
    private function bookedShipment(Order $order, array $itemIds): array
    {
        $items = OrderItem::whereIn('id', $itemIds)->where('order_id', $order->id)->get();
        if ($items->isEmpty()) {
            return [null, null, 'some_items_do_not_belong_to_this_order'];
        }

        $shipmentId = (string) $items->pluck('courier_shipment_id')->filter()->first();
        if ($shipmentId === '') {
            return [null, null, 'this_item_has_no_shipment_yet', null];
        }

        $provider = $this->providerFor($order, (string) $items->pluck('courier_provider')->filter()->first() ?: null, $items->pluck('id')->all());
        if (!$provider) {
            return [null, null, 'no_shipping_provider_is_available', null];
        }

        return [$provider, $shipmentId, null, (string) $items->pluck('courier_order_id')->filter()->first() ?: null];
    }

    private function isCod(Order $order): bool
    {
        return (string) $order->payment_method === (string) Transaction::$paymentTypeCod
            && (float) $order->remaining_final > 0;
    }

    /** Order has no country() relation, so the code is read once per order. */
    private function countryCode(Order $order): ?string
    {
        if (!$order->country_id) {
            return null;
        }

        return Cache::remember(
            'order_country_code:' . $order->country_id,
            600,
            fn () => Country::where('id', $order->country_id)->value('code')
        ) ?: null;
    }
}
