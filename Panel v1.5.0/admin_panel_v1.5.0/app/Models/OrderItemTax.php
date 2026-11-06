<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Frozen tax line. Written once at order time and never recalculated — the rate on
 * an old invoice must stay what was actually charged even after the admin edits the
 * rule. `order_item_id` is NULL for a tax on an order-level charge (quick-channel
 * delivery / surge / additional), which belongs to no single item.
 */
class OrderItemTax extends Model
{
    use HasFactory;

    protected $table = 'order_item_taxes';
    public $timestamps = false;
    protected $guarded = [];

    protected $casts = [
        'order_id'      => 'integer',
        'order_item_id' => 'integer',
        'tax_rule_id'   => 'integer',
        'rate'          => 'float',
        'taxable_value' => 'float',
        'amount'        => 'float',
        'is_reversal'   => 'boolean',
        'created_at'    => 'datetime',
    ];

    public function order()
    {
        return $this->belongsTo(Order::class, 'order_id');
    }

    public function orderItem()
    {
        return $this->belongsTo(OrderItem::class, 'order_item_id');
    }
}
