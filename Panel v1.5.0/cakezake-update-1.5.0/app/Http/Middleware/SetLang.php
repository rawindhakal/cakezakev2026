<?php

namespace App\Http\Middleware;

use App\Models\Language;
use App\Models\SupportedLanguage;
use Closure;
use Illuminate\Support\Facades\Session;

class SetLang
{
    public function handle($request, Closure $next)
    {
        $lang = 'en';

        if (Session::has('lang') && Session::get('lang') != '') {
            $lang = Session::get('lang');
        } else {
            // Skip DB queries during install - no database/tables yet
            try {
                $role = Language::$systemTypeAdminPanel;
                $language = Language::where('system_type', $role)
                    ->where('is_default', 1)
                    ->first();
                if ($language) {
                    $supportedLanguage = SupportedLanguage::where('id', $language->supported_language_id)->first();
                    if ($supportedLanguage) {
                        $lang = $supportedLanguage->code;
                    }
                }
            } catch (\Throwable $e) {
                // Database not ready (e.g. during install) - keep default 'en'
            }
        }

        if (isset($lang) && $lang != '') {
            app()->setLocale($lang);
            Session::put('app_locale', $lang);
        }

        //check installed
        if (!str_contains($request->path(), 'install') && !file_exists(storage_path('installed'))) {
            return redirect('install');
        }

        return $next($request);
    }
}
