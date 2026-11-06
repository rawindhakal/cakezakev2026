<?php

namespace App\Models;

use App\Traits\HasTranslations;
use App\Traits\LogsActivity;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;

/**
 * A spin-wheel campaign: the wheel itself plus the rules for who may spin and how often.
 *
 * Only one campaign is ever active — activating one deactivates the rest — so the
 * customer API never has to guess which wheel a customer should see.
 */
class SpinWheelCampaign extends Model
{
    use HasFactory, HasTranslations, LogsActivity;

    protected $translatable = ['name'];

    // Default would be `spinwheelcampaign_id`.
    protected $translationForeignKey = 'spin_wheel_campaign_id';

    protected $casts = [
        'theme'                => 'array',
        'status'               => 'integer',
        'is_scheduled'         => 'integer',
        'spins_per_day'        => 'integer',
        'max_spins_per_user'   => 'integer',
        'min_delivered_orders' => 'integer',
    ];

    protected $guarded = [];

    public function segments()
    {
        return $this->hasMany(SpinWheelSegment::class, 'spin_wheel_campaign_id')
            ->orderBy('sort_order')
            ->orderBy('id');
    }

    public function spins()
    {
        return $this->hasMany(SpinWheelSpin::class, 'spin_wheel_campaign_id');
    }

    /** Is the campaign inside its window right now? Null bounds mean "no bound". */
    public function isWithinWindow($at = null): bool
    {
        // Compared to the minute, not the day: an admin who ends a wheel at 18:00
        // means 18:00. Both sides pinned to UTC — the window is stored in UTC (the
        // panel converts from the admin's local time), like the maintenance schedule.
        $now = $at ? Carbon::parse($at, 'UTC') : Carbon::now('UTC');

        if ($this->start_date && $now->lt(Carbon::parse($this->start_date, 'UTC'))) {
            return false;
        }

        return !($this->end_date && $now->gt(Carbon::parse($this->end_date, 'UTC')));
    }
}
