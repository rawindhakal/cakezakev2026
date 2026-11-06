<?php

namespace App\Http\Controllers;

use App\Models\Setting;
use Illuminate\Routing\Controller as BaseController;
use Illuminate\Support\Facades\File;

/**
 * The PWA manifest and its icons, built from settings rather than shipped as static
 * files, so an install rebranded in the panel installs under its own name and logo.
 *
 * Icons are re-encoded to PNG here on purpose. Chrome only treats an app as installable
 * when the manifest offers a PNG / SVG / WebP icon of at least 192px — a JPEG logo
 * (which the settings form happily accepts) silently blocks the install prompt.
 */
class PwaController extends BaseController
{
    /** Sizes the manifest advertises. */
    private const SIZES = [192, 512];

    public function manifest()
    {
        if (!isInstalled()) {
            abort(404);
        }

        $appName = trim((string) $this->setting('pwa_name'))
            ?: ($this->setting('app_name') ?: 'CakeZake');
        $shortName = mb_substr($appName, 0, 12);
        $description = trim((string) $this->setting('pwa_description'))
            ?: $appName . ' — admin, branch and delivery panel';

        // The window chrome follows the panel theme rather than a field of its own.
        $theme = $this->setting('admin_theme_color');
        if (!preg_match('/^#[0-9a-fA-F]{6}$/', (string) $theme)) {
            $theme = '#435ebe';
        }

        // Cache-buster: a new logo must reach installed clients, not sit behind the icon
        // route's own long cache.
        $stamp = $this->sourceStamp();

        $icons = [];
        foreach (self::SIZES as $size) {
            $icons[] = [
                'src'     => url("pwa/icon-{$size}.png") . '?v=' . $stamp,
                'sizes'   => "{$size}x{$size}",
                'type'    => 'image/png',
                'purpose' => 'any',
            ];
        }
        // Maskable is padded into the safe zone; Android crops it to the launcher shape.
        $icons[] = [
            'src'     => url('pwa/icon-maskable-512.png') . '?v=' . $stamp,
            'sizes'   => '512x512',
            'type'    => 'image/png',
            'purpose' => 'maskable',
        ];

        return response()->json([
            'name'             => $appName,
            'short_name'       => $shortName,
            'description'      => $description,
            'start_url'        => '/dashboard',
            'scope'            => '/',
            'display'          => 'standalone',
            'orientation'      => 'any',
            'background_color' => '#ffffff',
            'theme_color'      => $theme,
            'icons'            => $icons,
        ], 200, [
            'Content-Type'  => 'application/manifest+json',
            'Cache-Control' => 'public, max-age=3600',
        ]);
    }

    /**
     * A square PNG of the panel's logo, whatever format was uploaded.
     *
     * @param int  $size     192 or 512
     * @param bool $maskable pad the artwork into Android's safe zone
     */
    public function icon(int $size, bool $maskable = false)
    {
        if (!isInstalled()) {
            abort(404);
        }

        $size = in_array($size, self::SIZES, true) ? $size : 512;

        $source = $this->sourcePath();
        $cache = storage_path('app/pwa-icons');
        $file = $cache . '/' . md5($source . '|' . $this->sourceStamp() . '|' . $size . '|' . (int) $maskable) . '.png';

        if (!is_file($file)) {
            File::ensureDirectoryExists($cache);
            $png = $this->render($source, $size, $maskable);
            if ($png === null) {
                abort(404);
            }
            File::put($file, $png);
        }

        return response()->file($file, [
            'Content-Type'  => 'image/png',
            // Safe to cache hard: the manifest's ?v= changes when the logo does.
            'Cache-Control' => 'public, max-age=31536000, immutable',
        ]);
    }

    /**
     * Draw the source onto a square transparent canvas, fitted (never cropped) so a wide
     * logo keeps its shape.
     */
    private function render(string $source, int $size, bool $maskable): ?string
    {
        $raw = @file_get_contents($source);
        if ($raw === false) {
            return null;
        }
        // GD cannot read SVG; the caller has already preferred a raster source, so this
        // only trips when the bundled fallback is missing too.
        $src = @imagecreatefromstring($raw);
        if (!$src) {
            return null;
        }

        $canvas = imagecreatetruecolor($size, $size);
        imagealphablending($canvas, false);
        imagesavealpha($canvas, true);
        imagefill($canvas, 0, 0, imagecolorallocatealpha($canvas, 0, 0, 0, 127));
        imagealphablending($canvas, true);

        // Maskable icons are cropped to a circle/squircle, so the artwork must sit inside
        // the middle ~80%.
        $box = $maskable ? (int) round($size * 0.8) : $size;
        $sw = imagesx($src);
        $sh = imagesy($src);
        $scale = min($box / $sw, $box / $sh);
        $dw = max(1, (int) round($sw * $scale));
        $dh = max(1, (int) round($sh * $scale));

        imagecopyresampled(
            $canvas, $src,
            (int) (($size - $dw) / 2), (int) (($size - $dh) / 2),
            0, 0, $dw, $dh, $sw, $sh
        );

        unset($src);

        ob_start();
        imagepng($canvas, null, 9);
        $png = ob_get_clean();
        unset($canvas);

        return $png ?: null;
    }

    /**
     * The image the icons are drawn from: the PWA icon set in Website Settings, then the
     * logo, then the app icon, then the bundled public/images/logo.png. SVG is skipped —
     * GD cannot rasterise it.
     */
    private function sourcePath(): string
    {
        foreach (['pwa_icon', 'logo', 'favicon'] as $key) {
            $path = trim((string) $this->setting($key));
            if ($path === '' || strtolower(pathinfo($path, PATHINFO_EXTENSION)) === 'svg') {
                continue;
            }
            $full = storage_path('app/public/' . $path);
            if (is_file($full)) {
                return $full;
            }
        }

        return public_path('images/favicon.png');
    }

    /** Changes whenever the source image changes, so caches turn over. */
    /**
     * A setting, or null when the database cannot answer. The manifest is public and is
     * fetched by the browser on every page, so a database that is down (or mid-upgrade)
     * must degrade to defaults instead of 500-ing and filling the log.
     */
    private function setting(string $key)
    {
        try {
            return Setting::get_value($key);
        } catch (\Throwable $e) {
            return null;
        }
    }

    private function sourceStamp(): string
    {
        $source = $this->sourcePath();

        return (string) (is_file($source) ? filemtime($source) : 0);
    }
}
