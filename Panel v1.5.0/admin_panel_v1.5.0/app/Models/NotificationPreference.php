<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NotificationPreference extends Model
{
    protected $guarded = [];

    protected $casts = [
        'is_enabled' => 'boolean',
        'user_type'  => 'integer',
        'user_id'    => 'integer',
    ];
}
