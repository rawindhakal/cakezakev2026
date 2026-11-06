<?php

namespace App\Traits;

use App\Services\LanguageService;
use Illuminate\Support\Facades\Request;
use Illuminate\Support\Facades\Schema;
trait HasTranslations
{

    public function translations()
    {
        $translationModel = $this->getTranslationModelClass();
        $foreignKey = $this->getTranslationForeignKey();

        return $this->hasMany($translationModel, $foreignKey);
    }

    public function translation($languageId = null)
    {
        if ($languageId === null) {
            $languageId = $this->getCurrentLanguageId();
        }

        // Request-level memo: the same (row, language) is often serialized many times in
        // one request — e.g. country #1 shared by every delivery boy in a list — and each
        static $memo = [];
        $key = get_class($this) . ':' . ($this->getKey() ?? '0') . ':' . ($languageId ?? '0');
        if (array_key_exists($key, $memo)) {
            return $memo[$key];
        }

        return $memo[$key] = $this->translations()->where('language_id', $languageId)->first();
    }

    public function getTranslatedAttribute(string $field, $languageId = null)
    {
        // Get current language ID from app container (set by ResolveLanguage middleware)
        if ($languageId === null) {
            $languageId = LanguageService::getCurrentId();
        }

        // If no language set, return base table value
        if (!$languageId) {
            return $this->attributes[$field] ?? null;
        }

        // Check if translations are eager loaded (from ->with('translations'))
        if ($this->relationLoaded('translations')) {
            try {
                $translationsCollection = $this->getRelation('translations');
                if ($translationsCollection !== null) {
                    $translation = $translationsCollection
                        ->where('language_id', $languageId)
                        ->first();
                } else {
                    $translation = $this->translation($languageId);
                }
            } catch (\Exception $e) {
                // If accessing translations fails, fallback to lazy loading
                $translation = $this->translation($languageId);
            }
        } else {
            // Fallback to lazy loading if not eager loaded
            $translation = $this->translation($languageId);
        }

        // If translation exists and field has value, use it
        // Check for both null and empty string
        if ($translation && isset($translation->$field) && $translation->$field !== '' && $translation->$field !== null) {
            return $translation->$field;
        }

        // This ensures we always have content even if translation is missing
        return $this->attributes[$field] ?? null;
    }

    public function translated(string $field)
    {
        $langId = \App\Services\LanguageService::getCurrentId();

        // If no language set, return base table value
        if (!$langId) {
            return $this->attributes[$field] ?? null;
        }

        // Check if translations are eager loaded (more efficient)
        if ($this->relationLoaded('translations')) {
            try {
                $translationsCollection = $this->getRelation('translations');
                if ($translationsCollection !== null) {
                    $translation = $translationsCollection
                        ->where('language_id', $langId)
                        ->first();
                } else {
                    $translation = $this->translation($langId);
                }
            } catch (\Exception $e) {
                $translation = $this->translation($langId);
            }
        } else {
            $translation = $this->translation($langId);
        }

        // Return translation if exists and not empty, otherwise base table fallback
        return ($translation && isset($translation->$field) && $translation->$field !== '' && $translation->$field !== null)
            ? $translation->$field
            : ($this->attributes[$field] ?? null);
    }

    public function getAttribute($key)
    {
        // Check if this is a translatable field
        if ($this->isTranslatableAttribute($key)) {
            return $this->getTranslatedAttribute($key);
        }

        // Default behavior for non-translatable fields
        return parent::getAttribute($key);
    }

    protected function isTranslatableAttribute(string $key): bool
    {
        return in_array($key, $this->getTranslatableAttributes());
    }

    protected function getTranslatableAttributes(): array
    {
        return property_exists($this, 'translatable') ? $this->translatable : [];
    }

    protected function getTranslationModelClass(): string
    {
        if (property_exists($this, 'translationModel')) {
            return 'App\\Models\\' . $this->translationModel;
        }

        // Default: ModelNameTranslation
        $modelName = class_basename($this);
        return 'App\\Models\\' . $modelName . 'Translation';
    }

    protected function getTranslationForeignKey(): string
    {
        if (property_exists($this, 'translationForeignKey')) {
            return $this->translationForeignKey;
        }

        // Default: model_id (e.g., category_id)
        return strtolower(class_basename($this)) . '_id';
    }

    protected function getCurrentLanguageId(): ?int
    {
        // Priority 1: Get from app container (set by middleware)
        if (app()->has('lang_id')) {
            return app('lang_id');
        }

        // Priority 2: Get from request attributes (backward compatibility)
        $request = Request::instance();
        if ($request) {
            return $request->attributes->get('language_id');
        }

        return null;
    }

    public function scopeWithTranslation($query)
    {
        $languageId = $this->getCurrentLanguageId();

        if ($languageId) {
            return $query->with(['translations' => function ($q) use ($languageId) {
                $q->where('language_id', $languageId);
            }]);
        }

        return $query->with('translations');
    }

    public function scopeWithAllTranslations($query)
    {
        return $query->with('translations');
    }

    public function saveTranslation(int $languageId, array $data)
    {
        $translationModel = $this->getTranslationModelClass();
        $foreignKey = $this->getTranslationForeignKey();

        // Only save translatable fields
        $translatableData = array_intersect_key($data, array_flip($this->getTranslatableAttributes()));

        foreach ($translatableData as $key => $value) {
            if (is_null($value)) {
                $translatableData[$key] = '';
            }
        }

        // Check if all translatable fields are empty
        $allFieldsEmpty = true;
        foreach ($translatableData as $value) {
            if (is_array($value)) {
                if (!empty($value)) {
                    $allFieldsEmpty = false;
                    break;
                }
                continue;
            }
            $trimmedValue = trim((string) $value);
            if ($trimmedValue !== '') {
                $allFieldsEmpty = false;
                break;
            }
        }

        // Mirror the default-language values into the base table so that any
        // legacy code reading translatable columns directly (e.g. raw DB
        // queries, search indexers, customer-facing list APIs that select
        // base columns) sees the canonical text. Translations table still
        // holds the per-language copy for non-default languages.
        $defaultLanguage = (new LanguageService())->getDefaultLanguage();
        $defaultLanguageId = $defaultLanguage ? (int) $defaultLanguage->id : null;
        if ($defaultLanguageId !== null && (int) $languageId === $defaultLanguageId) {
            $baseColumns = [];
            $tableName = $this->getTable();
            foreach ($translatableData as $key => $value) {
                // Skip fields that exist only on the translation table (no
                // matching base-table column).
                if (!Schema::hasColumn($tableName, $key)) {
                    continue;
                }
                // Mirror only scalar values; arrays (e.g. cast columns like
                // CategoryCustomField.options) are left to be handled by the
                // model's own cast definition if it has one.
                if (is_array($value)) {
                    $baseColumns[$key] = $value;
                } elseif (is_scalar($value) || $value === null) {
                    $baseColumns[$key] = $value;
                }
            }
            if (!empty($baseColumns)) {
                $this->forceFill($baseColumns)->saveQuietly();
            }
        }

        // If all fields are empty, delete the translation if it exists
        if ($allFieldsEmpty) {
            $existingTranslation = $translationModel::where($foreignKey, $this->id)
                ->where('language_id', $languageId)
                ->first();

            if ($existingTranslation) {
                $existingTranslation->delete();
                return null; // Return null to indicate deletion
            }

            // No existing translation to delete, return null
            return null;
        }

        // Update or create translation when there's actual data
        return $translationModel::updateOrCreate(
            [
                $foreignKey => $this->id,
                'language_id' => $languageId
            ],
            $translatableData
        );
    }

    public function deleteTranslation(int $languageId): bool
    {
        $foreignKey = $this->getTranslationForeignKey();

        return $this->translations()
            ->where($foreignKey, $this->id)
            ->where('language_id', $languageId)
            ->delete();
    }

    public function getTranslationsAttribute()
    {
        if ($this->relationLoaded('translations')) {
            return $this->getRelation('translations')->toArray();
        }

        // Default accessor behavior - return array with current language translations
        $langCode = LanguageService::getCurrentCode();

        $translations = [
            'lang' => $langCode,
        ];

        foreach ($this->getTranslatableAttributes() as $field) {
            // This automatically applies fallback via getAttribute()
            $translations[$field] = $this->getTranslatedAttribute($field);
        }

        return $translations;
    }

    /**
     * Serialization: when "optimized" (customer route or Content-Language header), the
     * current-language values are flattened into the main fields and the nested
     * translations object is dropped — customer apps read plain fields only.
     * Non-optimized (admin) responses keep the full translations payload for the
     * multi-language forms. Extra attributes to hide are controlled per request
     * via setHideAttributes() / setOnlyIdAndTranslationsFor() in your controller—no model property.
     */
    public function toArray()
    {
        $optimized = self::isOptimizedResponse();

        // Load translations once up front so the per-field lookups below (and the
        // translations append inside parent::toArray) hit the collection instead
        // of issuing a query per field.
        if ($optimized && !$this->relationLoaded('translations')) {
            $this->load('translations');
        }

        $array = parent::toArray();

        if (!$optimized) {
            return $array;
        }

        // Language-flat: localized value in the main field, no translations object.
        foreach ($this->getTranslatableAttributes() as $field) {
            $array[$field] = $this->getTranslatedAttribute($field);
        }
        unset($array['translations']);

        // Per-model: keep only id and localized fields (e.g. for Branch in app APIs)
        $onlyIdAndTranslations = self::getOnlyIdAndTranslationsModelsFromRequest();
        if (!empty($onlyIdAndTranslations) && in_array(class_basename($this), $onlyIdAndTranslations, true)) {
            return array_intersect_key($array, array_flip(array_merge(['id'], $this->getTranslatableAttributes())));
        }

        // Global or default: hide only attributes set for this request (via setHideAttributes).
        $hideAttrs = self::getTranslationHideAttributesFromRequest($this);
        foreach ($hideAttrs as $key) {
            unset($array[$key]);
        }

        return $array;
    }

    /**
     * Optimized when: customer route OR Content-Language header, unless overridden by setOptimizedResponse(false).
     */
    protected static function isOptimizedResponse(): bool
    {
        if (!app()->has('request') || !request()) {
            return false;
        }
        $override = request()->attributes->get('translation_optimized');
        if ($override !== null) {
            return (bool) $override;
        }
        if (self::isCustomerRoute()) {
            return true;
        }
        $contentLanguage = request()->header('Content-Language');
        return $contentLanguage !== null && trim((string) $contentLanguage) !== '';
    }

    /**
     * Attributes to hide in optimized response. Supports per-model list: translation_hide_attributes_Branch, etc.
     * Fallback: translation_hide_attributes (global). Empty or not set = hide nothing extra.
     */
    protected static function getTranslationHideAttributesFromRequest($model = null): array
    {
        if (!app()->has('request') || !request()) {
            return [];
        }
        if ($model !== null) {
            $key = 'translation_hide_attributes_' . class_basename($model);
            $attrs = request()->attributes->get($key);
            if (is_array($attrs)) {
                return $attrs;
            }
        }
        $attrs = request()->attributes->get('translation_hide_attributes');
        return is_array($attrs) ? $attrs : [];
    }

    /**
     * Model class basenames (e.g. ['Branch']) that should serialize as only id + translations.
     */
    protected static function getOnlyIdAndTranslationsModelsFromRequest(): array
    {
        if (!app()->has('request') || !request()) {
            return [];
        }
        $list = request()->attributes->get('translation_only_id_and_translations');
        return is_array($list) ? $list : [];
    }

    /**
     * Whether the current request is under the customer route prefix (customer/*).
     */
    protected static function isCustomerRoute(): bool
    {
        if (!app()->has('request') || !request()) {
            return false;
        }
        $path = request()->path();
        return $path === 'customer' || str_starts_with($path, 'customer/');
    }

    // --- Request-level controls (call from controller when building response) ---

    /**
     * Force optimized response (translations only at top level) for this request.
     * Call before returning response. Optional: default is derived from customer route / Content-Language.
     */
    public static function setOptimizedResponse(bool $enabled): void
    {
        if (app()->has('request') && request()) {
            request()->attributes->set('translation_optimized', $enabled);
        }
    }

    /**
     * Call in controller per API so the same model can return full or minimal data.
     * Pass [] to hide nothing extra; omit calling to also hide nothing.
     */
    public static function setHideAttributes(array $attributes): void
    {
        if (app()->has('request') && request()) {
            request()->attributes->set('translation_hide_attributes', $attributes);
        }
    }

    /**
     * Convenience: enable optimized response and set which attributes to hide in one call.
     * Example: HasTranslations::optimizedForRequest(['parent_id', 'conversion']);
     */
    public static function optimizedForRequest(array $hideAttributes = []): void
    {
        self::setOptimizedResponse(true);
        self::setHideAttributes($hideAttributes);
    }

    /**
     * In optimized response, these models will serialize with only id and translations.
     * Pass class basenames, e.g. setOnlyIdAndTranslationsFor(['Branch']).
     */
    public static function setOnlyIdAndTranslationsFor(array $modelBasenames): void
    {
        if (app()->has('request') && request()) {
            request()->attributes->set('translation_only_id_and_translations', $modelBasenames);
        }
    }

    public function getAllActiveLanguageTranslations(): array
    {
        // Ensure translations are loaded (eager load if not already loaded)
        if (!$this->relationLoaded('translations')) {
            $this->load('translations');
        }

        // Get default language for fallback logic
        $languageService = app(LanguageService::class);
        $defaultLanguage = $languageService->getDefaultLanguage();
        $defaultLanguageId = $defaultLanguage ? $defaultLanguage->id : null;

        // Get all active languages for admin panel (system_type = 4)
        $activeLanguages = collect($languageService->getActiveLanguages())->keyBy('id');

        $translationsRelation = $this->getRelation('translations');
        $modelTranslations = $translationsRelation ? collect($translationsRelation)->keyBy('language_id') : collect();

        $translatableFields = $this->getTranslatableAttributes();

        $hasAnyTranslation = $modelTranslations->isNotEmpty();
        $isSingleLanguage = $activeLanguages->count() === 1;

        $translations = [];
        
        foreach ($activeLanguages as $langId => $langInfo) {
            $translation = $modelTranslations->get($langId);
            
            $isDefaultLanguage = ($langId == $defaultLanguageId) || ($langInfo->is_default == 1);
            $hasTranslation = $translation !== null;
            
            $translationData = [
                'language_id' => $langId,
                'language_code' => $langInfo->code ?? '',
                'language_name' => $langInfo->name ?? '',
            ];

            // For each translatable field, get the value
            foreach ($translatableFields as $field) {
                // If single language and no translations exist, use main table data
                if ($isSingleLanguage && !$hasAnyTranslation) {
                    $translationData[$field] = $this->getAttributeValue($field) ?? '';
                } elseif ($isDefaultLanguage && !$hasTranslation) {
                    // Default language without translation: use base table values
                    $translationData[$field] = $this->getAttributeValue($field) ?? '';
                } else {
                    // Use translation data if available, otherwise empty string
                    $translationData[$field] = $translation ? ($translation->$field ?? '') : '';
                }
            }

            $translations[$langId] = $translationData;
        }

        return $translations;
    }
    
}