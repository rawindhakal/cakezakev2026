<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\SpinWheelCampaign;
use App\Models\SpinWheelSegment;
use App\Models\SpinWheelSegmentAmount;
use App\Models\SpinWheelSpin;
use App\Services\SpinWheelService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * Spin-wheel campaigns: the wheel, its wedges, their odds and their per-country prizes.
 *
 * A campaign is saved whole — wedges and their country amounts are replaced on every
 * save, the way tax rules replace their components — because the odds have to stay
 * consistent: they are validated to total exactly 100 across the whole set.
 */
class SpinWheelApiController extends Controller
{
    public function index(Request $request)
    {
        $query = SpinWheelCampaign::query()->withCount('segments');

        if ($request->filled('status')) {
            $query->where('status', (int) $request->input('status'));
        }

        $search = trim((string) $request->input('search', ''));
        if ($search !== '') {
            if (is_numeric($search)) {
                $query->where('id', (int) $search);
            } else {
                $query->where(fn ($q) => $q->where('name', 'like', "%{$search}%")
                    ->orWhere('code_prefix', 'like', "%{$search}%"));
            }
        }

        $total = (clone $query)->count();

        $limit = (int) $request->input('limit', 0);
        if ($limit > 0) {
            $query->skip((int) $request->input('offset', 0))->take($limit);
        }

        $campaigns = $query->orderByDesc('id')->get();

        // Spin/win counts per campaign in one query rather than one per row.
        if ($campaigns->isNotEmpty()) {
            $ids = $campaigns->pluck('id')->all();
            $spins = DB::table('spin_wheel_spins')
                ->whereIn('spin_wheel_campaign_id', $ids)
                ->selectRaw('spin_wheel_campaign_id, COUNT(*) as spins, SUM(result = "win") as wins')
                ->groupBy('spin_wheel_campaign_id')
                ->get()
                ->keyBy('spin_wheel_campaign_id');

            foreach ($campaigns as $campaign) {
                $row = $spins->get($campaign->id);
                $campaign->spins_count = (int) ($row->spins ?? 0);
                $campaign->wins_count = (int) ($row->wins ?? 0);
            }
        }

        return CommonHelper::responseWithData($campaigns, $total);
    }

    /**
     * One campaign with everything the form needs: every language's text (not just the
     * request language) and each wedge with its per-country amounts.
     */
    public function edit($id)
    {
        $campaign = SpinWheelCampaign::with(['segments.amounts', 'segments.translations', 'translations'])->find($id);
        if (!$campaign) {
            return CommonHelper::responseError('spin_wheel_campaign_not_found');
        }

        $data = $campaign->toArray();
        $data['translations'] = $campaign->getAllActiveLanguageTranslations();
        $data['segments'] = $campaign->segments->map(function (SpinWheelSegment $segment) {
            $row = $segment->toArray();
            $row['translations'] = $segment->getAllActiveLanguageTranslations();
            $row['amounts'] = $segment->amounts->map(fn ($a) => [
                'country_id'           => (int) $a->country_id,
                'amount'               => (float) $a->amount,
                'max_discount_amount'  => (float) $a->max_discount_amount,
                'minimum_order_amount' => (float) $a->minimum_order_amount,
            ])->values();

            return $row;
        })->values();

        return CommonHelper::responseWithData($data);
    }

    public function save(Request $request)
    {
        $segments = $this->arrayField($request, 'segments');

        $validator = Validator::make(array_merge($request->all(), ['segments' => $segments]), [
            'name'                 => 'required|string|max:15',
            'code_prefix'          => 'nullable|string|max:16',
            'spins_per_day'        => 'required|integer|min:1',
            'max_spins_per_user'   => 'nullable|integer|min:0',
            'min_delivered_orders' => 'nullable|integer|min:0',
            'start_date'           => 'nullable|date',
            'end_date'             => 'nullable|date|after_or_equal:start_date',
            'segments'             => 'required|array',
            'segments.*.type'      => 'required|in:promo_code,wallet,free_delivery,no_luck',
            'segments.*.label'     => 'required|string|max:191',
            'segments.*.win_chance' => 'required|numeric|min:0|max:100',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        if ($error = $this->segmentRulesError($segments)) {
            return CommonHelper::responseError($error);
        }

        $campaign = $request->filled('id') ? SpinWheelCampaign::find((int) $request->input('id')) : new SpinWheelCampaign();
        if ($request->filled('id') && !$campaign) {
            return CommonHelper::responseError('spin_wheel_campaign_not_found');
        }

        DB::transaction(function () use ($request, $campaign, $segments) {
            $this->applyFields($campaign, $request);
            $campaign->save();

            $this->saveCampaignTranslations($campaign, $request);
            $this->saveSegments($campaign, $request, $segments);
        });

        // Only one wheel may run at a time, so switching this one on switches the others
        // off — done after the save so the swap sees the final status.
        if ((int) $campaign->status === 1) {
            app(SpinWheelService::class)->activate($campaign);
        }

        return CommonHelper::responseSuccessWithData('spin_wheel_campaign_saved_successfully', $campaign->fresh());
    }

    public function delete(Request $request)
    {
        $validator = Validator::make($request->all(), ['id' => 'required']);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $campaign = SpinWheelCampaign::find((int) $request->input('id'));
        if (!$campaign) {
            return CommonHelper::responseError('spin_wheel_campaign_not_found');
        }

        DB::transaction(function () use ($campaign) {
            $segmentIds = SpinWheelSegment::where('spin_wheel_campaign_id', $campaign->id)->pluck('id');
            SpinWheelSegmentAmount::whereIn('spin_wheel_segment_id', $segmentIds)->delete();
            DB::table('spin_wheel_segment_translations')->whereIn('spin_wheel_segment_id', $segmentIds)->delete();
            SpinWheelSegment::whereIn('id', $segmentIds)->delete();
            DB::table('spin_wheel_campaign_translations')->where('spin_wheel_campaign_id', $campaign->id)->delete();
            // The spin log stays: it is the record of prizes already handed out.
            $campaign->delete();
        });

        return CommonHelper::responseSuccess('spin_wheel_campaign_deleted_successfully');
    }

    /**
     * Spin history: who spun, what they won, and the totals above the table.
     */
    public function history(Request $request)
    {
        $query = SpinWheelSpin::from('spin_wheel_spins as s')
            ->leftJoin('users as u', 'u.id', '=', 's.user_id')
            ->leftJoin('spin_wheel_campaigns as c', 'c.id', '=', 's.spin_wheel_campaign_id')
            ->leftJoin('spin_wheel_segments as g', 'g.id', '=', 's.spin_wheel_segment_id')
            ->leftJoin('promo_codes as p', 'p.id', '=', 's.promo_code_id');

        if ($request->filled('campaign_id')) {
            $query->where('s.spin_wheel_campaign_id', (int) $request->input('campaign_id'));
        }
        if ($request->filled('country_id')) {
            $query->where('s.country_id', (int) $request->input('country_id'));
        }
        if ($request->filled('reward_type')) {
            $query->where('s.reward_type', $request->input('reward_type'));
        }
        $start = $request->input('start_date');
        $end = $request->input('end_date');
        if ($start && $end) {
            $query->whereBetween('s.spun_at', [$start . ' 00:00:00', $end . ' 23:59:59']);
        }
        $search = trim((string) $request->input('search', ''));
        if ($search !== '') {
            $query->where(fn ($q) => $q->where('u.name', 'like', "%{$search}%")
                ->orWhere('u.mobile', 'like', "%{$search}%")
                ->orWhere('u.email', 'like', "%{$search}%")
                ->orWhere('p.promo_code', 'like', "%{$search}%"));
        }

        $total = (clone $query)->count('s.id');

        $summary = (clone $query)->selectRaw(
            'COUNT(*) as spins,
             SUM(s.result = "win") as wins,
             SUM(CASE WHEN s.reward_type = "wallet" THEN s.amount ELSE 0 END) as wallet_credited,
             SUM(s.reward_type = "promo_code") as promo_codes_issued,
             SUM(s.reward_type = "free_delivery") as free_deliveries'
        )->first();

        $limit = (int) $request->input('limit', 20);
        $rows = $query->select(
            's.*',
            'u.name as customer_name',
            'u.mobile as customer_mobile',
            'c.name as campaign_name',
            'g.label as segment_label',
            'p.promo_code',
            'p.end_date as promo_expires_on'
        )
            ->orderByDesc('s.id')
            ->skip((int) $request->input('offset', 0))
            ->take($limit > 0 ? $limit : 20)
            ->get();

        return CommonHelper::responseWithData([
            'spins'   => $rows,
            'summary' => [
                'spins'              => (int) ($summary->spins ?? 0),
                'wins'               => (int) ($summary->wins ?? 0),
                'wallet_credited'    => round((float) ($summary->wallet_credited ?? 0), 2),
                'promo_codes_issued' => (int) ($summary->promo_codes_issued ?? 0),
                'free_deliveries'    => (int) ($summary->free_deliveries ?? 0),
            ],
        ], $total);
    }

    /**
     * Branch one image and hand back its path.
     *
     * The form uploads on pick — the same flow the home builder uses — so the campaign
     * save carries paths, not files, and a half-filled form never loses its artwork.
     */
    public function uploadImage(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'image' => 'required|file|mimes:jpeg,jpg,png,gif,webp,svg|max:5120',
        ], [
            'image.max'   => str_replace('{size}', '5 MB', __('file_size_exceeds_limit_x')),
            'image.mimes' => str_replace(
                ['{types}', '{size}'],
                ['JPG, PNG, GIF, WEBP, SVG', '5 MB'],
                __('allowed_types_and_max_size')
            ),
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $path = CommonHelper::uploadFile($request, 'image', 'spin_wheel');

        return CommonHelper::responseWithData([
            'path' => $path,
            'url'  => asset('storage/' . $path),
        ]);
    }

    // ---------------------------------------------------------------- internals

    /**
     * The panel posts UTC ("2026-09-12 13:00:00", converted from the admin's local time
     * the way the maintenance schedule is); stored as-is and compared against UTC now by
     * the scheduler and the availability check. Pinned to UTC on parse so an app
     * timezone change can never shift stored windows.
     */
    private function toDateTime($value): ?string
    {
        $value = trim((string) $value);
        if ($value === '') {
            return null;
        }

        try {
            return \Carbon\Carbon::parse($value, 'UTC')->format('Y-m-d H:i:s');
        } catch (\Throwable $e) {
            return null;
        }
    }

    /** A field the form posts as JSON inside FormData. */
    private function arrayField(Request $request, string $key): array
    {
        $value = $request->input($key);
        if (is_string($value)) {
            $value = json_decode($value, true);
        }

        return is_array($value) ? $value : [];
    }

    /**
     * The rules that cannot be expressed as field validation.
     *
     * The odds are the important one: they must total exactly 100 or the wheel the admin
     * sees is not the wheel the customer spins. Compared with a tolerance because these
     * are decimals — a strict === on a float sum rejects perfectly good input.
     */
    private function segmentRulesError(array $segments): ?string
    {
        // A wheel with one wedge is not a wheel.
        if (count($segments) < 2) {
            return 'spin_wheel_min_two_segments';
        }

        $sum = 0.0;

        foreach ($segments as $segment) {
            $sum += (float) ($segment['win_chance'] ?? 0);
            $type = $segment['type'] ?? '';

            if ($type === SpinWheelSegment::TYPE_NO_LUCK) {
                continue;
            }
            if (in_array($type, [SpinWheelSegment::TYPE_PROMO_CODE, SpinWheelSegment::TYPE_FREE_DELIVERY], true)
                && (int) ($segment['validity_days'] ?? 0) < 1) {
                return 'spin_wheel_validity_days_required';
            }
            if ($type === SpinWheelSegment::TYPE_PROMO_CODE) {
                $discountType = $segment['discount_type'] ?? '';
                if (!in_array($discountType, ['percentage', 'flat'], true)) {
                    return 'spin_wheel_discount_type_required';
                }
                if ($discountType === 'percentage') {
                    $value = (float) ($segment['discount_value'] ?? 0);
                    if ($value <= 0 || $value > 100) {
                        return 'spin_wheel_invalid_percentage';
                    }
                }
            }
        }

        if (abs($sum - 100) > 0.01) {
            return 'spin_wheel_chances_must_total_100';
        }

        return null;
    }

    private function applyFields(SpinWheelCampaign $campaign, Request $request): void
    {
        $campaign->name = $request->input('name');
        $campaign->code_prefix = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', (string) $request->input('code_prefix')) ?: 'SPIN');
        $campaign->status = (int) $request->input('status', 0);
        $campaign->is_scheduled = (int) $request->input('is_scheduled', 0);
        $campaign->start_date = $this->toDateTime($request->input('start_date'));
        $campaign->end_date = $this->toDateTime($request->input('end_date'));
        $campaign->spins_per_day = max(1, (int) $request->input('spins_per_day', 1));
        $campaign->max_spins_per_user = max(0, (int) $request->input('max_spins_per_user', 0));
        $campaign->min_delivered_orders = max(0, (int) $request->input('min_delivered_orders', 0));
        $campaign->theme = $this->arrayField($request, 'theme') ?: null;
    }

    private function saveCampaignTranslations(SpinWheelCampaign $campaign, Request $request): void
    {
        foreach ($this->arrayField($request, 'translations') as $translation) {
            if (empty($translation['language_id'])) {
                continue;
            }
            $campaign->saveTranslation((int) $translation['language_id'], [
                'name'        => $translation['name'] ?? '',
            ]);
        }
    }

    /**
     * Replace the wedges.
     *
     * Rows the form still knows about keep their id — and therefore their wins_count, so
     * a winner limit already partly used is not silently reset by an unrelated edit.
     */
    private function saveSegments(SpinWheelCampaign $campaign, Request $request, array $segments): void
    {
        $keptIds = [];

        foreach (array_values($segments) as $index => $row) {
            $id = (int) ($row['id'] ?? 0);
            $segment = $id
                ? SpinWheelSegment::where('spin_wheel_campaign_id', $campaign->id)->find($id)
                : null;
            $segment = $segment ?: new SpinWheelSegment(['spin_wheel_campaign_id' => $campaign->id]);

            $type = $row['type'];
            $segment->spin_wheel_campaign_id = $campaign->id;
            $segment->label = $row['label'] ?? '';
            $segment->type = $type;
            $segment->win_chance = round((float) ($row['win_chance'] ?? 0), 2);
            $segment->winner_limit = max(0, (int) ($row['winner_limit'] ?? 0));
            $segment->color = $row['color'] ?? null;
            $segment->text_color = $row['text_color'] ?? null;
            $segment->display_mode = in_array($row['display_mode'] ?? '', ['name', 'icon', 'both'], true)
                ? $row['display_mode'] : 'both';
            $segment->sort_order = (int) ($row['sort_order'] ?? $index);
            $segment->status = (int) ($row['status'] ?? 1);

            // Reward config only means something for the paying types.
            $segment->discount_type = $type === SpinWheelSegment::TYPE_PROMO_CODE ? ($row['discount_type'] ?? null) : null;
            $segment->discount_apply_type = $type === SpinWheelSegment::TYPE_PROMO_CODE
                && in_array($row['discount_apply_type'] ?? '', ['instant', 'wallet'], true)
                ? $row['discount_apply_type'] : 'instant';
            $segment->discount_value = $type === SpinWheelSegment::TYPE_PROMO_CODE ? (float) ($row['discount_value'] ?? 0) : 0;
            $segment->validity_days = in_array($type, [SpinWheelSegment::TYPE_PROMO_CODE, SpinWheelSegment::TYPE_FREE_DELIVERY], true)
                ? max(1, (int) ($row['validity_days'] ?? 7)) : 7;
            $applicability = $row['applicability'] ?? 'all';
            $segment->applicability = in_array($applicability, ['all', 'categories', 'brands'], true) ? $applicability : 'all';
            // Ids travel with the applicability: a restriction with no ids blocks the
            // coupon outright when it is redeemed.
            $segment->applicability_ids = $segment->applicability === 'all' ? null : ($row['applicability_ids'] ?? null);

            $icon = $request->file("segment_icons.$index");
            if ($icon) {
                $segment->icon = CommonHelper::uploadFile($icon, null, 'spin_wheel/segments', $segment->icon);
            } elseif (array_key_exists('icon', $row)) {
                // The panel uploads on pick and sends back the stored path, so a changed
                // or cleared value means the old file is now orphaned.
                $path = trim((string) $row['icon']) ?: null;
                if ($segment->icon && $segment->icon !== $path) {
                    CommonHelper::deleteFile($segment->icon);
                }
                $segment->icon = $path;
            }

            $segment->save();
            $keptIds[] = $segment->id;

            foreach ($row['translations'] ?? [] as $translation) {
                if (!empty($translation['language_id'])) {
                    $segment->saveTranslation((int) $translation['language_id'], ['label' => $translation['label'] ?? '']);
                }
            }

            $this->saveSegmentAmounts($segment, $row['amounts'] ?? []);
        }

        // Wedges the form dropped.
        $removed = SpinWheelSegment::where('spin_wheel_campaign_id', $campaign->id)
            ->whereNotIn('id', $keptIds ?: [0])
            ->pluck('id');
        if ($removed->isNotEmpty()) {
            SpinWheelSegmentAmount::whereIn('spin_wheel_segment_id', $removed)->delete();
            DB::table('spin_wheel_segment_translations')->whereIn('spin_wheel_segment_id', $removed)->delete();
            SpinWheelSegment::whereIn('id', $removed)->delete();
        }
    }

    /** Per-country prize money. A country left blank means "not offered there". */
    private function saveSegmentAmounts(SpinWheelSegment $segment, array $amounts): void
    {
        $keptCountries = [];

        foreach ($amounts as $amount) {
            $countryId = (int) ($amount['country_id'] ?? 0);
            if (!$countryId) {
                continue;
            }
            $value = (float) ($amount['amount'] ?? 0);
            $minOrder = (float) ($amount['minimum_order_amount'] ?? 0);
            $maxDiscount = (float) ($amount['max_discount_amount'] ?? 0);

            // Nothing filled in at all: drop the row so the segment is simply not
            // offered in that country.
            if ($value <= 0 && $minOrder <= 0 && $maxDiscount <= 0) {
                continue;
            }

            SpinWheelSegmentAmount::updateOrCreate(
                ['spin_wheel_segment_id' => $segment->id, 'country_id' => $countryId],
                [
                    'amount'               => $value,
                    'max_discount_amount'  => $maxDiscount,
                    'minimum_order_amount' => $minOrder,
                ]
            );
            $keptCountries[] = $countryId;
        }

        SpinWheelSegmentAmount::where('spin_wheel_segment_id', $segment->id)
            ->whereNotIn('country_id', $keptCountries ?: [0])
            ->delete();
    }
}
