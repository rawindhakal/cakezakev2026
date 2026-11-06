<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CategoryTranslation extends Model
{
    use HasFactory;

    protected $table = 'category_translations';

    protected $fillable = [
        'category_id',
        'language_id',
        'name',
        'meta_title',
        'meta_keywords',
        'schema_markup',
        'meta_description',
    ];

    protected $hidden = [
        'created_at',
        'updated_at',
    ];

    public function category()
    {
        return $this->belongsTo(Category::class, 'category_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}

