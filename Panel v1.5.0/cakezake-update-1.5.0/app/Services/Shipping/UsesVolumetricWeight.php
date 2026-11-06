<?php

namespace App\Services\Shipping;

/**
 * A carrier that bills on volumetric weight when a parcel is light but bulky.
 *
 * Every Indian courier does: the charge is the greater of the parcel's actual weight and
 * `length × breadth × height ÷ divisor`, where the divisor is 5000 for most and 4000 for
 * a few. A cushion weighing 400 g in a 40 cm box is billed as 5 kg, and a surprise like
 * that is the most common complaint about courier pricing.
 *
 * Optional because it is a display concern: core shows both numbers and which one will
 * be billed, so an admin can repack before booking rather than argue after invoicing.
 */
interface UsesVolumetricWeight
{
    /** Divide L × B × H in centimetres by this to get kilograms. */
    public function volumetricDivisor(): int;
}
