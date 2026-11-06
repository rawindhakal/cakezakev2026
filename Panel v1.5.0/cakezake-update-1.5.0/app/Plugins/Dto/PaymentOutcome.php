<?php

namespace App\Plugins\Dto;

/**
 * What a gateway's callback means, in our vocabulary.
 *
 * A driver decides only "did this succeed, for which reference, for how much" — core
 * settles it. The driver never writes a transaction, moves an order or credits a wallet,
 * so a buggy plugin cannot invent money.
 */
final class PaymentOutcome
{
    public const SUCCESS = 'success';
    public const FAILED  = 'failed';
    public const PENDING = 'pending';
    public const IGNORE  = 'ignore';   // heartbeat / duplicate event the driver knows about

    private function __construct(
        public readonly string $status,
        /** `order-{id}-{userId}` / `wallet-{YmdHis}-{userId}[-c{countryId}]`. */
        public readonly string $reference = '',
        public readonly ?string $gatewayTxnId = null,
        public readonly float $amount = 0.0,
        public readonly ?string $message = null,
        public readonly array $raw = [],
    ) {}

    public static function success(string $reference, ?string $gatewayTxnId, float $amount, array $raw = []): self
    {
        return new self(self::SUCCESS, $reference, $gatewayTxnId, $amount, null, $raw);
    }

    public static function failed(string $reference, ?string $gatewayTxnId = null, float $amount = 0.0, ?string $message = null, array $raw = []): self
    {
        return new self(self::FAILED, $reference, $gatewayTxnId, $amount, $message, $raw);
    }

    /** Awaiting the gateway's final word: nothing is settled yet. */
    public static function pending(string $reference, ?string $gatewayTxnId = null, ?string $message = null): self
    {
        return new self(self::PENDING, $reference, $gatewayTxnId, 0.0, $message);
    }

    public static function ignore(?string $message = null): self
    {
        return new self(self::IGNORE, '', null, 0.0, $message);
    }

    public function isSuccess(): bool
    {
        return $this->status === self::SUCCESS;
    }

    public function isFailure(): bool
    {
        return $this->status === self::FAILED;
    }
}
