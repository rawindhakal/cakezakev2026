<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class DeliveryCity extends Model
{
    use HasFactory;

    protected $table = 'delivery_cities';

    protected $guarded = [];

    protected $casts = [
        'status'          => 'integer',
        'boundary_points' => 'array',
    ];

    public function areas()
    {
        return $this->hasMany(DeliveryArea::class, 'delivery_city_id');
    }

    public function country()
    {
        return $this->belongsTo(Country::class, 'country_id');
    }
}
