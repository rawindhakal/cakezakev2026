<?php

namespace App\Models;


use App\Helpers\CommonHelper;
use App\Traits\HasTranslations;
use App\Traits\LogsActivity;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * One wedge of the wheel and the reward behind it.
 *
 * Money is NOT stored here — a prize is worth different amounts in different countries,
 * so it lives in spin_wheel_segment_amounts keyed by country. A percentage discount is
 * the exception: the same number everywhere, so it stays on the segment.
 */
class SpinWheelSegment extends Model
{
    use HasFactory, HasTranslations, LogsActivity;

    public const TYPE_PROMO_CODE   = 'promo_code';
    public const TYPE_WALLET       = 'wallet';
    public const TYPE_FREE_DELIVERY = 'free_delivery';
    public const TYPE_NO_LUCK      = 'no_luck';

    protected $appends = ['icon_url'];

    protected $translatable = ['label'];

    // Default would be `spinwheelsegment_id`.
    protected $translationForeignKey = 'spin_wheel_segment_id';

    protected $casts = [
        'applicability_ids' => 'array',
        'win_chance'        => 'float',
        'discount_value'    => 'float',
        'winner_limit'      => 'integer',
        'wins_count'        => 'integer',
        'validity_days'     => 'integer',
        'sort_order'        => 'integer',
        'status'            => 'integer',
    ];

    protected $guarded = [];

    public function getIconUrlAttribute(): string
    {
        return CommonHelper::imageUrlIfSet($this->getAttributes()['icon'] ?? '');
    }

    public function campaign()
    {
        return $this->belongsTo(SpinWheelCampaign::class, 'spin_wheel_campaign_id');
    }

    public function amounts()
    {
        return $this->hasMany(SpinWheelSegmentAmount::class, 'spin_wheel_segment_id');
    }

    /** The country's row, or null when this segment is not offered there. */
    public function amountFor(?int $countryId): ?SpinWheelSegmentAmount
    {
        if (!$countryId) {
            return null;
        }

        return $this->amounts->firstWhere('country_id', (int) $countryId);
    }

    /** Segments that pay out money need a per-country amount; the others do not. */
    public function needsCountryAmount(): bool
    {
        if ($this->type === self::TYPE_WALLET) {
            return true;
        }

        // A flat discount is money; a percentage is not.
        return $this->type === self::TYPE_PROMO_CODE && $this->discount_type === 'flat';
    }

    public function hasWinnersLeft(): bool
    {
        return (int) $this->winner_limit === 0 || (int) $this->wins_count < (int) $this->winner_limit;
    }
}
