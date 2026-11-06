<?php

namespace App\Services\Shipping;

use Illuminate\Http\Request;

/**
 * Implemented only by courier plugins whose webhook can actually be proven genuine —
 * a shared secret, a signature, a token the carrier echoes back.
 *
 * Optional for the same reason the payment side's WebhookVerifiable is: a carrier that
 * offers no way to verify leaves a plugin with nothing to check, and a plugin that
 * faked a check would be worse than one that admits it. Where this is absent the host
 * treats a webhook as a hint and re-asks the carrier with `track()` before believing
 * anything, exactly as it does for an unverifiable payment return.
 */
interface VerifiesShippingWebhooks
{
    /** Throw if the request did not come from the carrier. */
    public function verifyWebhook(Request $request): void;
}
