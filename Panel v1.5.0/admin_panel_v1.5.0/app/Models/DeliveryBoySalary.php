<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class DeliveryBoySalary extends Model
{
    use HasFactory;

    protected $guarded = [];

    protected $casts = [
        'id'              => 'integer',
        'delivery_boy_id' => 'integer',
        'amount'          => 'float',
        'paid_on'         => 'date',
        'created_by'      => 'integer',
    ];

    public function deliveryBoy()
    {
        return $this->belongsTo(DeliveryBoy::class, 'delivery_boy_id');
    }
}
