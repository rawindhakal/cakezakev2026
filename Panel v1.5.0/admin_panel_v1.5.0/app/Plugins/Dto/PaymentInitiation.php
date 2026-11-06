<?php

namespace App\Plugins\Dto;

/**
 * How the app should continue the payment the driver just started.
 *
 * Three shapes cover every gateway core already supports: send the shopper to a hosted
 * page, hand the app a payload for a native SDK, or return a token/order id the app
 * completes with.
 */
final class PaymentInitiation
{
    public const REDIRECT = 'redirect';
    public const PAYLOAD  = 'payload';
    public const TOKEN    = 'token';

    private function __construct(
        public readonly bool $ok,
        public readonly string $type,
        public readonly ?string $url = null,
        public readonly array $payload = [],
        public readonly ?string $token = null,
        public readonly ?string $gatewayOrderId = null,
        public readonly ?string $error = null,
    ) {}

    public static function redirect(string $url, ?string $gatewayOrderId = null, array $payload = []): self
    {
        return new self(true, self::REDIRECT, url: $url, payload: $payload, gatewayOrderId: $gatewayOrderId);
    }

    /** A payload the customer app posts itself (a form, an SDK options object). */
    public static function payload(array $payload, ?string $gatewayOrderId = null): self
    {
        return new self(true, self::PAYLOAD, payload: $payload, gatewayOrderId: $gatewayOrderId);
    }

    public static function token(string $token, ?string $gatewayOrderId = null, array $payload = []): self
    {
        return new self(true, self::TOKEN, payload: $payload, token: $token, gatewayOrderId: $gatewayOrderId);
    }

    public static function failed(string $error): self
    {
        return new self(false, self::REDIRECT, error: $error);
    }

    /** What the customer API returns, so every gateway answers in one shape. */
    public function toArray(): array
    {
        return array_filter([
            'type'             => $this->type,
            'url'              => $this->url,
            'payload'          => $this->payload ?: null,
            'token'            => $this->token,
            'gateway_order_id' => $this->gatewayOrderId,
        ], fn ($v) => $v !== null);
    }
}
