<?php

namespace App\Services\Plugin;

use App\Plugins\PluginRegistry;
use App\Models\Plugin;
use App\Plugins\PluginAutoloader;
use App\Plugins\PluginManifest;
use App\Plugins\PluginPackage;
use App\Support\SafeZip;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Log;

/**
 * Installs a plugin: the package format every CakeZake product shares.
 *
 * The order of operations is where the safety lives. The purchase code is checked
 * BEFORE the archive is opened, so a package that fails its licence is never written to
 * disk at all. And the slug is read from the manifest inside the zip rather than from
 * the file name or the upload form, so a package can never be installed under a name
 * that is not its own — the form's slug is only ever a guard that must agree.
 *
 * A plugin ships no migrations: the tables a shipping plugin fills belong to core, so
 * that a second carrier cannot bring a second schema and uninstalling one cannot
 * destroy the shop's history.
 */
final class PluginInstaller
{
    private const LOCK = 'plugin-install';

    public function __construct(private PluginLicenceService $licences) {}

    /**
     * @return array{ok:bool, message:string, slug?:string, version?:string, updated?:bool}
     */
    public function install(UploadedFile $zip, string $purchaseCode, ?int $userId = null, string $expectedSlug = ''): array
    {
        // The same lock our own installer takes: two installs writing at once could
        // leave either half-applied.
        $lock = Cache::lock(self::LOCK, 300);

        if (!$lock->get()) {
            return $this->fail('another_plugin_operation_is_in_progress');
        }

        $work = storage_path('app/plugins_install/' . time() . '_' . random_int(1000, 9999));
        $backup = null;
        $slug = null;

        try {
            if (!class_exists(\ZipArchive::class)) {
                return $this->fail('php_zip_extension_is_required');
            }

            if (strtolower((string) $zip->getClientOriginalExtension()) !== 'zip') {
                return $this->fail('please_upload_a_valid_zip_file');
            }

            // ---- 1. what is in the package, without unpacking it ----------
            $peeked = $this->peek($zip->getRealPath());

            if (isset($peeked['error'])) {
                return $this->fail($peeked['error']);
            }

            [$slug, $manifest] = [$peeked['slug'], $peeked['manifest']];
            $expectedSlug = strtolower(trim($expectedSlug));

            if ($expectedSlug !== '' && $expectedSlug !== $slug) {
                return $this->fail('plugin_package_is_for_a_different_plugin', [
                    'expected' => $expectedSlug,
                    'found'    => $slug,
                ]);
            }

            if ($error = $this->manifestError($slug, $manifest)) {
                return $this->fail($error);
            }

            if ($error = $this->coreVersionError($slug, $manifest)) {
                return $this->fail($error, [
                    'required' => $this->requiredCore($slug, $manifest),
                    'current'  => (string) currentVersion(),
                ]);
            }

            /* Going backwards is refused outright. It is usually the wrong file picked
               out of a downloads folder, and it is the one mistake this installer cannot
               undo afterwards: the older code lands on top of the newer version's
               schema, which stays migrated. There is no confirmation to click past,
               because a shop that genuinely has to step back needs the schema dealt with
               too, and that is not a decision to take from an upload dialog. */
            $installedVersion = trim((string) (Plugin::where('slug', $slug)->value('version') ?? ''));
            $incomingVersion = trim((string) ($manifest['version'] ?? ''));

            if ($installedVersion !== '' && $incomingVersion !== ''
                && version_compare($incomingVersion, $installedVersion, '<')) {
                return $this->fail('plugin_package_is_older_than_the_installed_version', [
                    'installed' => $installedVersion,
                    'uploaded'  => $incomingVersion,
                ]);
            }

            // ---- 2. licence, before a single byte lands -------------------
            $licence = $this->licences->verifyPurchase($slug, $purchaseCode);

            if (!$licence->ok) {
                if (!$licence->reachable) {
                    return $this->fail($licence->message === 'licence_too_many_attempts'
                        ? 'licence_too_many_attempts'
                        : 'licence_validator_unreachable');
                }

                $reason = trim((string) $licence->message);

                return $this->fail($reason !== '' && $reason !== 'licence_was_rejected' ? $reason : 'invalid_purchase_code');
            }

            // ---- 3. now unpack -------------------------------------------
            File::ensureDirectoryExists($work);

            /* A plugin keeps its PHP under its own app/ directory and nowhere else, so
               the allow-list says exactly that: class files are extracted, a migration
               smuggled in beside them is not. Core owns the schema. */
            $opts = (array) config('plugins.install');
            $opts['php_dirs'] = ['app'];

            SafeZip::extract($zip->getRealPath(), $work . '/extracted', $opts);

            $source = $this->unwrap($work . '/extracted', $slug);

            if (!is_file($source . '/module.json')) {
                return $this->fail('plugin_manifest_is_missing');
            }

            // Re-read from the extracted copy. The peek told us what to expect; this is
            // what actually arrived, and only this is installed.
            $staged = json_decode((string) file_get_contents($source . '/module.json'), true);

            if (!is_array($staged) || ($staged['slug'] ?? null) !== $slug) {
                return $this->fail('plugin_package_name_does_not_match_its_manifest');
            }

            $mainClass = $staged['main_class'] ?? null;

            if (!is_string($mainClass) || !str_starts_with($mainClass, PluginManifest::namespaceFor($slug))) {
                return $this->fail('plugin_main_class_is_outside_its_own_namespace');
            }

            $classFile = $source . '/' . PluginManifest::mainClassFile($slug, $mainClass);

            if (!is_file($classFile)) {
                return $this->fail('plugin_main_class_file_is_missing');
            }

            // ---- 4. put it in place --------------------------------------
            $target = app_path('Modules/' . $slug);
            $existing = Plugin::where('slug', $slug)->first();
            $updated = is_dir($target);

            if (!$this->canWrite(app_path('Modules'))) {
                return $this->fail('plugins_directory_is_not_writable');
            }

            if ($updated) {
                // Kept until the new copy is in and the row is written, so a failure
                // half way leaves the working version rather than nothing.
                $backup = $work . '/backup';
                File::moveDirectory($target, $backup);
            }

            File::ensureDirectoryExists(dirname($target));
            File::copyDirectory($source, $target);

            /* Map the namespace now. The service provider does this at boot, which for
               the request doing the install ran before the folder existed — so without
               it the plugin we just wrote would be unloadable until the next request. */
            PluginAutoloader::register($slug);

            /* A product-scoped plugin may bring its own schema and its own strings.
               Both are applied now, while the installer still holds the lock and can
               still put the previous version back if something fails. */
            $langKeys = $this->mergePluginLanguage($slug, $staged, $existing);

            // ---- 5. record it --------------------------------------------
            $version = trim((string) ($staged['version'] ?? '1.0.0'));

            Plugin::updateOrCreate(['slug' => $slug], [
                'name'                => (string) ($staged['name'] ?? $slug),
                'version'             => $version,
                'type'                => (string) ($staged['type'] ?? 'plugin'),
                // Everything else about the plugin is read from this, live, so that an
                // update cannot leave the row describing the previous version.
                'manifest'            => $staged,
                'status'              => 'installed',
                'enabled'             => $existing ? (bool) $existing->enabled : true,
                'purchase_code'       => $purchaseCode,
                'purchase_code_last4' => substr($purchaseCode, -4),
                'verify_url'          => $licence->url,
                'licence_state'       => 'valid',
                'licence_verified_at' => now(),
                'licence_message'     => null,
                'lang_keys'           => $langKeys,
                'installed_by'        => $userId,
                'installed_at'        => $existing?->installed_at ?? now(),
                'last_error'          => null,
            ]);

            $this->refresh();

            return [
                'ok'      => true,
                'message' => $updated ? 'plugin_updated_successfully' : 'plugin_installed_successfully',
                'slug'    => $slug,
                'version' => $version,
                'updated' => $updated,
            ];
        } catch (\Throwable $e) {
            Log::error('[Plugins] install failed', ['slug' => $slug, 'message' => $e->getMessage()]);

            // Put the previous version back before reporting, so a failed update leaves
            // a working plugin rather than an empty folder.
            if ($slug && $backup && is_dir($backup)) {
                $target = app_path('Modules/' . $slug);
                File::deleteDirectory($target);
                File::moveDirectory($backup, $target);
                $backup = null;
            }

            return $this->fail($e->getMessage() ?: 'plugin_installation_failed');
        } finally {
            File::deleteDirectory($work);
            $lock->release();
        }
    }

    /**
     * Switch a plugin on.
     *
     * What has to hold is that the code is actually there and the licence still
     * permits it: an admin re-enabling a plugin whose files were deleted over FTP
     * should be told so, not left with a gateway that silently does nothing.
     */
    public function enable(Plugin $plugin): array
    {
        $package = PluginPackage::fromDisk($plugin->slug, $plugin->licence_state ?? 'unverified', true);

        if (!$package) {
            return $this->fail('plugin_files_are_missing_reinstall_it');
        }

        if (!$package->isIntact()) {
            return $this->fail('plugin_main_class_file_is_missing');
        }

        if (!$plugin->licenceAllowsBoot()) {
            return $this->fail('plugin_licence_is_not_valid');
        }

        $plugin->enabled = true;
        $plugin->status = Plugin::STATUS_ACTIVE;
        $plugin->last_error = null;
        $plugin->save();

        $this->refresh();

        return ['ok' => true, 'message' => 'plugin_enabled_successfully'];
    }

    public function disable(Plugin $plugin): array
    {
        $plugin->enabled = false;
        $plugin->status = Plugin::STATUS_DISABLED;
        $plugin->save();

        $this->refresh();

        return ['ok' => true, 'message' => 'plugin_disabled_successfully'];
    }

    /**
     * Remove a plugin: its folder, its row, its strings and its caches.
     *
     * Nothing of the shop's goes with it. A plugin brings no tables — the host owns
     * every one of them — so uninstalling is safe by construction rather than by the
     * admin answering a question correctly. Re-uploading a newer build, which is what
     * an uninstall usually precedes, picks the shop up exactly where it left off:
     * credentials, waybills and shipment history are all core's.
     */
    public function uninstall(Plugin $plugin): array
    {
        $lock = Cache::lock(self::LOCK, 300);

        if (!$lock->get()) {
            return $this->fail('another_plugin_operation_is_in_progress');
        }

        try {
            /* No question to ask any more. A plugin owns no tables, so the only thing it
               leaves behind is the wording it brought — which is meaningless once its
               code is gone, and would otherwise sit in the language file forever. The
               shop's own data is untouched because it was never the plugin's. */
            $this->removePluginLanguage($plugin);

            File::deleteDirectory(app_path('Modules/' . $plugin->slug));
            $plugin->delete();
            $this->refresh();

            return ['ok' => true, 'message' => 'plugin_uninstalled_successfully', 'slug' => $plugin->slug];
        } finally {
            $lock->release();
        }
    }

    /**
     * Merge the plugin's English strings into the panel's, and return the keys it owns.
     *
     * A product-scoped plugin keeps its own wording, which is where it belongs: the
     * alternative is several hundred carrier-specific keys living in core for a plugin
     * a given shop may never buy.
     *
     * @return array<int,string> the keys this plugin brought, recorded on its row
     */
    private function mergePluginLanguage(string $slug, array $manifest, ?Plugin $existing): array
    {
        if (PluginManifest::scope($slug, $manifest) !== 'product') {
            return [];
        }

        $relative = PluginManifest::langPath($slug, $manifest);

        if (!$relative) {
            return [];
        }

        $source = PluginManifest::path($slug, trim($relative, '/') . '/en.json');
        $target = resource_path('lang/en.json');

        if (!is_file($source) || !is_file($target)) {
            return [];
        }

        $incoming = json_decode((string) file_get_contents($source), true);
        $current = json_decode((string) file_get_contents($target), true);

        if (!is_array($incoming) || !is_array($current)) {
            Log::warning("[Plugin:{$slug}] language file could not be read; strings were left alone.");

            return (array) ($existing?->lang_keys ?? []);
        }

        /* Who wins a collision depends on who owns the key.
           Core wins against a key core defines — a plugin must not be able to reword the
           panel around it. But a key this same plugin brought in an earlier version is
           the plugin's own, and core only holds a copy of it: if core won those too, a
           plugin could never correct its own wording, which is a bug with no workaround
           short of editing the client's language file by hand. */
        $owned = array_flip(array_map('strval', (array) ($existing?->lang_keys ?? [])));
        $merged = $current;
        $keys = [];

        foreach ($incoming as $key => $value) {
            $key = (string) $key;

            /* Recorded only when the plugin actually won it. A key core already held and
               kept is core's, and must not end up on the plugin's owned list — that list
               is what the NEXT version is allowed to overwrite, so claiming a word here
               would be a way to take a core string one update later. */
            if (!array_key_exists($key, $merged) || isset($owned[$key])) {
                $merged[$key] = $value;
                $keys[] = $key;
            }
        }

        if ($merged !== $current) {
            file_put_contents(
                $target,
                json_encode($merged, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . "\n"
            );
        }

        return array_values(array_unique($keys));
    }

    /**
     * Take the plugin's strings back out of core's language file.
     *
     * Only on an uninstall that was asked to remove the plugin's data, and only the keys
     * this plugin brought — a key core had already is core's, and was never replaced.
     */
    private function removePluginLanguage(Plugin $plugin): void
    {
        $keys = (array) ($plugin->lang_keys ?? []);

        if (!$keys) {
            return;
        }

        $target = resource_path('lang/en.json');

        if (!is_file($target)) {
            return;
        }

        $current = json_decode((string) file_get_contents($target), true);

        if (!is_array($current)) {
            return;
        }

        $remaining = array_diff_key($current, array_flip(array_map('strval', $keys)));

        if (count($remaining) === count($current)) {
            return;
        }

        file_put_contents(
            $target,
            json_encode($remaining, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . "\n"
        );
    }

    /* ------------------------------------------------------------------ helpers */

    /**
     * Read the manifest out of the archive without extracting anything.
     *
     * The slug has to come from inside the package — it decides the install path, the
     * namespace and which licence is checked — and reading it before extraction is what
     * lets the licence be checked first.
     *
     * @return array{slug?:string, manifest?:array, error?:string}
     */
    private function peek(string $zipPath): array
    {
        $zip = new \ZipArchive();

        if ($zip->open($zipPath) !== true) {
            return ['error' => 'please_upload_a_valid_zip_file'];
        }

        try {
            // Flat, or wrapped in one folder — both are normal, and the wrapper's name
            // is not trusted either way.
            $entry = null;

            for ($i = 0; $i < $zip->numFiles; $i++) {
                $name = (string) $zip->getNameIndex($i);

                if ($name === 'module.json' || preg_match('#^[^/]+/module\.json$#', $name)) {
                    $entry = $name;
                    break;
                }
            }

            if ($entry === null) {
                return ['error' => 'plugin_manifest_is_missing'];
            }

            $raw = $zip->getFromName($entry);
            $manifest = $raw !== false ? json_decode($raw, true) : null;

            if (!is_array($manifest)) {
                return ['error' => 'plugin_manifest_is_not_valid_json'];
            }

            $slug = strtolower(trim((string) ($manifest['slug'] ?? '')));

            if (!PluginManifest::validSlug($slug)) {
                return ['error' => 'plugin_manifest_is_missing_a_valid_slug'];
            }

            return ['slug' => $slug, 'manifest' => $manifest];
        } finally {
            $zip->close();
        }
    }

    /** Everything about the manifest that can be refused before unpacking. */
    private function manifestError(string $slug, array $manifest): ?string
    {
        $mainClass = $manifest['main_class'] ?? null;

        if (!is_string($mainClass) || $mainClass === '') {
            return 'plugin_manifest_must_declare_main_class';
        }

        if (!str_starts_with($mainClass, PluginManifest::namespaceFor($slug))) {
            return 'plugin_main_class_is_outside_its_own_namespace';
        }

        $type = strtolower(trim((string) ($manifest['type'] ?? '')));

        // An unknown type would install cleanly and then do nothing, with no way for
        // the admin to tell why, so it is refused while there is still a message to
        // show.
        if (!in_array($type, ['payment', 'shipping'], true)) {
            return 'plugin_type_is_not_supported_by_this_version';
        }

        return null;
    }

    /**
     * The core version this package needs, if it says.
     *
     * The package's own word comes first — only it knows what it was built against —
     * and the catalogue is the fallback for the plugins we sell, whose requirement we
     * publish on the card before anyone has downloaded anything.
     */
    private function requiredCore(string $slug, array $manifest): string
    {
        foreach (['core_min', 'min_core_version'] as $key) {
            $declared = trim((string) ($manifest[$key] ?? ''));

            if ($declared !== '') {
                return $declared;
            }
        }

        return trim((string) (app(PluginCatalog::class)->find($slug)['core_min'] ?? ''));
    }

    /**
     * Refuse a package built for a core this install does not have.
     *
     * It would otherwise install cleanly and fail later against a method or a column
     * that does not exist yet — at a checkout or a booking, where the admin has no way
     * to connect the failure to the upload that caused it.
     */
    private function coreVersionError(string $slug, array $manifest): ?string
    {
        $required = $this->requiredCore($slug, $manifest);

        if ($required === '') {
            return null;   // says nothing, so nothing to hold it to
        }

        return version_compare((string) currentVersion(), $required, '>=')
            ? null
            : 'plugin_requires_a_newer_core_version';
    }


    /** A single wrapper folder is unwrapped, whatever it is called. */
    private function unwrap(string $dir, string $slug): string
    {
        if (is_file($dir . '/module.json')) {
            return $dir;
        }

        $entries = array_values(array_diff(scandir($dir) ?: [], ['.', '..', '__MACOSX', '.DS_Store']));

        if (count($entries) === 1 && is_dir($dir . '/' . $entries[0]) && is_file($dir . '/' . $entries[0] . '/module.json')) {
            return $dir . '/' . $entries[0];
        }

        return $dir;
    }

    private function canWrite(string $target): bool
    {
        File::ensureDirectoryExists($target);

        return is_writable($target);
    }

    /** Rebuild everything that remembers which plugins exist. */
    private function refresh(): void
    {
        app(PluginRegistry::class)->flush();

        try {
            Artisan::call('optimize:clear');
        } catch (\Throwable $e) {
            // A failed cache clear is not a failed install; the next request rebuilds.
            Log::warning('[Plugins] optimize:clear failed after install: ' . $e->getMessage());
        }

        /* A daemon worker booted before this install has never seen the plugin's classes,
           so its jobs would fail until someone restarted it by hand. */
        try {
            Artisan::call('queue:restart');
        } catch (\Throwable $e) {
            Log::warning('[Plugins] queue:restart failed after install: ' . $e->getMessage());
        }
    }

    private function fail(string $message, array $replace = []): array
    {
        return ['ok' => false, 'message' => $message, 'replace' => $replace];
    }
}
