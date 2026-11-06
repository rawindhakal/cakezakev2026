<?php

namespace App\Models;

use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProductVariant extends Model
{
    use HasFactory, HasTranslations;

    protected $fillable = [
        'id',
        'product_id',
        'name',
        'sku',
        'hsn_code',
        'image',
        'sort_order',
        // Shipping: dead weight in kg, box in cm. Null until the admin fills them in.
        'weight',
        'length',
        'breadth',
        'height',
    ];

    protected $casts = [
        'weight'  => 'float',
        'length'  => 'float',
        'breadth' => 'float',
        'height'  => 'float',
    ];

    protected $translatable = ['name'];

    protected $translationModel = 'ProductVariantTranslation';
    protected $translationForeignKey = 'product_variant_id';

    protected $appends = ['final_price_with_tax', 'translations'];

    protected $hidden = ['deleted_at'];

    public function images()
    {
        return $this->hasMany(ProductImages::class, 'product_variant_id', 'id');
    }

    public function product()
    {
        return $this->belongsTo(Product::class, 'product_id', 'id');
    }

    public function attributeValues()
    {
        return $this->hasMany(ProductVariantAttributeValue::class, 'product_variant_id');
    }

    public function customValues()
    {
        return $this->hasMany(ProductVariantCustomValue::class, 'product_variant_id');
    }

    public function branchStocks()
    {
        return $this->hasMany(ProductVariantBranchStock::class, 'product_variant_id');
    }

    public function getFinalPriceWithTaxAttribute()
    {
        // price / discounted_price are per-branch (PVSS); populated on the in-memory
        // variant by ProductHelper::applyBranchPrice(). Absent until applied.
        $price      = (float) ($this->attributes['price'] ?? 0);
        $discounted = (float) ($this->attributes['discounted_price'] ?? 0);

        return $discounted > 0 ? $discounted : $price;
    }
}
