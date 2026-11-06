<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Country;
use App\Models\Region;
use App\Services\LanguageService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * Country subdivisions — states, provinces, emirates.
 *
 * Import works exactly like the country import: a shipped dataset per country under
 * config/states.json, the admin ticks the rows they operate in, and only those
 * become selectable. Adding support for a new country is a JSON file, not a code change.
 * A country with no dataset and no manual rows simply has no dropdown — callers fall
 * back to free-text, which is why nothing here special-cases a country.
 */
class RegionApiController extends Controller
{
    protected $languageService;

    public function __construct(LanguageService $languageService)
    {
        $this->languageService = $languageService;
    }

    /** Regions of one country. `status=1` for pickers, unfiltered for admin lists. */
    public function index(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'country_id' => 'required|exists:countries,id',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $useContentLanguage = trim((string) $request->header('Content-Language')) !== '';

        $query = ($useContentLanguage ? Region::query() : Region::with('translations'))
            ->where('country_id', (int) $request->country_id);

        if ($request->filled('status')) {
            $query->where('status', (int) $request->input('status'));
        }
        if ($request->filled('search')) {
            $search = trim((string) $request->input('search'));
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('code', 'like', "%{$search}%")
                    ->orWhere('tax_code', 'like', "%{$search}%");
            });
        }

        $total = (clone $query)->count();

        $limit = (int) $request->get('limit', 0);
        if ($limit > 0) {
            $query->skip((int) $request->get('offset', 0))->take($limit);
        }

        return CommonHelper::responseWithData($query->orderBy('name')->get(), $total);
    }

    /**
     * The full shipped list for a country, each row flagged `imported` so the UI can
     * grey out what is already in. Empty list = no dataset shipped for that country.
     */
    public function importList(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'country_id' => 'required|exists:countries,id',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $country = Country::find((int) $request->country_id);
        $rows = Region::dataset((string) $country->code);
        $existing = Region::where('country_id', $country->id)->pluck('code')->all();

        $list = array_map(function ($row) use ($existing) {
            $row['imported'] = in_array($row['code'] ?? '', $existing, true);
            return $row;
        }, $rows);

        return CommonHelper::responseWithData($list, count($list));
    }

    /** Import the ticked subdivision codes. Re-importing an existing code is a no-op. */
    public function import(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'country_id' => 'required|exists:countries,id',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $codes = $request->input('codes', []);
        if (is_string($codes)) {
            $codes = json_decode($codes, true) ?: array_filter(array_map('trim', explode(',', $codes)));
        }
        if (empty($codes)) {
            return CommonHelper::responseError('select_at_least_one_region');
        }

        $country = Country::find((int) $request->country_id);
        $defaultLanguage = $this->languageService->getDefaultLanguage();

        $imported = Region::importFromDataset(
            (int) $country->id,
            (string) $country->code,
            array_map('strval', $codes),
            $defaultLanguage?->id
        );

        return CommonHelper::responseSuccessWithData('regions_imported_successfully', ['imported' => $imported]);
    }

    /** Manual add / edit, for a subdivision the shipped dataset doesn't carry. */
    public function save(Request $request)
    {
        $defaultLanguage = $this->languageService->getDefaultLanguage();
        if (!$defaultLanguage) {
            return CommonHelper::responseError('default_language_not_found');
        }
        $isDefaultLanguage = $request->language_id == $defaultLanguage->id;

        $rules = [
            'country_id'  => 'required|exists:countries,id',
            'language_id' => 'required|exists:languages,id',
            'name'        => $isDefaultLanguage ? 'required|string|max:191' : 'nullable|string|max:191',
            'code'        => 'nullable|string|max:12',
            'tax_code'    => 'nullable|string|max:8',
            'type'        => 'nullable|string|max:24',
        ];
        $validator = Validator::make($request->all(), $rules);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        if (!$isDefaultLanguage && !$request->filled('id')) {
            return CommonHelper::responseError('default_language_required');
        }

        $region = $request->filled('id') ? Region::find((int) $request->id) : new Region();
        if ($request->filled('id') && !$region) {
            return CommonHelper::responseError('region_not_found');
        }

        if ($isDefaultLanguage) {
            $code = $request->filled('code') ? strtoupper(trim((string) $request->code)) : null;
            if ($code) {
                $clash = Region::where('country_id', (int) $request->country_id)->where('code', $code)
                    ->when($region->exists, fn ($q) => $q->where('id', '!=', $region->id))->exists();
                if ($clash) {
                    return CommonHelper::responseError('region_code_already_exists');
                }
            }
            $region->country_id = (int) $request->country_id;
            $region->name = $request->name;
            $region->code = $code;
            $region->tax_code = $request->filled('tax_code') ? trim((string) $request->tax_code) : null;
            $region->type = $request->input('type') ?: 'state';
            $region->status = $request->has('status') ? (int) $request->status : ($region->status ?? 1);
            $region->save();
        }

        $region->saveTranslation($request->language_id, ['name' => $request->input('name', '')]);

        return CommonHelper::responseSuccessWithData('region_saved_successfully', $region->fresh());
    }

    public function delete(Request $request)
    {
        $region = Region::find((int) $request->input('id'));
        if (!$region) {
            return CommonHelper::responseError('region_not_found');
        }

        $inUse = DB::table('zones')->where('region_id', $region->id)->exists()
            || DB::table('user_addresses')->where('region_id', $region->id)->exists()
            || DB::table('tax_rules')->where('region_id', $region->id)->exists()
            || DB::table('orders')->where('buyer_region_id', $region->id)->exists()
            || DB::table('order_items')->where('branch_region_id', $region->id)->exists();

        if ($inUse) {
            return CommonHelper::responseError('region_in_use_deactivate_instead');
        }

        DB::table('region_translations')->where('region_id', $region->id)->delete();
        $region->delete();

        return CommonHelper::responseSuccess('region_deleted_successfully');
    }
}
