<?php

namespace App\Services;

use App\Models\Language;
use App\Models\SupportedLanguage;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Translation JSON storage — FILES are the single source of truth.
 *
 * The `languages.json_data` column used to hold a copy of every platform's strings,
 * but only the admin panel ever wrote a file, so the two drifted badly (on this
 * install the admin file had grown to 167KB while its DB row still held 71KB, and
 * some languages had a DB row with no file at all). One branch, one truth.
 *
 * Layout — the admin panel keeps Laravel's own convention because `__()` and
 * welcome.blade.php read it directly; the app/website bundles sit in a sibling
 * `apps/` folder so they never collide with Laravel's `lang/{locale}/*.php` groups:
 *
 *   lang/{code}.json                      admin panel   (system_type 4)
 *   lang/apps/customer/{code}.json        customer app  (system_type 1)
 *   lang/apps/delivery_boy/{code}.json    delivery boy  (system_type 2)
 *   lang/apps/web/{code}.json             website       (system_type 3)
 */
class LanguageFileService
{
    /** system_type => sub-directory under lang/apps ('' = flat lang/ root). */
    public const TYPE_DIRS = [
        Language::SYSTEM_TYPE_CUSTOMER_APP => 'apps/customer',
        Language::SYSTEM_TYPE_DELIVERY_BOY_APP => 'apps/delivery_boy',
        Language::SYSTEM_TYPE_WEBSITE => 'apps/web',
        Language::SYSTEM_TYPE_ADMIN_PANEL => '',
    ];

    /** Absolute path of the JSON file for one (system_type, language code). */
    public static function path(int $systemType, string $code): ?string
    {
        $code = trim($code);
        if ($code === '' || !array_key_exists($systemType, self::TYPE_DIRS)) {
            return null;
        }
        // Never let a crafted code escape the lang directory.
        if (preg_match('/[^A-Za-z0-9_-]/', $code)) {
            return null;
        }

        $dir = self::TYPE_DIRS[$systemType];

        return lang_path(($dir !== '' ? $dir . '/' : '') . $code . '.json');
    }

    /** Path for a Language row (resolves its supported language's code). */
    public static function pathForLanguage(Language $language): ?string
    {
        $code = self::codeFor($language);

        return $code ? self::path((int) $language->system_type, $code) : null;
    }

    public static function codeFor(Language $language): ?string
    {
        return SupportedLanguage::where('id', $language->supported_language_id)->value('code');
    }

    /** Raw file contents, or null when the file is missing/unreadable. */
    public static function read(int $systemType, string $code): ?string
    {
        $path = self::path($systemType, $code);
        if (!$path || !is_file($path)) {
            return null;
        }
        $raw = @file_get_contents($path);

        return $raw === false ? null : $raw;
    }

    /** Decoded translations array (empty when missing or invalid JSON). */
    public static function readArray(int $systemType, string $code): array
    {
        $raw = self::read($systemType, $code);
        if ($raw === null || trim($raw) === '') {
            return [];
        }
        $decoded = json_decode($raw, true);

        return is_array($decoded) ? $decoded : [];
    }

    /**
     * Write the bundle. Throws on failure — with files as the only store, a silent
     * write failure would be data loss, not just a stale cache.
     *
     * @param string|array $json
     */
    public static function write(int $systemType, string $code, $json): void
    {
        $path = self::path($systemType, $code);
        if (!$path) {
            throw new \RuntimeException(__('invalid_language_file_path'));
        }

        $payload = is_array($json)
            ? json_encode($json, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT)
            : (string) $json;

        // Reject malformed JSON before it replaces a good file.
        if (trim($payload) === '' || json_decode($payload) === null) {
            throw new \RuntimeException(__('invalid_json_data'));
        }

        $dir = dirname($path);
        if (!is_dir($dir) && !@mkdir($dir, 0775, true) && !is_dir($dir)) {
            throw new \RuntimeException(__('could_not_create_language_directory') . ': ' . $dir);
        }
        if (@file_put_contents($path, $payload) === false) {
            throw new \RuntimeException(__('could_not_write_language_file') . ': ' . $path);
        }

        self::forgetCache($code);
    }

    public static function delete(int $systemType, string $code): void
    {
        $path = self::path($systemType, $code);
        if ($path && is_file($path)) {
            @unlink($path);
        }
        self::forgetCache($code);
    }

    /** Remove every platform's file for one language code. */
    public static function deleteAll(string $code): void
    {
        foreach (array_keys(self::TYPE_DIRS) as $type) {
            self::delete($type, $code);
        }
    }

    /** Does a bundle exist for this platform + code? */
    public static function exists(int $systemType, string $code): bool
    {
        $path = self::path($systemType, $code);

        return $path !== null && is_file($path);
    }

    /**
     * without this the panel would keep serving pre-edit strings.
     */
    private static function forgetCache(string $code): void
    {
        try {
            Cache::forget('lang.js.' . $code);
        } catch (\Throwable $e) {
            Log::warning('Could not clear language cache for ' . $code . ': ' . $e->getMessage());
        }
    }
}
