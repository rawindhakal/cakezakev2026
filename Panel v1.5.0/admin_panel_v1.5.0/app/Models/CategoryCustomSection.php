<?php

namespace App\Models;

use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CategoryCustomSection extends Model
{
    use HasFactory, HasTranslations;

    protected $table = 'category_custom_sections';

    protected $fillable = [
        'category_id',
        'name',
        'is_overridden_off',
        'sort_order',
    ];

    protected $translatable = ['name'];

    protected $translationModel = 'CategoryCustomSectionTranslation';

    protected $translationForeignKey = 'category_custom_section_id';

    protected $appends = ['translations'];

    protected $hidden = ['created_at', 'updated_at'];

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    public function fields()
    {
        return $this->hasMany(CategoryCustomField::class, 'category_custom_section_id')->orderBy('sort_order');
    }
}
