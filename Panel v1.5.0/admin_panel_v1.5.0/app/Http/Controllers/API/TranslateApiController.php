<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class TranslateApiController extends Controller
{
    /**
     * Translate the default-language field values into the requested languages.
     *
     * Params:
     *  - data:             field => source text (from the default language)
     *  - target_languages: optional array of language codes; omitted/empty = every
     *                      active panel language.
     *
     * Response: { <language_code>: { field: "translated", ... }, ... }
     */
    public function translateFields(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'data'               => 'required|array',
            'target_languages'   => 'nullable|array',
            'target_languages.*' => 'string',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        try {
            $sourceData = $request->input('data', []);

            // Only send fields that actually have text — blank ones have nothing to
            // translate and would just waste tokens.
            $toTranslate = [];
            foreach ($sourceData as $field => $sourceValue) {
                if (is_scalar($sourceValue) && trim((string) $sourceValue) !== '') {
                    $toTranslate[$field] = $sourceValue;
                }
            }

            if (empty($toTranslate)) {
                return CommonHelper::responseError(__('translation_error_all_fields_empty'));
            }

            $targetLanguages = array_values(array_filter((array) $request->input('target_languages', [])));

            $translations = CommonHelper::translate($toTranslate, $targetLanguages);

            if (empty($translations)) {
                return CommonHelper::responseWithData([]);
            }

            if (isset($translations[0]['error']['code'])) {
                return CommonHelper::responseError($translations[0]['error']['message']);
            }

            return CommonHelper::responseWithData($translations);
        } catch (\Exception $e) {
            return CommonHelper::responseError($e->getMessage());
        }
    }
}
