<?php

namespace App\Plugins\Registries;

use App\Plugins\Contracts\ShippingProvider;
use Illuminate\Support\Facades\Log;

/**
 * The couriers available to this install.
 *
 * Core ships none: every entry comes from an plugin calling register() during its own
 * register phase. Consumers ask this registry rather than knowing any carrier's name,
 * so the panel and the pricing code work the same whether zero or three are installed.
 */
final class ShippingProviderRegistry
{
    /** @var array<string,class-string<ShippingProvider>|ShippingProvider> */
    private array $providers = [];

    /** key => plugin slug that registered it. */
    private array $owners = [];

    public function register(string $key, string|ShippingProvider $provider, string $pluginSlug): bool
    {
        $key = strtolower(trim($key));
        if ($key === '') {
            return false;
        }
        if (isset($this->providers[$key])) {
            Log::warning("[Plugins] shipping provider '{$key}' is already registered; '{$pluginSlug}' was ignored.");

            return false;
        }
        if (is_string($provider) && !is_subclass_of($provider, ShippingProvider::class)) {
            Log::error("[Plugins] {$provider} does not implement ShippingProvider; '{$key}' not registered.");

            return false;
        }

        $this->providers[$key] = $provider;
        $this->owners[$key] = $pluginSlug;

        return true;
    }

    public function has(string $key): bool
    {
        return isset($this->providers[strtolower($key)]);
    }

    public function provider(?string $key): ?ShippingProvider
    {
        $key = strtolower((string) $key);
        $entry = $this->providers[$key] ?? null;
        if ($entry === null) {
            return null;
        }

        // Resolved through the container so a provider can take dependencies.
        return is_string($entry) ? app($entry) : $entry;
    }

    /** @return array<int,string> */
    public function keys(): array
    {
        return array_keys($this->providers);
    }

    public function ownerOf(string $key): ?string
    {
        return $this->owners[strtolower($key)] ?? null;
    }

    /**
     * Providers that can actually be used right now: configured, serving this channel
     * and this country.
     *
     * @return array<string,ShippingProvider>
     */
    public function usable(string $channel = 'ecommerce', ?string $countryCode = null): array
    {
        $out = [];
        foreach ($this->keys() as $key) {
            $provider = $this->provider($key);
            if (!$provider || !$provider->isConfigured()) {
                continue;
            }
            if (!in_array($channel, $provider->channels(), true)) {
                continue;
            }
            $countries = $provider->countries();
            if ($countryCode && $countries && !in_array(strtoupper($countryCode), array_map('strtoupper', $countries), true)) {
                continue;
            }
            $out[$key] = $provider;
        }

        return $out;
    }

    /** The one to use when the caller has no preference. */
    public function default(string $channel = 'ecommerce', ?string $countryCode = null): ?ShippingProvider
    {
        $usable = $this->usable($channel, $countryCode);

        return $usable ? reset($usable) : null;
    }

    /** The logo declared by the plugin that owns this provider, if any. */
    public function iconUrl(string $key): ?string
    {
        $slug = $this->ownerOf($key);

        return $slug
            ? app(\App\Plugins\PluginRegistry::class)->get($slug)?->iconUrl()
            : null;
    }

    /** For the panel: [['key','label','channels','quotes_on','configured','icon'], ...] */
    public function describe(): array
    {
        return collect($this->keys())->map(function (string $key) {
            $provider = $this->provider($key);

            return [
                'key'        => $key,
                'label'      => $provider?->label() ?? $key,
                'channels'   => $provider?->channels() ?? [],
                'quotes_on'  => $provider?->quotesOn() ?? 'weight',
                'countries'  => $provider?->countries() ?? [],
                'configured' => (bool) $provider?->isConfigured(),
                'plugin'      => $this->ownerOf($key),
                'icon'       => $this->iconUrl($key),
            ];
        })->values()->all();
    }
}
