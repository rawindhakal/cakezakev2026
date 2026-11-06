<?php

namespace App\Models;

use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use App\Traits\LogsActivity;

class Attribute extends Model
{
    use HasFactory, HasTranslations, SoftDeletes, LogsActivity;

    protected $fillable = [
        'name',
        'slug',
        'status',
    ];

    protected $translatable = ['name'];

    protected $translationModel = 'AttributeTranslation';

    protected $appends = ['translations'];

    protected $hidden = ['created_at', 'updated_at', 'deleted_at'];

    public function values()
    {
        return $this->hasMany(AttributeValue::class)->orderBy('id');
    }

    public function activeValues()
    {
        return $this->hasMany(AttributeValue::class)->orderBy('id');
    }

    public function categories()
    {
        return $this->belongsToMany(Category::class, 'category_attribute')
            ->withPivot(['is_overridden_off'])
            ->withTimestamps();
    }
}
