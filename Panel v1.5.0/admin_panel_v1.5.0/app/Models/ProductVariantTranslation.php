<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProductVariantTranslation extends Model
{
    use HasFactory;

    protected $table = 'product_variant_translations';

    protected $fillable = [
        'product_variant_id',
        'language_id',
        'name',
    ];

    protected $hidden = ['created_at', 'updated_at'];

    public function variant()
    {
        return $this->belongsTo(ProductVariant::class, 'product_variant_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class);
    }
}
