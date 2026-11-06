<?php

namespace App\Jobs;

use App\Models\Order;
use App\Models\User;
use App\Helpers\CommonHelper;
use App\Models\OrderStatusList;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ProcessReferralBonusAfterReturnPeriod implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $orderId;

    public function __construct(int $orderId)
    {
        $this->orderId = $orderId;
    }

    public function handle()
    {
        $order = Order::with('user')->find($this->orderId);
        if (!$order) {
            return;
        }
        $user = $order->user;
        if (!$user || !$user->friends_code) {
            return;
        }

        // Refer-&-earn is country-wise, resolved from the ORDER's country: the order
        // qualifies by that country's threshold, the credit is in that country's
        // currency, and it is paid into the referrer's wallet FOR THAT COUNTRY.
        $orderCountry = CommonHelper::resolveOrderCountry($order);
        $referralCountryId = $order->country_id ?: ($orderCountry->id ?? null);
        $referralMinOrderAmount = (float) ($orderCountry->referral_min_order_amount ?? 0);
        $referralCredit = (float) ($orderCountry->referral_credit_first_order ?? 0);
        $referredCredit = (float) ($orderCountry->referral_credit_referred ?? 0);

        if ($order->final_total < $referralMinOrderAmount) {
            return;
        }

        // Check if this is the user's FIRST delivered order
        $deliveredOrdersCount = Order::where('user_id', $user->id)
            ->where('active_status', OrderStatusList::$delivered)
            ->where('id', '!=', $order->id)
            ->count();

        if ($deliveredOrdersCount > 0) {
            return;
        }

        $referrer = User::where('referral_code', $user->friends_code)->first();

        if ($referrer && !CommonHelper::referralLimitReached($referrer->id, $orderCountry)) {
            // Referrer bonus → referrer's wallet for the ORDER's country.
            if ($referralCredit > 0) {
                $current = (float) CommonHelper::getUserWalletBalance($referrer->id, $referralCountryId);
                CommonHelper::updateUserWalletBalance($current + $referralCredit, $referrer->id, $referralCountryId);
                CommonHelper::addWalletTransaction($order->id, 0, $referrer->id, 'credit', $referralCredit, 'wallet_refer_earn_first_order_bonus');
                CommonHelper::sendWalletNotification($referrer, $referralCredit, 'wallet_referral_bonus_customer', 'customer_wallet_referral_bonus', [], $referralCountryId);
            }
            // Referred-user bonus → the new user's wallet for the same country.
            if ($referredCredit > 0) {
                $currentReferred = (float) CommonHelper::getUserWalletBalance($user->id, $referralCountryId);
                CommonHelper::updateUserWalletBalance($currentReferred + $referredCredit, $user->id, $referralCountryId);
                CommonHelper::addWalletTransaction($order->id, 0, $user->id, 'credit', $referredCredit, 'wallet_refer_earn_referred_user_bonus');
                CommonHelper::sendWalletNotification($user, $referredCredit, 'wallet_referral_bonus_customer', 'customer_wallet_referral_bonus', [], $referralCountryId);
            }
        }
    }
}

