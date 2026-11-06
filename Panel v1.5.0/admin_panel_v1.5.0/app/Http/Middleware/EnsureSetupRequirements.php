<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Pre-flight checks for the pieces the product ships WITHOUT, so a fresh copy
 * explains itself instead of throwing a stack trace:
 *
 *   .env          — only .env.example is shipped; nothing works until it's copied.
 *   public/build  — compiled front-end assets; @vite() fatals without the manifest.
 *
 * vendor/ is deliberately NOT checked here: public/index.php requires the
 * autoloader before the framework (and therefore this middleware) can run, so
 * that check lives there and renders the same screen.
 *
 * All wording lives in resources/views/setup-required.php — this only decides
 * WHAT is missing, never how it is phrased.
 *
 * Runs first (prepended) so it fires even before installation. Once everything
 * is in place, this is a no-op.
 */
class EnsureSetupRequirements
{
    public function handle(Request $request, Closure $next): Response
    {
        $missing = [];

        if (!file_exists(base_path('.env'))) {
            $missing[] = 'env';
        }

        if (!$this->buildExists()) {
            $missing[] = 'build';
        }

        if ($missing) {
            ob_start();
            require base_path('resources/views/setup-required.php');

            return response((string) ob_get_clean(), 503)
                ->header('Content-Type', 'text/html; charset=utf-8');
        }

        return $next($request);
    }

    /**
     * Vite writes the manifest inside public/build — under .vite/ since Vite 5,
     * at the root before that. Either one means the assets were compiled.
     */
    private function buildExists(): bool
    {
        return file_exists(public_path('build/manifest.json'))
            || file_exists(public_path('build/.vite/manifest.json'));
    }
}
