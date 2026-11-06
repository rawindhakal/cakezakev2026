<?php

namespace App\Plugins\Dto;

/**
 * Everything a gateway needs to start a payment, assembled by core.
 *
 * A driver never reads the order, the cart or the country row itself — it is handed
 * exactly what it may know, so one gateway cannot see another's keys and none of them
 * can change what is being charged.
 */
final class PaymentContext
{
    public function __construct(
        /** `order-{orderId}-{userId}` or `wallet-{YmdHis}-{userId}-c{countryId}`. */
        public readonly string $reference,
        public readonly string $purpose,          // 'order' | 'wallet'
        public readonly float $amount,
        public readonly string $currencyCode,     // ISO: INR, USD
        public readonly ?int $orderId,
        public readonly ?string $orderNumber,
        public readonly int $userId,
        public readonly string $customerName,
        public readonly string $customerEmail,
        public readonly string $customerPhone,
        /** This country's credentials for THIS gateway only, keys already un-prefixed. */
        public readonly array $credentials,
        public readonly ?int $countryId,
        /** Where the gateway sends the shopper back to. */
        public readonly string $successUrl,
        public readonly string $failureUrl,
        /** Server-to-server callback for this gateway. */
        public readonly string $webhookUrl,
        public readonly array $meta = [],
    ) {}

    public function isWalletRecharge(): bool
    {
        return $this->purpose === 'wallet';
    }
}
