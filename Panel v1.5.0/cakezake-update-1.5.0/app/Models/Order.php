<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Casts\Attribute;
use App\Traits\LogsActivity;

class Order extends Model
{
    use HasFactory, SoftDeletes, LogsActivity;

    public static $activeType = 1;
    public static $previousType = 0;

    // How the order reaches the customer.
    public const DELIVERY_TYPE_DELIVERY = 'delivery';
    public const DELIVERY_TYPE_PICKUP = 'pickup';

    /** Collected at the branch by the customer — no address, no rider, no delivery charge. */
    public function isPickup(): bool
    {
        return ($this->delivery_type ?? self::DELIVERY_TYPE_DELIVERY) === self::DELIVERY_TYPE_PICKUP;
    }
    protected $casts = [
        'additional_charges' => 'array',
        'total'            => 'float',
        'delivery_charge'  => 'float',
        'tax_amount'       => 'float',
        'tax_percentage'   => 'float',
        'wallet_balance'   => 'float',
        'paid_wallet'      => 'float',
        'discount'         => 'float',
        'promo_discount'   => 'float',
        'cashback_amount'  => 'float',
        'final_total'      => 'float',
        'remaining_total'  => 'float',
        'remaining_final'  => 'float',
        'refund_amount'    => 'float',
        'active_status'    => 'integer',
        'till_status'      => 'integer',
        'surge_charges'      => 'array',
        'address'            => 'array',
    ];

    public static $previousTypeStatus = 0;

    public static function boot()
    {
        parent::boot();
        static::deleting(function ($data) { // before delete() method call this
            $data->items()->delete();
        });
    }

    function getActiveStatusNameAttribute()
    {

    }

    public function items()
    {
        return $this->hasMany(OrderItem::class, 'order_id', 'id');
    }

    public function user()
    {
        return $this->hasOne(User::class, 'id', 'user_id');
    }

    public function orderStatus()
    {
        return $this->hasMany(OrderStatus::class, 'order_id', 'id');
    }

    public function setDeliveryBoyBonusDetailsAttribute($value)
    {
        $this->attributes['delivery_boy_bonus_details'] = json_encode($value);
    }

    public function getDeliveryBoyBonusDetailsAttribute($value)
    {
        return $value === null ? null : json_decode($value, true);
    }


    public function buyerRegion()
    {
        return $this->belongsTo(Region::class, 'buyer_region_id');
    }

    /** Every frozen tax line on this order, items and charges alike. */
    public function taxLines()
    {
        return $this->hasMany(OrderItemTax::class, 'order_id');
    }
}
