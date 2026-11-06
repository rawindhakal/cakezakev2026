<?php

namespace App\Helpers;

use Illuminate\Support\Facades\Log;

class EnvHelper
{
    /**
     * Update (or append) keys in the .env file.
     *
     * Rewrites in place, preserving comments, blank lines and key order. Keys that
     * don't exist yet are appended. Returns false if .env is missing or unwritable
     * (common on locked-down shared hosting) — callers must surface that, because a
     * silent failure looks like "settings saved" while nothing changed.
     *
     * @param array<string,string|int|null> $values
     */
    public static function set(array $values): bool
    {
        $path = base_path('.env');

        if (!file_exists($path) || !is_readable($path) || !is_writable($path)) {
            Log::error('EnvHelper: .env missing or not writable', ['path' => $path]);
            return false;
        }

        $lines = file($path, FILE_IGNORE_NEW_LINES);
        if ($lines === false) {
            return false;
        }

        $remaining = $values;

        foreach ($lines as $i => $line) {
            $trimmed = ltrim($line);
            // Skip comments and blank lines.
            if ($trimmed === '' || str_starts_with($trimmed, '#')) {
                continue;
            }
            $eq = strpos($line, '=');
            if ($eq === false) {
                continue;
            }
            $key = trim(substr($line, 0, $eq));
            if (array_key_exists($key, $remaining)) {
                $lines[$i] = $key . '=' . self::escape($remaining[$key]);
                unset($remaining[$key]);
            }
        }

        foreach ($remaining as $key => $value) {
            $lines[] = $key . '=' . self::escape($value);
        }

        // Write via a temp file in the same dir + rename, so a crash mid-write can't
        // leave a truncated .env and take the whole app down.
        $tmp = $path . '.' . getmypid() . '.tmp';
        if (file_put_contents($tmp, implode(PHP_EOL, $lines) . PHP_EOL, LOCK_EX) === false) {
            @unlink($tmp);
            return false;
        }
        @chmod($tmp, 0644);

        if (!rename($tmp, $path)) {
            @unlink($tmp);
            return false;
        }

        return true;
    }

    /**
     * Quote a value when it contains characters the dotenv parser would choke on.
     */
    private static function escape(string|int|null $value): string
    {
        $value = (string) ($value ?? '');

        if ($value === '') {
            return '';
        }

        if (preg_match('/[\s"\'#=]/', $value)) {
            return '"' . addcslashes($value, '"\\') . '"';
        }

        return $value;
    }
}
