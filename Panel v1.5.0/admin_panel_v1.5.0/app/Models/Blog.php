<?php

namespace App\Models;


use App\Helpers\CommonHelper;
use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\LogsActivity;

class Blog extends Model
{
    use HasFactory, HasTranslations, LogsActivity;

    protected $table = 'blogs';
    
    protected $translationModel = 'BlogTranslation';

    protected $fillable = [
        'title',
        'slug',
        'category_id',
        'image',
        'description',
        'short_description',
        'tags',
        'meta_title',
        'meta_keywords',
        'meta_description',
        'schema_markup',
        'views_count',
        'status'
    ];
    protected $translatable = [
        'title',
        'description',
        'short_description',
        'meta_title',
        'meta_keywords',
        'meta_description',
        'schema_markup',
    ];

    protected $hidden = ['updated_at'];

    protected $appends = ['image_url', 'read_time', 'views_count', 'translations'];

    public function category()
    {
        return $this->belongsTo(BlogCategory::class);
    }

    public function translations()
    {
        return $this->hasMany(BlogTranslation::class);
    }
    public function views()
    {
        return $this->hasMany(BlogView::class);
    }

    public function getReadTimeAttribute()
    {
        $wordCount = str_word_count(strip_tags($this->description));
        $readTimeMinutes = ceil($wordCount / 200); // Using 200 words per minute
        $readTimeMinutes = max(1, $readTimeMinutes); // Minimum 1 minute

        if ($readTimeMinutes < 60) {
            return $readTimeMinutes . ' ' . ($readTimeMinutes == 1 ? __('minute') : __('minutes'));
        } else {
            $hours = floor($readTimeMinutes / 60);
            $minutes = $readTimeMinutes % 60;

            $timeString = '';
            if ($hours > 0) {
                $timeString .= $hours . ' ' . ($hours == 1 ? __('hour') : __('hours'));
            }
            if ($minutes > 0) {
                if ($hours > 0) {
                    $timeString .= ' ';
                }
                $timeString .= $minutes . ' ' . ($minutes == 1 ? __('min') : __('mins'));
            }

            return $timeString;
        }
    }

    public function getViewsCountAttribute()
    {
        return $this->views()->count();
    }

    public function getImageUrlAttribute()
    {
        return CommonHelper::modelImageUrl($this, 'image');
    }

    protected $translationAttributes = [
        'title',
        'description',
        'short_description',
        'meta_title',
        'meta_keywords',
        'meta_description'
    ];

    protected $translationForeignKey = 'blog_id';

    public function scopeActive($query)
    {
        return $query->where('status', 1);
    }

    public function scopeByCategory($query, $categoryId)
    {
        return $query->where('category_id', $categoryId);
    }

    public function scopeSearch($query, $search)
    {
        return $query->where(function ($q) use ($search) {
            $q->where('title', 'like', '%' . $search . '%')
                ->orWhere('description', 'like', '%' . $search . '%');
        });
    }
}
