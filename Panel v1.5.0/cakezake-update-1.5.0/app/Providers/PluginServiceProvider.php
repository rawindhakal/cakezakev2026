<?php

namespace App\Providers;

use App\Plugins\PluginAutoloader;
use App\Plugins\PluginManifest;
use App\Plugins\PluginPackage;
use App\Plugins\PluginRegistry;
use App\Plugins\Adapters\PaymentAdapter;
use App\Plugins\Adapters\ShippingAdapter;
use App\Plugins\Registries\PaymentGatewayRegistry;
use App\Plugins\Registries\ShippingProviderRegistry;
use App\Plugins\Registries\SmsGatewayRegistry;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\ServiceProvider;

/**
 * Boots the installed plugins.
 *
 * There is one plugin format: a kebab-case folder under `app/Modules/` carrying a
 * `module.json`, with its code namespaced `App\Modules\{StudlySlug}\`. The same package
 * installs in any CakeZake product, which is only true because the host adapts to the
 * plugin and never the other way round.
 *
 * Two phases, for two different reasons:
 *
 *  * **register()** makes every plugin folder *autoloadable*. Composer's `App\ => app/`
 *    mapping cannot reach `app/Modules/payu-india-payment-gateway/app/` — a hyphen is
 *    legal in a folder and illegal in a namespace — so each one is mapped explicitly.
 *    This touches no database, which is what lets it run this early. Autoloading is
 *    granted to every folder, licensed or not: the panel has to describe and configure
 *    a plugin whose licence has lapsed, and being able to name a class is not the same
 *    as running it.
 *
 *  * **boot()** decides what actually *runs*. Whether a plugin is enabled and licensed
 *    is a database question, so it cannot be asked any earlier.
 *
 * The registries are bound unconditionally, so core call sites never have to ask
 * whether the plugin system is switched on — with nothing installed they are simply
 * empty. And every plugin is wired inside its own try/catch: a broken plugin is logged
 * and skipped, never able to white-screen the panel.
 */
class PluginServiceProvider extends ServiceProvider
{
    /** Plugins are wired once per request. */
    private bool $wired = false;

    public function register(): void
    {
        $this->app->singleton(PluginRegistry::class);
        $this->app->singleton(PaymentGatewayRegistry::class);
        $this->app->singleton(SmsGatewayRegistry::class);
        $this->app->singleton(ShippingProviderRegistry::class);

        if (!config('plugins.enabled', true) || $this->rebuildingDatabase()) {
            return;
        }

        $this->registerAutoloading();
    }

    public function boot(): void
    {
        if ($this->wired || !config('plugins.enabled', true) || $this->rebuildingDatabase()) {
            return;
        }

        $this->wired = true;

        $registry = $this->app->make(PluginRegistry::class);

        foreach ($registry->runnable() as $slug => $plugin) {
            try {
                $this->wire($plugin);
            } catch (\Throwable $e) {
                // One plugin must never take the rest of the panel with it.
                Log::error("[Plugin:{$slug}] failed to boot.", ['message' => $e->getMessage()]);
            }
        }
    }

    /**
     * Plug one plugin into the registry its type belongs to.
     *
     * The plugin implements the shared contract; the registry consumes ours. The
     * adapter in between is the only thing that knows both, which is what keeps the
     * plugin portable and core unaware that a gateway came from a package at all.
     */
    private function wire(PluginPackage $plugin): void
    {
        switch ($plugin->type()) {
            case 'payment':
                $this->app->make(PaymentGatewayRegistry::class)->register(
                    $plugin->code(),
                    new PaymentAdapter($plugin),
                    $plugin->slug,
                    $plugin->name()
                );
                break;

            case 'shipping':
                $this->app->make(ShippingProviderRegistry::class)->register(
                    $plugin->slug,
                    new ShippingAdapter($plugin),
                    $plugin->slug
                );
                break;
        }

        // A plugin may also ship a service provider of its own — for routes, listeners
        // or commands. That one IS gated on licence, because registering it runs the
        // plugin's code on every request.
        $providerClass = $plugin->providerClass();

        if ($providerClass && class_exists($providerClass) && is_subclass_of($providerClass, ServiceProvider::class)) {
            $this->app->register($providerClass);
        } elseif ($providerClass) {
            Log::warning("[Plugin:{$plugin->slug}] provider {$providerClass} is missing or not a ServiceProvider.");
        }
    }

    /** Map each installed plugin's namespace onto its own folder. */
    private function registerAutoloading(): void
    {
        foreach (PluginManifest::installedSlugs() as $slug) {
            if (!PluginManifest::readValidated($slug)) {
                // Slug/folder mismatch or unreadable JSON. The panel reports it from
                // the same manifest, so this stays quiet.
                continue;
            }

            PluginAutoloader::register($slug);
        }
    }

    /**
     * Never let a plugin interfere with a database rebuild: migrate:fresh, db:wipe and
     * friends must run against core schema only.
     */
    private function rebuildingDatabase(): bool
    {
        if (!$this->app->runningInConsole()) {
            return false;
        }

        $argv = (array) ($_SERVER['argv'] ?? []);

        foreach (['migrate:fresh', 'migrate:install', 'migrate:reset', 'db:wipe'] as $command) {
            if (in_array($command, $argv, true)) {
                return true;
            }
        }

        return false;
    }
}
