<?php

namespace App\Plugins\Dto;

/** What came back after handing a parcel over. */
final class ShipmentResult
{
    public function __construct(
        public readonly bool $ok,
        public readonly ?string $providerOrderId = null,
        public readonly ?string $shipmentId = null,
        public readonly ?string $awb = null,
        public readonly ?string $courierId = null,
        public readonly ?string $courierName = null,
        public readonly ?string $labelUrl = null,
        public readonly ?string $trackingUrl = null,
        public readonly ?float $rate = null,
        public readonly ?string $error = null,
        public readonly array $raw = [],
    ) {}

    public static function failed(string $error, array $raw = []): self
    {
        return new self(false, error: $error, raw: $raw);
    }
}
