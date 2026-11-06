<?php

namespace App\Services\Shipping;


/**
 * A carrier that will also collect a parcel from a customer and bring it back.
 *
 * Optional, and deliberately separate from the forward contract: plenty of carriers ship
 * out without offering reverse logistics, and a shop whose courier cannot collect still
 * has its own riders. Declaring this is what puts the "pick up with <carrier>" option on
 * a return request.
 *
 * Quoting a reverse parcel reuses the forward quote — the rate for a pincode pair is the
 * same journey in the other direction — so there is nothing extra to implement for it.
 * Labels and manifests are not part of this contract: on a reverse pickup the carrier's
 * own rider brings the paperwork, which is why Shiprocket's own documentation says a
 * label and a manifest are not required for returns.
 */
interface HandlesReturnPickups
{
    /** Book the collection. The AWB comes back on the result, as with a forward parcel. */
    /**
     * Book a collection from the customer.
     *
     * `$pickup` is the same shape `createShipment()` takes, with the addresses the
     * other way round: the customer is the collection point and the branch is the
     * destination. Returns the same shape too.
     */
    public function createReturnPickup(array $pickup): array;

    /** Call off a collection the carrier has not made yet. */
    public function cancelReturnPickup(string $shipmentId): bool;
}
