<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProductVariantCustomValueTranslation extends Model
{
    use HasFactory;

    protected $table = 'product_variant_custom_value_translations';

    protected $fillable = [
        'product_variant_custom_value_id',
        'language_id',
        'value_text',
        'value_json',
    ];

    protected $casts = [
        'value_json' => 'array',
    ];

    protected $hidden = ['created_at', 'updated_at'];

    public function customValue()
    {
        return $this->belongsTo(ProductVariantCustomValue::class, 'product_variant_custom_value_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class);
    }
}
