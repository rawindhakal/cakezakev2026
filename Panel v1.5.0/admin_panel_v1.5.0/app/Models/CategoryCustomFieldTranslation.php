<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CategoryCustomFieldTranslation extends Model
{
    use HasFactory;

    protected $table = 'category_custom_field_translations';

    protected $fillable = [
        'category_custom_field_id',
        'language_id',
        'field_label',
        'options',
    ];

    protected $casts = [
        'options' => 'array',
    ];

    protected $hidden = ['created_at', 'updated_at'];

    public function field()
    {
        return $this->belongsTo(CategoryCustomField::class, 'category_custom_field_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}
