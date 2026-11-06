<?php

namespace App\Services\Shipping;

/**
 * A carrier that can print for several parcels at once.
 *
 * Separate from ShippingProvider because it is a convenience, not part of carrying a
 * parcel: a carrier without it still works, the panel just prints one label at a time.
 * Once a branch ships thirty parcels a day, one sheet instead of thirty tabs is the
 * difference between usable and not.
 */
interface PrintsShippingDocuments
{
    /**
     * One printable document covering every listed shipment, or null when the carrier
     * could not produce it.
     *
     * @param array<int,string> $shipmentIds
     */
    public function labelsUrl(array $shipmentIds): ?string;

    /**
     * The handover manifest for these shipments — the sheet the pickup agent signs.
     *
     * @param array<int,string> $shipmentIds
     */
    public function manifestUrl(array $shipmentIds): ?string;
}
