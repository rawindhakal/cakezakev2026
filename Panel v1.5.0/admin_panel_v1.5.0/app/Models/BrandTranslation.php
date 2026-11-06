<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class BrandTranslation extends Model
{
    use HasFactory;
    public $timestamps = false;
     protected $fillable = [
        'brand_id',
        'language_id',
        'name',
    ];

    public function brand()
    {
        return $this->belongsTo(Brand::class);
    }
}
