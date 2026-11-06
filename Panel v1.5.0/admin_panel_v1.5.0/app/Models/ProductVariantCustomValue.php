<?php

namespace App\Models;

use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProductVariantCustomValue extends Model
{
    use HasFactory, HasTranslations;

    protected $table = 'product_variant_custom_values';

    protected $fillable = [
        'product_variant_id',
        'category_custom_field_id',
        'value_text',
        'value_number',
        'value_date',
        'value_json',
    ];

    protected $casts = [
        'value_json' => 'array',
    ];

    public function getValueDateAttribute($value)
    {
        return $value ? \Illuminate\Support\Carbon::parse($value)->format('Y-m-d') : null;
    }

    public function getValueNumberAttribute($value)
    {
        if ($value === null || $value === '') {
            return null;
        }
        $n = (float) $value;
        return $n == (int) $n ? (int) $n : $n;
    }

    protected $translatable = ['value_text', 'value_json'];

    protected $translationModel = 'ProductVariantCustomValueTranslation';
    protected $translationForeignKey = 'product_variant_custom_value_id';

    protected $appends = ['translations'];

    protected $hidden = ['created_at', 'updated_at'];

    public function variant()
    {
        return $this->belongsTo(ProductVariant::class, 'product_variant_id');
    }

    public function field()
    {
        return $this->belongsTo(CategoryCustomField::class, 'category_custom_field_id');
    }
}
