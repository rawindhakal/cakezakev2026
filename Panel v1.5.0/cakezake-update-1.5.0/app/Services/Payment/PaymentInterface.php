<?php

namespace App\Services\Payment;

/**
 * The payment contract every CakeZake product implements, so one plugin zip works in
 * all of them.
 *
 * Do not add methods here. A plugin compiled against this interface in another product
 * must keep working in this one, and vice versa — the whole point of the universal
 * format is that the host adapts to the plugin, never the other way round. Anything
 * CakeZake needs beyond this belongs in the bridge that wraps the plugin
 * (App\Plugins\Adapters\PaymentAdapter), not in the contract.
 *
 * A plugin receives an App\Models\PaymentConfiguration and, optionally, the success and
 * failure URLs the host wants the shopper returned to:
 *
 *     public function __construct(PaymentConfiguration $config, ?string $successUrl, ?string $failedUrl)
 *
 * Statuses a plugin may return from formatPaymentIntent(): 'succeed', 'failed',
 * 'pending'. Nothing else is understood.
 */
interface PaymentInterface
{
    /** Open a payment with the gateway. Shape is the plugin's own. */
    public function createPaymentIntent($amount, $customMetaData);

    /** The same, normalised through formatPaymentIntent() — what hosts call. */
    public function createAndFormatPaymentIntent($amount, $customMetaData): array;

    /** Ask the gateway what actually happened. The only trustworthy source. */
    public function retrievePaymentIntent($paymentId): array;

    /** Raise an amount the gateway would refuse, or return it untouched. */
    public function minimumAmountValidation($currency, $amount);

    /** Normalise a gateway payload: id, amount, currency, metadata, status, raw. */
    public function formatPaymentIntent($id, $amount, $currency, $status, $metadata, $paymentIntent): array;
}
