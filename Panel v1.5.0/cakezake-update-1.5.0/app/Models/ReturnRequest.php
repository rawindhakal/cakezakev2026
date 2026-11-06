<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\LogsActivity;

class ReturnRequest extends Model
{
    use HasFactory, LogsActivity;

    protected $fillable = [
        'user_id',
        'product_variant_id',
        'order_id',
        'order_item_id',
        'address_id',
        'address',
        'return_reason',
        'status',
        'remarks',
        'delivery_boy_id',
        'reject_reason',
        'delivery_boy_bonus_amount',
        'delivery_boy_bonus_details',
        'bonus_credited',
    ];

    protected $casts = [
        'delivery_boy_bonus_details' => 'array',
        'address' => 'array',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function orderItem()
    {
        return $this->belongsTo(OrderItem::class);
    }

    public function productVariant()
    {
        return $this->belongsTo(ProductVariant::class);
    }

    public function deliveryBoy()
    {
        return $this->belongsTo(DeliveryBoy::class);
    }

    public function getStatusNameAttribute()
    {
        return ReturnStatusList::getStatusName($this->status);
    }
}
