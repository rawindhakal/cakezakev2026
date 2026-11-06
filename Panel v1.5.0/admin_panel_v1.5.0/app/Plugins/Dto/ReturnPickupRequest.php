<?php

namespace App\Plugins\Dto;

/**
 * A parcel to be collected from a customer and brought back to a branch.
 *
 * The mirror image of a ShipmentRequest: `pickup` is the customer's doorstep and `drop`
 * is the branch, which is the whole trick of a reverse booking — get those two the wrong
 * way round and the carrier cheerfully delivers the goods back to the person returning
 * them. Carried as its own type so no provider can confuse the two.
 */
final class ReturnPickupRequest
{
    public function __construct(
        public readonly int $returnRequestId,
        public readonly string $returnNumber,
        public readonly int $orderId,
        public readonly string $orderNumber,
        /** [['name','sku','units','selling_price','hsn'], ...] — one line, as a return is per item. */
        public readonly array $items,
        public readonly array $pickup,          // the CUSTOMER: name, address, city, state, pincode, country, phone, email
        public readonly array $drop,            // the BRANCH: location, name, address, city, state, pincode, country, phone
        public readonly float $weight,          // kg
        public readonly float $length,          // cm
        public readonly float $breadth,
        public readonly float $height,
        public readonly float $subTotal,
        public readonly ?string $courierId = null,   // null = let the carrier pick
        public readonly ?string $requestDate = null,
        public readonly ?string $reason = null,
    ) {}
}
