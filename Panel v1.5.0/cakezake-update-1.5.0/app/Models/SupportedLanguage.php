<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\LogsActivity;

class SupportedLanguage extends Model
{
    use HasFactory, LogsActivity;
    public $timestamps = false;
    protected $fillable = ['name','code','type'];

    public function getTypeAttribute($value)
    {
        return strtoupper($value);
    }
}
