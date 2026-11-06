<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Finds uploaded files under the public disk that nothing in the database points at,
 * and moves them to a trash folder the admin can restore from or empty.
 *
 * Stills and clips both count: a product gallery takes mp4, and an orphaned clip is the
 * one file worth finding, being far heavier than any image it sits beside.
 *
 * "Used" is decided by reading the database, never by guessing from folder names:
 * every text and JSON column of every table is searched for image paths, in any of
 * the shapes the app stores them — `products/a.webp`, a full `…/storage/…` URL, a
 * JSON-escaped `products\/a.webp`, or a bare file name next to a `sub_directory`.
 *
 * Every rule leans towards keeping a file:
 *   - a file is used when its path OR just its file name appears anywhere, so the
 *     same name referenced from another folder still protects it;
 *   - files changed in the last day are left alone (a form may have uploaded one and
 *     not been saved yet);
 *   - a name the path matcher cannot read reliably (spaces, other characters) is kept;
 *   - a table that cannot be read stops the scan instead of being skipped, because a
 *     skipped table would make its images look unused.
 * And nothing is deleted outright: files go to a trash outside the public folder,
 * re-checked against a fresh scan at the moment they are moved.
 */
class StorageCleanupService
{
    public const MEDIA_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'avif', 'bmp', 'ico', 'mp4'];

    /** Recently changed files are never offered: they may belong to a form not saved yet. */
    public const MIN_AGE_SECONDS = 86400;

    /**
     * Tables that hold no image references the app serves. Activity logs are here on
     * purpose: they keep the old values of deleted records, which would otherwise pin
     * every image ever replaced.
     */
    private const SKIP_TABLES = [
        'activity_logs', 'jobs', 'failed_jobs', 'job_batches', 'sessions', 'cache',
        'cache_locks', 'migrations', 'password_reset_tokens', 'password_resets',
        'oauth_access_tokens', 'oauth_refresh_tokens', 'oauth_auth_codes',
        'oauth_personal_access_clients', 'oauth_clients', 'personal_access_tokens',
    ];

    private const TEXT_TYPES = ['char', 'varchar', 'tinytext', 'text', 'mediumtext', 'longtext', 'json'];

    /** File names the path matcher reads whole; anything else is kept, not judged. */
    private const SAFE_NAME = '/^[A-Za-z0-9._\-]+$/';

    public function publicRoot(): string
    {
        return rtrim((string) config('filesystems.disks.public.root', storage_path('app/public')), '/');
    }

    public function trashRoot(): string
    {
        return storage_path('app/media_trash');
    }

    /* ------------------------------------------------------------------ usage */

    /**
     * Disk usage for the Media page: the uploads folder by top-level folder, the
     * trash, and the disk itself where the host allows asking.
     */
    public function usage(): array
    {
        $folders = [];
        $totalSize = 0;
        $totalFiles = 0;
        $imageFiles = 0;
        $imageSize = 0;

        foreach ($this->walk($this->publicRoot()) as $rel => $info) {
            $top = str_contains($rel, '/') ? strstr($rel, '/', true) : '/';
            $folders[$top] ??= ['folder' => $top, 'size' => 0, 'files' => 0];
            $folders[$top]['size'] += $info['size'];
            $folders[$top]['files']++;
            $totalSize += $info['size'];
            $totalFiles++;
            if ($this->isMedia($rel)) {
                $imageFiles++;
                $imageSize += $info['size'];
            }
        }

        usort($folders, fn ($a, $b) => $b['size'] <=> $a['size']);

        return [
            'uploads' => [
                'size'        => $totalSize,
                'files'       => $totalFiles,
                'image_files' => $imageFiles,
                'image_size'  => $imageSize,
                'folders'     => array_values($folders),
            ],
            'trash' => $this->trashBatches(),
            'disk'  => $this->diskSpace(),
        ];
    }

    /** Free/total space of the disk holding storage/, or null where the host blocks it. */
    private function diskSpace(): ?array
    {
        $disabled = array_map('trim', explode(',', (string) ini_get('disable_functions')));
        foreach (['disk_total_space', 'disk_free_space'] as $fn) {
            if (!function_exists($fn) || in_array($fn, $disabled, true)) {
                return null;
            }
        }

        $total = @disk_total_space(storage_path());
        $free = @disk_free_space(storage_path());
        if (!$total || $free === false) {
            return null;
        }

        return ['total' => (int) $total, 'free' => (int) $free, 'used' => (int) ($total - $free)];
    }

    /* ------------------------------------------------------------------ scan */

    /**
     * Images nothing references, plus what was held back and why.
     *
     * @return array{unused: array<int, array{path:string,size:int,modified:int}>, unused_size:int,
     *   image_files:int, skipped_recent:int, skipped_unreadable_name:int, references:int}
     */
    public function scan(): array
    {
        [$paths, $names] = $this->referencedPaths();

        $unused = [];
        $unusedSize = 0;
        $imageFiles = 0;
        $recent = 0;
        $unreadable = 0;
        $cutoff = time() - self::MIN_AGE_SECONDS;

        foreach ($this->walk($this->publicRoot()) as $rel => $info) {
            if (!$this->isMedia($rel)) {
                continue;
            }
            $imageFiles++;

            if ($this->isReferenced($rel, $paths, $names)) {
                continue;
            }
            if (!preg_match(self::SAFE_NAME, basename($rel))) {
                $unreadable++;
                continue;
            }
            if ($info['modified'] > $cutoff) {
                $recent++;
                continue;
            }

            $unused[] = ['path' => $rel, 'size' => $info['size'], 'modified' => $info['modified']];
            $unusedSize += $info['size'];
        }

        usort($unused, fn ($a, $b) => $b['size'] <=> $a['size']);

        return [
            'unused'                  => $unused,
            'unused_size'             => $unusedSize,
            'image_files'             => $imageFiles,
            'skipped_recent'          => $recent,
            'skipped_unreadable_name' => $unreadable,
            'references'              => count($paths),
        ];
    }

    /**
     * Every image path the database mentions, lower-cased, as two sets: full relative
     * paths and bare file names.
     *
     * @return array{0: array<string,true>, 1: array<string,true>}
     */
    public function referencedPaths(): array
    {
        $columns = DB::select(
            'SELECT c.TABLE_NAME AS t, c.COLUMN_NAME AS c
               FROM information_schema.COLUMNS c
               JOIN information_schema.TABLES tb
                 ON tb.TABLE_SCHEMA = c.TABLE_SCHEMA AND tb.TABLE_NAME = c.TABLE_NAME
              WHERE c.TABLE_SCHEMA = DATABASE()
                AND tb.TABLE_TYPE = \'BASE TABLE\'
                AND c.DATA_TYPE IN (' . implode(',', array_fill(0, count(self::TEXT_TYPES), '?')) . ')',
            self::TEXT_TYPES
        );

        $byTable = [];
        foreach ($columns as $row) {
            $table = (string) ($row->t ?? $row->T ?? '');
            $column = (string) ($row->c ?? $row->C ?? '');
            if ($table === '' || $column === '' || in_array($table, self::SKIP_TABLES, true)) {
                continue;
            }
            $byTable[$table][] = $column;
        }

        if ($byTable === []) {
            throw new RuntimeException('No database columns could be read; scan stopped.');
        }

        $paths = [];
        $names = [];
        $pattern = '\\.(' . implode('|', self::MEDIA_EXTENSIONS) . ')';

        foreach ($byTable as $table => $cols) {
            $selects = [];
            $wheres = [];
            foreach ($cols as $col) {
                $quoted = '`' . str_replace('`', '``', $col) . '`';
                $selects[] = "CAST({$quoted} AS CHAR) AS `c" . count($selects) . '`';
                $wheres[] = "CAST({$quoted} AS CHAR) REGEXP ?";
            }

            try {
                $rows = DB::table($table)
                    ->selectRaw(implode(', ', $selects))
                    ->whereRaw('(' . implode(' OR ', $wheres) . ')', array_fill(0, count($wheres), $pattern))
                    ->cursor();

                foreach ($rows as $row) {
                    foreach ((array) $row as $value) {
                        if ($value !== null && $value !== '') {
                            $this->collect((string) $value, $paths, $names);
                        }
                    }
                }
            } catch (\Throwable $e) {
                // A table we cannot read could be the only place an image is used.
                throw new RuntimeException("Could not read table `{$table}`; scan stopped so nothing is wrongly marked unused. " . $e->getMessage());
            }
        }

        return [$paths, $names];
    }

    /** Pull every image path out of one stored value. */
    private function collect(string $value, array &$paths, array &$names): void
    {
        $text = str_replace('\\/', '/', $value);
        if (str_contains($text, '%')) {
            $text .= ' ' . rawurldecode($text);
        }

        $ext = implode('|', self::MEDIA_EXTENSIONS);
        if (!preg_match_all('~[^\s"\'<>()\\\\,;|`=?#\[\]{}*]+\.(?:' . $ext . ')(?![a-z0-9])~i', $text, $m)) {
            return;
        }

        foreach ($m[0] as $token) {
            $token = strtolower($token);
            if (($at = strrpos($token, '/storage/')) !== false) {
                $token = substr($token, $at + 9);
            }
            $token = ltrim($token, '/');
            if (str_starts_with($token, 'storage/')) {
                $token = substr($token, 8);
            }
            if ($token === '') {
                continue;
            }
            $paths[$token] = true;
            $names[basename($token)] = true;
        }
    }

    private function isReferenced(string $rel, array $paths, array $names): bool
    {
        $lower = strtolower($rel);

        return isset($paths[$lower]) || isset($names[basename($lower)]);
    }

    /* ------------------------------------------------------------------ trash */

    /**
     * Move the given files to a new trash batch, after checking each one again
     * against a fresh read of the database.
     *
     * @return array{batch:?string, moved:int, size:int, kept:int}
     */
    public function moveToTrash(array $relPaths, ?int $adminId = null): array
    {
        [$paths, $names] = $this->referencedPaths();
        $root = $this->publicRoot();
        $cutoff = time() - self::MIN_AGE_SECONDS;

        $batch = date('Ymd_His') . '_' . Str::lower(Str::random(4));
        $batchDir = $this->trashRoot() . '/' . $batch;

        $moved = [];
        $size = 0;
        $kept = 0;

        foreach (array_unique($relPaths) as $rel) {
            $rel = $this->cleanRelative((string) $rel);
            $source = $rel === null ? null : $root . '/' . $rel;

            if ($source === null || !is_file($source) || is_link($source) || !$this->isMedia($rel)
                || !preg_match(self::SAFE_NAME, basename($rel))
                || filemtime($source) > $cutoff
                || $this->isReferenced($rel, $paths, $names)) {
                $kept++;
                continue;
            }

            $target = $batchDir . '/files/' . $rel;
            File::ensureDirectoryExists(dirname($target));
            $bytes = (int) filesize($source);

            if (!@rename($source, $target)) {
                if (!@copy($source, $target) || !@unlink($source)) {
                    @unlink($target);
                    $kept++;
                    continue;
                }
            }

            $moved[] = $rel;
            $size += $bytes;
        }

        if ($moved === []) {
            if (is_dir($batchDir)) {
                File::deleteDirectory($batchDir);
            }

            return ['batch' => null, 'moved' => 0, 'size' => 0, 'kept' => $kept];
        }

        File::put($batchDir . '/manifest.json', json_encode([
            'batch'      => $batch,
            'created_at' => date('c'),
            'admin_id'   => $adminId,
            'files'      => $moved,
            'size'       => $size,
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

        return ['batch' => $batch, 'moved' => count($moved), 'size' => $size, 'kept' => $kept];
    }

    /** Put a batch back where it came from. A file whose place is taken stays in trash. */
    public function restore(string $batch): array
    {
        $dir = $this->batchDir($batch);
        $manifest = $this->manifest($dir);
        $root = $this->publicRoot();

        $restored = 0;
        $left = 0;
        foreach ($manifest['files'] as $rel) {
            $rel = $this->cleanRelative((string) $rel);
            $from = $rel === null ? null : $dir . '/files/' . $rel;
            if ($from === null || !is_file($from)) {
                continue;
            }
            $to = $root . '/' . $rel;
            if (file_exists($to)) {
                $left++;
                continue;
            }
            File::ensureDirectoryExists(dirname($to));
            if (@rename($from, $to) || (@copy($from, $to) && @unlink($from))) {
                $restored++;
            } else {
                $left++;
            }
        }

        if ($left === 0) {
            File::deleteDirectory($dir);
        }

        return ['restored' => $restored, 'left_in_trash' => $left];
    }

    /** Permanently delete one batch, or every batch when $batch is null. */
    public function emptyTrash(?string $batch = null): array
    {
        $dirs = $batch === null
            ? array_map(fn ($b) => $this->trashRoot() . '/' . $b['batch'], $this->trashBatches())
            : [$this->batchDir($batch)];

        $freed = 0;
        foreach ($dirs as $dir) {
            foreach ($this->walk($dir) as $info) {
                $freed += $info['size'];
            }
            File::deleteDirectory($dir);
        }

        return ['batches' => count($dirs), 'freed' => $freed];
    }

    /**
     * The files still sitting in one batch, for previewing before a restore.
     *
     * @return array<int, array{path:string, size:int}>
     */
    public function trashFiles(string $batch): array
    {
        $dir = $this->batchDir($batch);
        $files = [];
        foreach ($this->manifest($dir)['files'] as $rel) {
            $rel = $this->cleanRelative((string) $rel);
            $abs = $rel === null ? null : $dir . '/files/' . $rel;
            if ($abs !== null && is_file($abs) && !is_link($abs)) {
                $files[] = ['path' => $rel, 'size' => (int) filesize($abs)];
            }
        }

        return $files;
    }

    /** Absolute path of one trashed image, or null when it is not a file of that batch. */
    public function trashFilePath(string $batch, string $rel): ?string
    {
        try {
            $dir = $this->batchDir($batch);
        } catch (\Throwable) {
            return null;
        }
        $rel = $this->cleanRelative($rel);
        if ($rel === null || !$this->isMedia($rel)) {
            return null;
        }
        $abs = $dir . '/files/' . $rel;

        return is_file($abs) && !is_link($abs) ? $abs : null;
    }

    /**
     * Every image in the trash, newest cleanup first.
     *
     * @return array<int, array{batch:string, path:string, size:int}>
     */
    public function allTrashFiles(): array
    {
        $all = [];
        foreach ($this->trashBatches() as $b) {
            foreach ($this->trashFiles($b['batch']) as $file) {
                $all[] = ['batch' => $b['batch']] + $file;
            }
        }

        return $all;
    }

    /**
     * Restore chosen files, each `{batch, path}`. A file whose original place is taken
     * stays in the trash.
     */
    public function restoreItems(array $items): array
    {
        $root = $this->publicRoot();
        $restored = 0;
        $left = 0;

        foreach ($this->groupItems($items) as $batch => $paths) {
            $dir = $this->batchDir($batch);
            $manifest = $this->manifest($dir);
            $done = [];
            foreach ($paths as $rel) {
                $from = $dir . '/files/' . $rel;
                $to = $root . '/' . $rel;
                if (!is_file($from) || file_exists($to)) {
                    $left++;
                    continue;
                }
                File::ensureDirectoryExists(dirname($to));
                if (@rename($from, $to) || (@copy($from, $to) && @unlink($from))) {
                    $restored++;
                    $done[] = $rel;
                } else {
                    $left++;
                }
            }
            $this->dropFromManifest($dir, $manifest, $done);
        }

        return ['restored' => $restored, 'left_in_trash' => $left];
    }

    /** Permanently delete chosen files, each `{batch, path}`. */
    public function deleteItems(array $items): array
    {
        $freed = 0;
        $deleted = 0;

        foreach ($this->groupItems($items) as $batch => $paths) {
            $dir = $this->batchDir($batch);
            $manifest = $this->manifest($dir);
            $done = [];
            foreach ($paths as $rel) {
                $abs = $dir . '/files/' . $rel;
                if (is_file($abs) && !is_link($abs)) {
                    $bytes = (int) filesize($abs);
                    if (@unlink($abs)) {
                        $freed += $bytes;
                        $deleted++;
                        $done[] = $rel;
                    }
                } else {
                    $done[] = $rel; // already gone; just forget it
                }
            }
            $this->dropFromManifest($dir, $manifest, $done);
        }

        return ['deleted' => $deleted, 'freed' => $freed];
    }

    /**
     * `{batch, path}` items as batch => clean paths, keeping only paths the batch's own
     * manifest lists — a request cannot point at any other file.
     *
     * @return array<string, string[]>
     */
    private function groupItems(array $items): array
    {
        $grouped = [];
        foreach ($items as $item) {
            $batch = is_array($item) ? (string) ($item['batch'] ?? '') : '';
            $rel = is_array($item) ? $this->cleanRelative((string) ($item['path'] ?? '')) : null;
            if ($batch !== '' && $rel !== null) {
                $grouped[$batch][] = $rel;
            }
        }

        foreach ($grouped as $batch => $paths) {
            $listed = $this->manifest($this->batchDir($batch))['files'];
            $grouped[$batch] = array_values(array_intersect(array_unique($paths), $listed));
        }

        return $grouped;
    }

    /** Remove handled files from a batch; the batch goes once nothing is left in it. */
    private function dropFromManifest(string $dir, array $manifest, array $done): void
    {
        if ($done === []) {
            return;
        }
        $remaining = array_values(array_diff($manifest['files'], $done));
        if ($remaining === []) {
            File::deleteDirectory($dir);

            return;
        }

        $size = 0;
        foreach ($remaining as $rel) {
            $abs = $dir . '/files/' . $rel;
            $size += is_file($abs) ? (int) filesize($abs) : 0;
        }
        $manifest['files'] = $remaining;
        $manifest['size'] = $size;
        File::put($dir . '/manifest.json', json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    }

    public function trashBatches(): array
    {
        $root = $this->trashRoot();
        if (!is_dir($root)) {
            return [];
        }

        $batches = [];
        foreach (glob($root . '/*', GLOB_ONLYDIR) ?: [] as $dir) {
            try {
                $manifest = $this->manifest($dir);
            } catch (\Throwable) {
                continue;
            }
            $batches[] = [
                'batch'      => basename($dir),
                'created_at' => $manifest['created_at'] ?? null,
                'files'      => count($manifest['files']),
                'size'       => (int) ($manifest['size'] ?? 0),
            ];
        }
        usort($batches, fn ($a, $b) => strcmp($b['batch'], $a['batch']));

        return $batches;
    }

    /* ------------------------------------------------------------------ helpers */

    private function batchDir(string $batch): string
    {
        if (!preg_match('/^\d{8}_\d{6}_[a-z0-9]{4}$/', $batch)) {
            throw new RuntimeException('invalid_trash_batch');
        }
        $dir = $this->trashRoot() . '/' . $batch;
        if (!is_dir($dir)) {
            throw new RuntimeException('trash_batch_not_found');
        }

        return $dir;
    }

    private function manifest(string $dir): array
    {
        $manifest = json_decode((string) @file_get_contents($dir . '/manifest.json'), true);
        if (!is_array($manifest) || !is_array($manifest['files'] ?? null)) {
            throw new RuntimeException('trash_batch_not_found');
        }

        return $manifest;
    }

    /** A path inside the public disk, or null for anything that tries to leave it. */
    private function cleanRelative(string $rel): ?string
    {
        $rel = ltrim(str_replace('\\', '/', $rel), '/');
        if ($rel === '' || str_contains($rel, "\0")) {
            return null;
        }
        foreach (explode('/', $rel) as $part) {
            if ($part === '' || $part === '.' || $part === '..') {
                return null;
            }
        }

        return $rel;
    }

    private function isMedia(string $rel): bool
    {
        return in_array(strtolower(pathinfo($rel, PATHINFO_EXTENSION)), self::MEDIA_EXTENSIONS, true);
    }

    /**
     * Regular files under a folder as relative path => size/mtime. Symlinks are not
     * followed and dot-files are skipped.
     *
     * @return \Generator<string, array{size:int, modified:int}>
     */
    private function walk(string $root): \Generator
    {
        if (!is_dir($root)) {
            return;
        }

        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($root, \FilesystemIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::LEAVES_ONLY,
            \RecursiveIteratorIterator::CATCH_GET_CHILD
        );

        $prefix = strlen($root) + 1;
        foreach ($iterator as $file) {
            /** @var \SplFileInfo $file */
            if ($file->isLink() || !$file->isFile() || str_starts_with($file->getFilename(), '.')) {
                continue;
            }
            yield str_replace('\\', '/', substr($file->getPathname(), $prefix)) => [
                'size'     => (int) $file->getSize(),
                'modified' => (int) $file->getMTime(),
            ];
        }
    }
}
