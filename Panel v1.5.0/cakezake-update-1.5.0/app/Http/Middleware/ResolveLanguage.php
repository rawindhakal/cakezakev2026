<?php

namespace App\Http\Middleware;

use Closure;
use App\Services\LanguageService;
use Illuminate\Http\Request;

class ResolveLanguage
{
    /**
     * @var LanguageService
     */
    protected $languageService;

    public function __construct(LanguageService $languageService)
    {
        $this->languageService = $languageService;
    }

    public function handle(Request $request, Closure $next)
    {
        try {
            // Get Content-Language header
            $langCode = $request->header('Content-Language');

            // Resolve language from header
            $language = $langCode
                ? $this->languageService->getLanguageByCode($langCode)
                : null;

            // Fallback to default language if not found
            if (!$language) {
                $language = $this->languageService->getDefaultLanguage();
            }

            // This makes language available everywhere via app('lang_id')
            if ($language) {
                app()->instance('current_language', $language);
                app()->instance('lang_id', $language->id);
                app()->instance('lang_code', $this->languageService->getLanguageCode($language->id));
            }
        } catch (\Throwable $e) {
            // Database not ready (e.g. during install) - skip language resolution
        }

        return $next($request);
    }
}

