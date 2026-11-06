<?php

namespace App\Services\Shipping;

/**
 * A shipping provider that can say why it returned no quotes.
 *
 * Kept out of ShippingProvider so the main contract stays about carrying parcels: this
 * is diagnostics, and a provider that cannot explain itself simply does not implement
 * it. What it buys is a real answer in the ship dialog — "No courier service available
 * between 400001 and 284204" instead of "not available at this pincode", which is the
 * difference between an admin fixing the address and an admin filing a support ticket.
 */
interface ReportsQuoteFailure
{
    /** Why the last quote came back empty, in the carrier's own words, or null. */
    public function lastQuoteMessage(): ?string;
}
