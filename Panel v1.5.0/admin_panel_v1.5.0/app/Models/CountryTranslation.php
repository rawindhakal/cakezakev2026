<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CountryTranslation extends Model
{
    use HasFactory;

    protected $table = 'country_translations';

    protected $fillable = [
        'country_id',
        'language_id',
        'name',
        'privacy_policy',
        'return_policy',
        'shipping_policy',
        'cancellation_policy',
        'terms_conditions',
        'privacy_policy_delivery_boy',
        'terms_conditions_delivery_boy',
    ];

    protected $hidden = [
        'created_at',
        'updated_at'
    ];

    public function country()
    {
        return $this->belongsTo(country::class,'country_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class,'language_id');
    }
}
