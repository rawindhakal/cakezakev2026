<?php

namespace App\Plugins\Registries;

use App\Helpers\Sms\SmsDriverInterface;
use Illuminate\Support\Facades\Log;

/**
 * SMS gateways contributed by plugins, merged with the four core drivers in
 * SmsHelper::driver(). Core keys win, so an plugin cannot shadow a built-in gateway.
 */
final class SmsGatewayRegistry
{
    /** Keys SmsHelper already owns. */
    public const RESERVED = ['twilio', 'msg91', 'fast2sms', 'twofactor'];

    /** @var array<string,class-string<SmsDriverInterface>> */
    private array $drivers = [];
    private array $owners = [];
    private array $schemas = [];

    public function register(string $key, string $driverClass, string $pluginSlug, array $settingsSchema = []): bool
    {
        $key = strtolower(trim($key));
        if ($key === '' || in_array($key, self::RESERVED, true)) {
            Log::warning("[Plugins] '{$key}' is a core SMS gateway; '{$pluginSlug}' was ignored.");

            return false;
        }
        if (isset($this->drivers[$key])) {
            return false;
        }
        if (!is_subclass_of($driverClass, SmsDriverInterface::class)) {
            Log::error("[Plugins] {$driverClass} does not implement SmsDriverInterface; '{$key}' not registered.");

            return false;
        }

        $this->drivers[$key] = $driverClass;
        $this->owners[$key] = $pluginSlug;
        $this->schemas[$key] = $settingsSchema;

        return true;
    }

    public function driverClass(string $key): ?string
    {
        return $this->drivers[strtolower($key)] ?? null;
    }

    public function keys(): array
    {
        return array_keys($this->drivers);
    }

    public function schemas(): array
    {
        return $this->schemas;
    }

    public function ownerOf(string $key): ?string
    {
        return $this->owners[strtolower($key)] ?? null;
    }
}
