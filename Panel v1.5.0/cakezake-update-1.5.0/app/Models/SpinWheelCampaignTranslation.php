<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SpinWheelCampaignTranslation extends Model
{
    use HasFactory;

    protected $table = 'spin_wheel_campaign_translations';

    protected $fillable = [
        'spin_wheel_campaign_id',
        'language_id',
        'name',
    ];

    protected $hidden = [
        'created_at',
        'updated_at',
    ];

    public function campaign()
    {
        return $this->belongsTo(SpinWheelCampaign::class, 'spin_wheel_campaign_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}
