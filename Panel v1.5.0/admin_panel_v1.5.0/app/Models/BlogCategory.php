<?php

namespace App\Models;

use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
class BlogCategory extends Model
{
    use HasFactory, HasTranslations;
    protected $table = 'blog_categories';

    protected $fillable = [
        'slug',
        'name',
        'meta_title',
        'meta_keywords',
        'meta_description',
        'schema_markup',
        'status',
           'name' // base table name
    ];

    protected $translatable = [
        'name',
        'meta_title',
        'meta_keywords',
        'meta_description',
        'schema_markup',
    ];


    public function translations()
    {
        return $this->hasMany(BlogCategoryTranslation::class, 'blog_category_id', 'id');
    }

    /**
     * The attributes that should be hidden for arrays.
     *
     * @var array
     */
    protected $hidden = ['created_at', 'updated_at'];

    protected $translationModel = 'BlogCategoryTranslation';

    protected $translationForeignKey = 'blog_category_id';

    protected $appends = ['translations'];

    /**
     * Get the blogs for the category.
     */
    public function blogs()
    {
        return $this->hasMany(Blog::class, 'category_id');
    }

    /**
     * Get the active blogs for the category.
     */
    public function activeBlogs()
    {
        return $this->hasMany(Blog::class, 'category_id')->where('status', 1);
    }

    /**
     * Scope a query to only include active categories.
     */
    public function scopeActive($query)
    {
        return $query->where('status', 1);
    }

    /**
     * Get the active blogs count for the category.
     */
    public function getActiveBlogsCountAttribute()
    {
        return $this->activeBlogs()->count();
    }
}
