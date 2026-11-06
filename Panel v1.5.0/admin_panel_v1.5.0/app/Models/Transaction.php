<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Transaction extends Model
{
    use HasFactory;
    public static $statusSuccess = "success";
    public static $statusFailed = "failed";
    

    public static $paymentTypeCod = "COD";
    public static $paymentTypeStripe = "Stripe";
    public static $paymentTypeRazorpay = "Razorpay";
    public static $paymentTypePaystack = "Paystack";
    public static $paymentTypePaypal = "Paypal";
    public static $paymentTypeWallet = "Wallet";
    public static $paymentTypeMidtrans = "Midtrans";
    public static $paymentTypePhonepe = "Phonepe";
    public static $paymentTypeCashfree = "Cashfree";
    public static $paymentTypePaytabs = "Paytabs";
    public static $paymentTypeInAppPurchase = "InAppPurchase";

    // Normalized type keys stored in transactions.type (used for lang-wise labels)
    public static $typeCod = 'txn_type_cod';
    public static $typeStripe = 'txn_type_stripe';
    public static $typeRazorpay = 'txn_type_razorpay';
    public static $typePaystack = 'txn_type_paystack';
    public static $typePaypal = 'txn_type_paypal';
    public static $typeWallet = 'txn_type_wallet';
    public static $typeMidtrans = 'txn_type_midtrans';
    public static $typePhonepe = 'txn_type_phonepe';
    public static $typeCashfree = 'txn_type_cashfree';
    public static $typePaytabs = 'txn_type_paytabs';
    public static $typeInAppPurchase = 'txn_type_in_app_purchase';

    protected $fillable = ['user_id','order_id','country_id','zone_id','currency','currency_code','type',
        'txn_id','payu_txn_id','amount',
        'status','message','transaction_date'];

     protected $casts = [
        'amount' => 'decimal:2',
    ];

    /**
     * Stamp the currency + country/zone snapshot from the order on create, so every
     * transaction (across all gateway controllers) carries them without touching
     * each call site. Only fills values not already set explicitly.
     */
    protected static function booted()
    {
        static::creating(function ($txn) {
            if (empty($txn->order_id)) {
                return;
            }
            if (!empty($txn->currency) && !empty($txn->country_id)) {
                return;
            }
            $order = Order::select('currency', 'currency_code', 'country_id', 'zone_id')->find($txn->order_id);
            if ($order) {
                $txn->currency      = $txn->currency ?: $order->currency;
                $txn->currency_code = $txn->currency_code ?: $order->currency_code;
                $txn->country_id    = $txn->country_id ?: $order->country_id;
                $txn->zone_id       = $txn->zone_id ?: $order->zone_id;
            }
        });
    }

    // Force output as float
    public function getAmountAttribute($value)
    {
        return (float) $value;
    }
}
