<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class RegionTranslation extends Model
{
    use HasFactory;

    protected $table = 'region_translations';

    protected $fillable = ['region_id', 'language_id', 'name'];

    protected $hidden = ['created_at', 'updated_at'];

    public function region()
    {
        return $this->belongsTo(Region::class, 'region_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}
