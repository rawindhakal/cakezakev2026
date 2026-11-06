<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ZoneTranslation extends Model
{
    use HasFactory;

    protected $table = 'zone_translations';

    protected $fillable = [
        'zone_id',
        'language_id',
        'surge_labels',
        'additional_charge_names_quick',
        'additional_charge_names_ecommerce',
    ];

    protected $casts = [
        'surge_labels' => 'array',
        'additional_charge_names_quick' => 'array',
        'additional_charge_names_ecommerce' => 'array',
    ];

    protected $hidden = ['created_at', 'updated_at'];

    public function zone()
    {
        return $this->belongsTo(Zone::class, 'zone_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}
