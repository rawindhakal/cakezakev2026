<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class BlogCategoryTranslation extends Model
{
    use HasFactory;
 
     protected $table = 'blog_category_translations';

        protected $fillable = [
        'blog_category_id',
        'language_id',
        'name',
        'meta_title',
        'meta_keywords',
        'meta_description',
        'schema_markup',
    ];
          protected $translatable = [
        'name',
         'meta_title',
        'meta_keywords',
        'meta_description',
        'schema_markup',
    ];


    protected $hidden = [
        'created_at',
        'updated_at',
    ];
   public function category()
    {
        return $this->belongsTo(BlogCategory::class, 'blog_category_id');
    }

        public function language()
    {
        return $this->belongsTo(Language::class);
    }
       public $timestamps = false;

}
