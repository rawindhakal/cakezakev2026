<?php

namespace App\Models;


use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SeoSettingTranslation extends Model
{
    use HasFactory;


     protected $table = 'seo_setting_translations';

    protected $fillable = [
        'seo_setting_id',
        'language_id',
        'meta_title',
        'meta_keyword',
        'schema_markup',
        'meta_description',
    ];

     protected $hidden = ['created_at', 'updated_at'];

    public function seoSetting()
    {
        return $this->belongsTo(SeoSetting::class);
    }
    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}
