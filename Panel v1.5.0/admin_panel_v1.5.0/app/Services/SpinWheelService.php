<?php

namespace App\Services;

use App\Helpers\CommonHelper;
use App\Models\Order;
use App\Models\OrderStatusList;
use App\Models\PromoCode;
use App\Models\SpinWheelCampaign;
use App\Models\SpinWheelSegment;
use App\Models\SpinWheelSpin;
use App\Models\WalletTransaction;
use Carbon\Carbon;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * The spin wheel: what a customer may spin, what they win, and how the prize is issued.
 *
 * Everything a spin decides happens inside one transaction that locks the campaign row.
 * That single lock is the whole concurrency story: only one campaign is ever active, so
 * one row serialises every spin, and locking exactly one row in exactly one place makes
 * the lock-ordering deadlocks we hit on orders impossible. A spin is a rare action, so
 * the throughput cost is irrelevant.
 */
class SpinWheelService
{
    /** How many times to retry a generated coupon code before giving up. */
    private const CODE_ATTEMPTS = 10;

    /** The live campaign, or null when there is none to show. */
    public function activeCampaign(): ?SpinWheelCampaign
    {
        $campaign = SpinWheelCampaign::where('status', 1)
            ->orderByDesc('updated_at')
            ->orderByDesc('id')
            ->first();

        if (!$campaign || !$campaign->isWithinWindow()) {
            return null;
        }

        return $campaign;
    }

    /**
     * The wedges a customer in $countryId can actually win, with their resolved money.
     *
     * A segment is dropped when it is switched off, has given away its winner limit, or
     * has no amount configured for that country — a prize is worth different sums in
     * different markets, and paying a foreign amount would be worse than not offering it.
     * The chance freed by every dropped wedge goes to the no-luck segment, so the odds
     * still add up to 100 for the customer actually spinning.
     *
     * @return array<int, array{segment: SpinWheelSegment, chance: float, amount: float, max_discount: float, min_order: float}>
     */
    public function availableSegments(SpinWheelCampaign $campaign, ?int $countryId): array
    {
        $segments = $campaign->segments()->with('amounts')->get();
        $available = [];
        $dropped = 0.0;
        $noLuckKey = null;

        foreach ($segments as $segment) {
            $row = $segment->amountFor($countryId);
            $usable = (int) $segment->status === 1
                && $segment->hasWinnersLeft()
                && (!$segment->needsCountryAmount() || ($row && $row->amount > 0));

            if (!$usable) {
                $dropped += (float) $segment->win_chance;
                continue;
            }

            // The first live no-luck wedge is where dropped chance lands. There may be
            // several, or none — with none, pick() simply weighs what is left.
            if ($segment->type === SpinWheelSegment::TYPE_NO_LUCK && $noLuckKey === null) {
                $noLuckKey = count($available);
            }

            $isPercentage = $segment->type === SpinWheelSegment::TYPE_PROMO_CODE && $segment->discount_type === 'percentage';

            $available[] = [
                'segment'      => $segment,
                'chance'       => (float) $segment->win_chance,
                'amount'       => $isPercentage ? (float) $segment->discount_value : (float) ($row->amount ?? 0),
                'max_discount' => (float) ($row->max_discount_amount ?? 0),
                'min_order'    => (float) ($row->minimum_order_amount ?? 0),
            ];
        }

        if ($dropped > 0 && $noLuckKey !== null) {
            $available[$noLuckKey]['chance'] += $dropped;
        }

        return $available;
    }

    /**
     * How many spins this customer has left.
     *
     * "Today" is midnight in the CUSTOMER's country, the same rule promo codes use for
     * their day windows — a UTC boundary resets mid-evening for half the world.
     *
     * @return array{spins_per_day: int, used_today: int, remaining_today: int, max_spins_per_user: int, used_lifetime: int, remaining_lifetime: int|null, can_spin: bool, reason: string, next_spin_at: string|null}
     */
    public function quota(SpinWheelCampaign $campaign, int $userId, ?int $countryId): array
    {
        $timezone = CommonHelper::countryTimezone($countryId);
        $now = Carbon::now($timezone);

        $perDay = max(1, (int) $campaign->spins_per_day);
        $usedToday = SpinWheelSpin::where('spin_wheel_campaign_id', $campaign->id)
            ->where('user_id', $userId)
            ->where('spun_at', '>=', $now->copy()->startOfDay()->utc())
            ->count();
        $usedLifetime = SpinWheelSpin::where('spin_wheel_campaign_id', $campaign->id)
            ->where('user_id', $userId)
            ->count();

        $lifetimeCap = (int) $campaign->max_spins_per_user;
        $remainingToday = max(0, $perDay - $usedToday);
        $remainingLifetime = $lifetimeCap > 0 ? max(0, $lifetimeCap - $usedLifetime) : null;

        $reason = '';
        if ($lifetimeCap > 0 && $usedLifetime >= $lifetimeCap) {
            $reason = 'spin_wheel_no_spins_left';
        } elseif ($remainingToday < 1) {
            $reason = 'spin_wheel_daily_limit_reached';
        } elseif (!$this->hasEnoughOrders($campaign, $userId)) {
            $reason = 'spin_wheel_order_required';
        }

        // Only meaningful when today's allowance is what ran out.
        $nextSpinAt = ($reason === 'spin_wheel_daily_limit_reached')
            ? $now->copy()->addDay()->startOfDay()
            : null;

        return [
            'spins_per_day'      => $perDay,
            'used_today'         => $usedToday,
            'remaining_today'    => $remainingToday,
            'max_spins_per_user' => $lifetimeCap,
            'used_lifetime'      => $usedLifetime,
            'remaining_lifetime' => $remainingLifetime,
            'can_spin'           => $reason === '',
            'reason'             => $reason,
            'next_spin_at'       => $nextSpinAt?->toIso8601String(),
            'next_spin_in_seconds' => $nextSpinAt ? max(0, $now->diffInSeconds($nextSpinAt, false)) : null,
        ];
    }

    /**
     * Spin. Returns the result, or an error key when the customer may not spin.
     *
     * @return array{ok: bool, message: string, spin?: SpinWheelSpin, index?: int, reward?: array}
     */
    public function spin(SpinWheelCampaign $campaign, $user, $zone, ?string $requestToken = null): array
    {
        $countryId = $zone ? (int) ($zone->country_id ?? 0) : 0;
        if (!$countryId) {
            // Without a country there is no amount to pay and no country to scope a
            // coupon to — better to refuse than to hand out an unusable prize.
            return ['ok' => false, 'message' => 'spin_wheel_location_required'];
        }

        // A retried request (flaky network, double tap) must replay its own result
        // rather than win a second prize.
        if ($requestToken) {
            $existing = SpinWheelSpin::where('spin_wheel_campaign_id', $campaign->id)
                ->where('user_id', $user->id)
                ->where('request_token', $requestToken)
                ->first();
            if ($existing) {
                return $this->replay($campaign, $existing, $countryId);
            }
        }

        try {
            return DB::transaction(function () use ($campaign, $user, $zone, $countryId, $requestToken) {
                // The one and only lock.
                $campaign = SpinWheelCampaign::whereKey($campaign->id)->lockForUpdate()->first();
                if (!$campaign || (int) $campaign->status !== 1 || !$campaign->isWithinWindow()) {
                    return ['ok' => false, 'message' => 'spin_wheel_not_available'];
                }

                // Counted under the lock: outside it, two concurrent spins both read the
                // old count and both get through.
                $quota = $this->quota($campaign, (int) $user->id, $countryId);
                if (!$quota['can_spin']) {
                    return ['ok' => false, 'message' => $quota['reason'] ?: 'spin_wheel_not_available'];
                }

                $available = $this->availableSegments($campaign, $countryId);
                if (empty($available)) {
                    return ['ok' => false, 'message' => 'spin_wheel_not_available'];
                }

                // Claiming the wedge IS the winner-limit check: the conditional update
                // either takes the last slot or tells us it is gone. Losing that race sends
                // the spin to a no-luck wedge; with no no-luck on this wheel the exhausted
                // wedge is dropped and the draw is made again over what is left — the one
                // thing that must never happen is paying out past the limit.
                $index = null;
                $won = null;
                while (!empty($available)) {
                    $candidate = $this->pick($available);
                    if ($this->claim($available[$candidate]['segment'])) {
                        $index = $candidate;
                        $won = $available[$candidate];
                        break;
                    }
                    $noLuck = $this->noLuckIndex($available);
                    if ($noLuck !== null) {
                        $index = $noLuck;
                        $won = $available[$noLuck];
                        break;
                    }
                    // Keys are kept: the index handed back must still point into the
                    // same list the GET endpoint returned, or the app lands on the
                    // wrong wedge.
                    unset($available[$candidate]);
                }
                if ($won === null) {
                    return ['ok' => false, 'message' => 'spin_wheel_not_available'];
                }

                $spin = $this->record($campaign, $user, $zone, $countryId, $won, $requestToken);
                $reward = $this->issue($campaign, $won, $spin, $user, $countryId);

                return ['ok' => true, 'message' => 'spin_wheel_spun', 'spin' => $spin, 'index' => $index, 'reward' => $reward];
            }, 3);
        } catch (QueryException $e) {
            // Duplicate request_token: the sibling request already won. Replay it.
            if ($requestToken && (int) ($e->errorInfo[1] ?? 0) === 1062) {
                $existing = SpinWheelSpin::where('spin_wheel_campaign_id', $campaign->id)
                    ->where('user_id', $user->id)
                    ->where('request_token', $requestToken)
                    ->first();
                if ($existing) {
                    return $this->replay($campaign, $existing, $countryId);
                }
            }
            Log::error('spin failed: ' . $e->getMessage());

            return ['ok' => false, 'message' => 'something_went_wrong'];
        }
    }

    /**
     * Switch a campaign on and everything else off.
     *
     * Only one wheel may run at a time, so activation is a swap rather than a toggle —
     * otherwise the customer API has to guess which of two live campaigns is the real one.
     * Used by the admin save and by the scheduler.
     *
     * @return int how many other campaigns were switched off
     */
    public function activate(SpinWheelCampaign $campaign): int
    {
        return DB::transaction(function () use ($campaign) {
            $others = SpinWheelCampaign::where('id', '!=', $campaign->id)
                ->where('status', 1)
                ->update(['status' => 0]);

            $campaign->status = 1;
            // Its turn came, so it is no longer waiting for one.
            $campaign->is_scheduled = 0;
            $campaign->save();

            return $others;
        });
    }

    /**
     * Apply the campaign calendar. Run from the scheduler every minute.
     *
     * Two jobs: retire a campaign whose end time has passed, and promote the scheduled one
     * whose start date has arrived — activating it switches the outgoing one off, so the
     * admin can line up the next wheel and leave it alone.
     *
     * @return array{activated: ?int, expired: int}
     */
    public function applySchedule(): array
    {
        // Windows are stored in UTC, so the clock is UTC too — bound as a plain string so
        // nothing downstream can reinterpret it in another timezone.
        $now = Carbon::now('UTC')->toDateTimeString();

        // Past its end time: stop showing it.
        $expired = SpinWheelCampaign::where('status', 1)
            ->whereNotNull('end_date')
            ->where('end_date', '<', $now)
            ->update(['status' => 0]);

        // Due to start, scheduled by the admin, and not already over.
        $due = SpinWheelCampaign::where('status', 0)
            ->where('is_scheduled', 1)
            ->whereNotNull('start_date')
            ->where('start_date', '<=', $now)
            ->where(function ($q) use ($now) {
                $q->whereNull('end_date')->orWhere('end_date', '>=', $now);
            })
            ->orderBy('start_date')
            ->orderBy('id')
            ->first();

        $activated = null;
        if ($due) {
            $this->activate($due);
            $activated = (int) $due->id;
        }

        return ['activated' => $activated, 'expired' => (int) $expired];
    }

    // ------------------------------------------------------------------ picking

    /** Weighted random over win_chance. Chances are scaled to integers to keep it exact. */
    private function pick(array $available): int
    {
        $weights = [];
        $total = 0;
        foreach ($available as $i => $row) {
            $w = (int) round($row['chance'] * 100);
            $weights[$i] = max(0, $w);
            $total += $weights[$i];
        }

        if ($total <= 0) {
            // Keys may be sparse once exhausted wedges are dropped, so not a bare 0.
            return $this->noLuckIndex($available) ?? array_key_first($available);
        }

        $roll = random_int(1, $total);
        foreach ($weights as $i => $w) {
            $roll -= $w;
            if ($roll <= 0) {
                return $i;
            }
        }

        return array_key_last($weights);
    }

    private function noLuckIndex(array $available): ?int
    {
        foreach ($available as $i => $row) {
            if ($row['segment']->type === SpinWheelSegment::TYPE_NO_LUCK) {
                return $i;
            }
        }

        return null;
    }

    /** Take one of the segment's remaining wins, or report that they are gone. */
    private function claim(SpinWheelSegment $segment): bool
    {
        if ($segment->type === SpinWheelSegment::TYPE_NO_LUCK) {
            return true;
        }

        $claimed = SpinWheelSegment::whereKey($segment->id)
            ->where(function ($q) {
                $q->where('winner_limit', 0)->orWhereColumn('wins_count', '<', 'winner_limit');
            })
            ->increment('wins_count');

        return $claimed > 0;
    }

    private function hasEnoughOrders(SpinWheelCampaign $campaign, int $userId): bool
    {
        $required = (int) $campaign->min_delivered_orders;
        if ($required < 1) {
            return true;
        }

        // Delivered, not merely placed — an abandoned payment must not unlock the wheel.
        return Order::where('user_id', $userId)
            ->where('active_status', OrderStatusList::$delivered)
            ->count() >= $required;
    }

    // ----------------------------------------------------------------- issuing

    private function record(SpinWheelCampaign $campaign, $user, $zone, int $countryId, array $won, ?string $requestToken): SpinWheelSpin
    {
        $segment = $won['segment'];
        $isNoLuck = $segment->type === SpinWheelSegment::TYPE_NO_LUCK;
        $currency = CommonHelper::countryCurrency($zone?->country);

        return SpinWheelSpin::create([
            'spin_wheel_campaign_id' => $campaign->id,
            'spin_wheel_segment_id'  => $segment->id,
            'user_id'                => $user->id,
            'country_id'             => $countryId,
            'zone_id'                => $zone?->id,
            'result'                 => $isNoLuck ? 'no_luck' : 'win',
            'reward_type'            => $segment->type,
            'amount'                 => $isNoLuck ? 0 : $won['amount'],
            'currency'               => $currency['currency'],
            'currency_code'          => $currency['currency_code'],
            'request_token'          => $requestToken,
            'spun_at'                => now(),
        ]);
    }

    /** Hand over the prize and describe it for the response. */
    private function issue(SpinWheelCampaign $campaign, array $won, SpinWheelSpin $spin, $user, int $countryId): array
    {
        $segment = $won['segment'];

        return match ($segment->type) {
            SpinWheelSegment::TYPE_WALLET => $this->issueWalletReward($won, $spin, $user, $countryId),
            SpinWheelSegment::TYPE_PROMO_CODE,
            SpinWheelSegment::TYPE_FREE_DELIVERY => $this->issuePromoReward($campaign, $won, $spin, $user, $countryId),
            default => ['type' => SpinWheelSegment::TYPE_NO_LUCK],
        };
    }

    /**
     * Credit the customer's wallet for THIS country.
     *
     * Written by hand rather than through addWalletTransaction(), which only copies
     * country/currency off an Order — there is no order here, and a transaction with no
     * country lands in the wrong wallet's history.
     */
    private function issueWalletReward(array $won, SpinWheelSpin $spin, $user, int $countryId): array
    {
        $amount = round((float) $won['amount'], 2);
        if ($amount <= 0) {
            return ['type' => SpinWheelSegment::TYPE_NO_LUCK];
        }

        $meta = CommonHelper::rechargeWalletMeta($countryId, $user->id);

        $transaction = new WalletTransaction();
        $transaction->user_id       = $user->id;
        $transaction->type          = 'credit';
        $transaction->amount        = $amount;
        $transaction->txn_id        = null;
        $transaction->payment_type  = 'Spin Wheel';
        $transaction->message       = 'wallet_spin_wheel_reward';
        $transaction->status        = 1;
        $transaction->country_id    = $meta['country_id'];
        $transaction->currency      = $meta['currency'];
        $transaction->currency_code = $meta['currency_code'];
        $transaction->save();

        $balance = CommonHelper::addUserWalletBalance($amount, $user->id, $meta['country_id']);

        $spin->wallet_transaction_id = $transaction->id;
        $spin->save();

        return [
            'type'        => SpinWheelSegment::TYPE_WALLET,
            'amount'      => $amount,
            'new_balance' => $balance,
            'transaction' => $transaction,
        ];
    }

    /**
     * Issue a coupon that only this customer can use, in this country.
     *
     * Every gate in validatePromoCode() is set explicitly here, because a default would
     * quietly block the prize: the audience makes it exclusive, the country matches the
     * zone the spin happened in (the same source redemption reads), and the dates are
     * computed in that country's timezone so the code is not "not valid yet" for someone
     * east of the server.
     */
    private function issuePromoReward(SpinWheelCampaign $campaign, array $won, SpinWheelSpin $spin, $user, int $countryId): array
    {
        $segment = $won['segment'];
        $isFreeDelivery = $segment->type === SpinWheelSegment::TYPE_FREE_DELIVERY;

        $code = $this->generateCode($campaign->code_prefix ?: 'SPIN');
        if (!$code) {
            Log::error('spin wheel: could not generate a unique coupon code');

            return ['type' => SpinWheelSegment::TYPE_NO_LUCK];
        }

        $timezone = CommonHelper::countryTimezone($countryId);
        $today = Carbon::now($timezone);
        $days = max(1, (int) $segment->validity_days);

        $promo = new PromoCode();
        $promo->title = $segment->label ?: $code;
        $promo->promo_code = $code;
        $promo->discount_type = $isFreeDelivery ? 'free_delivery' : ($segment->discount_type ?: 'flat');
        $promo->discount = $isFreeDelivery ? 0 : round((float) $won['amount'], 2);
        // instant = off the bill now; wallet = cashback credited once the order is
        // delivered. Free delivery is always instant.
        $promo->discount_apply_type = (!$isFreeDelivery && $segment->discount_apply_type === 'wallet') ? 'wallet' : 'instant';
        $promo->max_discount_amount = $isFreeDelivery ? 0 : (float) $won['max_discount'];
        $promo->minimum_order_amount = (float) $won['min_order'];
        $promo->min_product_quantity = 0;
        $promo->applicability = $segment->applicability ?: 'all';
        // An applicability with no ids fails the coupon outright, so they travel together.
        $promo->applicability_ids = $segment->applicability === 'all' ? null : ($segment->applicability_ids ?: null);
        $promo->total_usage_limit = 1;
        $promo->per_user_usage_limit = 1;
        $promo->is_permanent = 0;
        $promo->start_date = $today->toDateString();
        $promo->end_date = $today->copy()->addDays($days)->toDateString();
        $promo->full_day_promotion = 1;
        // weekday_recurrence stays NULL — an empty value means "every day".
        $promo->audience_type = 'specific';
        $promo->audience_ids = [(int) $user->id];
        $promo->visibility = 'public';   // listed, but only to its audience
        $promo->platform = 'all';
        $promo->channel = 'both';
        $promo->country_ids = [$countryId];
        $promo->zone_ids = null;
        $promo->status = 1;
        $promo->source = 'spin_wheel';
        $promo->source_id = $segment->id;
        $promo->save();

        $spin->promo_code_id = $promo->id;
        $spin->save();

        return [
            'type'  => $segment->type,
            'promo' => $promo,
        ];
    }

    /** A code nobody else holds. The column is unique now, but check anyway and retry. */
    private function generateCode(string $prefix): ?string
    {
        $prefix = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $prefix) ?: 'SPIN');

        for ($i = 0; $i < self::CODE_ATTEMPTS; $i++) {
            $code = $prefix . strtoupper(Str::random(8));
            if (!PromoCode::where('promo_code', $code)->exists()) {
                return $code;
            }
        }

        return null;
    }

    // ----------------------------------------------------------------- replay

    /** Describe a spin that already happened, for a retried request. */
    private function replay(SpinWheelCampaign $campaign, SpinWheelSpin $spin, int $countryId): array
    {
        $available = $this->availableSegments($campaign, $countryId);
        $index = 0;
        foreach ($available as $i => $row) {
            if ((int) $row['segment']->id === (int) $spin->spin_wheel_segment_id) {
                $index = $i;
                break;
            }
        }

        $reward = ['type' => $spin->reward_type];
        if ($spin->reward_type === SpinWheelSegment::TYPE_WALLET) {
            $reward['amount'] = (float) $spin->amount;
            $reward['new_balance'] = CommonHelper::getUserWalletBalance($spin->user_id, $spin->country_id);
        } elseif ($spin->promo_code_id) {
            $reward['promo'] = PromoCode::find($spin->promo_code_id);
        }

        // Flagged so the caller does not announce a prize the customer was already told about.
        return ['ok' => true, 'message' => 'spin_wheel_spun', 'spin' => $spin, 'index' => $index, 'reward' => $reward, 'replayed' => true];
    }
}
