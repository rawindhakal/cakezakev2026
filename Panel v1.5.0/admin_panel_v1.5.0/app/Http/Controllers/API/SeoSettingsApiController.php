<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Services\LanguageService;
use App\Http\Controllers\Controller;
use App\Models\SeoSetting;
use App\Models\Zone;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class SeoSettingsApiController extends Controller
{

    protected $languageService;

    public function __construct(LanguageService $languageService)
    {
        $this->languageService = $languageService;
    }

    public function getSeoSettings(Request $request)
    {
        try {
            $limit  = $request->input('limit');
            $offset = (($request->input('offset', 1)) - 1) * $limit;
            $filter = $request->input('filter', '');

            $query = SeoSetting::with(['translations', 'zone:id,name'])->orderBy('id', 'DESC');

            // Header zone filter: show that zone's pages plus the default (zone_id 0)
            // ones, since those still apply wherever a zone has no page of its own.
            if ($request->filled('zone_id')) {
                $zoneId = (int) $request->input('zone_id');
                $query->where(function ($q) use ($zoneId) {
                    $q->where('zone_id', $zoneId)->orWhere('zone_id', 0);
                });
            }

            if ($filter) {
                $query->where('page_type', 'like', "%{$filter}%")
                    ->orWhereHas('translations', function ($q) use ($filter) {
                        $q->where('meta_title', 'like', "%{$filter}%")
                            ->orWhere('meta_description', 'like', "%{$filter}%");
                    });
            }

            $total = $query->count();

            if ($limit) {
                $seoSettings = $query->skip($offset)->take($limit)->get();
            } else {
                $seoSettings = $query->get();
            }

            $seoSettings->each(function ($row) {
                $row->zone_id = (int) $row->zone_id;
                // zone_id 0 is the default page, used by every zone that has none.
                $row->is_default = $row->zone_id === 0 ? 1 : 0;
                $row->zone_name = $row->zone_id === 0 ? __('default') : ($row->zone->name ?? '');
            });

            return CommonHelper::responseWithData($seoSettings, $total);
        } catch (\Exception $e) {
            return CommonHelper::responseError($e->getMessage());
        }
    }

    public function save(Request $request)
    {
        $defaultLanguage = $this->languageService->getDefaultLanguage();
        $isDefault = $request->language_id == $defaultLanguage->id;

        $rules = [
            'page_type'   => 'required|string|max:255',
            'language_id' => 'required|exists:languages,id',
            // 0 = default (applies to every zone); any other value must be a real zone.
            'zone_id'     => 'nullable|integer',
        ];

        if ($isDefault) {
            $rules['og_image'] = 'required|image|mimes:jpeg,png,jpg,gif,svg,webp|max:2048';
        }

        $validator = Validator::make($request->all(), $rules);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $zoneId = (int) $request->input('zone_id', 0);
        if ($zoneId > 0 && !Zone::where('id', $zoneId)->exists()) {
            return CommonHelper::responseError(__('zone_not_found'));
        }

        if ($zoneId > 0 && !SeoSetting::where('page_type', $request->page_type)->where('zone_id', 0)->exists()) {
            return CommonHelper::responseError(__('add_default_seo_for_this_page_first'));
        }

        $existingSeo = SeoSetting::where('page_type', $request->page_type)
            ->where('zone_id', $zoneId)->first();
        if ($existingSeo) {
            return CommonHelper::responseError(__('page_type_already_exists'));
        }

        $seo = new SeoSetting();
        $seo->page_type = $request->page_type;
        $seo->zone_id = $zoneId;

        if ($request->hasFile('og_image')) {
            $seo->og_image = CommonHelper::uploadFile($request, 'og_image', 'seo_settings');
        }

        $seo->save();

        $translationData = [
            'meta_title'       => $request->meta_title ?? '',
            'meta_keyword'     => $request->meta_keyword ?? '',
            'schema_markup'    => $request->schema_markup ?? '',
            'meta_description' => $request->meta_description ?? '',
        ];


        if ($isDefault) {
            $seo->meta_title       = $translationData['meta_title'];
            $seo->meta_keyword     = $translationData['meta_keyword'];
            $seo->schema_markup    = $translationData['schema_markup'];
            $seo->meta_description = $translationData['meta_description'];
            $seo->save();
        }

        $seo->saveTranslation($request->language_id, $translationData);

        return CommonHelper::responseWithData($seo, __('seo_setting_saved_successfully'));
    }

    public function update(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'id'          => 'required|exists:web_seo_pages,id',
            'language_id' => 'required|exists:languages,id',
            'page_type'   => 'required|string|max:255',
            'zone_id'     => 'nullable|integer',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $seo = SeoSetting::find($request->id);
        if (!$seo) {
            return CommonHelper::responseError(__('page_not_found'));
        }

        $zoneId = $request->has('zone_id') ? (int) $request->input('zone_id') : (int) $seo->zone_id;
        if ($zoneId > 0 && !Zone::where('id', $zoneId)->exists()) {
            return CommonHelper::responseError(__('zone_not_found'));
        }

        if ($zoneId > 0 && !SeoSetting::where('page_type', $request->page_type)
                ->where('zone_id', 0)->where('id', '!=', $request->id)->exists()) {
            return CommonHelper::responseError(__('add_default_seo_for_this_page_first'));
        }

        $existingSeo = SeoSetting::where('page_type', $request->page_type)
            ->where('zone_id', $zoneId)
            ->where('id', '!=', $request->id)
            ->first();
        if ($existingSeo) {
            return CommonHelper::responseError(__('page_type_already_exists'));
        }

        $defaultLanguage = $this->languageService->getDefaultLanguage();
        $isDefault = $request->language_id == $defaultLanguage->id;

        if ($isDefault) {
            $seo->page_type = $request->page_type;
            $seo->zone_id = $zoneId;

            if ($request->hasFile('og_image')) {
                $seo->og_image = CommonHelper::uploadFile($request, 'og_image', 'seo_settings', $seo->og_image);
            }

            $seo->save();
        }

        $translationData = [
            'meta_title'       => $request->meta_title ?? '',
            'meta_keyword'     => $request->meta_keyword ?? '',
            'schema_markup'    => $request->schema_markup ?? '',
            'meta_description' => $request->meta_description ?? '',
        ];
        if ($isDefault) {
            $seo->meta_title       = $request->meta_title ?? '';
            $seo->meta_keyword     = $request->meta_keyword ?? '';
            $seo->schema_markup    = $request->schema_markup ?? '';
            $seo->meta_description = $request->meta_description ?? '';
            $seo->save();
        }

        $seo->saveTranslation($request->language_id, $translationData);

        return CommonHelper::responseWithData([
            'id' => $seo->id
        ], __('seo_setting_updated_successfully'));
    }

    public function delete(Request $request)
    {
        if (isset($request->id)) {
            $SeoSetting = SeoSetting::find($request->id);
            if ($SeoSetting) {
                $SeoSetting->delete();
                return CommonHelper::responseSuccess(__('seo_setting_deleted_successfully'));
            } else {
                return CommonHelper::responseSuccess("SeoSetting Already Deleted!");
            }
        }
    }
}
