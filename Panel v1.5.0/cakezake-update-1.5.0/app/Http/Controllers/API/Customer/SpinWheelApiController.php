<?php

namespace App\Http\Controllers\API\Customer;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use Carbon\Carbon;
use App\Models\Setting;
use App\Models\SpinWheelCampaign;
use App\Models\SpinWheelSegment;
use App\Jobs\SendSpinWheelRewardNotification;
use App\Models\SpinWheelSpin;
use App\Services\SpinWheelService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * The customer side of the spin wheel: what the wheel looks like, and one spin.
 *
 * Both endpoints resolve the customer's country from their delivery location, because
 * every prize is country-scoped — the wallet the credit lands in, the coupon's country,
 * and even which wedges exist at all. A wedge with no amount for that country is not
 * offered there, so the wheel is built per country and both endpoints must build it the
 * same way: the app animates to an array index, and a different ordering here than in
 * the spin response is the classic "landed on the wrong wedge" bug.
 */
class SpinWheelApiController extends Controller
{
    public function __construct(private SpinWheelService $service)
    {
    }

    /**
     * The wheel to draw, plus how many spins the customer has left.
     *
     * Public: a guest sees the wheel — that is the point of the teaser — but with
     * requires_login set, and no quota, because there is nobody to count spins for.
     * Win chances and winner limits never leave the server.
     */
    public function index(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude'  => 'required',
            'longitude' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $user = $request->user('api-customers');
        $campaign = $this->service->activeCampaign();
        $zone = CommonHelper::getDeliverableCity(
            $request->input('latitude'),
            $request->input('longitude'),
            strtolower(trim((string) $request->header('channel'))) ?: null
        );
        $countryId = $zone ? (int) $zone->country_id : 0;
        $currency = CommonHelper::countryCurrency($zone?->country);

        if (!$campaign) {
            return CommonHelper::responseWithData($this->unavailable('spin_wheel_not_available', $currency), false);
        }
        if (!$countryId) {
            // No country means no prize table, so there is no honest wheel to show.
            return CommonHelper::responseWithData($this->unavailable('spin_wheel_location_required', $currency), false);
        }

        $available = $this->service->availableSegments($campaign, $countryId);
        if (empty($available)) {
            return CommonHelper::responseWithData($this->unavailable('spin_wheel_not_available', $currency), false);
        }

        $spins = $user
            ? $this->quotaWithLabel($this->service->quota($campaign, (int) $user->id, $countryId), $zone->country)
            : $this->quotaWithLabel($this->guestQuota($campaign), $zone->country);

        return CommonHelper::responseWithData([
            'is_available'    => 1,
            'requires_login'  => $user ? 0 : 1,
            'message'         => '',
            'campaign'        => $this->campaignPayload($campaign),
            'segments'        => $this->segmentsPayload($available),
            'spins'           => $spins,
            'currency'        => $currency['currency'],
            'currency_code'   => $currency['currency_code'],
            'decimal_point'   => $currency['decimal_point'],
        ], false);
    }

    /**
     * Spin once.
     *
     * request_token is the app's own idempotency key: a retried request (flaky network,
     * a double tap) replays the same result instead of winning a second prize.
     */
    public function spin(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'latitude'      => 'required',
            'longitude'     => 'required',
            'request_token' => 'nullable|string|max:64',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $user = $request->user('api-customers');
        $campaign = $this->service->activeCampaign();
        if (!$campaign) {
            return CommonHelper::responseError('spin_wheel_not_available');
        }

        $zone = CommonHelper::getDeliverableCity(
            $request->input('latitude'),
            $request->input('longitude'),
            strtolower(trim((string) $request->header('channel'))) ?: null
        );
        if (!$zone || !$zone->country_id) {
            return CommonHelper::responseError('spin_wheel_location_required');
        }

        $result = $this->service->spin($campaign, $user, $zone, $request->input('request_token'));
        if (!$result['ok']) {
            return CommonHelper::responseError($result['message']);
        }

        $spin = $result['spin'];
        $segment = SpinWheelSegment::find($spin->spin_wheel_segment_id);
        $reward = $result['reward'] ?? ['type' => SpinWheelSegment::TYPE_NO_LUCK];
        $currency = CommonHelper::countryCurrency($zone->country);

        // Prizes are announced only once — a replayed request must not notify again.
        // Announcing means mail + SMS + a call out to FCM, so it happens off the
        // request: the wheel has already stopped, the customer should not wait for it.
        if (empty($result['replayed']) && $spin->result === 'win') {
            $job = new SendSpinWheelRewardNotification((int) $spin->id);
            // With a worker running this queues; on a sync install it still leaves the
            // request, firing once the response has been sent.
            config('queue.default') === 'sync'
                ? dispatch($job)->afterResponse()
                : dispatch($job);
        }

        $data = [
            'segment_id'    => (int) $spin->spin_wheel_segment_id,
            'segment_index' => (int) ($result['index'] ?? 0),
            'result'        => $spin->result,
            'reward_type'   => $spin->reward_type,
            'label'         => $segment ? $segment->label : '',
            'title'         => $this->rewardTitle($spin->reward_type),
            'message'       => $this->rewardMessage($spin->reward_type, $reward, $currency['currency']),
            'promo_code'    => null,
            'wallet'        => null,
            'reward'        => $spin->result === 'win' ? $this->rewardRowFor((int) $spin->id) : null,
            'spins'         => $this->quotaWithLabel(
                $this->service->quota($campaign->fresh(), (int) $user->id, (int) $zone->country_id),
                $zone->country
            ),
            'currency'      => $currency['currency'],
            'currency_code' => $currency['currency_code'],
            'decimal_point' => $currency['decimal_point'],
        ];

        if (!empty($reward['promo'])) {
            $promo = $reward['promo'];
            $data['promo_code'] = [
                'id'                   => $promo->id,
                'promo_code'           => $promo->promo_code,
                'title'                => $promo->title,
                'discount_type'        => $promo->discount_type,
                'discount_apply_type'  => $promo->discount_apply_type,
                'discount'             => (float) $promo->discount,
                'max_discount_amount'  => (float) $promo->max_discount_amount,
                'minimum_order_amount' => (float) $promo->minimum_order_amount,
                'start_date'           => (string) $promo->start_date,
                'end_date'             => (string) $promo->end_date,
                'start_date_label'     => CommonHelper::formatDateForCountry($promo->start_date, (int) $zone->country_id),
                'end_date_label'       => CommonHelper::formatDateForCountry($promo->end_date, (int) $zone->country_id),
            ];
        }
        if (($reward['type'] ?? '') === SpinWheelSegment::TYPE_WALLET) {
            $data['wallet'] = [
                'amount'      => (float) ($reward['amount'] ?? 0),
                'new_balance' => (float) ($reward['new_balance'] ?? 0),
                'currency'    => $currency['currency'],
            ];
        }

        return CommonHelper::responseSuccessWithData('spin_wheel_spun', $data);
    }

    /**
     * What this customer has won and can still use.
     *
     * Wallet credits are listed as history — the money is already in the wallet — while a
     * coupon is only a reward while it can still be redeemed, so expired, deactivated
     * and already-used codes drop out rather than sitting in the list as dead entries.
     * "Expired" is judged in the timezone of the country the coupon was issued for, the
     * same clock redemption uses.
     */
    public function rewards(Request $request)
    {
        $user = $request->user('api-customers');
        $limit = (int) $request->input('limit', 20);
        $limit = $limit > 0 ? min($limit, 100) : 20;
        $offset = max(0, (int) $request->input('offset', 0));

        $query = SpinWheelSpin::from('spin_wheel_spins as s')
            ->leftJoin('spin_wheel_campaigns as c', 'c.id', '=', 's.spin_wheel_campaign_id')
            ->leftJoin('spin_wheel_segments as g', 'g.id', '=', 's.spin_wheel_segment_id')
            ->leftJoin('promo_codes as p', 'p.id', '=', 's.promo_code_id')
            ->where('s.user_id', $user->id)
            // Only wins: a no-luck spin is not a reward.
            ->where('s.result', 'win');

        if ($request->filled('reward_type')) {
            $query->where('s.reward_type', $request->input('reward_type'));
        }

        // A coupon is country-scoped, so when the app sends a location, show only the
        // ones usable where the customer actually is.
        if ($request->filled('latitude') && $request->filled('longitude')) {
            $zone = CommonHelper::getDeliverableCity(
                $request->input('latitude'),
                $request->input('longitude'),
                strtolower(trim((string) $request->header('channel'))) ?: null
            );
            if ($zone && $zone->country_id) {
                $query->where('s.country_id', (int) $zone->country_id);
            }
        }

        // Dead coupons are filtered in SQL on everything that is exact: status, usage
        // and a one-day-wide date bound. The bound is deliberately loose because
        // end_date belongs to the coupon's own country — the exact call happens below,
        // once each row's country is known.
        $query->where(function ($outer) {
            $outer->whereNull('s.promo_code_id')->orWhere('s.promo_code_id', 0)
                ->orWhere(function ($valid) {
                    $valid->where('p.status', 1)
                        ->where(function ($dates) {
                            $dates->whereNull('p.end_date')
                                ->orWhere('p.end_date', '>=', now()->subDay()->toDateString());
                        })
                        // Single-use by design; 0 means no ceiling.
                        ->whereRaw('(p.total_usage_limit = 0 OR (SELECT COUNT(*) FROM orders o WHERE o.promo_code_id = p.id) < p.total_usage_limit)');
                });
        });

        $total = (clone $query)->count('s.id');

        $rows = $query->select(self::REWARD_COLUMNS)
            ->orderByDesc('s.id')
            ->skip($offset)
            ->take($limit)
            ->get();

        $rewards = [];
        foreach ($rows as $row) {
            // The exact expiry call, in the coupon's own country.
            if ($row->promo_code && $row->promo_end_date) {
                $today = Carbon::now(CommonHelper::countryTimezone((int) $row->country_id))->toDateString();
                if ($today > (string) $row->promo_end_date) {
                    $total = max(0, $total - 1);
                    continue;
                }
            }

            $rewards[] = $this->rewardRow($row);
        }

        return CommonHelper::responseWithData([
            'rewards' => $rewards,
            'summary' => $this->rewardsSummary($user->id),
        ], $total);
    }

    // ---------------------------------------------------------------- internals

    /** Columns rewardRow() needs, off the spin + campaign + segment + promo join. */
    private const REWARD_COLUMNS = [
        's.*',
        'c.name as campaign_name',
        'g.label as segment_label',
        'g.display_mode',
        'g.icon as segment_icon',
        'p.promo_code',
        'p.discount_type',
        'p.discount_apply_type',
        'p.discount',
        'p.max_discount_amount',
        'p.minimum_order_amount',
        'p.start_date as promo_start_date',
        'p.end_date as promo_end_date',
    ];

    /** The rewards-list row for one spin (the same joins the list uses). */
    private function rewardRowFor(int $spinId): ?array
    {
        $row = SpinWheelSpin::from('spin_wheel_spins as s')
            ->leftJoin('spin_wheel_campaigns as c', 'c.id', '=', 's.spin_wheel_campaign_id')
            ->leftJoin('spin_wheel_segments as g', 'g.id', '=', 's.spin_wheel_segment_id')
            ->leftJoin('promo_codes as p', 'p.id', '=', 's.promo_code_id')
            ->where('s.id', $spinId)
            ->select(self::REWARD_COLUMNS)
            ->first();

        return $row ? $this->rewardRow($row) : null;
    }

    /** One row of the rewards list, shaped the same whatever the prize was. */
    private function rewardRow($row): array
    {
        $countryId = (int) $row->country_id;

        $reward = [
            'id'            => (int) $row->id,
            'reward_type'   => $row->reward_type,
            'label'         => $row->segment_label ?: '',
            'campaign_name' => $row->campaign_name ?: '',
            'icon_url'      => CommonHelper::imageUrlIfSet($row->segment_icon),
            'amount'        => (float) $row->amount,
            'currency'      => $row->currency ?: '',
            'currency_code' => $row->currency_code ?: '',
            'won_at'        => (string) $row->spun_at,
            'won_at_label'  => CommonHelper::formatDateForCountry($row->spun_at, $countryId),
            'promo_code'    => null,
        ];

        if ($row->promo_code) {
            $reward['promo_code'] = [
                'promo_code'           => $row->promo_code,
                'discount_type'        => $row->discount_type,
                'discount_apply_type'  => $row->discount_apply_type ?: 'instant',
                'discount'             => (float) $row->discount,
                'max_discount_amount'  => (float) $row->max_discount_amount,
                'minimum_order_amount' => (float) $row->minimum_order_amount,
                'start_date'           => (string) $row->promo_start_date,
                'end_date'             => (string) $row->promo_end_date,
                'end_date_label'       => CommonHelper::formatDateForCountry($row->promo_end_date, $countryId),
            ];
        }

        return $reward;
    }

    /** Totals across every spin this customer has ever made, filters aside. */
    private function rewardsSummary(int $userId): array
    {
        $row = SpinWheelSpin::where('user_id', $userId)
            ->selectRaw(
                'COUNT(*) as spins,
                 SUM(result = "win") as wins,
                 SUM(CASE WHEN reward_type = "wallet" THEN amount ELSE 0 END) as wallet_won,
                 SUM(reward_type = "promo_code") as coupons_won,
                 SUM(reward_type = "free_delivery") as free_deliveries_won'
            )
            ->first();

        return [
            'spins'                => (int) ($row->spins ?? 0),
            'wins'                 => (int) ($row->wins ?? 0),
            'wallet_won'           => round((float) ($row->wallet_won ?? 0), 2),
            'coupons_won'          => (int) ($row->coupons_won ?? 0),
            'free_deliveries_won'  => (int) ($row->free_deliveries_won ?? 0),
        ];
    }

    /**
     * The quota block plus a printable next_spin_at.
     *
     * next_spin_at stays ISO-8601 with the country's offset — that is what a countdown
     * needs — and the label beside it uses the country's own date and time formats, so
     * the app never has to guess how this market writes a date.
     */
    private function quotaWithLabel(?array $quota, $country): ?array
    {
        if (!$quota) {
            return $quota;
        }

        $quota['reason_key'] = $quota['reason'];
        $quota['reason'] = $quota['reason'] ? __($quota['reason']) : '';
        $quota['next_spin_at_label'] = $quota['next_spin_at']
            ? CommonHelper::formatDateTimeForCountry(
                \Carbon\Carbon::parse($quota['next_spin_at'])->utc(),
                $country->timezone ?? null,
                $country->date_format ?? null,
                $country->time_format ?? null
            )
            : '';

        return $quota;
    }

    /** The shape the app gets when there is nothing to spin, so it can render one screen. */
    private function unavailable(string $message, array $currency): array
    {
        return [
            'is_available'   => 0,
            'requires_login' => 0,
            'message'        => __($message),
            'campaign'       => null,
            'segments'       => [],
            'spins'          => null,
            'currency'       => $currency['currency'],
            'currency_code'  => $currency['currency_code'],
            'decimal_point'  => $currency['decimal_point'],
        ];
    }

    private function campaignPayload(SpinWheelCampaign $campaign): array
    {
        // Theme as the app draws it: one background colour (gradients are shaded from
        // it), pointer / rim / button colours, the button label and the hub icon.
        $theme = is_array($campaign->theme) ? $campaign->theme : [];
        // No base colour saved -> the admin theme colour from settings.
        $appColor = (string) (Setting::get_value('admin_theme_color') ?: '');
        if (!preg_match('/^#[0-9a-fA-F]{6}$/', $appColor)) {
            $appColor = '#FE3C5E';
        }
        $theme = [
            'bg_color'      => $theme['bg_color'] ?? $appColor,
            'title_color'   => $theme['title_color'] ?? '#b9f2c3',
            'title_color_2' => $theme['title_color_2'] ?? ($theme['title_color'] ?? '#b9f2c3'),
            'pointer_color' => $theme['pointer_color'] ?? '#f4b400',
            'border_color'  => $theme['border_color'] ?? '#f4b400',
            // Borders between the wedges.
            'line_color'    => $theme['line_color'] ?? '#0a5e18',
            'button_color'  => $theme['button_color'] ?? '#f4b400',
            'button_text'   => $theme['button_text'] ?? 'SPIN',
            'button_text_color' => $theme['button_text_color'] ?? '#5a3a00',
            // Stand lamps: the lit one (bottom at rest, chasing while spinning); the
            // others sit dark in the base colour.
            'light_color'   => $theme['light_color'] ?? '#ffffff',
            'segment_fill'  => $theme['segment_fill'] ?? 'flat',
            'hub_icon_url'  => CommonHelper::imageUrlIfSet($theme['hub_icon'] ?? ''),
        ];

        return [
            'id'    => $campaign->id,
            'name'  => $campaign->name,
            'theme' => $theme,
        ];
    }

    /** Wedges as the app draws them — labels, colours, icons. No odds, no amounts. */
    private function segmentsPayload(array $available): array
    {
        $out = [];
        foreach ($available as $index => $row) {
            $segment = $row['segment'];
            $out[] = [
                'index'        => $index,
                'id'           => $segment->id,
                'label'        => $segment->label,
                'display_mode' => $segment->display_mode ?: 'both',
                'color'        => $segment->color ?: '',
                'text_color'   => $segment->text_color ?: '',
                'icon_url'     => $segment->icon_url,
            ];
        }

        return $out;
    }

    /** A guest is shown the rules, not a count — there is no account to count against. */
    private function guestQuota(SpinWheelCampaign $campaign): array
    {
        return [
            'spins_per_day'      => max(1, (int) $campaign->spins_per_day),
            'used_today'         => 0,
            'remaining_today'    => 0,
            'max_spins_per_user' => (int) $campaign->max_spins_per_user,
            'used_lifetime'      => 0,
            'remaining_lifetime' => null,
            'can_spin'           => false,
            'reason'             => 'login_to_continue',
            'next_spin_at'       => null,
        ];
    }

    private function rewardTitle(string $rewardType): string
    {
        return match ($rewardType) {
            SpinWheelSegment::TYPE_WALLET => __('congratulations'),
            SpinWheelSegment::TYPE_PROMO_CODE,
            SpinWheelSegment::TYPE_FREE_DELIVERY => __('congratulations'),
            default => __('no_luck'),
        };
    }

    private function rewardMessage(string $rewardType, array $reward, ?string $currency): string
    {
        return match ($rewardType) {
            SpinWheelSegment::TYPE_WALLET => __('spin_wheel_wallet_won', [
                'amount' => ($currency ?? '') . round((float) ($reward['amount'] ?? 0), 2),
            ]),
            SpinWheelSegment::TYPE_PROMO_CODE => __('spin_wheel_coupon_won', [
                'code' => $reward['promo']->promo_code ?? '',
            ]),
            SpinWheelSegment::TYPE_FREE_DELIVERY => __('spin_wheel_free_delivery_won', [
                'code' => $reward['promo']->promo_code ?? '',
            ]),
            default => __('no_luck'),
        };
    }

}
