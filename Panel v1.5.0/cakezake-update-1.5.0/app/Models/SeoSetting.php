<?php

namespace App\Models;

use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SeoSetting extends Model
{
    use HasFactory,HasTranslations;
    // Specify the table if it's different from the default plural form
    protected $table = 'web_seo_pages';

    // Specify the fields that are mass assignable
    protected $fillable = [
        'page_type',
        'zone_id',
        'og_image',
        'meta_title',
        'meta_keyword',
        'schema_markup',
        'meta_description'
    ];

    protected $translatable = [
        'meta_title',
        'meta_keyword',
        'schema_markup',
        'meta_description',
    ];

    protected $translationModel = 'SeoSettingTranslation';
    protected $translationForeignKey = 'seo_setting_id';
    protected $appends = ['og_image_url', 'translations'];

    protected $hidden = ['created_at', 'updated_at'];


    public function getOgImageUrlAttribute(){

        if($this->og_image){
            $og_image_url = asset('storage/'.$this->og_image);
            return $og_image_url;
        }
        return $this->og_image;
    }

    public function zone()
    {
        return $this->belongsTo(Zone::class, 'zone_id');
    }
}
