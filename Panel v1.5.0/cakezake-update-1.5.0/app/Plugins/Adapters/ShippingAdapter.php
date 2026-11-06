<?php

namespace App\Plugins\Adapters;

use App\Models\ShippingConfiguration;
use App\Plugins\Contracts\ShippingProvider;
use App\Plugins\Dto\ShipmentRequest;
use App\Plugins\Dto\ShipmentResult;
use App\Plugins\Dto\ShippingQuote;
use App\Plugins\Dto\ShippingQuoteRequest;
use App\Plugins\Dto\TrackingUpdate;
use App\Plugins\PluginPackage;
use App\Services\Shipping\AssignsWaybillOnBooking;
use App\Services\Shipping\HandlesDeliveryExceptions;
use App\Services\Shipping\HandlesReturnPickups;
use App\Services\Shipping\PrintsShippingDocuments;
use App\Services\Shipping\ReportsAccountBalance;
use App\Services\Shipping\ReportsQuoteFailure;
use App\Services\Shipping\ShippingInterface;
use App\Services\Shipping\UsesVolumetricWeight;
use App\Services\Shipping\VerifiesShippingWebhooks;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Makes a courier plugin look like one of CakeZake's own shipping providers.
 *
 * Core's shipping services speak in orders, DTOs and shipment rows; a plugin speaks in
 * plain arrays about one parcel, because that is all a carrier integration can rely on
 * across every CakeZake product. This class is where the difference is absorbed, and it
 * is the only place that knows both — which is what keeps the plugin portable and keeps
 * core unaware that a courier came from a package at all.
 *
 * It also decides what the plugin is *allowed* to be asked. Plenty of carriers cannot
 * print a label, book a pickup or carry a parcel backwards, so those live behind
 * optional capability interfaces: the adapter tests for each and answers "cannot" on
 * the plugin's behalf rather than letting core call a method that is not there.
 */
final class ShippingAdapter implements ShippingProvider
{
    private ?ShippingInterface $carrier = null;

    public function __construct(private readonly PluginPackage $plugin) {}

    /* ------------------------------------------------------------------ identity */

    public function key(): string
    {
        return $this->plugin->slug;
    }

    public function label(): string
    {
        return $this->plugin->name();
    }

    /**
     * Courier shipping is the ecommerce channel's.
     *
     * Quick commerce is a rider leaving a branch with a bag, measured in minutes; a
     * parcel carrier cannot serve it, and offering one there would put an order in a
     * queue nobody is watching.
     */
    public function channels(): array
    {
        return ['ecommerce'];
    }

    public function quotesOn(): string
    {
        return 'weight';
    }

    /**
     * Which countries this carrier serves.
     *
     * Read from the catalogue rather than asked of the plugin: the shared contract has
     * no place for it, and a carrier's coverage is a commercial fact about the product
     * we sell, not something the integration knows.
     */
    public function countries(): array
    {
        foreach ((array) config('plugin_catalog.plugins', []) as $entry) {
            if (($entry['slug'] ?? null) === $this->plugin->slug) {
                return (array) ($entry['countries'] ?? []);
            }
        }

        return [];
    }

    public function isConfigured(): bool
    {
        $carrier = $this->carrier();

        if (!$carrier) {
            return false;
        }

        // A plugin may say so itself; otherwise the credentials being present is the
        // best the host can judge.
        if (method_exists($carrier, 'isConfigured')) {
            return (bool) $carrier->isConfigured();
        }

        return (bool) $this->config()->status;
    }

    /* --------------------------------------------------------------------- rates */

    public function quote(ShippingQuoteRequest $request): array
    {
        $carrier = $this->carrier();

        if (!$carrier) {
            return [];
        }

        $rows = $this->guard('quote', fn () => $carrier->quote([
            'from_pincode'   => $request->pickupPincode,
            'to_pincode'     => $request->deliveryPincode,
            'weight'         => $request->weight,
            'length'         => $request->length,
            'breadth'        => $request->breadth,
            'height'         => $request->height,
            'cod'            => $request->cod,
            'declared_value' => $request->declaredValue,
        ]), []);

        $quotes = [];

        foreach ($rows as $row) {
            $quotes[] = new ShippingQuote(
                courierId: (string) ($row['courier_id'] ?? ''),
                courierName: (string) ($row['courier_name'] ?? ''),
                rate: (float) ($row['rate'] ?? 0),
                etaDays: isset($row['estimated_days']) ? (int) $row['estimated_days'] : null,
                etaText: $row['estimated_text'] ?? null,
                codAvailable: (bool) ($row['cod'] ?? false),
                codCharge: isset($row['cod_charge']) ? (float) $row['cod_charge'] : null,
                rating: isset($row['rating']) ? (float) $row['rating'] : null,
                recommended: (bool) ($row['recommended'] ?? false),
                raw: (array) ($row['raw'] ?? $row),
            );
        }

        return $quotes;
    }

    /** Why the last quote was empty — "no courier between these pincodes". */
    public function lastQuoteMessage(): ?string
    {
        $carrier = $this->carrier();

        return $carrier instanceof ReportsQuoteFailure ? $carrier->lastQuoteMessage() : null;
    }

    /* ------------------------------------------------------------------- policy */

    /**
     * The host's own settings for this carrier, offered beside the plugin's.
     *
     * Deliberately not in `module.json`. "Assign the waybill the moment a parcel is
     * booked" is a decision about how this shop wants to work, not something a carrier
     * integration knows or should be able to change — and a plugin that could declare
     * it would have to be rewritten for every product with a different answer.
     *
     * Each is offered only when this carrier can actually do it, so a courier with no
     * pickup booking never shows a switch that does nothing.
     *
     * @return array<int,array<string,mixed>>
     */
    public function policyFields(): array
    {
        $carrier = $this->carrier();
        $fields = [];

        /* The address the carrier pushes tracking to. It is the host's route, not
           anything the package knows, so the host is what puts it on the screen —
           read-only, with a copy button, because it exists to be pasted into the
           carrier's own dashboard. Shown only for a carrier that can prove a webhook
           came from it; for one that cannot there is nothing safe to point at it. */
        if ($carrier instanceof VerifiesShippingWebhooks) {
            $fields[] = [
                'key'    => 'tracking_webhook_url',
                'type'   => 'webhook_url',
                'action' => 'track',
                'label'  => 'tracking_webhook_url',
                'hint'   => 'tracking_webhook_url_hint',
            ];
        }

        if ($carrier && method_exists($carrier, 'assignWaybill')) {
            $fields[] = [
                'key'     => 'auto_awb',
                'type'    => 'toggle',
                'label'   => 'assign_waybill_automatically',
                'hint'    => 'assign_waybill_automatically_hint',
                'default' => 1,
            ];
        }

        if ($carrier && method_exists($carrier, 'schedulePickup')) {
            $fields[] = [
                'key'     => 'auto_pickup',
                'type'    => 'toggle',
                'label'   => 'request_pickup_automatically',
                'hint'    => 'request_pickup_automatically_hint',
                'default' => 0,
            ];
        }

        return $fields;
    }

    /**
     * The keys policyFields() may actually branch.
     *
     * The webhook address is shown, never saved — it is derived from the route and
     * would be stale the moment the site moved domain.
     */
    public function policyKeys(): array
    {
        return array_values(array_diff(array_column($this->policyFields(), 'key'), ['tracking_webhook_url']));
    }

    public function policy(string $key, $default = null)
    {
        return $this->config()->policy($key, $default);
    }

    /* ------------------------------------------------------------------ booking */

    public function createShipment(ShipmentRequest $request): ShipmentResult
    {
        $carrier = $this->carrier();

        if (!$carrier) {
            return ShipmentResult::failed('shipping_plugin_is_unavailable');
        }

        /* The parcel leaves the branch that holds the items, and the carrier refuses an
           order naming a collection address it does not recognise — with a body that
           carries no shipment id, which reads as a carrier fault rather than a setup
           one. So it is resolved and checked here, and an unregistered branch is told
           exactly that. */
        $pickupLocation = (string) ($request->pickup['location'] ?? '')
            ?: (string) ($this->pickupNickname($request->pickup) ?? '');

        if ($pickupLocation === '') {
            return ShipmentResult::failed('branch_is_not_registered_with_the_carrier');
        }

        $result = $this->guard('createShipment', fn () => $carrier->createShipment([
            'reference'        => $request->orderNumber . '-' . $request->orderId,
            'order_date'       => $request->orderDate,
            'comment'          => $request->comment,
            'pickup_location'  => $pickupLocation,
            'consignee'        => $request->shipping,
            'billing'          => $request->billing,
            'items'            => $request->items,
            'weight'           => $request->weight,
            'length'           => $request->length,
            'breadth'          => $request->breadth,
            'height'           => $request->height,
            'sub_total'        => $request->subTotal,
            'cod'              => $request->cod,
            'cod_amount'       => $request->codAmount,
            'shipping_charges' => $request->shippingCharges,
            'other_charges'    => $request->otherCharges,
            'discount'         => $request->discount,
            'courier_id'       => $request->courierId,
        ]), ['ok' => false, 'message' => 'shipping_plugin_is_unavailable']);

        if (empty($result['ok'])) {
            return ShipmentResult::failed((string) ($result['message'] ?? 'shipment_could_not_be_booked'), $result);
        }

        $shipmentId = (string) ($result['provider_shipment_id'] ?? '');
        $awb = (string) ($result['awb'] ?? '');

        /* Most carriers hand out the waybill in a second call, and a parcel without one
           cannot be labelled, picked up or tracked — so it is asked for here rather
           than left for someone to notice. A refusal is reported, not fatal: the
           shipment exists and the waybill can be assigned again from the panel.
           Shops that would rather pick the courier by hand turn this off. */
        $wantsWaybill = (int) $this->policy('auto_awb', 1) === 1;

        if ($wantsWaybill && $awb === '' && $shipmentId !== '' && $carrier instanceof AssignsWaybillOnBooking
            && !$carrier->assignsWaybillOnBooking() && method_exists($carrier, 'assignWaybill')) {
            $assigned = $this->guard('assignWaybill',
                fn () => $carrier->assignWaybill($shipmentId, $request->courierId), ['ok' => false]);

            if (!empty($assigned['ok'])) {
                $awb = (string) ($assigned['awb'] ?? '');
                $result['courier_id'] = $assigned['courier_id'] ?? ($result['courier_id'] ?? null);
                $result['courier_name'] = $assigned['courier_name'] ?? ($result['courier_name'] ?? null);
                $result['rate'] = $assigned['rate'] ?? ($result['rate'] ?? null);
                $result['tracking_url'] = $assigned['tracking_url'] ?? ($result['tracking_url'] ?? null);
            } else {
                Log::warning("[Plugin:{$this->key()}] shipment {$shipmentId} booked without a waybill.");
            }
        }

        /* Booking the collection straight away suits a shop that ships everything on
           one daily round; one that batches parcels and calls the courier once would
           rather do it from the dispatch desk, so this is off unless asked for. It
           needs a waybill to exist, and a refusal is logged rather than failing a
           parcel that is otherwise booked. */
        if ($awb !== '' && $shipmentId !== '' && (int) $this->policy('auto_pickup', 0) === 1
            && method_exists($carrier, 'schedulePickup')) {
            if (!$this->guard('schedulePickup', fn () => $carrier->schedulePickup($shipmentId), false)) {
                Log::warning("[Plugin:{$this->key()}] pickup was not scheduled for shipment {$shipmentId}.");
            }
        }

        return new ShipmentResult(
            ok: true,
            providerOrderId: (string) ($result['provider_order_id'] ?? '') ?: null,
            shipmentId: $shipmentId ?: null,
            awb: $awb ?: null,
            courierId: (string) ($result['courier_id'] ?? '') ?: null,
            courierName: (string) ($result['courier_name'] ?? '') ?: null,
            labelUrl: (string) ($result['label_url'] ?? '') ?: null,
            trackingUrl: (string) ($result['tracking_url'] ?? '') ?: null,
            rate: isset($result['rate']) ? (float) $result['rate'] : null,
            raw: (array) ($result['raw'] ?? $result),
        );
    }

    public function schedulePickup(string $shipmentId): bool
    {
        $carrier = $this->carrier();

        return $carrier && method_exists($carrier, 'schedulePickup')
            ? (bool) $this->guard('schedulePickup', fn () => $carrier->schedulePickup($shipmentId), false)
            : false;
    }

    public function labelUrl(string $shipmentId): ?string
    {
        return $this->labelsUrl([$shipmentId]);
    }

    public function labelsUrl(array $shipmentIds): ?string
    {
        $carrier = $this->carrier();

        return $carrier instanceof PrintsShippingDocuments
            ? $this->guard('labelsUrl', fn () => $carrier->labelsUrl($shipmentIds), null)
            : null;
    }

    public function manifestUrl(array $shipmentIds): ?string
    {
        $carrier = $this->carrier();

        return $carrier instanceof PrintsShippingDocuments
            ? $this->guard('manifestUrl', fn () => $carrier->manifestUrl($shipmentIds), null)
            : null;
    }

    public function cancelShipment(string $shipmentId, ?string $providerOrderId = null): bool
    {
        $carrier = $this->carrier();

        return $carrier && method_exists($carrier, 'cancelShipment')
            ? (bool) $this->guard(
                'cancelShipment',
                // The format names this parameter providerOrderId, so that is what it
                // gets when core has one; the shipment id is only the fallback.
                fn () => $carrier->cancelShipment((string) ($providerOrderId ?: $shipmentId)),
                false
            )
            : false;
    }

    public function resolveDeliveryException(string $awb, string $action, ?string $comment = null): array
    {
        $carrier = $this->carrier();

        if (!$carrier instanceof HandlesDeliveryExceptions) {
            return ['ok' => false, 'message' => 'this_carrier_cannot_resolve_delivery_exceptions'];
        }

        return $this->guard('resolveDeliveryException',
            fn () => $carrier->resolveDeliveryException($awb, $action, $comment),
            ['ok' => false, 'message' => 'carrier_request_failed']);
    }

    public function accountBalance(): array
    {
        $carrier = $this->carrier();

        return $carrier instanceof ReportsAccountBalance
            ? $this->guard('accountBalance', fn () => $carrier->accountBalance(), ['ok' => false, 'balance' => null])
            : ['ok' => false, 'balance' => null, 'message' => 'this_carrier_reports_no_balance'];
    }

    /** How this carrier converts a box into a billable weight. */
    public function volumetricDivisor(): int
    {
        $carrier = $this->carrier();

        return $carrier instanceof UsesVolumetricWeight ? $carrier->volumetricDivisor() : 0;
    }

    /* --------------------------------------------------------------- collections */

    public function createReturnPickup($request): ShipmentResult
    {
        $carrier = $this->carrier();

        if (!$carrier instanceof HandlesReturnPickups) {
            return ShipmentResult::failed('this_carrier_cannot_collect_returns');
        }

        $result = $this->guard('createReturnPickup', fn () => $carrier->createReturnPickup([
            'reference'  => $request->reference,
            'order_date' => $request->orderDate ?? null,
            'pickup'     => $request->pickup,
            /* The customer side already arrives in the contract's words; the branch side
               is a host `pickupInfo()` array, so it is translated here too. Without it a
               reverse order is booked to a branch with no name, phone or country. */
            'drop'       => $this->branchAddress($request->drop),
            'items'      => $request->items,
            'weight'     => $request->weight,
            'length'     => $request->length,
            'breadth'    => $request->breadth,
            'height'     => $request->height,
            'sub_total'  => $request->subTotal,
        ]), ['ok' => false, 'message' => 'return_pickup_could_not_be_booked']);

        if (empty($result['ok'])) {
            return ShipmentResult::failed((string) ($result['message'] ?? 'return_pickup_could_not_be_booked'), $result);
        }

        return new ShipmentResult(
            ok: true,
            providerOrderId: (string) ($result['provider_order_id'] ?? '') ?: null,
            shipmentId: (string) ($result['provider_shipment_id'] ?? '') ?: null,
            awb: (string) ($result['awb'] ?? '') ?: null,
            courierName: (string) ($result['courier_name'] ?? '') ?: null,
            raw: (array) ($result['raw'] ?? $result),
        );
    }

    public function cancelReturnPickup(string $shipmentId, ?string $providerOrderId = null): bool
    {
        $carrier = $this->carrier();

        return $carrier instanceof HandlesReturnPickups
            ? (bool) $this->guard(
                'cancelReturnPickup',
                fn () => $carrier->cancelReturnPickup((string) ($providerOrderId ?: $shipmentId)),
                false
            )
            : false;
    }

    /* ------------------------------------------------------------------ pickups */

    public function registerPickup(array $branch): array
    {
        $carrier = $this->carrier();

        if (!$carrier || !method_exists($carrier, 'registerPickup')) {
            // A carrier that needs no registration is ready by definition.
            return ['ok' => true, 'nickname' => null, 'verified' => true, 'message' => ''];
        }

        $payload = $this->pickupPayload($branch);

        if (($payload['nickname'] ?? '') === '') {
            return ['ok' => false, 'nickname' => null, 'verified' => false, 'message' => 'branch_pickup_pincode_is_missing'];
        }

        $result = $this->guard('registerPickup', fn () => $carrier->registerPickup($payload),
            ['ok' => false, 'nickname' => null, 'message' => 'pickup_address_could_not_be_registered']);

        // The account list is cached and has just changed.
        $this->forgetAccountPickupLocations();

        return [
            'ok'       => (bool) ($result['ok'] ?? false),
            'nickname' => $result['nickname'] ?? null,
            'verified' => (bool) ($result['verified'] ?? ($result['ok'] ?? false)),
            'message'  => (string) ($result['message'] ?? ''),
        ];
    }

    public function verifyPickup(array $branch): array
    {
        $carrier = $this->carrier();

        if (!$carrier || !method_exists($carrier, 'pickupLocations')) {
            return $this->pickupAnswer(true, true, true, null, 0, '');
        }

        $nickname = $this->pickupNickname($branch);
        $locations = $this->accountPickupLocations();
        $match = $nickname !== null ? ($locations[$nickname] ?? null) : null;

        /* Serviceability is a question about the pincode, and it is asked whether or not
           the address is registered: an admin deciding whether to register this branch
           wants to know couriers collect there, and after registering wants to know the
           address is actually usable. Registered is not the same as collectable — a
           carrier can hold an address and serve no courier from it. */
        $pincode = $this->digits((string) ($branch['pincode'] ?? ''));
        $origin = $this->digits((string) ($match['pincode'] ?? '')) ?: $pincode;
        $couriers = [];

        if ($origin !== '') {
            $couriers = $this->guard('quote', fn () => $carrier->quote([
                'from_pincode'   => $origin,
                'to_pincode'     => $pincode ?: $origin,
                'weight'         => 0.5,
                'cod'            => false,
                'declared_value' => 100,
            ]), []);
        }

        if (!$match) {
            return $this->pickupAnswer(
                false,
                count($couriers) > 0,
                false,
                null,
                count($couriers),
                'branch_is_not_registered_with_the_carrier'
            );
        }

        /* Only an explicit no. A carrier that has not said whether an address is
           verified reports null, and an absence of good news is not bad news — reading
           it as one put a red warning on an address that books orders perfectly well. */
        if (($match['verified'] ?? null) === false) {
            return $this->pickupAnswer(
                false,
                count($couriers) > 0,
                true,
                $nickname,
                count($couriers),
                'carrier_pickup_address_is_switched_off'
            );
        }

        /* The carrier collects from the address IT holds, not from the pincode on the
           branch. When the two disagree, every rate the panel quotes is priced from one
           origin and the parcel leaves from another — which nobody notices until a
           delivery estimate or a charge comes out wrong. */
        if ($pincode !== '' && $origin !== '' && $origin !== $pincode) {
            return $this->pickupAnswer(
                false,
                count($couriers) > 0,
                true,
                $nickname,
                count($couriers),
                'carrier_pickup_pincode_differs_from_the_branch'
            );
        }

        return $this->pickupAnswer(
            true,
            count($couriers) > 0,
            true,
            $nickname,
            count($couriers),
            count($couriers) > 0 ? '' : 'carrier_serves_no_courier_from_this_pincode'
        );
    }

    /**
     * Which of the carrier's pickup addresses this branch ships from, or null.
     *
     * The host names its own collection points — `SB-BRANCH-{id}`, from the id because
     * names get edited and translated while an id does not, and because a nickname the
     * carrier has accepted cannot be renamed from our side. The pincode fallback is what
     * makes a live account work: a merchant who was already shipping has addresses they
     * created by hand, and refusing to use one would mean registering a duplicate of an
     * address the carrier already holds.
     *
     * Null rather than a global default, deliberately. One nickname shared by every
     * unresolved branch sends a courier to the wrong warehouse, which is worse than a
     * booking that refuses and names the branch that needs registering.
     */
    public function pickupNickname(array $branch): ?string
    {
        $branchId = (int) ($branch['branch_id'] ?? 0);

        if ($branchId < 1) {
            return null;
        }

        $locations = $this->accountPickupLocations();
        $convention = $this->conventionNickname($branchId);

        if (isset($locations[$convention])) {
            return $convention;
        }

        $pincode = $this->digits((string) ($branch['pincode'] ?? ''));

        if ($pincode === '') {
            return null;
        }

        $matches = array_filter(
            $locations,
            fn (array $row) => $this->digits((string) ($row['pincode'] ?? '')) === $pincode
        );

        if (count($matches) === 1) {
            return (string) array_key_first($matches);
        }

        if (count($matches) > 1) {
            Log::warning("[Plugin:{$this->key()}] branch {$branchId}: " . count($matches)
                . " pickup addresses share pincode {$pincode}; register the branch so it has its own.");
        }

        return null;
    }

    public function conventionNickname(int $branchId): string
    {
        return 'SB-BRANCH-' . $branchId;
    }

    /**
     * The host's branch, in the words the shared contract uses.
     *
     * Core describes a branch as `branch_name` / `contact_number` / `country_code`; the
     * format's pickup contract asks for `name` / `phone` / `country`. Translating here is
     * the whole reason this class exists — without it the carrier is handed an address
     * with no name, no phone and no country and refuses it.
     */
    private function pickupPayload(array $branch): array
    {
        return $this->branchAddress($branch) + [
            'nickname'     => (string) ($this->pickupNickname($branch)
                ?: $this->conventionNickname((int) ($branch['branch_id'] ?? 0))),
            'contact_name' => trim((string) ($branch['branch_name'] ?? '')),
        ];
    }

    /**
     * A host branch in the words the shared contract uses.
     *
     * Core describes a branch as `branch_name` / `contact_number` / `country_code`; the
     * format asks for `name` / `phone` / `country`. Translating is the whole reason this
     * class exists — hand the names straight over and the carrier gets an address with
     * no name, no phone and no country, and refuses it.
     */
    private function branchAddress(array $branch): array
    {
        $country = trim((string) ($branch['country_name'] ?? ''));

        return [
            'name'      => trim((string) ($branch['branch_name'] ?? ($branch['name'] ?? ''))),
            'phone'     => (string) ($branch['contact_number'] ?? ($branch['phone'] ?? '')),
            'email'     => (string) ($branch['email'] ?? ''),
            'address'   => (string) ($branch['address'] ?? ''),
            'address_2' => (string) ($branch['address_2'] ?? ''),
            'city'      => (string) ($branch['city'] ?? ''),
            'state'     => (string) ($branch['state'] ?? ''),
            'country'   => $country !== '' ? $country : ((string) ($branch['country'] ?? '') ?: 'India'),
            'pincode'   => $this->digits((string) ($branch['pincode'] ?? '')),
        ];
    }

    /** The carrier's address list, which changes rarely and must not be on a hot path. */
    private function accountPickupLocations(): array
    {
        $carrier = $this->carrier();

        if (!$carrier || !method_exists($carrier, 'pickupLocations')) {
            return [];
        }

        return Cache::remember(
            $this->pickupCacheKey(),
            3600,
            fn () => (array) $this->guard('pickupLocations', fn () => $carrier->pickupLocations(), [])
        );
    }

    private function forgetAccountPickupLocations(): void
    {
        Cache::forget($this->pickupCacheKey());
    }

    private function pickupCacheKey(): string
    {
        return 'shipping_pickup_locations:' . $this->key();
    }

    private function digits(string $value): string
    {
        return (string) preg_replace('/\D+/', '', $value);
    }

    private function pickupAnswer(bool $ok, bool $serviceable, bool $registered, ?string $nickname, int $couriers, string $message): array
    {
        return compact('ok', 'serviceable', 'registered', 'nickname', 'couriers', 'message');
    }

    /* ----------------------------------------------------------------- tracking */

    public function track(string $awb): ?TrackingUpdate
    {
        $carrier = $this->carrier();

        if (!$carrier) {
            return null;
        }

        return $this->toUpdate($this->guard('track', fn () => $carrier->track($awb), []));
    }

    public function parseWebhook(array $payload, string $action): ?TrackingUpdate
    {
        $carrier = $this->carrier();

        if (!$carrier) {
            return null;
        }

        return $this->toUpdate($this->guard('parseWebhook', fn () => $carrier->parseWebhook($payload), []));
    }

    /**
     * Whether a webhook really came from the carrier.
     *
     * A plugin that cannot prove it does not implement the interface, and the answer is
     * then false rather than a silent yes: core re-asks the carrier with `track()`
     * instead of believing an unverified push, exactly as the payment side does.
     */
    public function verifyWebhook(array $payload, array $headers): bool
    {
        $carrier = $this->carrier();

        if (!$carrier instanceof VerifiesShippingWebhooks) {
            return false;
        }

        try {
            $request = Request::create('', 'POST', $payload, [], [], $this->serverHeaders($headers), json_encode($payload) ?: '');
            $carrier->verifyWebhook($request);

            return true;
        } catch (\Throwable $e) {
            Log::warning("[Plugin:{$this->key()}] webhook verification failed", ['message' => $e->getMessage()]);

            return false;
        }
    }

    /* ------------------------------------------------------------------- wiring */

    /** `x-api-key` => `HTTP_X_API_KEY`, which is where a Request looks for it. */
    private function serverHeaders(array $headers): array
    {
        $server = [];

        foreach ($headers as $name => $value) {
            $server['HTTP_' . strtoupper(str_replace('-', '_', (string) $name))] = is_array($value)
                ? (string) reset($value)
                : (string) $value;
        }

        return $server;
    }

    private function toUpdate(array $row): ?TrackingUpdate
    {
        if (!$row || empty($row['status'])) {
            return null;
        }

        $scans = (array) ($row['scans'] ?? []);
        $latest = $scans[0] ?? [];

        return new TrackingUpdate(
            status: (string) $row['status'],
            awb: (string) ($row['awb'] ?? '') ?: null,
            shipmentId: (string) ($row['shipment_id'] ?? '') ?: null,
            courierName: (string) ($row['courier_name'] ?? '') ?: null,
            carrierStatus: (string) ($row['carrier_status'] ?? '') ?: null,
            happenedAt: (string) ($row['delivered_at'] ?? $latest['at'] ?? '') ?: null,
            location: (string) ($latest['location'] ?? '') ?: null,
            scans: $scans,
            raw: (array) ($row['raw'] ?? $row),
        );
    }

    private function config(): ShippingConfiguration
    {
        return ShippingConfiguration::forProvider($this->plugin->slug);
    }

    /**
     * The plugin itself, built once per adapter.
     *
     * Null when the package names a class that is missing or does not implement the
     * contract — files deleted over FTP, a bad update. Every caller above checks, so a
     * broken plugin degrades to "this carrier cannot do that" rather than a 500.
     */
    private function carrier(): ?ShippingInterface
    {
        if ($this->carrier !== null) {
            return $this->carrier;
        }

        $class = $this->plugin->mainClass();

        if (!$class || !class_exists($class) || !is_subclass_of($class, ShippingInterface::class)) {
            Log::error("[Plugin:{$this->key()}] main_class is missing or does not implement ShippingInterface.");

            return null;
        }

        try {
            return $this->carrier = new $class($this->config());
        } catch (\Throwable $e) {
            Log::error("[Plugin:{$this->key()}] could not be constructed", ['message' => $e->getMessage()]);

            return null;
        }
    }

    /**
     * Run one carrier call, turning a thrown error into the caller's fallback.
     *
     * A plugin is third-party code reaching a third-party API; letting an exception out
     * of here would take down whatever screen asked — a quote on the checkout, a label
     * on the dispatch desk. Every failure is logged with the method that caused it.
     */
    private function guard(string $method, callable $call, $fallback)
    {
        try {
            return $call();
        } catch (\Throwable $e) {
            Log::error("[Plugin:{$this->key()}] {$method}() failed", ['message' => $e->getMessage()]);

            return $fallback;
        }
    }
}
