<?php

namespace App\Models;


use App\Helpers\CommonHelper;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;


class ProductRating extends Model
{
    use HasFactory;
  
    protected $hidden = ['created_at','deleted_at'];

   
    public function user()
    {
        return $this->belongsTo(User::class, 'user_id')->select(['id', 'name', 'profile']);
    } 
    public function images(){

        return $this->hasMany(RatingImages::class,'product_rating_id','id');
    }

    public function getImageUrlAttribute(){
        return CommonHelper::modelImageUrl($this, 'image');
    }
}
