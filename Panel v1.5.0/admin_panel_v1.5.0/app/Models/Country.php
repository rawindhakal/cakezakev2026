<?php

namespace App\Models;


use App\Helpers\CommonHelper;
use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\LogsActivity;

class Country extends Model
{
    use HasFactory,HasTranslations, LogsActivity;

    public $timestamps = false;

    protected $table = 'countries';

    protected $guarded = [];

    protected $casts = [
        'payment_gateways' => 'array',
        'decimal_point'    => 'integer',
        'min_mobile_length' => 'integer',
        'max_mobile_length' => 'integer',
        'status'           => 'integer',
        'is_default'       => 'integer',
        'referral_min_order_amount'   => 'float',
        'referral_credit_first_order' => 'float',
        'referral_credit_referred'    => 'float',
        'referral_usage_limit'        => 'integer',
    ];

    protected $translatable = [
        'name',
        'privacy_policy',
        'return_policy',
        'shipping_policy',
        'cancellation_policy',
        'terms_conditions',
        'privacy_policy_delivery_boy',
        'terms_conditions_delivery_boy',
    ];

    protected $translationModel = 'CountryTranslation';

    protected $appends = ['logo_url','translations'];

    protected $translationForeignKey = 'country_id';
    
    protected $hidden = ['created_at','updated_at','deleted_at'];

    // Logo URL
    public function getLogoUrlAttribute()
    {
        return CommonHelper::imageUrlIfSet($this->getAttributes()['logo'] ?? '');
    }

    public function zones()
    {
        return $this->hasMany(Zone::class, 'country_id');
    }

    public function regions()
    {
        return $this->hasMany(Region::class, 'country_id');
    }

    public function activeRegions()
    {
        return $this->regions()->where('status', 1)->orderBy('name');
    }
}