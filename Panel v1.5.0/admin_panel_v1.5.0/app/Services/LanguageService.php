<?php

namespace App\Services;

use App\Models\Language;
use App\Models\SupportedLanguage;

class LanguageService
{
    // Per-request memoization (shared across instances). The same default/active
    // language + code lookups are hit many times per request (e.g. when shaping
    // branch/delivery-boy translations for every order list row).
    private static ?Language $defaultLanguage = null;
    private static bool $defaultLoaded = false;
    private static $activeLanguages = null;
    private static array $byId = [];
    private static array $byCode = [];
    private static array $codeById = [];

    public function getLanguageByCode(string $code): ?Language
    {
        if (array_key_exists($code, self::$byCode)) {
            return self::$byCode[$code];
        }
        // Get supported language by code
        $supportedLanguage = SupportedLanguage::where('code', $code)->first();
        if (!$supportedLanguage) {
            return self::$byCode[$code] = null;
        }
        // Get language by supported_language_id for Admin Panel only (system_type = 4)
        return self::$byCode[$code] = Language::select(['id', 'supported_language_id', 'system_type', 'is_default', 'display_name'])
            ->where('supported_language_id', $supportedLanguage->id)
            ->where('system_type', 4)
            ->where('status', 1)
            ->first();
    }

    public function getLanguageById(int $languageId): ?Language
    {
        if (array_key_exists($languageId, self::$byId)) {
            return self::$byId[$languageId];
        }
        return self::$byId[$languageId] = Language::where('id', $languageId)
            ->where('status', 1)
            ->first();
    }

    public function getDefaultLanguage(): ?Language
    {
        if (!self::$defaultLoaded) {
            self::$defaultLanguage = Language::select(['id', 'supported_language_id', 'system_type', 'is_default', 'display_name'])
                ->where('system_type', 4)
                ->where('is_default', 1)
                ->where('status', 1)
                ->first();
            self::$defaultLoaded = true;
        }
        return self::$defaultLanguage;
    }

    public function getLanguageCode(int $languageId): ?string
    {
        if (array_key_exists($languageId, self::$codeById)) {
            return self::$codeById[$languageId];
        }
        $language = $this->getLanguageById($languageId);
        if (!$language) {
            return self::$codeById[$languageId] = null;
        }
        $supportedLanguage = SupportedLanguage::find($language->supported_language_id);
        return self::$codeById[$languageId] = ($supportedLanguage ? $supportedLanguage->code : null);
    }

    public function getActiveLanguages()
    {
        if (self::$activeLanguages !== null) {
            return self::$activeLanguages;
        }
        return self::$activeLanguages = Language::leftJoin('supported_languages', 'supported_languages.id', 'languages.supported_language_id')
            ->where('languages.system_type', 4)
            ->where('languages.status', 1)
            ->orderBy('languages.is_default', 'DESC')
            ->orderBy('supported_languages.name', 'ASC')
            ->get([
                'languages.id',
                'languages.supported_language_id',
                'languages.system_type',
                'languages.is_default',
                'languages.display_name',
                'supported_languages.name',
                'supported_languages.code'
            ]);
    }

    public static function getCurrentId(): ?int
    {
        return app()->has('lang_id') ? app('lang_id') : null;
    }

    public static function getCurrentCode(): ?string
    {
        return app()->has('lang_code') ? app('lang_code') : null;
    }
}

