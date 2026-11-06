<?php

namespace App\Jobs;

use App\Helpers\CommonHelper;
use App\Models\Notification;
use App\Models\PromoCode;
use App\Models\SpinWheelSegment;
use App\Models\SpinWheelSpin;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Tells the winner what they won, off the request.
 *
 * The prize itself is granted inside the spin's transaction — this only announces it,
 * and announcing means mail, SMS and an HTTP round trip to FCM. Doing that inline made
 * the customer wait seconds for a wheel that had already stopped, so it moved here.
 * The spin row is the whole payload: everything else is read back from it, which also
 * means a retried job cannot announce a stale prize.
 */
class SendSpinWheelRewardNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $tries = 3;

    public $backoff = 30;

    public function __construct(private int $spinId)
    {
    }

    public function handle(): void
    {
        $spin = SpinWheelSpin::find($this->spinId);
        if (!$spin || $spin->result !== 'win') {
            return;
        }

        $user = User::find($spin->user_id);
        if (!$user) {
            return;
        }

        $promo = $spin->promo_code_id ? PromoCode::find($spin->promo_code_id) : null;
        $segment = $spin->spin_wheel_segment_id ? SpinWheelSegment::find($spin->spin_wheel_segment_id) : null;

        try {
            if ($spin->reward_type === SpinWheelSegment::TYPE_WALLET) {
                // Existing wallet event: it already renders amount, balance and currency.
                CommonHelper::sendWalletNotification(
                    $user,
                    (float) $spin->amount,
                    'wallet_admin_credit_customer',
                    'customer_wallet_admin_credit',
                    ['message' => __('wallet_spin_wheel_reward')],
                    (int) $spin->country_id,
                    $spin->wallet_transaction_id
                );
            } elseif ($promo) {
                // Audience-aware: a coupon aimed at one customer reaches only them.
                CommonHelper::sendPromoCodeNotification($promo);
            } else {
                return;
            }
        } catch (\Throwable $e) {
            Log::error('spin wheel notify failed: ' . $e->getMessage());
        }

        try {
            $notification = new Notification();
            $notification->type = 'user';
            $notification->type_id = (int) $user->id;
            $notification->type_link = '';
            $notification->title = __('spin_wheel');
            $notification->message = $this->message($spin, $promo);
            $notification->image = $segment && $segment->icon ? $segment->icon : '';
            $notification->date_sent = now();
            $notification->save();
        } catch (\Throwable $e) {
            Log::error('spin wheel in-app notification failed: ' . $e->getMessage());
        }
    }

    /** The same wording the spin response returned, rebuilt from the stored row. */
    private function message(SpinWheelSpin $spin, ?PromoCode $promo): string
    {
        return match ($spin->reward_type) {
            SpinWheelSegment::TYPE_WALLET => __('spin_wheel_wallet_won', [
                'amount' => ($spin->currency ?? '') . round((float) $spin->amount, 2),
            ]),
            SpinWheelSegment::TYPE_PROMO_CODE => __('spin_wheel_coupon_won', [
                'code' => $promo->promo_code ?? '',
            ]),
            SpinWheelSegment::TYPE_FREE_DELIVERY => __('spin_wheel_free_delivery_won', [
                'code' => $promo->promo_code ?? '',
            ]),
            default => __('no_luck'),
        };
    }
}
