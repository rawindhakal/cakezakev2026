<?php

namespace App\Support;

use Illuminate\Support\Facades\File;

/**
 * Extracts a zip without letting it escape its target directory.
 *
 * `ZipArchive::extractTo()` trusts the archive: an entry named `../../config/app.php`
 * overwrites core code, and a symlink entry can point anywhere on disk. Every entry is
 * therefore checked before a single byte is written, and files are streamed out one at
 * a time so the checks cannot be bypassed.
 *
 * Also guards against archive bombs (entry count, uncompressed size, compression ratio)
 * and refuses executable payloads outside the directories an plugin legitimately uses
 * for code.
 */
final class SafeZip
{
    /**
     * @param array{max_entries?:int,max_bytes?:int,max_ratio?:int,php_dirs?:array,deny_names?:array,deny_extensions?:array} $opts
     *
     * @throws \RuntimeException with a translation key as the message
     */
    public static function extract(string $zipPath, string $target, array $opts = []): void
    {
        $maxEntries = (int) ($opts['max_entries'] ?? 2000);
        $maxBytes   = (int) ($opts['max_bytes'] ?? 200 * 1024 * 1024);
        $maxRatio   = (int) ($opts['max_ratio'] ?? 200);
        $phpDirs    = (array) ($opts['php_dirs'] ?? ['src', 'routes', 'database']);
        $denyNames  = array_map('strtolower', (array) ($opts['deny_names'] ?? []));
        $denyExts   = array_map('strtolower', (array) ($opts['deny_extensions'] ?? []));

        $zip = new \ZipArchive();
        if ($zip->open($zipPath) !== true) {
            throw new \RuntimeException('please_upload_a_valid_zip_file');
        }

        try {
            if ($zip->numFiles > $maxEntries) {
                throw new \RuntimeException('plugin_zip_has_too_many_files');
            }

            File::ensureDirectoryExists($target);
            $root = self::realDir($target);
            $totalBytes = 0;

            /* A package is just as often zipped as a folder as from inside one, and
               both are valid — the installer unwraps a single wrapper either way. The
               per-file rules read the first path segment, though, so against a wrapped
               archive that segment is the wrapper and every PHP file looks misplaced.
               The wrapper is identified once, here, and discounted below; it is only
               treated as one when every entry shares it, so a zip with files at the
               root cannot smuggle anything past the check. */
            $wrapper = self::soleTopLevelFolder($zip);

            for ($i = 0; $i < $zip->numFiles; $i++) {
                $stat = $zip->statIndex($i);
                if ($stat === false) {
                    throw new \RuntimeException('plugin_zip_entry_unreadable');
                }

                $name = (string) $stat['name'];
                $isDir = str_ends_with($name, '/');

                self::assertSafeName($name);
                if (!$isDir) {
                    self::assertAllowedFile(self::withoutWrapper($name, $wrapper), $phpDirs, $denyNames, $denyExts);
                }

                // Symlinks and anything that is not a plain file or directory: the
                // external attributes carry the unix mode in the high two bytes.
                $mode = ($stat['external_attributes'] ?? 0) >> 16;
                if ($mode && ($mode & 0xF000) === 0xA000) {
                    throw new \RuntimeException('plugin_zip_contains_a_symlink');
                }

                $size = (int) $stat['size'];
                $compressed = max(1, (int) $stat['comp_size']);
                $totalBytes += $size;
                if ($totalBytes > $maxBytes) {
                    throw new \RuntimeException('plugin_zip_is_too_large_uncompressed');
                }
                if ($size > 0 && ($size / $compressed) > $maxRatio) {
                    throw new \RuntimeException('plugin_zip_compression_ratio_rejected');
                }

                $destination = $root . '/' . $name;

                // The resolved parent must still be inside the target.
                $parent = dirname($destination);
                File::ensureDirectoryExists($parent);
                if (!self::isInside($root, self::realDir($parent))) {
                    throw new \RuntimeException('plugin_zip_tried_to_escape_its_folder');
                }

                if ($isDir) {
                    continue;
                }

                $in = $zip->getStream($name);
                if (!is_resource($in)) {
                    throw new \RuntimeException('plugin_zip_entry_unreadable');
                }
                $out = @fopen($destination, 'wb');
                if (!is_resource($out)) {
                    fclose($in);
                    throw new \RuntimeException('plugin_files_not_writable');
                }
                stream_copy_to_stream($in, $out);
                fclose($in);
                fclose($out);
                @chmod($destination, 0664);
            }
        } finally {
            $zip->close();
        }
    }

    /** Entry list + totals, without writing anything — used for a dry-run report. */
    public static function inspect(string $zipPath): array
    {
        $zip = new \ZipArchive();
        if ($zip->open($zipPath) !== true) {
            throw new \RuntimeException('please_upload_a_valid_zip_file');
        }

        $entries = [];
        $bytes = 0;
        for ($i = 0; $i < $zip->numFiles; $i++) {
            $stat = $zip->statIndex($i);
            if ($stat === false) {
                continue;
            }
            $entries[] = $stat['name'];
            $bytes += (int) $stat['size'];
        }
        $zip->close();

        return ['entries' => $entries, 'count' => count($entries), 'bytes' => $bytes];
    }

    /** Reject traversal, absolute paths and anything with control characters. */
    private static function assertSafeName(string $name): void
    {
        if ($name === '' || str_starts_with($name, '/') || str_starts_with($name, '\\')) {
            throw new \RuntimeException('plugin_zip_tried_to_escape_its_folder');
        }
        if (preg_match('#(^|/)\.\.(/|$)#', $name) || str_contains($name, '\\')) {
            throw new \RuntimeException('plugin_zip_tried_to_escape_its_folder');
        }
        if (preg_match('/[\x00-\x1f]/', $name) || preg_match('#^[a-zA-Z]:#', $name)) {
            throw new \RuntimeException('plugin_zip_tried_to_escape_its_folder');
        }
    }

    /**
     * An plugin may ship PHP only where it keeps code, and never the files that would
     * let it reconfigure the app (.env, composer.json, .htaccess, a vendored tree).
     */
    private static function assertAllowedFile(string $name, array $phpDirs, array $denyNames, array $denyExts): void
    {
        $lower = strtolower($name);
        $base = strtolower(basename($name));
        $ext = strtolower((string) pathinfo($name, PATHINFO_EXTENSION));
        $first = strtolower(explode('/', $name)[0]);

        foreach ($denyNames as $denied) {
            if ($base === $denied || $first === $denied || str_starts_with($lower, $denied . '/')) {
                throw new \RuntimeException('plugin_zip_contains_a_forbidden_file');
            }
        }

        if (in_array($ext, $denyExts, true)) {
            throw new \RuntimeException('plugin_zip_contains_a_forbidden_file');
        }

        if ($ext === 'php' && !in_array($first, array_map('strtolower', $phpDirs), true)) {
            throw new \RuntimeException('plugin_zip_has_php_outside_its_code_folders');
        }
    }

    /**
     * The single top-level folder every entry sits in, or null when there is not one.
     *
     * Null is the safe answer: it leaves the checks reading the real first segment.
     */
    private static function soleTopLevelFolder(\ZipArchive $zip): ?string
    {
        $wrapper = null;

        for ($i = 0; $i < $zip->numFiles; $i++) {
            $name = (string) $zip->getNameIndex($i);

            if ($name === '' || str_starts_with($name, '__MACOSX/')) {
                continue;
            }

            $slash = strpos($name, '/');

            // Something at the archive root: there is no wrapper.
            if ($slash === false || $slash === 0) {
                return null;
            }

            $top = substr($name, 0, $slash);

            if ($wrapper === null) {
                $wrapper = $top;
            } elseif ($wrapper !== $top) {
                return null;
            }
        }

        return $wrapper;
    }

    private static function withoutWrapper(string $name, ?string $wrapper): string
    {
        if ($wrapper === null) {
            return $name;
        }

        return str_starts_with($name, $wrapper . '/') ? substr($name, strlen($wrapper) + 1) : $name;
    }

    private static function realDir(string $path): string
    {
        $real = realpath($path);

        return rtrim($real !== false ? $real : $path, '/');
    }

    private static function isInside(string $root, string $candidate): bool
    {
        return $candidate === $root || str_starts_with($candidate . '/', $root . '/');
    }
}
