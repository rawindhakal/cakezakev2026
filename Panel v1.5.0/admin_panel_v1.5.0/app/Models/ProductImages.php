<?php

namespace App\Models;


use App\Helpers\CommonHelper;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProductImages extends Model
{
    use HasFactory;
    public $timestamps = false;

    protected $fillable = [
        'product_id',
        'product_variant_id',
        'image',
    ];

    protected $hidden = [];
    protected $appends = ['image_url'];

    public function getImageUrlAttribute(){
        return CommonHelper::modelImageUrl($this, 'image');
    }
}
