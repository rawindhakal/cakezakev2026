<?php

namespace App\Services\Payment;

/**
 * A gateway whose native SDK asks the server to sign things while a payment is open.
 *
 * A hosted checkout needs one signature, computed when the payment starts. A native SDK
 * is chattier: it fetches the payment options it may offer, lists the shopper's saved
 * cards, checks an offer — and each of those calls is signed with the merchant's salt,
 * which must never reach the app. So the SDK hands the server a string and asks for its
 * hash.
 *
 * That is a signing oracle, and it is dangerous in exactly one place: the signature that
 * authorises money. An attacker who could have any string signed could sign a payment for
 * one rupee against a thousand-rupee order. So the amount-bearing signature is never
 * signed on request — core computes it once, from the order, when the payment starts —
 * and this interface covers only the auxiliary calls, each checked against a whitelist
 * the driver itself declares.
 */
interface SignsSdkRequests
{
    /**
     * Sign one SDK call, or return null to refuse.
     *
     * A driver must refuse anything it does not recognise: an unknown command, a string
     * that does not belong to this merchant, or any command that carries an amount.
     *
     * @param  string $name        the SDK's own name for the call, e.g. 'payment_related_details_for_mobile_sdk'
     * @param  string $value       the exact string the SDK asked to have hashed
     * @param  array  $gateways    this country's `payment_gateways` array, as stored —
     *                             the same shape `isConfigured()` and `verifyWebhook()`
     *                             are given, so a driver reads its own keys from it
     */
    public function signSdkRequest(string $name, string $value, array $gateways, array $context = []): ?string;
}
