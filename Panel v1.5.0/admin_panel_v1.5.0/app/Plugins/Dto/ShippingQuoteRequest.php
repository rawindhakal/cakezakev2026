<?php

namespace App\Plugins\Dto;

/**
 * "Can you carry this, and for how much." Built by core from a cart or an order, never
 * by the provider — so every courier is asked the same question.
 */
final class ShippingQuoteRequest
{
    public function __construct(
        public readonly string $pickupPincode,
        public readonly string $deliveryPincode,
        public readonly float $weight,          // kg, total for the parcel
        public readonly bool $cod,
        public readonly float $declaredValue = 0.0,
        public readonly ?float $length = null,  // cm
        public readonly ?float $breadth = null,
        public readonly ?float $height = null,
        public readonly ?int $branchId = null,
        public readonly string $channel = 'ecommerce',
        public readonly ?string $countryCode = null,
    ) {}

    /** Stable cache key: the same question must not be asked twice in a minute. */
    public function cacheKey(): string
    {
        return implode(':', [
            'ship_quote',
            $this->pickupPincode,
            $this->deliveryPincode,
            // Bucket the weight so 0.51 kg and 0.52 kg share an answer.
            (string) (ceil(max(0.01, $this->weight) * 2) / 2),
            $this->cod ? 'cod' : 'prepaid',
            $this->channel,
        ]);
    }
}
