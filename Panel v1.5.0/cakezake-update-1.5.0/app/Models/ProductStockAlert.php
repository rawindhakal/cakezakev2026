<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * A customer's "tell me when this is back" for one variant.
 *
 * Zone-scoped: stock lives per branch and a branch serves one zone, so the row remembers
 * where the customer was when they asked and is only settled by stock returning there.
 */
class ProductStockAlert extends Model
{
    use HasFactory;

    public const STATUS_CANCELLED = 0;
    public const STATUS_WAITING   = 1;
    public const STATUS_NOTIFIED  = 2;

    protected $fillable = [
        'user_id',
        'product_id',
        'product_variant_id',
        'country_id',
        'zone_id',
        'status',
        'notified_at',
    ];

    protected $casts = [
        'status'      => 'integer',
        'notified_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function product()
    {
        return $this->belongsTo(Product::class, 'product_id');
    }

    public function variant()
    {
        return $this->belongsTo(ProductVariant::class, 'product_variant_id');
    }

    public function scopeWaiting($query)
    {
        return $query->where('status', self::STATUS_WAITING);
    }
}
