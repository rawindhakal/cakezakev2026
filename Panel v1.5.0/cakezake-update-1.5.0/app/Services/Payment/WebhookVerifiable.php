<?php

namespace App\Services\Payment;

use Illuminate\Http\Request;

/**
 * Implemented only by plugin gateways that have a webhook worth trusting.
 *
 * A gateway without it is reconciled by asking the gateway itself
 * (retrievePaymentIntent) when the shopper comes back — which is why a plugin may
 * safely skip this rather than fake a verification it cannot perform. PayU's Payment
 * Links product is exactly that case.
 */
interface WebhookVerifiable
{
    /**
     * Prove the request came from the gateway and say which payment it concerns.
     * Throw if it does not check out — returning a reference the host then settles is
     * how a forged callback becomes a free order.
     *
     * Takes the whole Request, since some gateways sign headers rather than the body.
     *
     * @return array{payment_transaction_id: int|string|null}
     */
    public function verifyWebhook(Request $request): array;
}
