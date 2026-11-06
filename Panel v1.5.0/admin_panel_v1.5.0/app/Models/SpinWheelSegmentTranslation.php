<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SpinWheelSegmentTranslation extends Model
{
    use HasFactory;

    protected $table = 'spin_wheel_segment_translations';

    protected $fillable = [
        'spin_wheel_segment_id',
        'language_id',
        'label',
    ];

    protected $hidden = [
        'created_at',
        'updated_at',
    ];

    public function segment()
    {
        return $this->belongsTo(SpinWheelSegment::class, 'spin_wheel_segment_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}
