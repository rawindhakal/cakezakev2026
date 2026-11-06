<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Master switch
    |--------------------------------------------------------------------------
    |
    | Set PLUGINS_ENABLED=false in .env to boot the panel with every plugin off.
    | This is the recovery path when a plugin breaks the app badly enough that the
    | per-plugin guards cannot catch it — a fatal error, an infinite loop.
    */
    'enabled' => env('PLUGINS_ENABLED', true),

    /*
    |--------------------------------------------------------------------------
    | Where plugins live
    |--------------------------------------------------------------------------
    |
    | One kebab-case folder per plugin, named after its slug, each namespaced
    | `App\Modules\{StudlySlug}\` from its own `app/` directory. This path is fixed by
    | the shared plugin format rather than chosen by us, which is what lets the same
    | package install in any CakeZake product — so it is stated here for reference and
    | derived from the slug everywhere it is used, never configured away from it.
    |
    | It sits inside the shipped `app` tree, so update packages exclude it explicitly
    | (see scripts/make-update-package.sh). The overlay never deletes files, which is
    | what lets a client's installed plugins survive a core update.
    */
    'path' => app_path('Modules'),

    /*
    |--------------------------------------------------------------------------
    | Licensing
    |--------------------------------------------------------------------------
    |
    | Everything about licensing lives in config/license.php, which is identical in
    | every CakeZake product. There is nothing to tune here: a purchase code is checked
    | once, when the plugin is installed, and the answer stands — so there is no
    | interval, no grace window and no scheduled re-check to configure.
    */

    /*
    |--------------------------------------------------------------------------
    | Installer limits
    |--------------------------------------------------------------------------
    */
    'install' => [
        'max_zip_kb'      => 102400,      // 100 MB upload
        'max_entries'     => 2000,
        'max_bytes'       => 200 * 1024 * 1024,
        'max_ratio'       => 200,         // compression-bomb guard
        // .php is only allowed where a plugin legitimately keeps code.
        'php_dirs'        => ['app'],
        'deny_names'      => ['.env', 'composer.json', 'composer.lock', '.htaccess', '.git', 'vendor'],
        'deny_extensions' => ['phar', 'so', 'sh', 'exe', 'bat'],
    ],
];
