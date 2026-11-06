<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProductRecommendation extends Model
{
    protected $guarded = [];

    public const TYPE_CROSS_SELL = 'cross_sell';
    public const TYPE_UPSELL     = 'upsell';

    public function product()
    {
        return $this->belongsTo(Product::class, 'product_id');
    }

    public function relatedProduct()
    {
        return $this->belongsTo(Product::class, 'related_product_id');
    }
}
