<?php

namespace App\Services\Shipping;

/**
 * A carrier whose failed deliveries can be acted on from the panel.
 *
 * When a courier cannot deliver — nobody home, wrong address, refused — the parcel sits
 * waiting for a decision, and every day it waits costs storage and goodwill. Carriers
 * call this an NDR. The two answers are always the same: try again, or send it back.
 *
 * Separate from ShippingProvider because a carrier without an NDR API is still a
 * perfectly good carrier; the panel then just shows the failure and the admin resolves
 * it in the carrier's own dashboard.
 */
interface HandlesDeliveryExceptions
{
    public const REATTEMPT = 'reattempt';
    public const RETURN    = 'return';

    /**
     * Ask the carrier to try again, or to send the parcel back.
     *
     * @param  string $action  self::REATTEMPT | self::RETURN
     * @return array{ok:bool, message:string}
     */
    public function resolveDeliveryException(string $awb, string $action, ?string $comment = null): array;
}
