<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CategoryCustomSectionTranslation extends Model
{
    use HasFactory;

    protected $table = 'category_custom_section_translations';

    protected $fillable = [
        'category_custom_section_id',
        'language_id',
        'name',
    ];

    protected $hidden = ['created_at', 'updated_at'];

    public function section()
    {
        return $this->belongsTo(CategoryCustomSection::class, 'category_custom_section_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}
