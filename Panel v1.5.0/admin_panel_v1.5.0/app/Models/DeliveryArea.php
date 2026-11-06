<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class DeliveryArea extends Model
{
    use HasFactory;

    protected $table = 'delivery_areas';

    protected $guarded = [];

    protected $casts = [
        'status'          => 'integer',
        'boundary_points' => 'array',
    ];

    public function city()
    {
        return $this->belongsTo(DeliveryCity::class, 'delivery_city_id');
    }
}
