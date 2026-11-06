<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class BlogTranslation extends Model
{
    use HasFactory;

    public $timestamps = false;
    protected $table = 'blog_translations';

    protected $fillable = [
        'blog_id',
        'language_id',
        'title',
        'description',
        'short_description',
        'meta_title',
        'meta_keywords',
        'meta_description',
        'schema_markup',
    ];

    protected $hidden = [
        'created_at',
        'updated_at',
    ];

    public function language()
    {
        return $this->belongsTo(Language::class);
    }
}
