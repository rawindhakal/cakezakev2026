<?php

namespace App\Services\Plugin;

use App\Plugins\PluginRegistry;
use App\Models\Plugin;

/**
 * What plugins exist, and how each one relates to this install.
 *
 * The list itself comes from `config/plugin_catalog.php` — a static file, so the panel
 * never waits on a network call and an offline install still shows the shop window.
 * When the catalogue moves to a hosted endpoint only `entries()` changes.
 */
final class PluginCatalog
{
    /** Raw catalogue entries, keyed by slug. */
    public function entries(): array
    {
        $out = [];
        foreach ((array) config('plugin_catalog.plugins', []) as $entry) {
            $slug = (string) ($entry['slug'] ?? '');
            if ($slug !== '') {
                $out[$slug] = $entry;
            }
        }

        return $out;
    }

    public function find(string $slug): ?array
    {
        return $this->entries()[$slug] ?? null;
    }

    /**
     * The catalogue with install state folded in — one list the Plugins page can render.
     *
     * @return array<int,array>
     */
    public function available(): array
    {
        $installed = $this->installedBySlug();
        $retained = $this->uninstalledBySlug();
        $core = (string) currentVersion();

        $out = [];
        foreach ($this->entries() as $slug => $entry) {
            $row = $installed[$slug] ?? null;
            $latest = (string) ($entry['version'] ?? '0.0.0');

            $out[] = array_merge($entry, [
                'is_installed'      => (bool) $row,
                'installed_version' => $row?->version,
                'update_available'  => $row && version_compare($latest, (string) $row->version, '>'),
                'core_compatible'   => empty($entry['core_min']) || version_compare($core, (string) $entry['core_min'], '>='),
                /* Uninstalled but its data was kept: the card offers a plain install, and
                   says the settings and history are still there to be picked up. */
                'has_retained_data' => isset($retained[$slug]),
            ]);
        }

        return $out;
    }

    /**
     * Installed plugins as the panel sees them: never the purchase code, only its last 4.
     *
     * @return array<int,array>
     */
    public function installed(): array
    {
        $registry = app(PluginRegistry::class);
        $broken = $registry->broken();
        $catalogue = $this->entries();

        /* An uninstalled plugin is not installed, whatever its row still holds. Its files
           are gone, so listing it here would show a card whose every action fails — it
           belongs in the catalogue below, offering a fresh install. */
        return Plugin::where('status', '!=', Plugin::STATUS_UNINSTALLED)
            ->orderBy('name')->get()->map(function (Plugin $plugin) use ($broken, $catalogue) {
            $entry = $catalogue[$plugin->slug] ?? [];
            $latest = (string) ($entry['version'] ?? $plugin->version);

            return [
                'slug'                => $plugin->slug,
                'name'                => $plugin->name,
                'version'             => $plugin->version,
                'type'                => $plugin->type,
                'capabilities'        => (array) $plugin->capabilities,
                'status'              => $plugin->status,
                'enabled'             => (bool) $plugin->enabled,
                'licence_state'       => $plugin->licence_state,
                /* Which core a plugin needs is stated in OUR catalogue, not in the
                   package: `module.json` has no field for it, and one that did could
                   be edited by whoever holds the zip. A plugin we do not list carries
                   no constraint, so it is compatible by default. */
                'core_min'            => $catalogue[$plugin->slug]['core_min'] ?? null,
                'core_compatible'     => empty($catalogue[$plugin->slug]['core_min'])
                    || version_compare((string) currentVersion(), (string) $catalogue[$plugin->slug]['core_min'], '>='),
                'licence_message'     => $plugin->licence_message,
                'licence_verified_at' => optional($plugin->licence_verified_at)->toDateTimeString(),
                'purchase_code_last4' => $plugin->purchase_code_last4,
                'installed_at'        => optional($plugin->installed_at)->toDateTimeString(),
                'settings_scope'      => $plugin->settings_scope,
                /* Does this plugin have a settings page of its own? Fields alone are not
                   enough: a country-scoped plugin's fields are rendered inside the country
                   form, so its own page would only say so — a button leading nowhere. */
                /* Only a shipping plugin has a page of its own: a payment plugin's
                   credentials are per country, so they render inside the country form
                   and a page for them could only say so. */
                'has_settings'        => $plugin->type === 'shipping',
                'files_present'       => is_dir(app_path('Modules/' . $plugin->slug)),
                'broken_reason'       => $broken[$plugin->slug] ?? null,
                'last_error'          => $plugin->last_error,
                'update_available'    => version_compare($latest, (string) $plugin->version, '>'),
                'latest_version'      => $latest,
                'icon'                => $entry['icon'] ?? null,
                'docs_url'            => $entry['docs_url'] ?? null,
            ];
        })->values()->all();
    }

    /** @return array<string,Plugin> */
    private function installedBySlug(): array
    {
        try {
            return Plugin::where('status', '!=', Plugin::STATUS_UNINSTALLED)->get()->keyBy('slug')->all();
        } catch (\Throwable $e) {
            return [];
        }
    }

    /**
     * Rows left behind by an uninstall that kept its data.
     *
     * @return array<string,Plugin>
     */
    private function uninstalledBySlug(): array
    {
        try {
            return Plugin::where('status', Plugin::STATUS_UNINSTALLED)->get()->keyBy('slug')->all();
        } catch (\Throwable $e) {
            return [];
        }
    }

}
