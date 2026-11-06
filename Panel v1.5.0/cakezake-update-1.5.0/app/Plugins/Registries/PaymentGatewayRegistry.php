<?php

namespace App\Plugins\Registries;

use Illuminate\Support\Facades\Log;

/**
 * Payment gateways contributed by plugins.
 *
 * Core's nine gateways keep their existing hand-written branches in
 * Customer/OrderApiController::initiateTransaction — this registry is consulted only
 * where that chain used to give up, so an plugin can add a gateway without any core
 * gateway changing behaviour. Their names are reserved so an plugin can never shadow one.
 */
final class PaymentGatewayRegistry
{
    public const RESERVED = [
        'cod', 'wallet', 'razorpay', 'paypal', 'stripe', 'paystack',
        'midtrans', 'phonepe', 'cashfree', 'paytabs', 'inapppurchase',
    ];

    /** @var array<string,string|object> lowercased code => driver */
    private array $drivers = [];
    private array $labels = [];
    private array $owners = [];

    public function register(string $code, string|object $driver, string $pluginSlug, ?string $label = null): bool
    {
        $key = strtolower(trim($code));
        if ($key === '' || in_array($key, self::RESERVED, true)) {
            Log::warning("[Plugins] '{$code}' is a core payment method; '{$pluginSlug}' was ignored.");

            return false;
        }
        if (isset($this->drivers[$key])) {
            return false;
        }

        $this->drivers[$key] = $driver;
        $this->labels[$key] = $label ?: $code;
        $this->owners[$key] = $pluginSlug;

        return true;
    }

    public function has(?string $code): bool
    {
        return $code !== null && isset($this->drivers[strtolower($code)]);
    }

    public function driver(?string $code)
    {
        $entry = $this->drivers[strtolower((string) $code)] ?? null;

        return is_string($entry) ? app($entry) : $entry;
    }

    /** Display names, keyed by the value stored in orders.payment_method. */
    public function labels(): array
    {
        return $this->labels;
    }

    public function keys(): array
    {
        return array_keys($this->drivers);
    }

    public function ownerOf(string $code): ?string
    {
        return $this->owners[strtolower($code)] ?? null;
    }
}
