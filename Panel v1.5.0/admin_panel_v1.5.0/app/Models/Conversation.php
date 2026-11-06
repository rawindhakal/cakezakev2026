<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Conversation extends Model
{
    public const TYPE_ADMIN_CUSTOMER = 'admin_customer';
    public const TYPE_ADMIN_DELIVERY_BOY = 'admin_delivery_boy';
    public const TYPE_DELIVERY_BOY_CUSTOMER = 'delivery_boy_customer';
    // Order-scoped customer <-> admin thread (distinct from the general admin_customer support thread).
    public const TYPE_ORDER_ADMIN = 'order_admin';

    /** Order-scoped conversation types (tie a specific order to its participants). */
    public const ORDER_SCOPED_TYPES = [self::TYPE_DELIVERY_BOY_CUSTOMER, self::TYPE_ORDER_ADMIN];

    protected $fillable = [
        'type',
        'order_id',
        'user_id',
        'delivery_boy_id',
        'last_message',
        'last_sender_type',
        'last_message_at',
    ];

    protected $casts = [
        'order_id'        => 'integer',
        'user_id'         => 'integer',
        'delivery_boy_id' => 'integer',
        'last_message_at' => 'datetime',
    ];

    public function messages()
    {
        return $this->hasMany(Message::class)->orderBy('id', 'ASC');
    }

    public function customer()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function deliveryBoy()
    {
        return $this->belongsTo(DeliveryBoy::class, 'delivery_boy_id');
    }

    public function order()
    {
        return $this->belongsTo(Order::class, 'order_id');
    }
}
