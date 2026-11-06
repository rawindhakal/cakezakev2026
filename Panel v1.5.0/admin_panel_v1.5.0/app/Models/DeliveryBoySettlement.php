<?php

namespace App\Models;

use App\Helpers\CommonHelper;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Earnings wallet ledger for delivery boys (formerly FundTransfer / fund_transfers).
 * `delivery_boys.balance` is the authoritative running balance; every row snapshots
 * opening/closing balance. Credits = earnings (delivery bonus, return commission);
 * debits = payouts (withdrawals, manual debits, wallet-mode cash settlements).
 */
class DeliveryBoySettlement extends Model
{
    use HasFactory;

    public static $typeDebit = "debit";
    public static $typeCredit = "credit";

    protected $table = 'delivery_boy_settlements';

    protected $guarded = [];

    /**
     * Wallet transactions belong to a delivery boy, so snapshot the country + currency
     * (symbol + ISO code) from the boy's country on create — its currency can change
     * later. Only fills values not already set explicitly.
     */
    protected static function booted()
    {
        static::creating(function ($transaction) {
            if (!empty($transaction->country_id) && !empty($transaction->currency) && !empty($transaction->currency_code)) {
                return;
            }
            if (empty($transaction->delivery_boy_id)) {
                return;
            }
            $country = optional(DeliveryBoy::with('country')->find($transaction->delivery_boy_id))->country;
            if ($country) {
                $transaction->country_id = $transaction->country_id ?: $country->id;
                $transaction->currency = $transaction->currency ?: $country->currency;
                $transaction->currency_code = $transaction->currency_code ?: $country->currency_code;
            }
        });
    }

    /**
     * Classify a ledger row for the Settlement History screens. Legacy rows with
     * free-text messages fall back to plain credit/debit.
     */
    public static function entryType($type, $message)
    {
        $message = (string) $message;
        if ($type === self::$typeCredit) {
            return $message === 'return_commission' ? 'return_commission' : 'delivery_commission';
        }
        if (str_starts_with($message, 'withdrawal_request_approved')) {
            return 'withdrawal';
        }
        if ($message === 'cash_collection_settled_against_wallet') {
            return 'cash_deposit_wallet';
        }
        return 'debit';
    }

    /**
     * Unified settlement history for delivery boy money: wallet ledger rows
     * (commission credits, withdrawal + wallet-settlement debits) merged with
     * cash-mode deposit rows from the cash ledger (those never touch the wallet,
     * so they carry no opening/closing balance). Newest first.
     */
    public static function settlementHistory($deliveryBoyId = null, $countryId = 0)
    {
        $wallet = self::query()
            ->select('delivery_boys.name', 'delivery_boys.mobile', 'delivery_boys.country_code as boy_country_code', 'delivery_boy_settlements.*')
            ->leftJoin('delivery_boys', 'delivery_boy_settlements.delivery_boy_id', '=', 'delivery_boys.id')
            ->when($deliveryBoyId, fn ($q) => $q->where('delivery_boy_settlements.delivery_boy_id', $deliveryBoyId))
            ->when($countryId, fn ($q) => $q->where('delivery_boys.country_id', $countryId))
            ->get()
            ->map(fn ($t) => [
                'id'              => 'W-' . $t->id,
                'delivery_boy_id' => $t->delivery_boy_id,
                'name'            => $t->name,
                'mobile'          => $t->mobile,
                'country_code'    => $t->boy_country_code,
                'entry_type'      => self::entryType($t->type, $t->message),
                'type'            => $t->type,
                'amount'          => (float) $t->amount,
                'opening_balance' => $t->opening_balance,
                'closing_balance' => $t->closing_balance,
                'currency'        => $t->currency,
                'message'         => CommonHelper::translateLedgerMessage($t->message),
                'created_at'      => $t->getRawOriginal('created_at'),
            ]);

        // Cash-mode deposits: recorded only in the cash ledger (wallet untouched);
        // wallet-mode deposits are already present above as their wallet debit.
        $cashDeposits = DeliveryBoyCashCollection::query()
            ->select('delivery_boys.name', 'delivery_boys.mobile', 'delivery_boys.country_code as boy_country_code', 'delivery_boy_cash_collections.*')
            ->leftJoin('delivery_boys', 'delivery_boy_cash_collections.delivery_boy_id', '=', 'delivery_boys.id')
            ->where('delivery_boy_cash_collections.type', DeliveryBoyCashCollection::$typeCashCollection)
            ->where(function ($q) {
                $q->where('delivery_boy_cash_collections.payment_mode', DeliveryBoyCashCollection::$modeCash)
                    ->orWhereNull('delivery_boy_cash_collections.payment_mode');
            })
            ->when($deliveryBoyId, fn ($q) => $q->where('delivery_boy_cash_collections.delivery_boy_id', $deliveryBoyId))
            ->when($countryId, fn ($q) => $q->where('delivery_boys.country_id', $countryId))
            ->get()
            ->map(fn ($t) => [
                'id'              => 'C-' . $t->id,
                'delivery_boy_id' => $t->delivery_boy_id,
                'name'            => $t->name,
                'mobile'          => $t->mobile,
                'country_code'    => $t->boy_country_code,
                'entry_type'      => 'cash_deposit_cash',
                'type'            => 'deposit',
                'amount'          => (float) $t->amount,
                'opening_balance' => null,
                'closing_balance' => null,
                'currency'        => $t->currency,
                'message'         => CommonHelper::translateLedgerMessage($t->message),
                'created_at'      => $t->getRawOriginal('transaction_date') ?: $t->getRawOriginal('created_at'),
            ]);

        return $wallet->concat($cashDeposits)
            ->sortByDesc('created_at')
            ->values();
    }

    public function country()
    {
        return $this->belongsTo(Country::class, 'country_id');
    }

    public function deliveryBoy()
    {
        return $this->belongsTo(DeliveryBoy::class, 'delivery_boy_id');
    }
}
