<?php

namespace App\Plugins\Dto;

/** One courier's offer for a parcel. */
final class ShippingQuote
{
    public function __construct(
        public readonly string $courierId,
        public readonly string $courierName,
        public readonly float $rate,             // what the carrier charges us
        public readonly ?int $etaDays = null,
        public readonly ?string $etaText = null,
        public readonly bool $codAvailable = true,
        public readonly ?float $codCharge = null,
        public readonly ?float $rating = null,
        public readonly bool $recommended = false,
        public readonly array $raw = [],
    ) {}

    public function toArray(): array
    {
        return [
            'courier_id'     => $this->courierId,
            'courier_name'   => $this->courierName,
            'rate'           => round($this->rate, 2),
            'eta_days'       => $this->etaDays,
            'eta_text'       => $this->etaText,
            'cod_available'  => $this->codAvailable,
            'cod_charge'     => $this->codCharge,
            'rating'         => $this->rating,
            'recommended'    => $this->recommended,
        ];
    }
}
