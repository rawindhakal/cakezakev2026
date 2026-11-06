<?php

namespace App\Plugins;

use Composer\Autoload\ClassLoader;

/**
 * Points a plugin's namespace at its folder.
 *
 * The format puts a plugin's code under `app/Modules/{kebab-slug}/app/` and namespaces
 * it `App\Modules\{StudlySlug}\`. Composer's `App\ => app/` mapping cannot reach that —
 * a hyphen is legal in a folder name and illegal in a namespace — so each installed
 * plugin is mapped explicitly. Longest prefix wins in PSR-4 resolution, so this never
 * disturbs the application's own mapping.
 *
 * Shared by the service provider, which maps every installed plugin at boot, and the
 * installer, which maps one the moment it lands. Without that second caller a plugin
 * installed during this request would stay unloadable until the next one.
 */
final class PluginAutoloader
{
    /** @var array<string,bool> slugs already mapped in this process */
    private static array $registered = [];

    public static function register(string $slug): void
    {
        if (isset(self::$registered[$slug])) {
            return;
        }

        $loader = self::classLoader();

        if (!$loader) {
            return;
        }

        $loader->addPsr4(
            PluginManifest::namespaceFor($slug),
            PluginManifest::path($slug, 'app') . DIRECTORY_SEPARATOR
        );

        self::$registered[$slug] = true;
    }

    /** Composer's own loader is the only thing that can add a PSR-4 prefix. */
    private static function classLoader(): ?ClassLoader
    {
        foreach (spl_autoload_functions() ?: [] as $callback) {
            if (is_array($callback) && ($callback[0] ?? null) instanceof ClassLoader) {
                return $callback[0];
            }
        }

        return null;
    }
}
