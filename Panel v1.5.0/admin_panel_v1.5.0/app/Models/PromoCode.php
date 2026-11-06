<?php

namespace App\Models;


use App\Helpers\CommonHelper;
use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\LogsActivity;

class PromoCode extends Model
{
    use HasFactory, HasTranslations, LogsActivity;

    protected $appends = ['image_url','is_applicable','validity'];
    protected $translatable = ['title', 'description'];
    protected $translationForeignKey = 'promo_code_id';

    protected $casts = [
        'applicability_ids'   => 'array',
        'audience_ids'        => 'array',
        'country_ids'         => 'array',
        'zone_ids'            => 'array',
        'weekday_recurrence'  => 'array',
        'is_permanent'        => 'integer',
        'full_day_promotion'  => 'integer',
    ];

    public function getImageUrlAttribute(){
        return CommonHelper::modelImageUrl($this, 'image');
    }

    public function getIsApplicableAttribute()
    {
        // Permanent promotions never expire by date.
        if ((int) ($this->is_permanent ?? 0) === 1) {
            return 1;
        }

        if (empty($this->start_date) || empty($this->end_date)) {
            return 1;
        }

        $current_date = now();
        $start = \Carbon\Carbon::parse($this->start_date)->startOfDay();
        $end = \Carbon\Carbon::parse($this->end_date)->endOfDay();

        if ($current_date->lt($start) || $current_date->gt($end)) {
            return 0;
        }

        return 1;
    }

    public function getValidityAttribute(){
        return ($this->is_applicable == 1) ? __('acceptable') : __('expired') ;
    }



}
