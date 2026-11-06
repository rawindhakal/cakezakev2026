<?php

namespace App\Models;


use App\Helpers\CommonHelper;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
//use Illuminate\Database\Eloquent\SoftDeletes;

class OrderItem extends Model
{
    //use HasFactory,SoftDeletes;
    use HasFactory;
    protected $hidden = [];
protected $casts = [
        'id' => 'integer',
        'user_id' => 'integer',
        'order_id' => 'integer',
        'price' => 'float',
        'variant_attributes' => 'array',
        'addons' => 'array',
        'addon_total' => 'float',
        'discounted_price' => 'float',
        'purchase_price' => 'float',
        'sub_total' => 'float',
        'delivery_charge' => 'float',
        'additional_charges' => 'array',
        'surge_charges' => 'array',
        'promo_discount' => 'float',
        'wallet_balance' => 'float',
        'final_total' => 'float',
        'tax_amount' => 'float',
        'tax_percentage' => 'float',
        'quantity' => 'float',
        'product_id' => 'integer',
        'product_variant_id' => 'integer',
        'variant_id' => 'integer',
        'return_days' => 'integer',
        'return_status' => 'integer',
        'cancelable_status' => 'integer',
        'is_credited' => 'integer',
        'delivery_boy_id' => 'integer',
        'delivery_boy_bonus_details' => 'array',
        'delivery_boy_bonus_amount' => 'float',
        'branch_id' => 'integer',
        'till_status' => 'integer',
        'active_status' => 'integer',
    ];
    protected $appends = ['image_url', 'prescription_url'];

    public function images(){
        return $this->hasMany(ProductImages::class,'product_variant_id','product_variant_id');
          
    }

    public function getImageUrlAttribute(){
        return CommonHelper::modelImageUrl($this, 'image');
    }

    public function getPrescriptionUrlAttribute()
    {
        // `prescription` is absent when the row came from a partial select().
        $path = $this->attributes['prescription'] ?? null;
        return $path ? asset('storage/' . $path) : '';
    }

    public function branch()
    {
        return $this->belongsTo(Branch::class, 'branch_id');
    }

    public function productVariant()
    {
        return $this->belongsTo(ProductVariant::class, 'product_variant_id');
    }
    public function user()
    {
        return $this->hasOne(User::class, 'id', 'user_id');
    }

    public function branchRegion()
    {
        return $this->belongsTo(Region::class, 'branch_region_id');
    }

    public function taxLines()
    {
        return $this->hasMany(OrderItemTax::class, 'order_item_id');
    }
}
