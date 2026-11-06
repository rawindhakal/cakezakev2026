<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProductTranslation extends Model
{
    use HasFactory;

    protected $table = 'product_translations';

    protected $fillable = [
        'product_id',
        'language_id',
        'name',
        'tags',
        'manufacturer',
        'made_in',
        'description',
        'short_description',
        'meta_title',
        'meta_keywords',
        'schema_markup',
        'meta_description',
    ];

    protected $hidden = [
        'created_at',
        'updated_at',
    ];

    public function product()
    {
        return $this->belongsTo(Product::class);
    }

    public function language()
    {
        return $this->belongsTo(Language::class);
    }
}

