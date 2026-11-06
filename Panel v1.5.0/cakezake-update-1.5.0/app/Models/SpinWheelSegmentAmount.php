<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * What a segment pays out in ONE country.
 *
 * A missing row is meaningful: the segment is simply not offered in that country, and the
 * spin drops it from the wheel rather than paying a foreign amount.
 */
class SpinWheelSegmentAmount extends Model
{
    use HasFactory;

    protected $fillable = [
        'spin_wheel_segment_id',
        'country_id',
        'amount',
        'max_discount_amount',
        'minimum_order_amount',
    ];

    protected $casts = [
        'amount'               => 'float',
        'max_discount_amount'  => 'float',
        'minimum_order_amount' => 'float',
    ];

    protected $hidden = ['created_at', 'updated_at'];

    public function segment()
    {
        return $this->belongsTo(SpinWheelSegment::class, 'spin_wheel_segment_id');
    }

    public function country()
    {
        return $this->belongsTo(Country::class, 'country_id');
    }
}
