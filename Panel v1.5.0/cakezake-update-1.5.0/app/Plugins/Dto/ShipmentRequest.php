<?php

namespace App\Plugins\Dto;

/**
 * A parcel ready to hand over: which order, which lines, which box, where from and to.
 * Core fills this in from the order and the ship dialog.
 */
final class ShipmentRequest
{
    public function __construct(
        public readonly int $orderId,
        public readonly string $orderNumber,
        /** [['order_item_id','name','sku','units','selling_price','discount','tax','hsn'], ...] */
        public readonly array $items,
        public readonly array $pickup,           // ['location','pincode','city','state','contact_number']
        public readonly array $shipping,         // ['name','address','address_2','city','state','pincode','country','email','phone']
        public readonly array $billing,          // same shape; equals shipping when the customer gave only one
        public readonly float $weight,           // kg
        public readonly float $length,           // cm
        public readonly float $breadth,
        public readonly float $height,
        public readonly float $subTotal,
        public readonly bool $cod,
        public readonly float $codAmount = 0.0,
        public readonly float $shippingCharges = 0.0,
        /** Additional and surge charges the customer was billed for these lines. */
        public readonly float $otherCharges = 0.0,
        public readonly float $discount = 0.0,
        public readonly ?string $courierId = null,   // null = let the carrier pick
        public readonly ?string $orderDate = null,
        public readonly ?string $comment = null,
    ) {}
}
