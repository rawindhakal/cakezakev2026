<?php

namespace App\Models;


use App\Helpers\CommonHelper;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Cart extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'product_id',
        'product_variant_id',
        'branch_id',
        'channel',
        'qty',
        'addons',
        'addon_signature',
    ];

    protected $casts = [
        'addons' => 'array',
    ];

    protected $hidden = [];
    protected $appends = ['image_url'];

    public function images(){
        return $this->hasMany(ProductImages::class,'product_id','product_id')
            ->where('product_variant_id',0);
        //$res = $res->makeHidden(['image']);
    }
    public function products()
    {
        return $this->belongsTo(Product::class, 'product_id');
    }

    // Relation to ProductVariant
    public function variants()
    {
        return $this->belongsTo(ProductVariant::class, 'product_variant_id');
    }

    public function branch()
    {
        return $this->belongsTo(Branch::class, 'branch_id');
    }

    public function getImageUrlAttribute(){
        return CommonHelper::modelImageUrl($this, 'image');
    }

}
