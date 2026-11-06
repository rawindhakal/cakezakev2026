<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class HomeLayoutTemplate extends Model
{
    protected $guarded = [];

    protected $casts = [
        'section_json' => 'array',
    ];
}
