<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Country-wise wallet balance for a user. One row per (user_id, country_id).
 */
class UserWallet extends Model
{
    use HasFactory;

    protected $table = 'user_wallets';

    protected $fillable = ['user_id', 'country_id', 'balance'];

    protected $casts = [
        'balance' => 'float',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function country()
    {
        return $this->belongsTo(Country::class, 'country_id');
    }
}
