<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * One spin. Doubles as the daily/lifetime quota source and the admin history.
 *
 * Deliberately NOT audited by LogsActivity — one activity row per spin is churn, and the
 * spin log already is the audit trail.
 */
class SpinWheelSpin extends Model
{
    use HasFactory;

    protected $fillable = [
        'spin_wheel_campaign_id',
        'spin_wheel_segment_id',
        'user_id',
        'country_id',
        'zone_id',
        'result',
        'reward_type',
        'amount',
        'currency',
        'currency_code',
        'promo_code_id',
        'wallet_transaction_id',
        'request_token',
        'spun_at',
    ];

    protected $casts = [
        'amount'  => 'float',
        'spun_at' => 'datetime',
    ];

    public function campaign()
    {
        return $this->belongsTo(SpinWheelCampaign::class, 'spin_wheel_campaign_id');
    }

    public function segment()
    {
        return $this->belongsTo(SpinWheelSegment::class, 'spin_wheel_segment_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function promoCode()
    {
        return $this->belongsTo(PromoCode::class, 'promo_code_id');
    }
}
