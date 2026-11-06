<?php

namespace App\Plugins\Dto;

/**
 * A carrier's status, already translated into our own vocabulary by the provider.
 *
 * `status` is one of the constants below, so core can map it onto an order-item status
 * without knowing a single carrier's status codes.
 */
final class TrackingUpdate
{
    public const CREATED       = 'created';
    public const PICKUP_DUE    = 'pickup_scheduled';
    public const IN_TRANSIT    = 'in_transit';
    public const OUT_FOR_DELIVERY = 'out_for_delivery';
    public const DELIVERED     = 'delivered';
    /**
     * A delivery was attempted and failed — nobody home, address unreachable, refused.
     * Its own state because it needs a decision (try again, or send it back) and must
     * never be mistaken for progress.
     */
    public const UNDELIVERED   = 'undelivered';
    /** On its way back to the sender, but not there yet. */
    public const RTO           = 'rto';
    /**
     * Back at the sender's door and accepted.
     *
     * Separate from RTO because this is the point where the money and the stock have to
     * move: while a parcel is still travelling back, nothing is certain enough to act on.
     */
    public const RTO_COMPLETED = 'rto_completed';
    public const CANCELLED     = 'cancelled';
    public const UNKNOWN       = 'unknown';

    public function __construct(
        public readonly string $status,
        public readonly ?string $awb = null,
        public readonly ?string $shipmentId = null,
        public readonly ?string $courierName = null,
        public readonly ?string $carrierStatus = null,   // the carrier's own label, for display
        public readonly ?string $happenedAt = null,
        public readonly ?string $location = null,
        public readonly array $scans = [],
        public readonly array $raw = [],
    ) {}

    public function isFinal(): bool
    {
        return in_array($this->status, [self::DELIVERED, self::RTO, self::RTO_COMPLETED, self::CANCELLED], true);
    }
}
