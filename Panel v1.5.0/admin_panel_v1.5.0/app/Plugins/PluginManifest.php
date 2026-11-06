<?php

namespace App\Plugins;

use Illuminate\Support\Str;

/**
 * The one place a universal plugin's `module.json` is read.
 *
 * A universal plugin is the format every CakeZake product shares: a kebab-case folder
 * under `app/Modules/`, its slug as the folder name, and all of its PHP under that
 * folder's own `app/` directory namespaced `App\Modules\{StudlySlug}\`. That shape is
 * fixed by the format, not by us — the same zip installs in eClassify and here — so
 * every path is derived from the slug and nothing is read out of the manifest.
 *
 * This is the only plugin format CakeZake hosts.
 */
class PluginManifest
{
    /** Folder names are the identity, so they are checked before being used as a path. */
    public const SLUG_PATTERN = '/^[a-z][a-z0-9]*(-[a-z0-9]+)*$/';

    public static function path(string $slug, string $relative = ''): string
    {
        return app_path('Modules/' . $slug . ($relative === '' ? '' : '/' . ltrim($relative, '/')));
    }

    public static function read(string $slug): ?array
    {
        if (!self::validSlug($slug)) {
            return null;
        }

        $path = self::path($slug, 'module.json');

        if (!is_file($path)) {
            return null;
        }

        $manifest = json_decode((string) file_get_contents($path), true);

        return is_array($manifest) ? $manifest : null;
    }

    /**
     * A manifest whose slug disagrees with its folder is refused rather than trusted:
     * the folder decides the namespace and the licence, so the two must agree.
     */
    public static function readValidated(string $slug): ?array
    {
        $manifest = self::read($slug);

        if (!$manifest || ($manifest['slug'] ?? null) !== $slug) {
            return null;
        }

        return $manifest;
    }

    public static function validSlug(string $slug): bool
    {
        return (bool) preg_match(self::SLUG_PATTERN, $slug);
    }

    public static function webhookSegment(string $slug, array $fallback = []): string
    {
        $manifest = self::readValidated($slug) ?: $fallback;
        $alias = strtolower(trim((string) ($manifest['webhook_alias'] ?? '')));

        return preg_match('/^[a-z][a-z0-9_\-]{2,39}$/', $alias) ? $alias : $slug;
    }

    /** `payu-india-payment-gateway` -> `App\Modules\PayuIndiaPaymentGateway\` */
    public static function namespaceFor(string $slug): string
    {
        return 'App\\Modules\\' . Str::studly($slug) . '\\';
    }

    /** Every folder that looks like a plugin, whether or not it is licensed. */
    public static function installedSlugs(): array
    {
        $root = app_path('Modules');

        if (!is_dir($root)) {
            return [];
        }

        $slugs = [];

        foreach (glob($root . '/*', GLOB_ONLYDIR) ?: [] as $dir) {
            $slug = basename($dir);

            if (self::validSlug($slug) && is_file($dir . '/module.json')) {
                $slugs[] = $slug;
            }
        }

        sort($slugs);

        return $slugs;
    }

    /**
     * The class that makes the plugin work — its gateway, its provider, its service.
     *
     * Returned only when it sits inside the plugin's own namespace. A manifest naming
     * a class outside it would otherwise let a package point the host at any class in
     * the application and have it constructed with the plugin's credentials.
     */
    public static function mainClass(string $slug, ?array $manifest = null): ?string
    {
        $manifest ??= self::readValidated($slug);
        $class = $manifest['main_class'] ?? null;

        if (!is_string($class) || $class === '') {
            return null;
        }

        return str_starts_with($class, self::namespaceFor($slug)) ? $class : null;
    }

    /** The file `main_class` must live in, relative to the plugin folder. */
    public static function mainClassFile(string $slug, string $mainClass): string
    {
        $relative = substr($mainClass, strlen(self::namespaceFor($slug)));

        return 'app/' . str_replace('\\', '/', $relative) . '.php';
    }

    /**
     * How portable a plugin claims to be.
     *
     * `universal` is the default and the stricter promise: the package must work in any
     * CakeZake product, so it may assume nothing beyond the shared contracts. `product`
     * says the opposite — this one was written for a single product and is free to lean
     * on its models, ship its own schema and register its own commands.
     *
     * It changes what the host permits, not where the licence is checked: both are
     * licensed on the same validator line, because a product-scoped plugin is still
     * sold as one plugin.
     */
    public static function scope(string $slug, ?array $manifest = null): string
    {
        $manifest ??= self::readValidated($slug);
        $scope = strtolower(trim((string) ($manifest['scope'] ?? 'universal')));

        return $scope === 'product' ? 'product' : 'universal';
    }

    /** Relative path of the plugin's language folder, when it ships one. */
    public static function langPath(string $slug, ?array $manifest = null): ?string
    {
        $manifest ??= self::readValidated($slug);
        $dir = trim((string) ($manifest['lang'] ?? ''));

        if ($dir === '' || str_contains($dir, '..')) {
            return null;
        }

        return $dir;
    }

    /** 'payment', 'shipping', … — what the host should plug this into. */
    public static function type(string $slug, ?array $manifest = null): ?string
    {
        $manifest ??= self::readValidated($slug);
        $type = $manifest['type'] ?? null;

        return is_string($type) && $type !== '' ? $type : null;
    }

    /**
     * The settings the plugin needs, as the host must render them.
     *
     * Each entry is `{column, label, type, options?}`; `column` is one of the generic
     * credential columns the format defines, which is what keeps a plugin's settings
     * storable by a host that has never heard of it.
     */
    public static function settingsFields(string $slug, ?array $manifest = null): array
    {
        $manifest ??= self::readValidated($slug);
        $fields = $manifest['settings_fields'] ?? [];

        return is_array($fields) ? array_values(array_filter($fields, fn ($f) => is_array($f) && !empty($f['column']))) : [];
    }
}
