<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class UserAddress extends Model
{
    use HasFactory;

    protected $fillable = ['id','user_id','type','name','mobile','country_code','alternate_mobile','alternate_country_code','address','landmark','area','pincode','zone_id','city','state','region_id','country','latitude','longitude','is_default'];

    protected $casts = [
        'zone_id' => 'string',
    ];

    protected $hidden = ['user_id','created_at','updated_at'];

    public function region()
    {
        return $this->belongsTo(Region::class, 'region_id');
    }
}
