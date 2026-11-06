<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\PromoCode;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
class PromoCodeApiController extends Controller
{
    public function index()
    {
        $search = request()->input('search');
        $countryId = (int) request()->input('country_id', 0);
        $source = request()->input('source', 'manual');
        $promocode = PromoCode::with('translations')
            ->when($source !== 'all', fn ($query) => $query->where('source', $source))
            ->when($search, function ($query) use ($search) {
                if (is_numeric($search)) {
                    $query->where('id', $search);
                } elseif (strtolower($search) === 'active') {
                    $query->where('status', 1);
                } elseif (strtolower($search) === 'deactive' || strtolower($search) === 'inactive') {
                    $query->where('status', 0);
                } else {
                    $query->where(function ($q) use ($search) {
                        $q->where('promo_code', 'like', "%{$search}%")
                            ->orWhere('title', 'like', "%{$search}%")
                            ->orWhere('description', 'like', "%{$search}%");
                    });
                }
            })
            // Global header country filter: promos for that country, or unrestricted (all).
            ->when($countryId, function ($query) use ($countryId) {
                $query->where(function ($q) use ($countryId) {
                    $q->whereNull('country_ids')
                        ->orWhereJsonLength('country_ids', 0)
                        ->orWhereJsonContains('country_ids', $countryId);
                });
            })
            // Zone filter (branch users are force-scoped to their zone): promos for
            // that zone, or unrestricted (empty zone_ids = all zones).
            ->when((int) request()->input('zone_id', 0), function ($query) {
                $zoneId = (int) request()->input('zone_id', 0);
                $query->where(function ($q) use ($zoneId) {
                    $q->whereNull('zone_ids')
                        ->orWhereJsonLength('zone_ids', 0)
                        ->orWhereJsonContains('zone_ids', $zoneId);
                });
            })
            ->orderBy('id', 'DESC')
            ->get();

        $reportResponse = app(ReportsApiController::class)
            ->promo(new Request(['period' => 'all']));
        $reportRows = json_decode($reportResponse->getContent(), true)['data']['rows'] ?? [];

        $usage = [];
        foreach ($reportRows as $r) {
            $usage[(int) $r['id']] = [
                'uses'           => (int) $r['uses'],
                'discount_given' => (float) $r['total_benefit'],
            ];
        }

        $promocode = $promocode
            ->map(function ($code) use ($usage) {
                // Convert promo code to array to ensure all data is included
                $codeArray = $code->toArray();

                // Hide the translations accessor that returns only current language
                $code->makeHidden(['translations']);
                // Add full translations array from relation
                if ($code->relationLoaded('translations')) {
                    $codeArray['translations'] = $code->getRelation('translations')->toArray();
                } else {
                    $codeArray['translations'] = [];
                }

                $u = $usage[$code->id] ?? ['uses' => 0, 'discount_given' => 0.0];
                $codeArray['used_count'] = $u['uses'];
                $codeArray['discount_given'] = $u['discount_given'];

                return $codeArray;
            })
            ->toArray();

        return CommonHelper::responseWithData($promocode);
    }

    /** Decode an array field that may arrive as a real array or a JSON string (FormData). */
    private function arrayField(Request $request, string $key): array
    {
        $val = $request->input($key);
        if (is_string($val)) {
            $decoded = json_decode($val, true);
            return is_array($decoded) ? $decoded : [];
        }
        return is_array($val) ? array_values($val) : [];
    }

    /** Map all coupon fields from the request onto the model (shared by save + update). */
    private function applyFields(PromoCode $promocode, Request $request): void
    {
        // 1. Basic
        $promocode->title = $request->title;
        $promocode->promo_code = $request->promo_code;
        $promocode->description = $request->description;

        // 2. Discount
        $promocode->discount_type = $request->discount_type; // percentage | flat | free_delivery
        $promocode->discount = ($request->discount_type === 'free_delivery') ? 0 : ($request->discount ?? 0);
        $promocode->discount_apply_type = in_array($request->discount_apply_type, ['instant', 'wallet'], true)
            ? $request->discount_apply_type : 'instant';
        $promocode->max_discount_amount = $request->max_discount_amount ?? 0;

        // 3. Applicability
        $promocode->applicability = in_array($request->applicability, ['all', 'categories', 'products', 'brands'], true)
            ? $request->applicability : 'all';
        $promocode->applicability_ids = array_values(array_map('intval', $this->arrayField($request, 'applicability_ids')));

        // 4. Cart conditions
        $promocode->minimum_order_amount = $request->minimum_order_amount ?? 0;
        $promocode->min_product_quantity = $request->min_product_quantity ?? 0;

        // 5. Usage restrictions
        $promocode->total_usage_limit = $request->total_usage_limit ?? 0;
        $promocode->per_user_usage_limit = $request->per_user_usage_limit ?? 0;

        // 6. Scheduling
        $promocode->is_permanent = $request->boolean('is_permanent') ? 1 : 0;
        $promocode->start_date = $promocode->is_permanent ? null : ($request->start_date ?: null);
        $promocode->end_date = $promocode->is_permanent ? null : ($request->end_date ?: null);
        $promocode->full_day_promotion = $request->boolean('full_day_promotion') ? 1 : 0;
        $promocode->start_time = $promocode->full_day_promotion ? null : ($request->start_time ?: null);
        $promocode->end_time = $promocode->full_day_promotion ? null : ($request->end_time ?: null);
        $weekdays = $this->arrayField($request, 'weekday_recurrence');
        $promocode->weekday_recurrence = !empty($weekdays)
            ? array_values(array_map('intval', $weekdays)) : [0, 1, 2, 3, 4, 5, 6];

        // 7. Audience ('new' = customers with no prior orders)
        $promocode->audience_type = in_array($request->audience_type, ['all', 'new', 'specific'], true)
            ? $request->audience_type : 'all';
        $promocode->audience_ids = $promocode->audience_type === 'specific'
            ? array_values(array_map('intval', $this->arrayField($request, 'audience_ids'))) : [];

        // 9. Platform & visibility
        $promocode->visibility = in_array($request->visibility, ['public', 'hidden'], true) ? $request->visibility : 'public';
        $promocode->platform = in_array($request->platform, ['all', 'app', 'web'], true) ? $request->platform : 'all';

        // 10. Sales channel + country/zone restriction (1 zone = 1 branch)
        $promocode->channel = in_array($request->channel, ['quick', 'ecommerce', 'both'], true) ? $request->channel : 'both';
        $promocode->country_ids = array_values(array_map('intval', $this->arrayField($request, 'country_ids')));
        $promocode->zone_ids = array_values(array_map('intval', $this->arrayField($request, 'zone_ids')));

        // A branch user's promo is locked to its own branch's zone/country/channel,
        // regardless of what the client sent.
        $authUser = auth()->user();
        if ($authUser && $authUser->isBranchUser() && $authUser->branch) {
            $branch = $authUser->branch;
            $promocode->zone_ids    = $branch->zone_id ? [(int) $branch->zone_id] : [];
            $promocode->country_ids = optional($branch->zone)->country_id ? [(int) $branch->zone->country_id] : [];
            $promocode->channel     = optional($branch->zone)->sales_channel ?: $promocode->channel;
        }
    }

    private function saveTranslations(PromoCode $promocode, Request $request): void
    {
        if (!$request->has('translations')) {
            return;
        }
        $translations = $request->translations;
        if (is_string($translations)) {
            $translations = json_decode($translations, true);
        }
        if (is_array($translations)) {
            foreach ($translations as $translation) {
                if (isset($translation['language_id'])) {
                    $promocode->saveTranslation($translation['language_id'], [
                        'title'       => $translation['title'] ?? '',
                        'description' => $translation['description'] ?? '',
                    ]);
                }
            }
        }
    }

    private function branchImage(PromoCode $promocode, Request $request): void
    {
        $promocode->image = CommonHelper::uploadFile($request, 'image', 'promocode', $promocode->image);
    }

    public function edit($id)
    {
        $promocode = PromoCode::with('translations')->find($id);
        if (!$promocode) {
            return CommonHelper::responseError('promo_code_not_found');
        }
        $data = $promocode->toArray();
        $data['translations'] = $promocode->relationLoaded('translations')
            ? $promocode->getRelation('translations')->toArray() : [];
        return CommonHelper::responseWithData($data);
    }

    public function save(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'promo_code' => 'required',
            'title' => 'required',
            'discount_type' => 'required|in:percentage,flat,free_delivery',
            'discount' => 'required_unless:discount_type,free_delivery',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        $authUser = auth()->user();
        $isBranchUser = $authUser && $authUser->isBranchUser() && $authUser->branch;
        if (!$isBranchUser && empty($this->arrayField($request, 'country_ids'))) {
            return CommonHelper::responseError('please_select_at_least_one_country');
        }

        $promocode = new PromoCode();
        $this->applyFields($promocode, $request);
        $promocode->status = $request->has('status') ? (int) $request->status : 1;
        $promocode->image = '';
        $this->branchImage($promocode, $request);
        $promocode->save();
        $this->saveTranslations($promocode, $request);

        // Announce the promo to its target customers (skips hidden/inactive promos).
        dispatch(function () use ($promocode) {
            CommonHelper::sendPromoCodeNotification($promocode);
        })->afterResponse();

        return CommonHelper::responseSuccess('promo_code_saved_successfully');
    }

    public function update(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'id' => 'required',
            'promo_code' => 'required',
            'title' => 'required',
            'discount_type' => 'required|in:percentage,flat,free_delivery',
            'discount' => 'required_unless:discount_type,free_delivery',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $authUser = auth()->user();
        $isBranchUser = $authUser && $authUser->isBranchUser() && $authUser->branch;
        if (!$isBranchUser && empty($this->arrayField($request, 'country_ids'))) {
            return CommonHelper::responseError('please_select_at_least_one_country');
        }

        $promocode = PromoCode::find($request->id);
        if (!$promocode) {
            return CommonHelper::responseError('promo_code_not_found');
        }

        $this->applyFields($promocode, $request);
        $promocode->status = $request->has('status') ? (int) $request->status : $promocode->status;
        $this->branchImage($promocode, $request);
        $promocode->save();
        $this->saveTranslations($promocode, $request);

        return CommonHelper::responseSuccess('promo_code_updated_successfully');
    }

    public function delete(Request $request)
    {

        if (isset($request->id)) {

            $promocode = PromoCode::find($request->id);
            if ($promocode) {
                $promocode->delete();
                return CommonHelper::responseSuccess('promo_code_deleted_successfully');
            } else {
                return CommonHelper::responseSuccess('promo_code_already_deleted');
            }
        }
    }
}
