<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * COD cash ledger for delivery boys (formerly DeliveryBoyTransaction /
 * delivery_boy_transactions). `delivery_boys.cash_received` is the running balance.
 *  - type=COD: cash collected from a customer on delivery (order-linked) — cash up.
 *  - type=delivery_boy_cash_collection: settlement back to admin — cash down;
 *    `payment_mode` says how (cash handover or wallet debit), and wallet-mode rows
 *    link the wallet debit via `wallet_transaction_id`.
 */
class DeliveryBoyCashCollection extends Model
{
    use HasFactory;

    public static $statusSuccess = "success";
    public static $statusFailed = "failed";

    public static $paymentTypeCod = "COD";
    public static $typeCashCollection = "delivery_boy_cash_collection";

    public static $modeCash = "cash";
    public static $modeWallet = "wallet";

    protected $table = 'delivery_boy_cash_collections';

    protected $fillable = ['user_id','order_id','delivery_boy_id','currency','currency_code','type',
        'payment_mode','wallet_transaction_id','amount','status','message','transaction_date'];

    /**
     * Snapshot the currency from the delivery boy's country on create (its currency
     * can change later). Prefers the order's snapshot when the txn is order-linked.
     * Only fills values not already set explicitly.
     */
    protected static function booted()
    {
        static::creating(function ($txn) {
            if (!empty($txn->currency) && !empty($txn->currency_code)) {
                return;
            }
            // Order-linked: use the order's frozen currency (same country as the boy).
            if (!empty($txn->order_id)) {
                $order = Order::select('currency', 'currency_code')->find($txn->order_id);
                if ($order && !empty($order->currency)) {
                    $txn->currency = $txn->currency ?: $order->currency;
                    $txn->currency_code = $txn->currency_code ?: $order->currency_code;
                    return;
                }
            }
            // Otherwise derive from the delivery boy's country (e.g. settlement rows).
            if (!empty($txn->delivery_boy_id)) {
                $country = optional(DeliveryBoy::with('country')->find($txn->delivery_boy_id))->country;
                if ($country) {
                    $txn->currency = $txn->currency ?: $country->currency;
                    $txn->currency_code = $txn->currency_code ?: $country->currency_code;
                }
            }
        });
    }

    public function walletTransaction()
    {
        return $this->belongsTo(DeliveryBoySettlement::class, 'wallet_transaction_id');
    }

    public function deliveryBoy()
    {
        return $this->belongsTo(DeliveryBoy::class, 'delivery_boy_id');
    }
}
