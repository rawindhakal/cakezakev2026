<?php

namespace App\Models;

use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CategoryCustomField extends Model
{
    use HasFactory, HasTranslations;

    protected $table = 'category_custom_fields';

    protected $fillable = [
        'category_custom_section_id',
        'field_label',
        'field_type',
        'options',
        'is_required',
        'sort_order',
    ];

    protected $casts = [
        'options' => 'array',
    ];

    protected $translatable = ['field_label', 'options'];

    protected $translationModel = 'CategoryCustomFieldTranslation';

    protected $translationForeignKey = 'category_custom_field_id';

    protected $appends = ['translations'];

    protected $hidden = ['created_at', 'updated_at'];

    public function section()
    {
        return $this->belongsTo(CategoryCustomSection::class, 'category_custom_section_id');
    }

    public function variantValues()
    {
        return $this->hasMany(ProductVariantCustomValue::class, 'category_custom_field_id');
    }
}
