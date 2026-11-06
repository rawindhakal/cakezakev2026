<?php

namespace App\Services\Shipping;

use App\Models\ShippingConfiguration;

/**
 * The shipping contract every CakeZake product implements, so one courier plugin works
 * in all of them. The counterpart of App\Services\Payment\PaymentInterface, and kept
 * deliberately as small.
 *
 * Four methods, because four things are true of every courier: it will say whether it
 * serves a route and for how much, it will take a parcel and give back a tracking
 * number, it will answer where that parcel is, and it will push that answer at us when
 * it changes. Anything beyond those is not universal — plenty of carriers have no
 * printable label, no pickup booking, no return leg — so it belongs in one of the
 * optional capability interfaces alongside this file, which the host tests for with
 * `instanceof` and simply does without.
 *
 * A plugin receives its credentials the same way a payment plugin does:
 *
 *     public function __construct(ShippingConfiguration $config)
 *
 * Everything crossing this boundary is a plain array, not a host DTO. A shared contract
 * cannot name types that only one product defines, and a carrier's own payload must
 * never reach the host's screens unexamined.
 */
interface ShippingInterface
{
    /*
     | The shared vocabulary for where a parcel is.
     |
     | Carriers each have their own words — Shiprocket alone has over forty — and a host
     | cannot act on words it has never seen. A plugin maps the carrier's status onto one
     | of these, and anything it does not recognise becomes UNKNOWN rather than being
     | passed through, so an unfamiliar status can never be mistaken for a delivery.
     */
    public const CREATED          = 'created';
    public const PICKUP_SCHEDULED = 'pickup_scheduled';
    public const IN_TRANSIT       = 'in_transit';
    public const OUT_FOR_DELIVERY = 'out_for_delivery';
    public const DELIVERED        = 'delivered';
    public const UNDELIVERED      = 'undelivered';
    public const RTO              = 'rto';
    public const RTO_COMPLETED    = 'rto_completed';
    public const CANCELLED        = 'cancelled';
    public const UNKNOWN          = 'unknown';

    /**
     * Can this parcel be carried, and for how much.
     *
     * `$shipment` carries `from_pincode`, `to_pincode`, `weight` (kg), `length`,
     * `breadth`, `height` (cm), `cod` (bool) and `declared_value`.
     *
     * Returns a list of options, cheapest first, each
     * `{courier_id, courier_name, rate, currency, estimated_days, cod}`. An empty list
     * means the route is not served — which is a real answer, and different from
     * throwing, which means we could not ask.
     *
     * @return array<int,array<string,mixed>>
     */
    public function quote(array $shipment): array;

    /**
     * Hand the parcel over.
     *
     * `$shipment` adds `reference` (ours, unique), `pickup_location`, `consignee`,
     * `items` and `payment_mode` to the quote fields.
     *
     * Returns `{ok, provider_order_id, provider_shipment_id, awb, courier_name, rate,
     * label_url, tracking_url, message}`. `ok: false` with a message is how a refusal
     * is reported; an exception is for not being able to ask at all.
     */
    public function createShipment(array $shipment): array;

    /**
     * Where a parcel is now, asked directly.
     *
     * Used to reconcile when a webhook was missed, so it must not depend on one having
     * arrived. Returns `{status, carrier_status, awb, scans, delivered_at}`, or an
     * empty array when the carrier knows nothing about that waybill yet.
     */
    public function track(string $awb): array;

    /**
     * Translate an inbound webhook body into the same shape `track()` returns, or an
     * empty array to ignore it.
     *
     * Carriers send heartbeats and repeats; ignoring one is normal and must not be
     * reported as a failure. Verifying that the request is genuine is a separate
     * concern — implement WebhookVerifiable for that — because a plugin that cannot
     * verify should say so rather than pretend.
     */
    public function parseWebhook(array $payload): array;
}
