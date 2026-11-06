<?php

namespace App\Models;

use App\Helpers\CommonHelper;
use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\LogsActivity;

class Brand extends Model
{
     use HasFactory,HasTranslations, LogsActivity;

       protected $fillable = [
        'name',
        'image',
        'status',
    ];
    protected $translatable = [
        'name',
    ];
    protected $translationModel = 'BrandTranslation';
    protected $translationForeignKey = 'brand_id';

    protected $appends = ['image_url', 'translations'];

    public function getImageUrlAttribute(){
        return CommonHelper::modelImageUrl($this, 'image');
    }
     public function translations()
    {
        return $this->hasMany(BrandTranslation::class);
    }

    public function products()
    {
        return $this->hasMany(Product::class, 'brand_id', 'id');
    }
    

}
